-- Migration: protected_data_007_schema
-- Purpose: schema groundwork for protected-data refactor
--   - add salary_visibility column (and GPS cols with if not exists guard)
--   - drop leaky views (user_cards, users_public)
--   - add match-lookup indexes for both match shapes
--   - create is_matched_with() helper function

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
