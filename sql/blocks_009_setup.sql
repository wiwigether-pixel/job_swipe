-- sql/blocks_009_setup.sql
create table if not exists public.blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

create policy blocks_select_own on public.blocks
  for select using (auth.uid() = blocker_id);
create policy blocks_insert_own on public.blocks
  for insert with check (auth.uid() = blocker_id);
create policy blocks_delete_own on public.blocks
  for delete using (auth.uid() = blocker_id);

-- 誰封鎖了我（RLS 讓我看不到，需 SECURITY DEFINER）
create or replace function public.get_blocked_me()
returns uuid[]
language sql
security definer
set search_path = public
as $$
  select coalesce(array_agg(blocker_id), '{}')
  from blocks
  where blocked_id = auth.uid();
$$;

-- create function 預設 grant 給 PUBLIC，必須連 public 一起 revoke
revoke execute on function public.get_blocked_me() from anon, public;
grant execute on function public.get_blocked_me() to authenticated;
