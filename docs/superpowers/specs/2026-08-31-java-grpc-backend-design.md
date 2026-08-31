# Java gRPC 後端 — 設計文件

日期：2026-08-31
狀態：已核可，待轉實作計畫

## 1. 背景與動機

現況：job_swipe 全部後端功能由 Supabase 提供（Auth / Postgres / Realtime / Storage），
Flutter 端直接呼叫 Supabase SDK，共 131 處散在 14 個檔案。

動機**不是** Supabase 有技術缺陷，而是：

1. 學習目標 — 實習公司使用 gRPC + Docker，想具備這兩項能力
2. 商業邏輯目前只能寫在 SQL function（如 `consume_job_quota()`），無法寫單元測試
3. 作品集需要一個自己寫的 Java 後端

**明確不是動機：省錢。** Supabase Free 方案本身免費（代價是 auto-pause 與容量上限）；
自架 Java 後端仍需要運算資源與資料庫，成本只是換地方付，並額外增加維運負擔。

### 非目標

- 不重寫 Auth（登入、註冊、session 繼續由 Supabase 管理）
- 不重寫 Realtime 聊天（繼續用 Supabase Realtime）
- 不重寫 Storage（頭像上傳繼續用 Supabase Storage）
- 不支援 Flutter Web 的 gRPC（需 gRPC-Web + Envoy proxy，複雜度與學習價值不成比例）
- 不做全面的 Flutter 分層重構（僅重構 jobs 相關路徑）

## 2. 架構

```
Flutter (iOS / Android)
├─ Supabase SDK ──────────> Supabase: Auth / Realtime(chat) / Storage
└─ gRPC over HTTP/2 ──────> Spring Boot :9090
                             ├─ AuthInterceptor   驗 Supabase JWT → userId 進 Context
                             ├─ JobGrpcService    薄轉接層（proto ⇄ domain）
                             ├─ JobService        商業邏輯 @Transactional
                             ├─ QuotaService      原子扣額度
                             └─ Spring Data JPA ──> 同一個 Supabase Postgres
                                （以 authenticated 角色連線，RLS 持續生效）
```

### 關鍵決定

**D1：不遷移資料庫。** Java 以 JDBC 直連現有 Supabase Postgres
（project_id `klwsmonobcenfoyhkyuq`）。零資料遷移；Flutter 舊路徑與 Java 新路徑可並存，
允許逐功能搬遷與隨時回滾。

**D2：Java 保留 RLS，不使用 service_role 繞過。**

Supabase 的 `auth.uid()` 底層讀取 Postgres session 設定 `request.jwt.claims`
（官方文件確認可直接設定）。因此 Java 端於每個交易開頭執行：

```sql
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"<JWT 取出的 userId>","role":"authenticated"}';
```

之後所有 SQL 受到與 Flutter 走 Supabase SDK 時**完全相同的 RLS 保護**。
這也是 Supabase 自身 PostgREST 採用的機制。

由此形成雙層防禦：

| 層 | 負責 |
|---|---|
| RLS（Postgres） | 這一列是不是你的 —— 漏寫檢查時兜底，回 0 列 |
| Java Service | 這個操作合不合商業規則 —— 例如額度必須 > 0，RLS 無法表達 |

Java 端仍會明確檢查資源擁有者，但那是第二層而非唯一防線。

**⚠️ 必要條件：必須是 `SET LOCAL` 且包在交易內。** Spring 使用 HikariCP 連線池，
若寫成 `SET`，身分會殘留於連線上，下一位使用者取得該連線時將沿用前一位的身分 ——
這會造成比繞過 RLS 更嚴重的漏洞。此點須以測試釘死（見第 6 節）。

**D3：額度邏輯由 SQL function 移至 Java。** 改為 `@Transactional` 服務，成為可單元測試的程式碼。

**D4：gRPC 僅覆蓋手機端。** 避免引入 Envoy proxy。protobuf、codegen、interceptor、
Docker 化等學習目標在 mobile-only 下皆可完整達成。

**D5：身分僅來自 JWT。** proto 中所有 request 皆不含 `user_id` / `employer_id` 欄位，
client 無法宣稱自己是誰。

## 3. 現有架構 Review

完整盤點結果，作為本次範圍的依據。

### 安全問題（與 Java 無關，Phase 0 獨立修復）

**S1（🔴 權限提升）** `campaign_screen.dart:76` 呼叫
`rpc('add_job_quota', params: {'p_amount': 3})`。該函式為 SECURITY DEFINER 但金額由 client 決定，
任何使用者可傳入任意數值取得無限刊登額度。

**S2（🟠 單點防禦）** 八處寫入無擁有者條件，完全仰賴 RLS（分布於三個檔案）：

| 位置 | 操作 |
|---|---|
| `employer_jobs_screen.dart:72` | 更新職缺，僅 `.eq('id', jobId)` |
| `employer_jobs_screen.dart:83` | 刪除職缺，僅 `.eq('id', jobId)` |
| `employer_jobs_screen.dart:93` | 切換職缺狀態，僅 `.eq('id', jobId)` |
| `matches_screen.dart:70,80` | 接受／拒絕配對，僅 `.eq('id', matchId)` |
| `supabase_swipe_repository.dart:137,169,187` | 更新配對為 accepted，僅 `.eq('id', ...)` |

目前 RLS 有擋住，**非 live 漏洞** —— 這正是 RLS 的價值展現。
補上擁有者條件是為了形成雙層防禦（見 D2），而非因為現況不安全。

注意：S1 與 S2 皆非 RLS 的能力不足。S1 是 SECURITY DEFINER 函式開了 RLS 之外的後門，
S2 在 RLS 下本來就是安全的。Supabase 的授權機制本身可靠，本設計因此選擇保留而非取代它。

### 架構問題

**A1** Screen 兼任 data source。6 個畫面直接呼叫 Supabase。
`employer_jobs_screen.dart` 989 行、`profile_screen.dart` 853 行。
lib/ 中所有超過 300 行的檔案（共 10 個）皆為 presentation 層。

**A2** `Supabase.instance.client.auth.currentUser` 散落 20+ 處，未集中。

**A3** matches / messages / reports / admin 資料以 `Map<String, dynamic>` 傳遞，
無 freezed model。僅 user / job / user_card 有型別。

**A4** 測試覆蓋率為 0。`test/` 僅有一個空的 `widget_test.dart`。

**A5** `SwipeRepository` domain 介面宣告回傳 `JobModel`，實作實際回傳 `SwipeCard`，介面與實作不符。

### 可沿用的既有模式

`auth_repository.dart`（domain 介面）+ `supabase_auth_repository.dart`（data 實作）
+ `ErrorHandler.handle()` 的組合是乾淨的分層範例。本次新增的 repository 一律照此模板，不另創模式。

### 本次範圍

- Phase 0 修復 S1、S2、A2
- Phase 1–4 完成 jobs + 額度的 Java/gRPC 切片，過程中修復 A1（僅 employer_jobs_screen），並建立測試基礎（部分解決 A4）
- A3、A5 及其餘畫面的分層重構**不在本次範圍**

## 4. gRPC 契約

單一真相來源，同時產出 Java server stub 與 Dart client stub。

```protobuf
syntax = "proto3";
package jobswipe.job.v1;

import "google/protobuf/timestamp.proto";

service JobService {
  rpc ListMyJobs   (ListMyJobsRequest)   returns (ListMyJobsResponse);
  rpc CreateJob    (CreateJobRequest)    returns (Job);
  rpc UpdateJob    (UpdateJobRequest)    returns (Job);
  rpc DeleteJob    (DeleteJobRequest)    returns (DeleteJobResponse);
  rpc SetJobStatus (SetJobStatusRequest) returns (Job);
}

service QuotaService {
  rpc GetQuota     (GetQuotaRequest)     returns (QuotaResponse);
  rpc JoinCampaign (JoinCampaignRequest) returns (QuotaResponse);
}

message Job {
  string id = 1;
  string employer_id = 2;
  string title = 3;
  string description = 4;
  string location = 5;
  int32  salary_min = 6;
  int32  salary_max = 7;
  JobStatus status = 8;
  google.protobuf.Timestamp created_at = 9;
  google.protobuf.Timestamp updated_at = 10;
}

enum JobStatus {
  JOB_STATUS_UNSPECIFIED = 0;
  OPEN = 1;
  CLOSED = 2;
}

message JoinCampaignRequest { string campaign_id = 1; }
message QuotaResponse { int32 remaining = 1; }
```

### 契約設計要點

- 所有 request 不含呼叫者身分欄位（見 D5）
- `JoinCampaignRequest` 不含金額欄位，加多少由 server 依 `campaign_id` 決定（修復 S1）
- `status` 使用 enum 而非字串，型別錯誤在編譯期即被攔截
- `Job` 欄位對應現有 `jobs` 表：id, employer_id, title, description, location,
  salary_min, salary_max, status, created_at, updated_at

### 錯誤對應

| 情況 | gRPC status | Flutter 行為 |
|---|---|---|
| JWT 無效或過期 | `UNAUTHENTICATED` | 導向登入 |
| 操作非本人資源 | `PERMISSION_DENIED` | 顯示錯誤訊息 |
| 刊登額度不足 | `RESOURCE_EXHAUSTED` | 拋 `JobQuotaExceeded`，彈出活動對話框 |
| 資源不存在 | `NOT_FOUND` | 顯示錯誤訊息 |
| 欄位驗證失敗 | `INVALID_ARGUMENT` | 顯示表單錯誤 |

## 5. 實作階段

### Phase 0 — 安全修補（純 Dart + SQL）

不涉及 Java。先讓現有 App 站穩，使後續階段即使中止亦有獨立價值。

- 新增 migration：以 `join_campaign(p_campaign_id text)` 取代 `add_job_quota(p_amount)`，
  金額由 DB 端 campaign 對照表決定；移除舊函式
- `campaign_screen.dart` 改呼叫新函式
- S2 的八處寫入補上擁有者條件（RLS 保留，形成雙層防禦）
- `AuthRepository` 新增 `currentUserId` getter，20+ 處改為由此取得（A2）

驗收：舊 `add_job_quota` 已不存在；以他人 id 嘗試更新職缺／配對回傳 0 列。

### Phase 1 — Java 骨架

**第一個任務：確認 Supabase JWT 簽章方式。**
Supabase 支援 HS256 共用密鑰與非對稱金鑰（JWKS）兩種，本專案採用何者將決定
`AuthInterceptor` 的驗證實作。必須連上 Supabase 專案設定確認，不得臆測。

- Spring Boot + Gradle 專案骨架
- protobuf codegen（Java）
- `net.devh:grpc-spring-boot-starter`
- `AuthInterceptor`：驗 Supabase JWT 簽章與有效期，取出 `sub` 作為 userId 存入 gRPC Context
- 一支 `Ping` rpc 供端到端驗證
- **RLS 連線機制**：實作交易層級的身分注入
  （`SET LOCAL ROLE authenticated` + `SET LOCAL request.jwt.claims`，見 D2）。
  以 `authenticated` 角色而非 service_role 連線
- 多階段 Dockerfile（build → JRE runtime）+ `docker-compose.yml`（app + 本機 Postgres 供測試）

驗收：
1. `docker compose up` 後，以 `grpcurl` 帶有效 token 呼叫 `Ping` 成功；
   不帶 token 或帶偽造 token 回傳 `UNAUTHENTICATED`
2. 連線池污染測試通過（見第 6 節）—— 此項未過不得進入 Phase 2

### Phase 2 — 商業邏輯

- `Job` JPA entity + repository，對應現有 `jobs` 表
- `JobService`：每個異動方法明確檢查 `job.employerId == callerId`，
  不符回傳 `PERMISSION_DENIED`；資源不存在回傳 `NOT_FOUND`
- `QuotaService`：
  - 扣除以單一原子語句實作
    `UPDATE users SET free_job_quota = free_job_quota - 1 WHERE id = ? AND free_job_quota > 0`，
    影響列數為 0 時拋 `RESOURCE_EXHAUSTED`
  - `CreateJob` 於同一 `@Transactional` 中扣額度並寫入職缺，任一失敗全部回滾
  - campaign 金額對照表置於 `application.yml`
- `GrpcExceptionHandler`：domain 例外對應至第 4 節的 gRPC status

### Phase 3 — Flutter 接上

- protobuf codegen（Dart）
- `JobRepository` domain 介面 + `GrpcJobRepository` 實作，照 `auth_repository` 模板
- gRPC channel 設定；每次呼叫由 metadata 附上 Supabase access token
- `employer_jobs_screen.dart` 移除所有 Supabase 呼叫，改用 repository（A1）
- 保留既有 Supabase 實作為第二個 `JobRepository` impl。回滾機制由介面免費提供：
  出問題時只需更換 provider 綁定一行，不需要額外的 feature flag

驗收：職缺列表、新增、編輯、刪除、開關狀態、額度顯示、參加活動加額度，全數走 gRPC 且行為與改版前一致。

### Phase 4 — 上雲

- 部署至 Fly.io（支援 HTTP/2 backend，gRPC 無需改動）
- TLS 設定
- DB 連線字串與 JWT 驗證金鑰以 secrets 注入，不進 git

## 6. 測試策略

| 層 | 工具 | 覆蓋重點 |
|---|---|---|
| Service | JUnit 5 + Mockito | 額度不足時擋下建立、操作他人資源被拒 |
| Repository | JUnit 5 + Testcontainers（真 Postgres） | 併發扣額度不會扣成負數 |
| **連線池隔離** | **Testcontainers + 啟用 RLS 的測試 schema** | **身分不會跨請求殘留** |
| gRPC | in-process server | domain 例外正確對應 status code、interceptor 擋下無效 token |

兩項需要真實資料庫、mock 測不出來的重點：

**併發扣額度** —— 額度扣除是典型競態情境（兩個請求同時到達是否都成功）。

**連線池隔離（D2 的必要條件）** —— 測試設計：以使用者 A 的身分執行一次請求，
歸還連線後以使用者 B 的身分執行第二次請求，斷言 B **看不到** A 的資料。
連線池大小設為 1 以強制重用同一條連線。若身分誤用 `SET` 而非 `SET LOCAL`，此測試必然失敗。

Flutter 端於 Phase 3 為 `JobRepository` 建立第一組 repository 測試，
作為日後擴展測試覆蓋的基礎（部分解決 A4）。

## 7. 風險

| 風險 | 對策 |
|---|---|
| 連線池身分殘留（誤用 `SET` 而非 `SET LOCAL`）| 最嚴重的風險。以連線池隔離測試釘死，且列為 Phase 1 的進入下一階段門檻 |
| Java 端授權寫錯 | RLS 作為第二層兜底；每個異動 rpc 仍強制擁有者檢查，並以測試覆蓋「操作他人資源」情境 |
| Supabase 免費專案 auto-pause 導致 Java 連線逾時 | 開發時先 restore 專案；連線設定合理 timeout 與重試 |
| JWT 簽章方式判斷錯誤導致驗證失效 | Phase 1 第一個任務即為連線確認，不臆測 |
| 新舊路徑並存造成行為不一致 | 一次只搬一個功能；舊實作保留可即時切回 |
