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
