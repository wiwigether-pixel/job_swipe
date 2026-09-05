-- Security amendment: replace exact distance with coarse buckets.
--
-- Rationale: get_distance_km previously returned a numeric value rounded to
-- 0.1 km. Because upsert_my_location lets a caller set their own coordinates
-- freely, an attacker could reposition themselves three times and trilaterate
-- a victim's raw location to ~100 m accuracy. An exactly-invertible derived
-- value defeats the goal of keeping raw coordinates as protected data.
--
-- Fix: return a text bucket label instead of a precise number. The bucket
-- granularity (coarsest bucket = 30 km wide) makes trilateration infeasible
-- while preserving the "this person is nearby" signal that swipe cards need.
-- The function remains readable by non-matched viewers (no relation gate
-- needed because no precise location is disclosed).
--
-- Because the return type changes from numeric → text, CREATE OR REPLACE
-- would fail. Drop first, then recreate.

drop function if exists get_distance_km(uuid);

create function get_distance_km(p_target uuid)
returns text
language sql stable security definer set search_path = public
as $$
  select case
    when me.lat is null or me.lng is null or t.lat is null or t.lng is null then null
    else (
      select case
        when d < 1    then '<1'
        when d < 3    then '1-3'
        when d < 5    then '3-5'
        when d < 10   then '5-10'
        when d < 20   then '10-20'
        when d < 50   then '20-50'
        else               '50+'
      end
      from (
        select 6371 * acos(least(1.0, greatest(-1.0,
          cos(radians(me.lat)) * cos(radians(t.lat)) * cos(radians(t.lng) - radians(me.lng))
          + sin(radians(me.lat)) * sin(radians(t.lat))
        ))) as d
      ) calc
    )
  end
  from users me, users t
  where me.id = auth.uid() and t.id = p_target;
$$;
