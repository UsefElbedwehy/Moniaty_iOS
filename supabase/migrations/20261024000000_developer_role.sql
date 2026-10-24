-- Developer role: the app's developer, above the owner and hidden from everyone else.
--
-- * `developer` holds every permission, including deleting records (like the owner).
-- * The audit log (`audit.read`) is developer-only: the owner and every other role lose it. The
--   push page still reads its own campaign history through a narrow policy.
-- * Nobody can grant the role from the dashboard: `admin_add_admin` refuses it, and the
--   `admin_users` write policy refuses any developer row. It is given only by SQL, as below.
-- * Developers are invisible to other admins: not in the team list, not in the role list, and
--   they can't be suspended or have their role changed.

-- ---------------------------------------------------------------------------------------------
-- Role and helpers
-- ---------------------------------------------------------------------------------------------

insert into public.admin_roles (id, name_ar, name_en) values ('developer', 'المطوّر', 'Developer')
on conflict (id) do nothing;

-- The audit log was the analyst's; it is now developer-only.
delete from public.admin_role_permissions where permission = 'audit.read';

create or replace function public.is_developer() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admin_users where user_id = auth.uid() and is_active and role_id = 'developer');
$$;

-- Developer: everything. Owner: everything except the audit log. Other roles: their own list,
-- never the audit log.
create or replace function public.has_admin_permission(p_permission text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from admin_users au
    left join admin_role_permissions rp on rp.role_id = au.role_id and rp.permission = p_permission
    where au.user_id = auth.uid()
      and au.is_active
      and (au.role_id = 'developer'
           or (p_permission <> 'audit.read' and (au.role_id = 'owner' or rp.permission is not null)))
  );
$$;

-- Owner-only actions (permanent delete) are open to the developer too.
create or replace function public.admin_is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admin_users where user_id = auth.uid() and is_active and role_id in ('owner', 'developer'));
$$;

-- ---------------------------------------------------------------------------------------------
-- Policies: hide the role and its members from other admins; never writable from the dashboard
-- ---------------------------------------------------------------------------------------------

drop policy if exists admin_roles_read on public.admin_roles;
create policy admin_roles_read on public.admin_roles for select to authenticated
  using (public.is_admin() and (id <> 'developer' or public.is_developer()));

drop policy if exists admin_role_permissions_read on public.admin_role_permissions;
create policy admin_role_permissions_read on public.admin_role_permissions for select to authenticated
  using (public.is_admin() and (role_id <> 'developer' or public.is_developer()));

drop policy if exists admin_users_read on public.admin_users;
create policy admin_users_read on public.admin_users for select to authenticated
  using (public.is_admin() and (role_id <> 'developer' or public.is_developer()));

drop policy if exists admin_users_manage on public.admin_users;
create policy admin_users_manage on public.admin_users for all to authenticated
  using (public.has_admin_permission('team.manage') and role_id <> 'developer')
  with check (public.has_admin_permission('team.manage') and role_id <> 'developer');

-- The push page lists past campaigns from the audit log.
drop policy if exists admin_audit_campaigns_read on public.admin_audit_log;
create policy admin_audit_campaigns_read on public.admin_audit_log for select to authenticated
  using (entity_type = 'campaigns' and public.has_admin_permission('push.send'));

-- ---------------------------------------------------------------------------------------------
-- Team RPCs
-- ---------------------------------------------------------------------------------------------

create or replace function public.admin_add_admin(p_email text, p_role text) returns jsonb
language plpgsql security definer set search_path = public, auth as $$
declare
  v_user uuid;
begin
  perform require_admin_permission('team.manage');
  if p_role = 'developer' or not exists (select 1 from admin_roles where id = p_role) then
    return jsonb_build_object('ok', false, 'error', 'role_not_allowed');
  end if;
  select id into v_user from auth.users where lower(email) = lower(trim(p_email));
  if v_user is null then return jsonb_build_object('ok', false, 'error', 'no_auth_user'); end if;
  -- A developer's role can't be changed from here (and to others the account looks unknown).
  if exists (select 1 from admin_users where user_id = v_user and role_id = 'developer') then
    return jsonb_build_object('ok', false, 'error', 'role_not_allowed');
  end if;
  insert into admin_users (user_id, role_id, created_by) values (v_user, p_role, auth.uid())
  on conflict (user_id) do update set role_id = excluded.role_id, is_active = true;
  perform admin_audit('add', 'admin_users', v_user::text, jsonb_build_object('email', p_email, 'role', p_role));
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.admin_list_admins() returns jsonb
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not is_admin() then raise exception 'admins only' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('user_id', a.user_id, 'email', u.email, 'role_id', a.role_id,
                                                      'is_active', a.is_active, 'created_at', a.created_at) order by a.created_at)
                   from admin_users a join auth.users u on u.id = a.user_id
                   where a.role_id <> 'developer' or is_developer()), '[]');
end;
$$;

create or replace function public.admin_set_admin_active(p_user uuid, p_active boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform require_admin_permission('team.manage');
  if p_user = auth.uid() then return jsonb_build_object('ok', false, 'error', 'cannot_change_self'); end if;
  if exists (select 1 from admin_users where user_id = p_user and role_id = 'developer') then
    return jsonb_build_object('ok', false, 'error', 'role_not_allowed');
  end if;
  update admin_users set is_active = p_active where user_id = p_user;
  perform admin_audit(case when p_active then 'activate' else 'deactivate' end, 'admin_users', p_user::text, null);
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.is_developer() from public, anon;
grant execute on function public.is_developer() to authenticated, service_role;

-- ---------------------------------------------------------------------------------------------
-- The developer account. It must already exist in Supabase Auth (Authentication → Users →
-- Add user / Invite); if it doesn't yet, this does nothing and can be re-run later.
-- ---------------------------------------------------------------------------------------------

do $$
declare
  v_user uuid;
begin
  select id into v_user from auth.users where lower(email) = 'youssef.m.elbedwehy@gmail.com';
  if v_user is null then
    raise notice 'youssef.m.elbedwehy@gmail.com is not in Supabase Auth yet: add the user, then run this block again';
    return;
  end if;
  insert into admin_users (user_id, role_id) values (v_user, 'developer')
  on conflict (user_id) do update set role_id = 'developer', is_active = true;
end;
$$;
