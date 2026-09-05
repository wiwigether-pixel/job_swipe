-- ============================================================
-- Admin 後台基礎設定 (Phase 1)
-- 在 Supabase SQL Editor 執行
-- 決策 C：獨立 admin_roles 表，分級 super_admin / moderator
-- ============================================================

-- 1. admin_roles 表：誰是管理員、什麼等級
create table if not exists admin_roles (
  user_id    uuid primary key references users(id) on delete cascade,
  level      text not null check (level in ('super_admin', 'moderator')),
  granted_by uuid references users(id),
  granted_at timestamptz not null default now()
);

-- 2. users 加停權狀態欄位（用戶管理用）
alter table users
  add column if not exists status text not null default 'active'
  check (status in ('active', 'suspended'));

-- 3. 權限判斷函式（SECURITY DEFINER 才能繞過 RLS 自我查詢）
create or replace function is_admin(uid uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (select 1 from admin_roles where user_id = uid);
$$;

create or replace function admin_level(uid uuid)
returns text
language sql
security definer
stable
as $$
  select level from admin_roles where user_id = uid;
$$;

create or replace function is_super_admin(uid uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from admin_roles
    where user_id = uid and level = 'super_admin'
  );
$$;

-- 4. RLS：admin_roles 表本身
alter table admin_roles enable row level security;

-- 任何人都能讀自己的 admin 等級（前端判斷入口顯示用）
drop policy if exists "讀自己的 admin 等級" on admin_roles;
create policy "讀自己的 admin 等級" on admin_roles
  for select using (user_id = auth.uid());

-- super_admin 可讀全部、管理其他 admin
drop policy if exists "super_admin 管理 admin_roles" on admin_roles;
create policy "super_admin 管理 admin_roles" on admin_roles
  for all using (is_super_admin(auth.uid()))
  with check (is_super_admin(auth.uid()));

-- 5. RLS：users 表 — admin 可讀全部、可更新（停權）、super_admin 可刪除
drop policy if exists "admin 讀所有用戶" on users;
create policy "admin 讀所有用戶" on users
  for select using (is_admin(auth.uid()));

drop policy if exists "admin 更新用戶狀態" on users;
create policy "admin 更新用戶狀態" on users
  for update using (is_admin(auth.uid()))
  with check (is_admin(auth.uid()));

drop policy if exists "super_admin 刪除用戶" on users;
create policy "super_admin 刪除用戶" on users
  for delete using (is_super_admin(auth.uid()));

-- 6. RLS：jobs 表 — admin 可讀全部、審核(update)、下架(delete)
drop policy if exists "admin 讀所有職缺" on jobs;
create policy "admin 讀所有職缺" on jobs
  for select using (is_admin(auth.uid()));

drop policy if exists "admin 審核職缺" on jobs;
create policy "admin 審核職缺" on jobs
  for update using (is_admin(auth.uid()))
  with check (is_admin(auth.uid()));

drop policy if exists "admin 下架職缺" on jobs;
create policy "admin 下架職缺" on jobs
  for delete using (is_admin(auth.uid()));

-- ============================================================
-- 指派第一位 super_admin（把 email 換成你的帳號）
-- ============================================================
-- insert into admin_roles (user_id, level)
-- select id, 'super_admin' from users where email = 'YOUR_EMAIL@example.com'
-- on conflict (user_id) do update set level = 'super_admin';
