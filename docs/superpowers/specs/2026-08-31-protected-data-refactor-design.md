# 保護資料重構：users 表 RPC-only 存取

日期：2026-08-31
狀態：待實作
負責：alice
前置關係：本 refactor 先做、merge 進 main 後，Google Maps 整合（2026-08-31-google-maps-integration）rebase 並縮減其 Task 1。

## 目的

區分「公開資料」（配對需要的）與「保護資料」（email、期望薪資、地理座標），讓 client 無法透過直接查 `users` 表拿到他人的保護資料。起因：Google Maps 整合 Task 1 發現 `users` 上有全域 SELECT policy，加上 view 遮蔽策略有 `security_invoker` 缺陷，欄位級保護在 Supabase RLS（row-level）下做不到。

## 資料分類

| 類別 | 欄位 | 存取方式 |
|---|---|---|
| 公開 | display_name, avatar_url, bio, location（文字）, skills, experience_years, company_name, company_size, role, status | 透過 RPC 回傳給任何登入者 |
| 保護 | email, expected_salary, lat, lng, formatted_address, location_updated_at | 只有本人或符合授權條件（matched）才能經 RPC 取得衍生值 |
| 已受保護（不動） | messages（match 雙方 RLS）、resume（未來） | 現有 row-level RLS 已足夠 |

`jobs` 是公開資料，不在本 refactor 範圍。

## Approach：單表 + RPC-only（做法 β）

決策過程：
- **α：單表 + 遮蔽 view** — 被否決。view 需要 `security_invoker` 細節正確，且 base table 的 SELECT policy 仍是漏洞面；Task 1 已實際踩雷。
- **Hybrid：拆 user_private / user_locations 三表** — 被否決。使用者選擇徹底方案；且未來後端（Java/gRPC）心智模型是「table 是私有實作、function 是公開介面」。
- **β：單表 + REVOKE + 全 RPC** — 採用。client 完全不能直接讀寫 `users`，所有存取經 SECURITY DEFINER function。

代價（已接受）：Flutter 所有 `users` 讀寫層重寫（見 Section 3）；`users` 上的 PostgREST embed join 一併失效，需改走 RPC。

### Salary 設計（已定案）

- 維持單欄 `users.expected_salary integer`（MVP；per-job override 留待未來有數據再開新 spec）
- 新增 `salary_visibility`：`'matched'`（配對成功後對方可見，預設）/ `'private'`（永遠只有本人）
- 滑卡卡片不再顯示薪資（`user_cards` 來源改為 `get_swipe_cards()`，不含 salary）— UX 變更已確認接受

### Email 設計（已定案）

`users.email` 欄位保留（單表），配對成功通知需要。透過 `get_user_contact()`，matched 的對方永遠可拿到 email；salary 另看 `salary_visibility`。

## Section 1: Schema

```sql
-- 不開新表，全部欄位留在 users
alter table users
  add column salary_visibility text not null default 'matched'
    check (salary_visibility in ('matched','private')),
  add column lat double precision,
  add column lng double precision,
  add column formatted_address text,
  add column location_updated_at timestamptz;

-- 核心：client 完全不能直接碰 users
revoke all on table users from authenticated, anon;

-- 配對判斷用 index（RPC 內部查 matches）
create index matches_lookup_idx on matches (job_seeker_id, employer_id, status);
```

- `users` 現有 RLS policy 保留作第二道防線（REVOKE 在 RLS 之前生效）。
- `jobs` / `matches` / `messages` 不動。
- 既有 `user_cards` view 移除（改由 `get_swipe_cards()` 取代）。

## Section 2: RPC catalog

全部 `SECURITY DEFINER` + `set search_path = public`（同 search_path_003 migration 模式）。授權檢查一律用 `auth.uid()`。

「matched」定義：`matches` 存在一列，(job_seeker_id, employer_id) 含雙方且 `status = 'accepted'`。

### 自己的資料

| Function | 簽名 | 行為 |
|---|---|---|
| `ensure_my_profile(p_email text)` | → users 完整列 | 無列則 insert（id=auth.uid(), email, role 預設），有則回傳。取代 auth repository 的 fetch-or-create |
| `get_my_profile()` | → users 完整列 | 只回 auth.uid() 自己的列 |
| `upsert_my_profile(...)` | 公開欄位 + expected_salary 各參數 → void | 只能更新自己；onboarding / 編輯 profile 用 |
| `upsert_my_location(p_lat, p_lng, p_formatted_address)` | → void | 只能更新自己；同時設 location_updated_at = now() |
| `set_salary_visibility(p_v text)` | → void | check p_v in ('matched','private') |

### 別人的資料（依關係過濾）

| Function | 回傳 | 授權邏輯 |
|---|---|---|
| `get_swipe_cards(p_role text, p_limit int)` | setof 公開欄位（不含 email/salary/座標） | 登入即可；取代 user_cards view，含既有排除邏輯（已滑過者不出現） |
| `get_user_public(p_target uuid)` | 公開欄位單筆 | 登入即可；match dialog / chat header / matches 列表用 |
| `get_user_contact(p_target uuid)` | (email text, expected_salary int) | 本人→全部；matched→email 一定回，salary 看對方 salary_visibility='matched'；否則兩者皆 null |
| `get_distance_km(p_target uuid)` | numeric | 任一方缺 lat/lng 回 null；只回衍生距離、不回座標 |

### Admin（現有後台直接 select users，REVOKE 後會壞）

| Function | 行為 |
|---|---|
| `admin_list_users(p_search text, p_limit int, p_offset int)` | 內部 `is_admin(auth.uid())` 檢查，否則 raise；回公開欄位 + email + status |
| `admin_set_user_status(p_target uuid, p_status text)` | 同上檢查；更新 status |

## Section 3: Flutter 重寫清單

1. `lib/features/auth/data/supabase_auth_repository.dart` — `_fetchOrCreateProfile` 改 `rpc('ensure_my_profile')`
2. `profileProvider` — 改 `rpc('get_my_profile')`
3. `lib/features/onboarding/onboarding_screen.dart` — 寫 users 改 `rpc('upsert_my_profile')`
4. swipe repository — `user_cards` view select 改 `rpc('get_swipe_cards')`；`UserCardModel` 移除 `expectedSalary`；`user_card.dart` 移除期望薪資顯示
5. matches / messages / match_dialog / chat 畫面 — 任何 `users` embed join（`users!inner(...)`）或直接 select 改 `rpc('get_user_public')`
6. `lib/features/admin/` users 畫面 — 改 admin RPC
7. profile 畫面新增「薪資可見度」開關（matched / private）→ `rpc('set_salary_visibility')`
8. Model：`UserModel` 加 `salaryVisibility`；freezed + build_runner 重跑

## Section 4: 測試 & Rollout

### 測試

**DB / RPC（SQL 層驗證，Supabase MCP execute_sql）**
- 以 authenticated 角色直接 `select * from users` → permission denied
- `get_user_contact`：非 matched → (null, null)；matched + visibility='matched' → 有值；matched + 'private' → email 有、salary null；本人 → 全部
- `get_swipe_cards` 回傳不含 email/salary/座標欄位
- `admin_list_users`：非 admin 呼叫 → raise exception

**Flutter**
- profileProvider / onboarding / swipe 流程 smoke test（既有畫面跑通）
- 滑卡卡片不再出現「期望 XXK」

### Rollout（pre-release，一次 cutover）

1. Migration `protected_data_007`（Supabase MCP apply_migration，project_id `klwsmonobcenfoyhkyuq`）：schema 變更 + REVOKE + 全部 RPC + drop `user_cards` view
2. Flutter 讀寫層改 RPC（同一 PR，因為 REVOKE 後舊碼直接壞，無相容期）
3. 手動驗證：登入 → onboarding → 滑卡 → 配對 → 聊天 → admin 後台
4. Merge main 後：google-maps-integration worktree `git reset --hard main`，Google Maps plan Task 1 縮減為只建 `commute_cache` + `edge_function_hits`（users 座標欄位本 refactor 已加）

## 未支援 / 未來擴充

- per-job salary override（`user_job_salary` 表）
- salary range（min/max）
- 經驗年細分（產業年資 / 現職年資）——本次不動 `experience_years`
- resume 上傳與其保護策略
- 全面 RPC 化其他表（jobs 等）——等 Java 後端立起來再評估
