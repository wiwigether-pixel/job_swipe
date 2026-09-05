-- Migration: protected_data_007_self_rpcs
-- Five SECURITY DEFINER RPCs for a user operating on their OWN row.
-- A later migration will REVOKE direct table access; these become the
-- only client-side path to touch the users table.

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
