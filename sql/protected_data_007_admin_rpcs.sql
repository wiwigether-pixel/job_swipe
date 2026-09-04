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
