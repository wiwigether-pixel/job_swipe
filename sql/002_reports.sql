-- ════════════════════════════════════════════════════════════
-- Phase 2：檢舉（reports）＋ 訊息審核
-- 需在 Supabase SQL Editor 整段執行（請勿只選取片段）
-- 前置：先跑過 001_admin_setup.sql（需要 is_admin() 函式）
-- ════════════════════════════════════════════════════════════

-- ── reports 表 ───────────────────────────────────────────────
create table if not exists reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references users(id) on delete cascade,
  target_type text not null check (target_type in ('user', 'job', 'conversation')),
  target_id   uuid not null,
  match_id    uuid references matches(id) on delete set null,
  reason      text not null,
  status      text not null default 'pending' check (status in ('pending', 'resolved', 'dismissed')),
  admin_note  text,
  resolved_by uuid references users(id),
  resolved_at timestamptz,
  created_at  timestamptz not null default now()
);

create index if not exists idx_reports_status     on reports(status);
create index if not exists idx_reports_created_at  on reports(created_at desc);
create index if not exists idx_reports_target      on reports(target_type, target_id);

-- ── RLS：reports ─────────────────────────────────────────────
alter table reports enable row level security;

-- 登入者可建立自己的檢舉
drop policy if exists "users insert own reports" on reports;
create policy "users insert own reports" on reports
  for insert to authenticated
  with check (reporter_id = auth.uid());

-- 檢舉人可看自己提交的檢舉
drop policy if exists "users read own reports" on reports;
create policy "users read own reports" on reports
  for select to authenticated
  using (reporter_id = auth.uid());

-- 管理員可讀全部檢舉
drop policy if exists "admin read all reports" on reports;
create policy "admin read all reports" on reports
  for select to authenticated
  using (is_admin(auth.uid()));

-- 管理員可更新檢舉（處理／駁回）
drop policy if exists "admin update reports" on reports;
create policy "admin update reports" on reports
  for update to authenticated
  using (is_admin(auth.uid()))
  with check (is_admin(auth.uid()));

-- ── RLS：messages（管理員審核用）─────────────────────────────
-- 讓管理員能讀取任意對話訊息以審核被檢舉的對話內容
alter table messages enable row level security;

drop policy if exists "admin read all messages" on messages;
create policy "admin read all messages" on messages
  for select to authenticated
  using (is_admin(auth.uid()));
