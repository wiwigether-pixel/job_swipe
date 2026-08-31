# Google Maps 整合：距離與通勤時間

日期：2026-08-31
狀態：待實作
負責：alice

## 目的

在求職者滑卡與職缺詳情頁提供地理距離與通勤時間資訊，幫助雙方判斷是否值得投遞/聯絡。同時支援未來以距離為條件的搜尋/篩選。

## 使用情境

1. **滑卡當下**：求職者滑到每張職缺卡時，即時看到「距我 5.2 km」（直線距離）。0 API 成本。
2. **詳情頁**：點開職缺詳情、按「查看通勤時間」→ 顯示大眾運輸、開車、機車/自行車三種模式的預估時間。
3. **未來搜尋/篩選**（本 spec 不含 UI，但 schema 支援）：以直線距離做 DB 端排序與過濾。

## Approach

分層策略：
- **地址→座標**：求職者 onboarding 完成、雇主張貼職缺時，backend Edge Function 呼叫 Google Geocoding 一次，將 `lat/lng/formatted_address` 存到 `users` / `jobs` 表。
- **直線距離**：client 端用 Haversine 公式即時計算，0 成本。
- **實際通勤時間**：只在使用者主動點「查看通勤」時，backend Edge Function 呼叫 Distance Matrix。
- **快取**：`commute_cache` 表以 (origin_geohash6, dest_geohash6, mode) 為 key 快取 7 天，命中則不打 Google API。geohash6 精度 ~1.2 km，讓同區域出發者共享快取。

決策拒絕理由：
- **完全 heuristics（不接 Distance Matrix）** — 通勤時間估不準會失信任。
- **卡上直接顯示通勤時間（進 swipe 就 batch 算）** — API 用量高、需 aggressive cache，MVP 用不到；未來有數據再升級。

## Cost 與安全

Google Maps Platform 每個 SKU 每月 10,000 次免費呼叫（2025 新制，實際以 Google 官方定價頁為準）。本設計預估用量：

| SKU | 預估月用量 | 免費額度 |
|---|---|---|
| Geocoding | 600（500 新求職者 + 100 新職缺） | 10,000 |
| Distance Matrix | 2,000–5,000 elements（快取後） | 10,000 |
| Places Autocomplete | 不使用 | — |

**信用卡保護必做（release 前）**：
1. Google Cloud Console → Quotas：Geocoding 500/day、Distance Matrix 500/day（達額直接回錯、不扣款）
2. API key 加 Application restrictions：iOS/Android bundle ID + API restrictions（只允許 Geocoding + Distance Matrix）
3. Billing → Budget Alert 設 $1，超過寄 email
4. Edge Function 端 per-user rate-limit（同 user 15 秒 > 5 次同 endpoint 回 429），防惡意刷 quota

## Section 1: DB Schema

```sql
alter table users
  add column lat double precision,
  add column lng double precision,
  add column formatted_address text,
  add column location_updated_at timestamptz;

alter table jobs
  add column lat double precision,
  add column lng double precision,
  add column formatted_address text,
  add column location_updated_at timestamptz;

create table commute_cache (
  origin_geohash text not null,
  dest_geohash text not null,
  mode text not null check (mode in ('driving','transit','bicycling')),
  duration_seconds integer not null,
  distance_meters integer not null,
  cached_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  primary key (origin_geohash, dest_geohash, mode)
);
create index commute_cache_expires_at_idx on commute_cache (expires_at);
```

**設計決策：**
- `geohash6` ~1.2 km 精度，換取跨用戶快取共享。
- `expires_at` 而非查時計算，可用 index 做過期清理。
- `formatted_address` 讓 UI 可顯示「已驗證地址：xxx」。
- **RLS**：`users.lat / lng` 不對其他使用者曝露。求職者對雇主、雇主對求職者，都只能透過 Edge Function 拿到「距離/通勤時間」的衍生結果，不能直接讀對方座標。
  - RLS policy：`select` 除本人外遮蔽 `lat, lng` 欄位（用 view + `security_barrier` 或 column-level RLS）。

## Section 2: Backend（Supabase Edge Functions）

### Secret
```bash
supabase secrets set GOOGLE_MAPS_API_KEY=xxxxx
```
Client 端不放 key、不引 `google_maps_flutter`。

### Function 1: `geocode-address`

```
POST /functions/v1/geocode-address
Auth: 需 JWT
body: { address: string }

回應：
  200 { lat: number, lng: number, formatted_address: string }
  400 { error: "invalid_address" }
  404 { error: "address_not_found" }（ZERO_RESULTS）
  429 { error: "rate_limited" }
  502 { error: "upstream_error" }
```
- 呼叫 `https://maps.googleapis.com/maps/api/geocode/json?address=<url>&key=<secret>`
- 只回 3 個欄位，不透傳 Google 原始 response
- 呼叫端負責寫回 users/jobs 的 lat/lng/formatted_address/location_updated_at

### Function 2: `commute-time`

```
POST /functions/v1/commute-time
Auth: 需 JWT
body: {
  originLat, originLng,
  destLat, destLng,
  modes: ["driving","transit","bicycling"]  // 一到多個
}

回應：
  200 {
    driving:   { duration_seconds, distance_meters, approximated?: bool },
    transit:   { ... },
    bicycling: { ... }
  }
  502 { error: "upstream_error" }
```

流程：
1. 對 origin/dest 各算 geohash6
2. 查 `commute_cache`（三個 mode 分別查）— 命中且未過期直接回
3. 未命中的 mode 才呼叫 Distance Matrix
4. 寫回 `commute_cache`
5. 未來若前端傳 `motorcycle` mode → 用 `driving` 結果並回 `approximated: true`（Google 不支援 motorcycle）

### 通用行為
- Per-user rate-limit：Redis-style 表 `edge_function_hits(user_id, endpoint, ts)` 或用 upstash；同 user 15s > 5 次同 endpoint 回 429
- Google 端錯誤：statusCode / errorMessage log 到 Supabase logs，前端一律看到 502

## Section 3: Flutter 端

### 3.1 相依套件
```yaml
dependencies:
  dart_geohash: ^2.0.2   # 或等價套件；需與 Deno 端算法一致
```
不新增 `google_maps_flutter`（不畫地圖）、不新增 `geolocator`（不用即時 GPS）。

### 3.2 新 module `lib/features/location/`
```
location/
├── data/
│   ├── geocoding_service.dart      # 包 geocode-address Edge Function 呼叫
│   └── commute_service.dart         # 包 commute-time Edge Function 呼叫
├── domain/
│   ├── distance_utils.dart          # Haversine + geohash6 wrapper
│   └── commute_result.dart          # freezed model
└── providers/
    ├── location_providers.dart      # geocoding/commute service providers
    └── commute_provider.dart        # FutureProvider.family((from, to)) → CommuteResult
```

### 3.3 UI 修改點

**`onboarding_screen.dart`（求職者）**
- 地址 TextField 送出前 `await geocodingService.geocode(address)`
- 失敗顯示「找不到這個地址，請確認再送出」（不阻擋 onboarding，但強烈提示）
- 成功後 UI 顯示綠勾 + `formatted_address`（表示已驗證）
- 寫入 `users` 表帶入 `lat/lng/formatted_address/location_updated_at`

**`employer_jobs_screen.dart` 職缺表單**
- 同上邏輯，作用於 `jobs.location`
- 失敗時可儲存，但職缺卡不會顯示距離、通勤按鈕不可按

**`swipe_screen.dart` / `job_card.dart`**
- 進頁時把 `profileProvider.user.lat/lng` 拿到手
- 每張 job card 若 job.lat/lng 存在：`distanceUtils.haversineKm(user, job)` → 顯示「📍 5.2 km」
- 使用者無 lat/lng 或 job 無 lat/lng：顯示「📍 <location text>」保底，不顯示 km

**Job 詳情頁**
- 直線距離永遠顯示（用 Haversine）
- 「查看通勤時間」按鈕 → tap 觸發 `commuteProvider` → 三 mode 卡片
- Loading spinner、失敗顯示「暫時無法取得，稍後再試」重試按鈕

### 3.4 錯誤與離線
- Edge Function 錯 → UI 只顯示 Haversine + 錯誤 tooltip
- 無網路 → 一樣 fallback，Haversine 是純 client 算的

## Section 4: 測試 & Rollout

### 4.1 測試

**Edge Function（Deno test）**
- `geocode-address`：mock fetch，覆蓋成功 / ZERO_RESULTS / OVER_QUERY_LIMIT / 500，各回對應狀態碼與 body
- `commute-time`：
  - cache miss 呼叫 Google + 寫 cache
  - cache hit 完全不呼叫 Google
  - 部分 mode 命中部分未命中，只對未命中發 request
  - motorcycle mode → 回 driving + `approximated: true`
- Rate-limit：同 user 15s 第 6 次回 429

**Flutter 單元/widget test**
- `distance_utils.haversineKm`：台北 101 → 高雄小港 ~350 km，誤差 ±5%
- geohash6 client/server 一致（避免 cache miss 因 hash 不同）
- provider mocking：commuteProvider overrides → 驗詳情頁三段 mode UI

**Manual release-gate**
- 台北市內兩個地址通勤時間與 Google Maps App 比對 ±3 分鐘
- 網路斷線：卡上 haversine 仍顯示、詳情頁 gracefully 失敗
- 未帶 JWT curl Edge Function → 401
- API key 只在指定 bundle ID 有效

### 4.2 Rollout 順序

1. **DB migration**（Supabase MCP 直接跑，project_id `klwsmonobcenfoyhkyuq`）
   - 加欄位 + `commute_cache` + `users.lat/lng` RLS 遮蔽 policy
2. **Google Cloud 設定**
   - 啟用 Geocoding + Distance Matrix API
   - 建 key、設 quotas（各 500/day）、Application restrictions
   - `supabase secrets set GOOGLE_MAPS_API_KEY=...`
   - Billing budget alert $1
3. **部署 Edge Functions**：`geocode-address`、`commute-time`
4. **Backfill 腳本**（Deno + service role key）：對 `location is not null and lat is null` 的既有 users/jobs 分批 geocode（`limit 100` per batch，跑到清空）
5. **Ship Flutter**：先 onboarding + job 表單、後滑卡與詳情頁；可拆兩個 PR
6. **監控**：Supabase Edge Function 錯誤率 + Google Cloud Quota dashboard

### 4.3 隱私 / 合規
- Google Maps TOS：只長期儲存被允許欄位（lat/lng/formatted_address/duration/distance）；不存 place_id、photos、reviews
- 台灣 PDPA：既有隱私條款涵蓋地址收集；release notes 補一句「新增：以地址計算職缺距離與通勤時間」
- **雇主看不到求職者實際 lat/lng**（RLS 遮蔽）；反之亦然。只能透過 Edge Function 拿距離/時間衍生值。

## 未支援 / 未來擴充

- 距離篩選 UI（「10 km 內」slider）
- 卡上直接顯示通勤時間（Approach B）
- 地圖預覽（`google_maps_flutter` + Map SKU）
- 即時 GPS 位置（需要 permission handling + iOS/Android plist/manifest）
- 多國家/國際化地址（現階段以台灣為主，Geocoding region hint = `tw`）
