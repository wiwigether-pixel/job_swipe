# Protected-Data Refactor (users RPC-only) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Client 完全不能直接讀寫 `users` 表；所有存取改經 SECURITY DEFINER RPC，保護 email / expected_salary / 座標。

**Architecture:** 單表 + REVOKE + 全 RPC（spec 做法 β）。先建齊 15 個 RPC（DB Task 1-4），再把 Flutter 所有 `users` 讀寫層與 embed join 改走 RPC（Task 5-11），最後才 REVOKE 斷開直接存取並跑完整驗證（Task 12-13）。pre-release 一次 cutover，無相容期。

**Tech Stack:** Supabase（Postgres SECURITY DEFINER functions, MCP `apply_migration`/`execute_sql`）、Flutter + Riverpod codegen + freezed。

**Spec:** `docs/superpowers/specs/2026-08-31-protected-data-refactor-design.md`

## Global Constraints

- 跑任何 flutter/dart 指令前：`export PATH="/opt/homebrew/bin:/Users/alice/dev/tooling/flutter/bin:$PATH"`
- Supabase MCP project_id = `klwsmonobcenfoyhkyuq`（免費版會 auto-pause；連線 timeout 就先 `restore_project` 再重試）
- 所有 DB 函式一律 `security definer set search_path = public`（同 search_path_003 模式）
- 改了 provider / freezed model 後必跑：`dart run build_runner build --delete-conflicting-outputs`
- 每個 DB task：migration 用 MCP `apply_migration` 套用，同時把相同 SQL 存進 repo `sql/` 目錄並 commit
- **執行順序不可換**：REVOKE（Task 12）必須在所有 Flutter 改寫完成後才執行
- 「matched」定義：`matches.status='accepted'` 且雙方出現在 (job_seeker_id, employer_id) **或** (initiator_id, target_user_id)（peer 配對用後者，spec 只寫了前者，本 plan 補上 peer 形狀）
- 事前狀態（已用 live DB 確認）：`users` 已有 lat/lng/formatted_address/location_updated_at（location_006 已套用）；存在待清除的 `users_public`（有 security_invoker 缺陷）與 `user_cards`（洩漏 email + expected_salary）兩個 view；`matches` 無 lookup index

### DB 測試 harness（Task 1-4、12 共用）

用 MCP `execute_sql` 一次送整段 script（同 session）。模擬 authenticated 使用者：

```sql
begin;
-- 先另外跑 select id, role from users limit 3; 挑兩個真實 id 代入 :USER_A / :USER_B
-- （users.id 可能 FK 到 auth.users，不要捏造 id）
update users set expected_salary = 55000, salary_visibility = 'matched' where id = ':USER_A';
insert into matches (job_seeker_id, employer_id, initiator_id, status)
values (':USER_A', ':USER_B', ':USER_A', 'accepted');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":":USER_B","role":"authenticated"}', true);

-- ...測試查詢...

rollback;
```

`rollback` 保證不留測試資料。若 execute_sql 拒絕顯式 transaction，改成：測完後以 postgres 身分手動 `delete from matches where ...` + 還原 update 的欄位。

---

### Task 1: DB — schema、清除 view、matched helper

**Files:**
- Create: `sql/protected_data_007_schema.sql`（migration 同內容）

**Interfaces:**
- Produces: `users.salary_visibility text`（'matched'|'private'，default 'matched'）；`is_matched_with(p_a uuid, p_b uuid) returns boolean`（後續 RPC 用）；`user_cards` / `users_public` view 消失

- [ ] **Step 1: 以 MCP `apply_migration` 套用 migration（name: `protected_data_007_schema`）**

```sql
-- salary visibility（座標欄位 location_006 已加過，用 if not exists 保險）
alter table users
  add column if not exists salary_visibility text not null default 'matched'
    check (salary_visibility in ('matched','private')),
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists formatted_address text,
  add column if not exists location_updated_at timestamptz;

-- 洩漏源頭：user_cards 含 email + expected_salary；users_public 是 Task 1 踩雷遺留
drop view if exists user_cards;
drop view if exists users_public;

-- 配對判斷 index（job 配對形狀 + peer 配對形狀）
create index if not exists matches_lookup_idx
  on matches (job_seeker_id, employer_id, status);
create index if not exists matches_peer_lookup_idx
  on matches (initiator_id, target_user_id, status);

-- matched 判斷 helper（含 peer 形狀）
create or replace function is_matched_with(p_a uuid, p_b uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from matches m
    where m.status = 'accepted'
      and ((m.job_seeker_id = p_a and m.employer_id = p_b)
        or (m.job_seeker_id = p_b and m.employer_id = p_a)
        or (m.initiator_id = p_a and m.target_user_id = p_b)
        or (m.initiator_id = p_b and m.target_user_id = p_a))
  );
$$;
```

- [ ] **Step 2: 驗證**

Run（execute_sql）：
```sql
select column_name from information_schema.columns
 where table_name='users' and column_name='salary_visibility';
select viewname from pg_views where schemaname='public';
select to_regprocedure('public.is_matched_with(uuid,uuid)');
```
Expected：salary_visibility 存在；pg_views 回空（兩個 view 都沒了）；to_regprocedure 非 null。

- [ ] **Step 3: 用 harness 測 is_matched_with**

兩個真實 id 插一筆 accepted match（job 形狀）→ `select is_matched_with(':USER_A', ':USER_B')` = true、對調也 true、無關第三人 = false；再測 peer 形狀（insert initiator_id/target_user_id + match_type='user'）= true。全部包在 begin/rollback。

- [ ] **Step 4: 存 `sql/protected_data_007_schema.sql` 並 commit**

```bash
git add sql/protected_data_007_schema.sql
git commit -m "feat(db): salary_visibility + drop leaky views + is_matched_with helper"
```

---

### Task 2: DB — 自己資料的 RPC（5 個）

**Files:**
- Create: `sql/protected_data_007_self_rpcs.sql`

**Interfaces:**
- Consumes: Task 1 的 schema
- Produces（Flutter Task 6/7/11 依賴這些名稱與參數名）:
  - `ensure_my_profile(p_email text, p_display_name text default null, p_role text default null) returns users` — 單一 object
  - `get_my_profile() returns setof users` — PostgREST 回 JSON array（0 或 1 筆）
  - `upsert_my_profile(p_fields jsonb) returns void` — key 出現才更新（value 可為 null＝清空）
  - `upsert_my_location(p_lat double precision, p_lng double precision, p_formatted_address text) returns void`
  - `set_salary_visibility(p_visibility text) returns void`

- [ ] **Step 1: 以 `apply_migration` 套用（name: `protected_data_007_self_rpcs`）**

```sql
-- 1) fetch-or-create（取代 auth repo 的 select+insert）
create or replace function ensure_my_profile(
  p_email text,
  p_display_name text default null,
  p_role text default null
) returns users
language plpgsql security definer set search_path = public
as $$
declare
  v_row users;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_row from users where id = auth.uid();
  if found then return v_row; end if;
  insert into users (id, email, display_name, role)
  values (
    auth.uid(),
    coalesce(p_email, ''),
    coalesce(nullif(p_display_name, ''), '未命名'),
    coalesce(p_role, 'job_seeker')
  )
  returning * into v_row;
  return v_row;
end;
$$;

-- 2) 讀自己完整列（含 email/salary/quota/座標）
create or replace function get_my_profile()
returns setof users
language sql stable security definer set search_path = public
as $$
  select * from users where id = auth.uid();
$$;

-- 3) 更新自己的公開欄位 + expected_salary（jsonb：key 存在才更新，值可為 null）
create or replace function upsert_my_profile(p_fields jsonb)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if exists (
    select 1 from jsonb_object_keys(p_fields) k
    where k not in ('display_name','avatar_url','bio','location','skills',
                    'experience_years','expected_salary','company_name',
                    'company_size','role')
  ) then
    raise exception 'invalid field in p_fields';
  end if;
  if p_fields ? 'role'
     and p_fields->>'role' not in ('job_seeker','employer','peer') then
    raise exception 'invalid role';
  end if;

  update users set
    display_name = case when p_fields ? 'display_name' then p_fields->>'display_name' else display_name end,
    avatar_url   = case when p_fields ? 'avatar_url'   then p_fields->>'avatar_url'   else avatar_url end,
    bio          = case when p_fields ? 'bio'          then p_fields->>'bio'          else bio end,
    location     = case when p_fields ? 'location'     then p_fields->>'location'     else location end,
    skills       = case when p_fields ? 'skills' then
                     case when jsonb_typeof(p_fields->'skills') = 'array'
                       then (select coalesce(array_agg(e), '{}') from jsonb_array_elements_text(p_fields->'skills') e)
                       else null end
                   else skills end,
    experience_years = case when p_fields ? 'experience_years' then (p_fields->>'experience_years')::int else experience_years end,
    expected_salary  = case when p_fields ? 'expected_salary'  then (p_fields->>'expected_salary')::int  else expected_salary end,
    company_name = case when p_fields ? 'company_name' then p_fields->>'company_name' else company_name end,
    company_size = case when p_fields ? 'company_size' then p_fields->>'company_size' else company_size end,
    role         = case when p_fields ? 'role'         then p_fields->>'role'         else role end,
    updated_at   = now()
  where id = auth.uid();
end;
$$;

-- 4) 更新自己的座標（Google Maps 整合用；本次先建好）
create or replace function upsert_my_location(
  p_lat double precision,
  p_lng double precision,
  p_formatted_address text
) returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update users set
    lat = p_lat, lng = p_lng,
    formatted_address = p_formatted_address,
    location_updated_at = now(),
    updated_at = now()
  where id = auth.uid();
end;
$$;

-- 5) 薪資可見度
create or replace function set_salary_visibility(p_visibility text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_visibility not in ('matched','private') then
    raise exception 'invalid visibility';
  end if;
  update users set salary_visibility = p_visibility, updated_at = now()
  where id = auth.uid();
end;
$$;
```

- [ ] **Step 2: harness 驗證（begin/rollback 包住）**

以 :USER_A 身分：
- `select * from get_my_profile();` → 回 1 筆且 id = :USER_A
- `select upsert_my_profile('{"bio":"harness test","expected_salary":12345}'::jsonb);` 後 get_my_profile 的 bio/expected_salary 更新
- `select upsert_my_profile('{"expected_salary":null}'::jsonb);` → expected_salary 變 null（清空語意）
- `select upsert_my_profile('{"email":"x@x.com"}'::jsonb);` → raise "invalid field"（email 不可經此改）
- `select set_salary_visibility('private');` → salary_visibility='private'；`select set_salary_visibility('xxx');` → raise
- `select upsert_my_location(25.03, 121.56, '台北市');` → lat/lng/formatted_address/location_updated_at 皆有值

Expected：全部符合。ensure_my_profile 用既有 user 測「有列直接回傳」即可（insert 分支靠 code review，避免在 auth.users 造假帳號）。

- [ ] **Step 3: 存 `sql/protected_data_007_self_rpcs.sql` 並 commit**

```bash
git add sql/protected_data_007_self_rpcs.sql
git commit -m "feat(db): self-data RPCs (ensure/get/upsert profile, location, salary visibility)"
```

---

### Task 3: DB — 讀別人資料的 RPC（5 個）

**Files:**
- Create: `sql/protected_data_007_read_rpcs.sql`

**Interfaces:**
- Consumes: `is_matched_with(uuid, uuid)`（Task 1）
- Produces（Flutter Task 8/9/10 依賴）:
  - `get_swipe_cards(p_role text, p_limit int default 20)` → setof 卡片列（欄位見下；**不含** email/expected_salary/座標）。`p_role` = 觀看者當前身份：`'employer'` 回 is_open_to_opportunity 的求職者；`'peer'` 回 is_open_to_exchange 的同業（技能重疊或觀看者無技能）
  - `get_user_public(p_target uuid)` → setof 公開欄位單筆
  - `get_users_public(p_ids uuid[])` → setof 公開欄位（batch，取代 embed join）
  - `get_user_contact(p_target uuid)` → `(email text, expected_salary integer)` 單筆
  - `get_distance_km(p_target uuid)` → numeric（可 null）

- [ ] **Step 1: 以 `apply_migration` 套用（name: `protected_data_007_read_rpcs`）**

```sql
-- 1) 滑卡：取代 user_cards view（原 view = user_profiles join users where is_complete）
--    差異：不再回 email / expected_salary；swiped 排除與自我排除移進函式
create or replace function get_swipe_cards(p_role text, p_limit int default 20)
returns table (
  id uuid, user_id uuid, role text, display_name text, avatar_url text,
  bio text, skills text[], company_name text, company_size text,
  is_open_to_opportunity boolean, is_open_to_exchange boolean
)
language sql stable security definer set search_path = public
as $$
  select up.id, up.user_id, up.role, up.display_name, u.avatar_url,
         up.bio, up.skills, up.company_name, up.company_size,
         up.is_open_to_opportunity, up.is_open_to_exchange
  from user_profiles up
  join users u on u.id = up.user_id
  where up.is_complete = true
    and up.user_id <> auth.uid()
    and not exists (
      select 1 from swipes s
      where s.swiper_id = auth.uid()
        and s.target_id = up.user_id
        and s.target_type = 'user')
    and case p_role
          when 'employer' then up.role = 'job_seeker' and up.is_open_to_opportunity
          when 'peer' then up.is_open_to_exchange
            and (
              coalesce((select u2.skills from users u2 where u2.id = auth.uid()), '{}') = '{}'
              or (select u2.skills from users u2 where u2.id = auth.uid()) && up.skills
            )
          else false
        end
  limit p_limit;
$$;

-- 2) 單筆公開資料
create or replace function get_user_public(p_target uuid)
returns table (
  id uuid, display_name text, avatar_url text, bio text, location text,
  skills text[], experience_years int, company_name text, company_size text,
  role text, status text
)
language sql stable security definer set search_path = public
as $$
  select u.id, u.display_name, u.avatar_url, u.bio, u.location,
         u.skills, u.experience_years, u.company_name, u.company_size,
         u.role, u.status
  from users u where u.id = p_target;
$$;

-- 3) batch 公開資料（取代所有 users embed join）
create or replace function get_users_public(p_ids uuid[])
returns table (
  id uuid, display_name text, avatar_url text, bio text, location text,
  skills text[], experience_years int, company_name text, company_size text,
  role text, status text
)
language sql stable security definer set search_path = public
as $$
  select u.id, u.display_name, u.avatar_url, u.bio, u.location,
         u.skills, u.experience_years, u.company_name, u.company_size,
         u.role, u.status
  from users u where u.id = any(p_ids);
$$;

-- 4) 聯絡資訊：本人→全部；matched→email 一定回、salary 看對方設定；否則 (null,null)
create or replace function get_user_contact(p_target uuid)
returns table (email text, expected_salary integer)
language plpgsql stable security definer set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_target = auth.uid() then
    return query select u.email, u.expected_salary from users u where u.id = p_target;
  elsif is_matched_with(auth.uid(), p_target) then
    return query
      select u.email,
             case when u.salary_visibility = 'matched' then u.expected_salary
                  else null end
      from users u where u.id = p_target;
  else
    return query select null::text, null::integer;
  end if;
end;
$$;

-- 5) 衍生距離（不回座標）；任一方缺座標回 null
create or replace function get_distance_km(p_target uuid)
returns numeric
language sql stable security definer set search_path = public
as $$
  select case
    when me.lat is null or me.lng is null or t.lat is null or t.lng is null then null
    else round((6371 * acos(least(1.0, greatest(-1.0,
      cos(radians(me.lat)) * cos(radians(t.lat)) * cos(radians(t.lng) - radians(me.lng))
      + sin(radians(me.lat)) * sin(radians(t.lat))))))::numeric, 1)
  end
  from users me, users t
  where me.id = auth.uid() and t.id = p_target;
$$;
```

- [ ] **Step 2: harness 驗證（begin/rollback）**

- `get_swipe_cards`：以雇主身分呼叫 `select * from get_swipe_cards('employer', 20);` → 回傳列不含 email/expected_salary/lat/lng 欄位（函式簽名保證，跑通即可）；確認不含自己 user_id
- `get_user_contact` 四象限：
  1. 非 matched 的 :USER_B 查 :USER_A → `(null, null)`
  2. 插 accepted match 後再查 → `('a的email', 55000)`（:USER_A salary_visibility='matched'）
  3. `update users set salary_visibility='private' where id=':USER_A'` 後再查 → `('a的email', null)`
  4. :USER_A 查自己 → email + salary 都有
- `get_users_public(array[':USER_A',':USER_B']::uuid[])` → 2 筆，無 email 欄位
- `get_distance_km`：兩人都設 lat/lng（如台北/高雄）→ 約 300km 上下的數字；清掉一方座標 → null

- [ ] **Step 3: 存 `sql/protected_data_007_read_rpcs.sql` 並 commit**

```bash
git add sql/protected_data_007_read_rpcs.sql
git commit -m "feat(db): relation-gated read RPCs (swipe cards, public, contact, distance)"
```

---

### Task 4: DB — Admin RPC（5 個）

**Files:**
- Create: `sql/protected_data_007_admin_rpcs.sql`

**Interfaces:**
- Consumes: 既有 `is_admin(uuid)` / `is_super_admin(uuid)`（admin_001 已建）
- Produces（Flutter Task 10 依賴）:
  - `admin_stats()` → `(total_users bigint, job_seekers bigint, employers bigint)` 單筆
  - `admin_list_users(p_search text default '', p_role text default null, p_limit int default 100, p_offset int default 0)` → setof (id, email, role, display_name, avatar_url, status, created_at)
  - `admin_set_user_status(p_target uuid, p_status text)` → void
  - `admin_delete_user(p_target uuid)` → void（**super_admin only**，對齊既有 RLS「super_admin 刪除用戶」）
  - `admin_get_users(p_ids uuid[])` → setof (id, display_name, email, avatar_url, company_name)（reports/inbox/jobs 畫面 hydration 用）

- [ ] **Step 1: 以 `apply_migration` 套用（name: `protected_data_007_admin_rpcs`）**

```sql
create or replace function admin_stats()
returns table (total_users bigint, job_seekers bigint, employers bigint)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not is_admin(auth.uid()) then raise exception 'not admin'; end if;
  return query
    select count(*),
           count(*) filter (where u.role = 'job_seeker'),
           count(*) filter (where u.role = 'employer')
    from users u;
end;
$$;

create or replace function admin_list_users(
  p_search text default '',
  p_role text default null,
  p_limit int default 100,
  p_offset int default 0
)
returns table (
  id uuid, email text, role text, display_name text,
  avatar_url text, status text, created_at timestamptz
)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not is_admin(auth.uid()) then raise exception 'not admin'; end if;
  return query
    select u.id, u.email, u.role, u.display_name, u.avatar_url, u.status, u.created_at
    from users u
    where (p_search = '' or u.display_name ilike '%' || p_search || '%'
                         or u.email ilike '%' || p_search || '%')
      and (p_role is null or u.role = p_role)
    order by u.created_at desc
    limit p_limit offset p_offset;
end;
$$;

create or replace function admin_set_user_status(p_target uuid, p_status text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not is_admin(auth.uid()) then raise exception 'not admin'; end if;
  update users set status = p_status, updated_at = now() where id = p_target;
end;
$$;

create or replace function admin_delete_user(p_target uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not is_super_admin(auth.uid()) then raise exception 'not super admin'; end if;
  delete from users where id = p_target;
end;
$$;

create or replace function admin_get_users(p_ids uuid[])
returns table (id uuid, display_name text, email text, avatar_url text, company_name text)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not is_admin(auth.uid()) then raise exception 'not admin'; end if;
  return query
    select u.id, u.display_name, u.email, u.avatar_url, u.company_name
    from users u where u.id = any(p_ids);
end;
$$;
```

- [ ] **Step 2: harness 驗證（begin/rollback）**

- 以**非 admin** 使用者身分：`select * from admin_stats();` → raise "not admin"；`admin_list_users()` / `admin_get_users(...)` 同樣 raise
- 以 admin 使用者（`select user_id from admin_roles limit 1;` 取真實 admin id 當 sub）：admin_stats 回 1 筆合理數字；admin_list_users('') 回列表含 email；`admin_set_user_status(':USER_A', 'active')` 成功（rollback 還原）
- moderator（若有）呼叫 `admin_delete_user` → raise "not super admin"

- [ ] **Step 3: 存 `sql/protected_data_007_admin_rpcs.sql` 並 commit**

```bash
git add sql/protected_data_007_admin_rpcs.sql
git commit -m "feat(db): admin RPCs (stats, list, status, delete, batch get)"
```

---

### Task 5: Flutter — Model 更新（UserModel / UserCardModel）

**Files:**
- Modify: `lib/shared/models/user_model.dart`
- Modify: `lib/shared/models/user_card_model.dart`
- Regenerate: `*.freezed.dart` / `*.g.dart`（build_runner）

**Interfaces:**
- Produces: `UserModel.salaryVisibility`（String，default 'matched'）；`UserCardModel` **不再有** `expectedSalary`（Task 8 依賴）

- [ ] **Step 1: `user_model.dart` 加 salaryVisibility**

factory 內（`companySize` 之後）加：
```dart
    @Default('matched') String salaryVisibility,
```
`fromSupabase` 內（`companySize:` 之後）加：
```dart
      salaryVisibility: row['salary_visibility'] as String? ?? 'matched',
```

- [ ] **Step 2: `user_card_model.dart` 移除 expectedSalary**

刪掉 factory 的 `int? expectedSalary,` 與 `fromSupabase` 的 `expectedSalary: row['expected_salary'] as int?,` 兩行。

- [ ] **Step 3: 跑 codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 成功。此時 `flutter analyze` 會在 `user_card.dart` 報 expectedSalary 錯誤 — 那是 Task 8 的工作，本 task 只要 build_runner 成功即可。

- [ ] **Step 4: Commit**

```bash
git add lib/shared/models/user_model.dart lib/shared/models/user_card_model.dart lib/shared/models/*.freezed.dart lib/shared/models/*.g.dart
git commit -m "feat(model): UserModel.salaryVisibility; drop UserCardModel.expectedSalary"
```

---

### Task 6: Flutter — 自己資料的「讀」改 RPC

**Files:**
- Modify: `lib/features/auth/data/supabase_auth_repository.dart:152-202`（`_fetchOrCreateProfile`）
- Modify: `lib/core/providers/profile_provider.dart`（Stream → Future + RPC）
- Modify: `lib/features/profile/presentation/employer_jobs_screen.dart:15-24`（`freeJobQuotaProvider`）
- Regenerate: `lib/core/providers/profile_provider.g.dart`

**Interfaces:**
- Consumes: `ensure_my_profile` / `get_my_profile`（Task 2；get_my_profile 回 JSON **array**）
- Produces: `profileProvider` 變成 `Future<UserModel?>`（呼叫端 `.valueOrNull` / `.future` 用法不變）。**Realtime 更新消失** — 之後所有寫入方必須 `ref.invalidate(profileProvider)`（Task 7 逐一補）

- [ ] **Step 1: `_fetchOrCreateProfile` 改單一 RPC**

整個方法（152-202 行）替換為：
```dart
  /// 抓取 profile；不存在則由 DB 端用暫存資料建立（ensure_my_profile RPC）
  Future<UserModel> _fetchOrCreateProfile(String userId, String? email) async {
    final pending = await _loadPendingProfile();

    final row = await SupabaseConfig.client.rpc('ensure_my_profile', params: {
      'p_email': email ?? pending?['email'] ?? '',
      'p_display_name': pending?['display_name'],
      'p_role': pending?['role'],
    });

    // 暫存只用一次
    if (pending != null) await _clearPendingProfile();

    final user = UserModel.fromSupabase(Map<String, dynamic>.from(row as Map));
    _currentUser = user;
    return user;
  }
```
（`AppAuthException('找不到個人資料...')` 分支移除；無暫存時 DB 以「未命名 / job_seeker」建列，router 會照 isProfileComplete 導去 onboarding。若 `AppAuthException` import 因此 unused，順手清掉 unused import 即可。）

- [ ] **Step 2: `profile_provider.dart` 改 Future + RPC**

`profile` 函式整個替換為：
```dart
@Riverpod(keepAlive: true)
Future<UserModel?> profile(ProfileRef ref) async {
  final supabase = Supabase.instance.client;

  final authAsync = ref.watch(authStateProvider);
  final userId = supabase.auth.currentUser?.id ?? authAsync.valueOrNull?.id;

  logger.i('[Profile] fetch: userId=$userId');
  if (userId == null) return null;

  final rows = await supabase.rpc('get_my_profile') as List;
  if (rows.isEmpty) return null;
  return UserModel.fromSupabase(Map<String, dynamic>.from(rows.first as Map));
}
```

- [ ] **Step 3: `freeJobQuotaProvider` 改 RPC**

```dart
final freeJobQuotaProvider = FutureProvider<int>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return 0;
  final rows = await Supabase.instance.client.rpc('get_my_profile') as List;
  if (rows.isEmpty) return 0;
  return ((rows.first as Map)['free_job_quota'] as int?) ?? 0;
});
```

- [ ] **Step 4: codegen + analyze**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter analyze lib/core/providers lib/features/auth lib/features/profile/presentation/employer_jobs_screen.dart`
Expected: 無新增 error（user_card.dart 的既有錯誤屬 Task 8）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/data/supabase_auth_repository.dart lib/core/providers/profile_provider.dart lib/core/providers/profile_provider.g.dart lib/features/profile/presentation/employer_jobs_screen.dart
git commit -m "feat(auth/profile): own-data reads via ensure_my_profile/get_my_profile RPC"
```

---

### Task 7: Flutter — 自己資料的「寫」改 RPC

**Files:**
- Modify: `lib/features/onboarding/onboarding_screen.dart:206-231`
- Modify: `lib/core/services/profile_service.dart:116-136`（`_updateUserData`）
- Modify: `lib/features/profile/presentation/profile_screen.dart:251-256`（`_save`）
- Modify: `lib/core/providers/current_role_provider.dart:40-43`（`switchRole`）

**Interfaces:**
- Consumes: `upsert_my_profile(p_fields jsonb)`（Task 2）；key 存在才更新、value null＝清空
- Produces: 所有寫入後呼叫 `ref.invalidate(profileProvider)`（profileProvider 已無 Realtime）

- [ ] **Step 1: onboarding `_saveRoleProfile` 的 users 同步改 RPC**

206-231 行（`// 同步更新 users 表...` 起）替換為：
```dart
    // 同步更新 users 表（upsert_my_profile RPC；key 帶 null = 清空該欄位）
    final usersUpdate = <String, dynamic>{'role': role};
    if (role == 'employer') {
      usersUpdate['company_name'] = _companyNameController.text.trim();
      usersUpdate['company_size'] = _companySize;
      usersUpdate['expected_salary'] = null;
    } else if (role == 'job_seeker') {
      usersUpdate['company_name'] = null;
      usersUpdate['company_size'] = null;
      usersUpdate['expected_salary'] = _expectedSalary;
      usersUpdate['skills'] = _skills;
    } else {
      usersUpdate['company_name'] = null;
      usersUpdate['company_size'] = null;
      usersUpdate['expected_salary'] = null;
    }

    logger.d('[Onboarding] upsert_my_profile: $usersUpdate');

    await Supabase.instance.client
        .rpc('upsert_my_profile', params: {'p_fields': usersUpdate});
```
（`_submit` 內已有 `ref.invalidate(profileProvider)`，不必再加。`updated_at` 由函式設定。）

- [ ] **Step 2: `profile_service.dart` `_updateUserData` 改 RPC**

方法主體替換為：
```dart
    final fields = <String, dynamic>{
      'display_name': name,
      'bio': bio,
      'skills': skills,
    };
    if (imageUrl != null) {
      fields['avatar_url'] = imageUrl;
    }

    await _client.rpc('upsert_my_profile', params: {'p_fields': fields});
    logger.i('[Storage] ✅ users 表更新成功 (RPC)');
```
（`userId` 參數留著沒關係，函式改用 auth.uid()。）

- [ ] **Step 3: `profile_screen.dart` `_save` 改 RPC + invalidate**

251-256 行替換為：
```dart
      await Supabase.instance.client.rpc('upsert_my_profile', params: {
        'p_fields': {
          'display_name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'skills': _skills,
        },
      });
      ref.invalidate(profileProvider);
```
（`_EditProfileSheetState` 是 `ConsumerState`，`ref` 可直接用；補 import `../../../core/providers/profile_provider.dart`，若尚未 import。）

- [ ] **Step 4: `current_role_provider.dart` `switchRole` 改 RPC**

40-43 行（`.from('users').update(...)`）替換為：
```dart
      await Supabase.instance.client
          .rpc('upsert_my_profile', params: {'p_fields': {'role': newRole.toDbString}});
      ref.invalidate(profileProvider);
```

- [ ] **Step 5: analyze + commit**

Run: `flutter analyze lib/features/onboarding lib/core lib/features/profile`
Expected: 無新增 error。
```bash
git add lib/features/onboarding/onboarding_screen.dart lib/core/services/profile_service.dart lib/features/profile/presentation/profile_screen.dart lib/core/providers/current_role_provider.dart
git commit -m "feat(profile): own-data writes via upsert_my_profile RPC + provider invalidation"
```

---

### Task 8: Flutter — 滑卡改 RPC、卡片去薪資

**Files:**
- Create: `lib/core/utils/user_hydration.dart`
- Modify: `lib/features/swipe/data/supabase_swipe_repository.dart:36-86`
- Modify: `lib/features/swipe/presentation/user_card.dart:66-72`

**Interfaces:**
- Consumes: `get_swipe_cards(p_role, p_limit)`、`get_users_public(p_ids uuid[])`（Task 3）；Task 5 的 UserCardModel（無 expectedSalary）
- Produces: `Future<Map<String, Map<String, dynamic>>> fetchPublicUsersMap(List<String> ids)`（id → 公開欄位 row；Task 9 重用）

- [ ] **Step 1: 建 hydration helper**

`lib/core/utils/user_hydration.dart`：
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// 批次取多位使用者的公開資料（get_users_public RPC），回 id -> row 的 map。
/// 用來取代被 REVOKE 弄壞的 `users` embed join。
Future<Map<String, Map<String, dynamic>>> fetchPublicUsersMap(
    List<String> ids) async {
  if (ids.isEmpty) return {};
  final data = await Supabase.instance.client
      .rpc('get_users_public', params: {'p_ids': ids.toSet().toList()});
  return {
    for (final row in (data as List))
      (row as Map)['id'] as String: Map<String, dynamic>.from(row),
  };
}
```

- [ ] **Step 2: `_getJobCards` 拿掉 users embed，改 hydration**

36-57 行替換為：
```dart
  Future<List<SwipeCard>> _getJobCards({required String userId}) async {
    final swipedData = await SupabaseConfig.client
        .from('swipes')
        .select('target_id')
        .eq('swiper_id', userId)
        .eq('target_type', 'job');

    final swipedIds = (swipedData as List).map((r) => r['target_id'] as String).toList();

    var query = SupabaseConfig.client
        .from('jobs')
        .select()
        .eq('status', 'open')
        .neq('employer_id', userId);

    if (swipedIds.isNotEmpty) {
      query = query.not('id', 'in', '(${swipedIds.map((id) => '"$id"').join(',')})');
    }

    final data = await query.limit(20).order('created_at', ascending: false);
    final jobs = (data as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();

    // 雇主公開資料（原本靠 users embed join，REVOKE 後改 RPC）
    final employerMap = await fetchPublicUsersMap(
        jobs.map((j) => j['employer_id'] as String).toList());
    for (final j in jobs) {
      j['users'] = employerMap[j['employer_id']];
    }

    return jobs.map((r) => SwipeCard.job(JobModel.fromSupabase(r))).toList();
  }
```
檔頭加：`import '../../../core/utils/user_hydration.dart';`

- [ ] **Step 3: `_getTalentCards` / `_getPeerCards` 改 get_swipe_cards RPC**

59-86 行替換為：
```dart
  Future<List<SwipeCard>> _getTalentCards({required String userId}) async {
    final data = await SupabaseConfig.client
        .rpc('get_swipe_cards', params: {'p_role': 'employer', 'p_limit': 20});
    return (data as List)
        .map((r) => SwipeCard.user(
            UserCardModel.fromSupabase(Map<String, dynamic>.from(r as Map))))
        .toList();
  }

  Future<List<SwipeCard>> _getPeerCards(
      {required String userId, required List<String> mySkills}) async {
    // 技能重疊與已滑排除都在 DB 函式內處理（讀 users.skills）
    final data = await SupabaseConfig.client
        .rpc('get_swipe_cards', params: {'p_role': 'peer', 'p_limit': 20});
    return (data as List)
        .map((r) => SwipeCard.user(
            UserCardModel.fromSupabase(Map<String, dynamic>.from(r as Map))))
        .toList();
  }
```

- [ ] **Step 4: `user_card.dart` 移除薪資 chip**

刪 66-72 行整段：
```dart
                      if (userCard.expectedSalary != null)
                        _InfoChip(
                          icon: Icons.payments_outlined,
                          label:
                              '期望 ${(userCard.expectedSalary! / 1000).toStringAsFixed(0)}K',
                          color: Colors.green,
                        ),
```

- [ ] **Step 5: analyze + commit**

Run: `flutter analyze lib/features/swipe lib/core/utils`
Expected: 無 error（expectedSalary 引用已全清）。
```bash
git add lib/core/utils/user_hydration.dart lib/features/swipe/data/supabase_swipe_repository.dart lib/features/swipe/presentation/user_card.dart
git commit -m "feat(swipe): cards via get_swipe_cards RPC; drop salary from cards"
```

---

### Task 9: Flutter — matches / messages / 應徵者列表去 embed

**Files:**
- Modify: `lib/features/match/presentation/matches_screen.dart:28-64`
- Modify: `lib/features/match/presentation/messages_screen.dart:24-58`
- Modify: `lib/features/profile/presentation/employer_jobs_screen.dart:474-497`（`_JobApplicantsState._load`）

**Interfaces:**
- Consumes: `fetchPublicUsersMap`（Task 8）
- Produces: 各 provider 回傳的 Map 結構**維持原 key**（`job_seeker`、`jobs`、`jobs.users`），UI 層不用改

- [ ] **Step 1: `matches_screen.dart` `_fetch` 改寫**

28-64 行替換為：
```dart
  Future<List<Map<String, dynamic>>> _fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final role = ref.read(currentRoleProvider);

    if (role == AppRole.employer) {
      // 雇主：看求職者右滑自己職缺的 pending 列表
      final data = await Supabase.instance.client
          .from('matches')
          .select('id, status, created_at, job_seeker_id, jobs ( id, title )')
          .eq('employer_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      final rows = (data as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final usersMap = await fetchPublicUsersMap(
          rows.map((r) => r['job_seeker_id'] as String).toList());
      for (final r in rows) {
        r['job_seeker'] = usersMap[r['job_seeker_id']];
      }
      return rows;
    } else {
      // 求職者：看自己已配對成功的職缺
      final data = await Supabase.instance.client
          .from('matches')
          .select('id, status, created_at, jobs ( id, title, employer_id )')
          .eq('job_seeker_id', user.id)
          .inFilter('status', ['pending', 'accepted'])
          .order('created_at', ascending: false);
      final rows = (data as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final employerIds = rows
          .map((r) => (r['jobs'] as Map?)?['employer_id'] as String?)
          .whereType<String>()
          .toList();
      final usersMap = await fetchPublicUsersMap(employerIds);
      for (final r in rows) {
        final jobs = r['jobs'] as Map?;
        if (jobs != null) {
          r['jobs'] = {...jobs, 'users': usersMap[jobs['employer_id']]};
        }
      }
      return rows;
    }
  }
```
檔頭加：`import '../../../core/utils/user_hydration.dart';`

- [ ] **Step 2: `messages_screen.dart` `_fetch` 同模式改寫**

24-58 行替換為（結構同上，僅 filter 不同）：
```dart
  Future<List<Map<String, dynamic>>> _fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final role = ref.read(currentRoleProvider);

    if (role == AppRole.jobSeeker) {
      final data = await Supabase.instance.client
          .from('matches')
          .select('id, status, created_at, jobs ( id, title, employer_id )')
          .eq('job_seeker_id', user.id)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);
      final rows = (data as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final employerIds = rows
          .map((r) => (r['jobs'] as Map?)?['employer_id'] as String?)
          .whereType<String>()
          .toList();
      final usersMap = await fetchPublicUsersMap(employerIds);
      for (final r in rows) {
        final jobs = r['jobs'] as Map?;
        if (jobs != null) {
          r['jobs'] = {...jobs, 'users': usersMap[jobs['employer_id']]};
        }
      }
      return rows;
    } else {
      final data = await Supabase.instance.client
          .from('matches')
          .select('id, status, created_at, job_seeker_id, jobs ( id, title )')
          .eq('employer_id', user.id)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);
      final rows = (data as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final usersMap = await fetchPublicUsersMap(
          rows.map((r) => r['job_seeker_id'] as String).toList());
      for (final r in rows) {
        r['job_seeker'] = usersMap[r['job_seeker_id']];
      }
      return rows;
    }
  }
```
檔頭加相同 import。

- [ ] **Step 3: `employer_jobs_screen.dart` `_JobApplicantsState._load` 改寫**

478-487 行的查詢與賦值替換為：
```dart
      final data = await Supabase.instance.client
          .from('matches')
          .select('id, job_seeker_id')
          .eq('job_id', widget.jobId)
          .eq('status', 'pending');

      final rows = (data as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final usersMap = await fetchPublicUsersMap(
          rows.map((r) => r['job_seeker_id'] as String).toList());
      for (final r in rows) {
        r['job_seeker'] = usersMap[r['job_seeker_id']];
      }

      setState(() {
        _applicants = rows;
        _loaded = true;
        _loading = false;
      });
```
檔頭加：`import '../../../core/utils/user_hydration.dart';`

- [ ] **Step 4: analyze + commit**

Run: `flutter analyze lib/features/match lib/features/profile/presentation/employer_jobs_screen.dart`
Expected: 無 error。
```bash
git add lib/features/match/presentation/matches_screen.dart lib/features/match/presentation/messages_screen.dart lib/features/profile/presentation/employer_jobs_screen.dart
git commit -m "feat(match): replace users embed joins with get_users_public hydration"
```

---

### Task 10: Flutter — Admin 後台改 RPC

**Files:**
- Modify: `lib/features/admin/data/admin_provider.dart`（adminStats / adminUsers / adminJobs / adminReports / reportConversation / adminInbox / AdminActions）
- Regenerate: `lib/features/admin/data/admin_provider.g.dart`

**Interfaces:**
- Consumes: `admin_stats` / `admin_list_users` / `admin_set_user_status` / `admin_delete_user` / `admin_get_users`（Task 4）、`fetchPublicUsersMap`（Task 8）
- Produces: 各 provider 回傳 Map 結構維持原 key（`reporter`、`sender`、`users`），admin UI 畫面不用改

- [ ] **Step 1: `adminStats` users 計數改 RPC**

`adminStats` 函式主體替換為：
```dart
  final client = Supabase.instance.client;

  Future<int> count(String table, {String? eqCol, Object? eqVal}) async {
    var query = client.from(table).select('id');
    if (eqCol != null) query = query.eq(eqCol, eqVal!);
    final res = await query.count(CountOption.exact);
    return res.count;
  }

  final results = await Future.wait([
    client.rpc('admin_stats'),
    count('jobs'),
    count('matches', eqCol: 'status', eqVal: 'accepted'),
  ]);

  final stats = ((results[0] as List).first as Map);
  return AdminStats(
    totalUsers: (stats['total_users'] as num).toInt(),
    jobSeekers: (stats['job_seekers'] as num).toInt(),
    employers: (stats['employers'] as num).toInt(),
    totalJobs: results[1] as int,
    acceptedMatches: results[2] as int,
  );
```

- [ ] **Step 2: `adminUsers` 改 RPC**

查詢部分（86-98 行）替換為：
```dart
  final client = Supabase.instance.client;
  final data = await client.rpc('admin_list_users', params: {
    'p_search': search,
    'p_role': roleFilter,
    'p_limit': 100,
    'p_offset': 0,
  });
  return (data as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
```

- [ ] **Step 3: `adminJobs` 去 users embed**

替換為：
```dart
  final client = Supabase.instance.client;
  var query = client
      .from('jobs')
      .select('id, title, status, created_at, employer_id');

  if (statusFilter != null) {
    query = query.eq('status', statusFilter);
  }

  final data = await query.order('created_at', ascending: false).limit(100);
  final rows = (data as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();

  final ids = rows.map((r) => r['employer_id'] as String).toSet().toList();
  final userRows = await client.rpc('admin_get_users', params: {'p_ids': ids});
  final usersMap = {
    for (final u in (userRows as List))
      (u as Map)['id'] as String: Map<String, dynamic>.from(u),
  };
  for (final r in rows) {
    r['users'] = usersMap[r['employer_id']];
  }
  return rows;
```
（rows 為空時 `admin_get_users` 收到空 array 回空 — 無需特判。）

- [ ] **Step 4: `adminReports` / `adminInbox` / `reportConversation` 去 embed**

- `adminReports`：select 改 `'id, reporter_id, target_type, target_id, match_id, reason, status, admin_note, resolved_at, created_at'`；取回後以 `reporter_id` 集合呼叫 `admin_get_users`，`r['reporter'] = usersMap[r['reporter_id']]`（同 Step 3 的 map 組法）
- `adminInbox`：select 去掉 `, sender:user_id(display_name, email)`；以 `user_id` 集合呼叫 `admin_get_users`，`r['sender'] = usersMap[r['user_id']]`（注意 `user_id` 可能為 null，收集時 `.whereType<String>()`）
- `reportConversation`：select 改 `'id, sender_id, content, created_at'`；以 `sender_id` 集合呼叫 `fetchPublicUsersMap`（display_name 是公開資料），`r['sender'] = usersMap[r['sender_id']]`。檔頭加 `import '../../../core/utils/user_hydration.dart';`

- [ ] **Step 5: `AdminActions` 的 users 寫入改 RPC**

```dart
  Future<void> setUserStatus(String userId, String status) async {
    await _client.rpc('admin_set_user_status',
        params: {'p_target': userId, 'p_status': status});
    ref.invalidate(adminUsersProvider);
  }

  Future<void> deleteUser(String userId) async {
    await _client.rpc('admin_delete_user', params: {'p_target': userId});
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminStatsProvider);
  }
```
（jobs / reports / inbox 的直接操作不動 — 那些表不在本 refactor 範圍。）

- [ ] **Step 6: codegen + analyze + commit**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter analyze lib/features/admin`
Expected: 無 error。
```bash
git add lib/features/admin/data/admin_provider.dart lib/features/admin/data/admin_provider.g.dart
git commit -m "feat(admin): users access via admin RPCs; embed joins replaced with hydration"
```

---

### Task 11: Flutter — 薪資可見度開關

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart`（`_ProfileBody` + 新 `_SalaryVisibilityTile`）

**Interfaces:**
- Consumes: `set_salary_visibility(p_visibility)`（Task 2）、`UserModel.salaryVisibility`（Task 5）、既有 `_ToggleTile`（profile_screen.dart:784）
- Produces: 求職者 profile 頁的「薪資可見度」開關

- [ ] **Step 1: `_ProfileBody` 插入 tile**

在 `_OpenToOpportunityTile` 那行（profile_screen.dart:104-105）之後加：
```dart
              // 薪資可見度（求職者模式下顯示）
              if (currentRole == AppRole.jobSeeker)
                _SalaryVisibilityTile(profile: profile, themeColor: themeColor),
```

- [ ] **Step 2: 檔尾（`_ToggleTile` 之前）加新 widget**

```dart
// ── 薪資可見度開關 ────────────────────────────────────────────────────────

class _SalaryVisibilityTile extends ConsumerStatefulWidget {
  const _SalaryVisibilityTile({required this.profile, required this.themeColor});
  final UserModel profile;
  final Color themeColor;

  @override
  ConsumerState<_SalaryVisibilityTile> createState() =>
      _SalaryVisibilityTileState();
}

class _SalaryVisibilityTileState extends ConsumerState<_SalaryVisibilityTile> {
  late bool _visibleToMatched;

  @override
  void initState() {
    super.initState();
    _visibleToMatched = widget.profile.salaryVisibility == 'matched';
  }

  Future<void> _toggle(bool value) async {
    setState(() => _visibleToMatched = value);
    await Supabase.instance.client.rpc('set_salary_visibility',
        params: {'p_visibility': value ? 'matched' : 'private'});
    ref.invalidate(profileProvider);
  }

  @override
  Widget build(BuildContext context) {
    return _ToggleTile(
      icon: Icons.payments_outlined,
      label: '期望薪資可見度',
      subtitle: _visibleToMatched ? '配對成功的對象可以看到你的期望薪資' : '期望薪資只有自己看得到',
      value: _visibleToMatched,
      themeColor: widget.themeColor,
      onChanged: _toggle,
    );
  }
}
```
（若 `profile_provider.dart` 尚未 import，補上。）

- [ ] **Step 3: analyze + commit**

Run: `flutter analyze lib/features/profile`
Expected: 無 error。
```bash
git add lib/features/profile/presentation/profile_screen.dart
git commit -m "feat(profile): salary visibility toggle (matched/private)"
```

---

### Task 12: DB — REVOKE cutover + 收緊 policy + anon 防護

**⚠️ 執行前提：Task 5-11 全部完成。REVOKE 之後舊的直接查詢立即失效。**

**Files:**
- Create: `sql/protected_data_007_revoke.sql`

- [ ] **Step 1: 以 `apply_migration` 套用（name: `protected_data_007_revoke`）**

```sql
-- 核心 cutover：client 完全不能直接碰 users（privilege 檢查在 RLS 之前）
revoke all on table users from authenticated, anon;

-- 第二道防線收緊：全域 SELECT policy 是當初漏洞的根源，移除。
-- 保留 own-row 與 admin policy（若 REVOKE 未來被誤還原，仍只剩 own-row 存取）。
drop policy if exists "所有登入用戶可以讀取 users" on users;

-- 匿名者不得呼叫本 refactor 的 RPC
revoke execute on function
  ensure_my_profile(text, text, text),
  get_my_profile(),
  upsert_my_profile(jsonb),
  upsert_my_location(double precision, double precision, text),
  set_salary_visibility(text),
  get_swipe_cards(text, int),
  get_user_public(uuid),
  get_users_public(uuid[]),
  get_user_contact(uuid),
  get_distance_km(uuid),
  admin_stats(),
  admin_list_users(text, text, int, int),
  admin_set_user_status(uuid, text),
  admin_delete_user(uuid),
  admin_get_users(uuid[]),
  is_matched_with(uuid, uuid)
from anon;
```

- [ ] **Step 2: harness 驗證封鎖生效**

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":":USER_A","role":"authenticated"}', true);
select * from users limit 1;
rollback;
```
Expected：**permission denied for table users**。
再以同身分跑 `select * from get_my_profile();` → 正常回自己一筆（RPC 通道活著）。
再 `set local role anon;` 跑 `select * from get_users_public(array[':USER_A']::uuid[]);` → permission denied（execute revoked）。

- [ ] **Step 3: 跑 Supabase advisors**

用 MCP `get_advisors`（type=security）確認沒有新增 security findings（特別是 SECURITY DEFINER search_path 類）。

- [ ] **Step 4: 存 `sql/protected_data_007_revoke.sql` 並 commit**

```bash
git add sql/protected_data_007_revoke.sql
git commit -m "feat(db): revoke direct users access; RPC-only cutover"
```

---

### Task 13: 全流程驗證

**Files:** 無新檔（驗證 + 修 bug）

- [ ] **Step 1: 靜態檢查**

Run: `flutter analyze`
Expected: No issues（或僅既有、與本 refactor 無關的 warning）。
確認沒有殘留直接存取：
Run: `rg -n "from\('users'\)|users!|:reporter_id\(|:sender_id\(|:user_id\(" lib/`
Expected: 只剩 `supabase_client.dart:47` 的註解與 `user_card_model.dart:8` 的註解（無實際查詢）。

- [ ] **Step 2: 跑起來 smoke（macOS debug 或 iOS simulator）**

Run: `flutter run -d macos`
手動流程（對照 spec Section 4）：
1. 登入 → 進得了主畫面（ensure_my_profile / get_my_profile 通）
2. onboarding（新角色切換）→ 完成後 profile 顯示正確（upsert_my_profile + invalidate 通）
3. 滑卡三身份：求職者看職缺（卡片有公司名/頭像）、雇主看人才、同業互滑；**人才/同業卡片不再出現「期望 XXK」**
4. 配對 → 配對清單 / 訊息列表顯示對方名字頭像（hydration 通）→ 進聊天室
5. 編輯個人資料存檔 → 回 profile 頁看到更新（invalidate 生效，無 Realtime 也即時）
6. 求職者 profile 頁切「期望薪資可見度」開關，重進頁面狀態保持
7. 雇主職缺管理：額度顯示正常、展開「有興趣的求職者」正常
8. Admin 帳號進 /admin：dashboard 數字、用戶列表（搜尋/停權）、職缺列表、檢舉、站內信全部有資料

- [ ] **Step 3: 發現問題就修，修完重跑對應驗證，然後 commit**

```bash
git add -u
git commit -m "fix: protected-data refactor smoke test fixes"
```
（若無修改則略過。）

- [ ] **Step 4: 收尾**

用 superpowers:finishing-a-development-branch 決定 merge 方式。Merge 進 main 後的既定後續（不在本 plan 內執行）：google-maps-integration worktree `git reset --hard main`，其 Task 1 縮減為只建 `commute_cache` + `edge_function_hits`。

---

## 與 spec 的差異（plan 層級決策，已寫死於上方任務）

1. **matched 定義補 peer 形狀**：spec 只寫 (job_seeker_id, employer_id)；live DB 的 peer 配對存在 (initiator_id, target_user_id, match_type='user')，`is_matched_with` 兩種都算，並多建一個 peer index。
2. **`upsert_my_profile` 用 jsonb 單參數**（spec 寫「各參數」）：因 onboarding 需要「明確清空欄位」語意（employer 要把 expected_salary 設 null），individual params 無法區分「不更新」與「設 null」；jsonb key-presence 語意可以，並附欄位白名單。
3. **新增 `get_users_public(uuid[])` batch 與 `admin_get_users(uuid[])`**：embed join 失效的畫面是列表，逐筆呼叫 `get_user_public` 會 N+1；batch 版欄位集與 spec 的 `get_user_public` 完全一致（admin 版多 email/company_name，有 is_admin 檢查）。
4. **新增 `admin_stats()`、`admin_delete_user()`**：現有後台的 users count 與刪除用戶在 REVOKE 後會壞，spec admin 段落漏列；`admin_delete_user` 要求 super_admin，對齊既有 RLS。
5. **drop「所有登入用戶可以讀取 users」policy**：spec 說「現有 policy 保留作第二道防線」——全域 SELECT policy 保留反而讓第二道防線失效，故移除它、保留 own-row 與 admin policies。
6. **`ensure_my_profile` 多 `p_display_name`/`p_role` 選填參數**：現行 client 建 profile 時會帶註冊暫存的 display_name/role，維持行為；「無暫存即報錯」改為「以預設值建列」（router 仍會導去 onboarding）。
7. **lat/lng 等座標欄位用 `if not exists`**：location_006 已在 live DB 加過這些欄位。
