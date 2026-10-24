-- =============================================================================================
-- Munyati — dashboard: edit, archive (restorable) and permanently delete any record.
--
-- Archive hides a record everywhere and can be undone: the record keeps its row, gets
-- `archived_at`, and whatever made it visible is switched off (provider suspended, service
-- paused, review hidden, store/banner/category/city/plan inactive, user banned). The previous
-- values are kept in `admin_archive` so Restore puts them back. Owners of a service or store
-- can't edit it while it's archived. Permanent delete is for the owner role only.
-- Every action is written to the audit log.
-- =============================================================================================

alter table public.profiles add column archived_at timestamptz;
alter table public.providers add column archived_at timestamptz;
alter table public.services add column archived_at timestamptz;
alter table public.stores add column archived_at timestamptz;
alter table public.bookings add column archived_at timestamptz;
alter table public.reviews add column archived_at timestamptz;
alter table public.reports add column archived_at timestamptz;
alter table public.support_tickets add column archived_at timestamptz;
alter table public.home_banners add column archived_at timestamptz;
alter table public.categories add column archived_at timestamptz;
alter table public.cities add column archived_at timestamptz;
alter table public.subscription_plans add column archived_at timestamptz;

-- What Restore puts back (the values the archive switched off).
create table public.admin_archive (
  entity text not null,
  entity_id text not null,
  previous jsonb not null default '{}'::jsonb,
  note text,
  archived_by uuid references auth.users(id) on delete set null,
  archived_at timestamptz not null default now(),
  primary key (entity, entity_id)
);
alter table public.admin_archive enable row level security;
create policy admin_archive_read on public.admin_archive for select to authenticated using (public.is_admin());

-- Record types the dashboard manages: table, id column type, and the permission needed.
create function public.admin_entity(p_entity text) returns jsonb
language sql immutable set search_path = public as $$
  select case p_entity
    when 'user'     then '{"table":"profiles","perm":"providers.review"}'
    when 'provider' then '{"table":"providers","perm":"providers.review"}'
    when 'service'  then '{"table":"services","perm":"providers.review"}'
    when 'store'    then '{"table":"stores","perm":"providers.review"}'
    when 'booking'  then '{"table":"bookings","perm":"bookings.manage"}'
    when 'review'   then '{"table":"reviews","perm":"reviews.moderate"}'
    when 'report'   then '{"table":"reports","perm":"reports.handle"}'
    when 'ticket'   then '{"table":"support_tickets","perm":"reports.handle"}'
    when 'banner'   then '{"table":"home_banners","perm":"content.edit","text_id":false}'
    when 'category' then '{"table":"categories","perm":"content.edit","text_id":true}'
    when 'city'     then '{"table":"cities","perm":"content.edit","text_id":true}'
    when 'plan'     then '{"table":"subscription_plans","perm":"subscriptions.manage","text_id":true}'
  end::jsonb;
$$;

create function public.admin_is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admin_users where user_id = auth.uid() and is_active and role_id = 'owner');
$$;

-- Archive: hide everywhere, remember what to restore.
create function public.admin_archive_record(p_entity text, p_id text, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_meta jsonb := admin_entity(p_entity);
  v_prev jsonb := '{}'::jsonb;
  v_found boolean;
begin
  if v_meta is null then raise exception 'unknown record type' using errcode = '22023'; end if;
  perform require_admin_permission(v_meta ->> 'perm');
  if exists (select 1 from admin_archive where entity = p_entity and entity_id = p_id) then
    return jsonb_build_object('ok', false, 'error', 'already_archived');
  end if;

  case p_entity
    when 'user' then
      select jsonb_build_object('is_banned', is_banned) into v_prev from profiles where id = p_id::uuid;
      update profiles set is_banned = true, archived_at = now() where id = p_id::uuid;
      v_found := found;
      -- A provider's account takes the business down with it.
      if exists (select 1 from providers where id = p_id::uuid) then
        v_prev := v_prev || jsonb_build_object('provider_status', (select status from providers where id = p_id::uuid));
        update providers set status = 'suspended', archived_at = now() where id = p_id::uuid;
      end if;
    when 'provider' then
      select jsonb_build_object('status', status) into v_prev from providers where id = p_id::uuid;
      update providers set status = 'suspended', archived_at = now() where id = p_id::uuid;
      v_found := found;
    when 'service' then
      select jsonb_build_object('status', status) into v_prev from services where id = p_id::uuid;
      update services set status = 'paused', archived_at = now() where id = p_id::uuid;
      v_found := found;
    when 'store' then
      select jsonb_build_object('is_active', is_active) into v_prev from stores where id = p_id::uuid;
      update stores set is_active = false, archived_at = now() where id = p_id::uuid;
      v_found := found;
    when 'booking' then
      update bookings set archived_at = now() where id = p_id::uuid;
      v_found := found;
    when 'review' then
      select jsonb_build_object('status', status) into v_prev from reviews where id = p_id::uuid;
      update reviews set status = 'hidden', archived_at = now() where id = p_id::uuid;
      v_found := found;
      if v_found then perform refresh_provider_rating((select provider_id from reviews where id = p_id::uuid)); end if;
    when 'report' then
      update reports set archived_at = now() where id = p_id::uuid;
      v_found := found;
    when 'ticket' then
      update support_tickets set archived_at = now() where id = p_id::uuid;
      v_found := found;
    when 'banner' then
      select jsonb_build_object('is_active', is_active) into v_prev from home_banners where id = p_id::uuid;
      update home_banners set is_active = false, archived_at = now() where id = p_id::uuid;
      v_found := found;
    when 'category' then
      select jsonb_build_object('is_active', is_active) into v_prev from categories where id = p_id;
      update categories set is_active = false, archived_at = now() where id = p_id;
      v_found := found;
    when 'city' then
      select jsonb_build_object('is_active', is_active) into v_prev from cities where id = p_id;
      update cities set is_active = false, archived_at = now() where id = p_id;
      v_found := found;
    when 'plan' then
      select jsonb_build_object('is_active', is_active) into v_prev from subscription_plans where id = p_id;
      update subscription_plans set is_active = false, archived_at = now() where id = p_id;
      v_found := found;
  end case;
  if not v_found then raise exception 'not found' using errcode = 'P0002'; end if;

  insert into admin_archive (entity, entity_id, previous, note, archived_by)
  values (p_entity, p_id, coalesce(v_prev, '{}'::jsonb), p_note, auth.uid());
  perform admin_audit('archive', p_entity, p_id, jsonb_build_object('previous', v_prev, 'note', p_note));
  return jsonb_build_object('ok', true);
end;
$$;

-- Restore: put back what the archive switched off.
create function public.admin_restore_record(p_entity text, p_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_meta jsonb := admin_entity(p_entity);
  v_prev jsonb;
begin
  if v_meta is null then raise exception 'unknown record type' using errcode = '22023'; end if;
  perform require_admin_permission(v_meta ->> 'perm');
  select previous into v_prev from admin_archive where entity = p_entity and entity_id = p_id;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_archived'); end if;

  case p_entity
    when 'user' then
      update profiles set is_banned = coalesce((v_prev ->> 'is_banned')::boolean, false), archived_at = null where id = p_id::uuid;
      if v_prev ? 'provider_status' then
        update providers set status = (v_prev ->> 'provider_status')::provider_status, archived_at = null where id = p_id::uuid;
      end if;
    when 'provider' then
      update providers set status = coalesce((v_prev ->> 'status')::provider_status, 'pending'), archived_at = null where id = p_id::uuid;
    when 'service' then
      update services set status = coalesce((v_prev ->> 'status')::service_status, 'paused'), archived_at = null where id = p_id::uuid;
    when 'store' then
      update stores set is_active = coalesce((v_prev ->> 'is_active')::boolean, true), archived_at = null where id = p_id::uuid;
    when 'booking' then
      update bookings set archived_at = null where id = p_id::uuid;
    when 'review' then
      update reviews set status = coalesce((v_prev ->> 'status')::review_status, 'pending'), archived_at = null where id = p_id::uuid;
      perform refresh_provider_rating((select provider_id from reviews where id = p_id::uuid));
    when 'report' then
      update reports set archived_at = null where id = p_id::uuid;
    when 'ticket' then
      update support_tickets set archived_at = null where id = p_id::uuid;
    when 'banner' then
      update home_banners set is_active = coalesce((v_prev ->> 'is_active')::boolean, true), archived_at = null where id = p_id::uuid;
    when 'category' then
      update categories set is_active = coalesce((v_prev ->> 'is_active')::boolean, true), archived_at = null where id = p_id;
    when 'city' then
      update cities set is_active = coalesce((v_prev ->> 'is_active')::boolean, true), archived_at = null where id = p_id;
    when 'plan' then
      update subscription_plans set is_active = coalesce((v_prev ->> 'is_active')::boolean, true), archived_at = null where id = p_id;
  end case;
  delete from admin_archive where entity = p_entity and entity_id = p_id;
  perform admin_audit('restore', p_entity, p_id, v_prev);
  return jsonb_build_object('ok', true);
end;
$$;

-- Permanent delete (owner only). Deleting a user or provider removes the whole account and
-- everything that cascades from it (their business, services, stores and bookings as provider).
-- Records still in use elsewhere (a category with services, a plan with subscriptions) refuse
-- with `in_use`: archive those instead.
create function public.admin_delete_record(p_entity text, p_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_meta jsonb := admin_entity(p_entity);
  v_snapshot jsonb;
begin
  if v_meta is null then raise exception 'unknown record type' using errcode = '22023'; end if;
  if not admin_is_owner() then raise exception 'permission denied: owner only' using errcode = '42501'; end if;
  if p_entity in ('user', 'provider') and exists (select 1 from admin_users where user_id = p_id::uuid) then
    return jsonb_build_object('ok', false, 'error', 'is_admin');
  end if;

  execute format('select to_jsonb(t) from %I t where id = $1%s', v_meta ->> 'table',
                 case when coalesce((v_meta ->> 'text_id')::boolean, false) then '' else '::uuid' end)
    into v_snapshot using p_id;
  if v_snapshot is null then raise exception 'not found' using errcode = 'P0002'; end if;

  begin
    if p_entity in ('user', 'provider') then
      delete from auth.users where id = p_id::uuid;      -- cascades to profile, provider and the rest
    elsif coalesce((v_meta ->> 'text_id')::boolean, false) then
      execute format('delete from %I where id = $1', v_meta ->> 'table') using p_id;
    else
      execute format('delete from %I where id = $1::uuid', v_meta ->> 'table') using p_id;
    end if;
  exception when foreign_key_violation then
    return jsonb_build_object('ok', false, 'error', 'in_use');
  end;
  delete from admin_archive where entity = p_entity and entity_id = p_id;
  -- Keep a copy in the audit log, minus phone numbers.
  perform admin_audit('delete', p_entity, p_id, v_snapshot - 'phone');
  return jsonb_build_object('ok', true);
end;
$$;

-- Edit: only the listed fields of each record type can change.
create function public.admin_update_record(p_entity text, p_id text, p_changes jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_meta jsonb := admin_entity(p_entity);
  v_allowed text[] := case p_entity
    when 'user'     then array['display_name', 'first_name', 'last_name']
    when 'provider' then array['business_name', 'bio', 'address', 'instagram', 'cr_number', 'freelance_doc_number',
                               'female_staff_only', 'is_verified', 'review_note']
    when 'service'  then array['title', 'description', 'price', 'duration_minutes', 'category_id', 'female_staff_only',
                               'at_customer_location', 'status']
    when 'store'    then array['name', 'description', 'address', 'instagram', 'is_active']
    when 'booking'  then array['note', 'status']
    when 'ticket'   then array['status']
    when 'report'   then array['status']
  end;
  v_key text;
  v_sets text[] := '{}';
begin
  if v_meta is null or v_allowed is null then raise exception 'not editable' using errcode = '22023'; end if;
  perform require_admin_permission(v_meta ->> 'perm');
  for v_key in select jsonb_object_keys(coalesce(p_changes, '{}'::jsonb)) loop
    if not v_key = any (v_allowed) then
      return jsonb_build_object('ok', false, 'error', 'field_not_editable', 'field', v_key);
    end if;
    -- jsonb_populate_record casts each value to the column's own type (enums, numbers, booleans).
    v_sets := v_sets || format('%1$I = (jsonb_populate_record(null::%2$I, $1)).%1$I', v_key, v_meta ->> 'table');
  end loop;
  if cardinality(v_sets) = 0 then return jsonb_build_object('ok', true); end if;
  execute format('update %I set %s where id = $2::uuid', v_meta ->> 'table', array_to_string(v_sets, ', '))
    using p_changes, p_id;
  if not found then raise exception 'not found' using errcode = 'P0002'; end if;
  if p_entity = 'user' and (p_changes ? 'first_name' or p_changes ? 'last_name') and not p_changes ? 'display_name' then
    update profiles set display_name = nullif(trim(concat_ws(' ', first_name, last_name)), '') where id = p_id::uuid;
  end if;
  perform admin_audit('edit', p_entity, p_id, p_changes);
  return jsonb_build_object('ok', true);
end;
$$;

-- Owners can't edit an archived service or store from the app, and don't see it in their studio;
-- brides don't see archived bookings. (Bodies otherwise unchanged.)

create or replace function public.upsert_my_service(
  p_id uuid,
  p_title text,
  p_category_id text,
  p_price numeric,
  p_description text default null,
  p_duration_minutes int default null,
  p_female_staff_only boolean default false,
  p_at_customer_location boolean default false,
  p_store_id uuid default null,
  p_image_urls text[] default '{}',
  p_status text default 'active',
  p_videos jsonb default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
  v_id uuid;
  v_status service_status := case when p_status = 'paused' then 'paused'::service_status else 'active'::service_status end;
  v_max int := (provider_limits(v_uid) ->> 'max_services')::int;
  v_existing jsonb;
  v_videos jsonb;
begin
  if p_store_id is not null and not exists (select 1 from stores where id = p_store_id and provider_id = v_uid) then
    raise exception 'unknown store' using errcode = '22023';
  end if;
  if not exists (select 1 from categories where id = p_category_id and is_active) then
    raise exception 'unknown category' using errcode = '22023';
  end if;
  -- Plan limit: counts the other active services (requirement 2).
  if v_status = 'active' and (select count(*) from services
      where provider_id = v_uid and status = 'active' and id is distinct from p_id) >= v_max then
    return jsonb_build_object('ok', false, 'error', 'service_limit', 'max_services', v_max);
  end if;

  if p_id is not null then
    select videos into v_existing from services where id = p_id and provider_id = v_uid;
  end if;
  if p_videos is not null then
    v_videos := normalize_service_videos(p_videos);
    if v_videos is null or not service_videos_allowed(v_videos, v_uid, v_existing) then
      return jsonb_build_object('ok', false, 'error', 'invalid_video');
    end if;
  end if;

  if p_id is null then
    insert into services (provider_id, store_id, category_id, title, description, price, duration_minutes,
                          female_staff_only, at_customer_location, image_urls, videos, status)
    values (v_uid, p_store_id, p_category_id, trim(p_title), p_description, p_price, p_duration_minutes,
            coalesce(p_female_staff_only, false), coalesce(p_at_customer_location, false),
            coalesce(p_image_urls, '{}'), coalesce(v_videos, '[]'::jsonb), v_status)
    returning id into v_id;
  else
    update services set store_id = p_store_id, category_id = p_category_id, title = trim(p_title),
      description = p_description, price = p_price, duration_minutes = p_duration_minutes,
      female_staff_only = coalesce(p_female_staff_only, false),
      at_customer_location = coalesce(p_at_customer_location, false),
      image_urls = coalesce(p_image_urls, '{}'), videos = coalesce(v_videos, videos), status = v_status
    where id = p_id and provider_id = v_uid and archived_at is null   -- archived by an admin: read-only
    returning id into v_id;
    if v_id is null then raise exception 'not found' using errcode = 'P0002'; end if;
  end if;
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create or replace function public.get_my_business() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
  v_provider providers%rowtype;
begin
  select * into v_provider from providers where id = v_uid;
  return jsonb_build_object(
    'id', v_provider.id,
    'status', v_provider.status,
    'business_name', v_provider.business_name,
    'bio', v_provider.bio,
    'logo_url', v_provider.logo_url,
    'cover_url', v_provider.cover_url,
    'address', v_provider.address,
    'city_id', v_provider.city_id,
    'lat', v_provider.lat,
    'lng', v_provider.lng,
    'instagram', v_provider.instagram,
    'cr_number', v_provider.cr_number,
    'freelance_doc_number', v_provider.freelance_doc_number,
    'is_verified', v_provider.is_verified,
    'female_staff_only', v_provider.female_staff_only,
    'trial_ends_at', v_provider.trial_ends_at,
    'review_note', v_provider.review_note,
    'category_ids', coalesce((select jsonb_agg(category_id order by category_id) from provider_categories where provider_id = v_uid), '[]'::jsonb),
    'city_ids', coalesce((select jsonb_agg(city_id order by city_id) from provider_cities where provider_id = v_uid), '[]'::jsonb),
    'limits', provider_limits(v_uid),
    'services', coalesce((select jsonb_agg(jsonb_build_object(
        'id', s.id, 'title', s.title, 'description', s.description, 'category_id', s.category_id,
        'price', s.price, 'duration_minutes', s.duration_minutes, 'female_staff_only', s.female_staff_only,
        'at_customer_location', s.at_customer_location, 'store_id', s.store_id,
        'image_urls', to_jsonb(s.image_urls), 'videos', s.videos, 'status', s.status) order by s.created_at)
      from services s where s.provider_id = v_uid and s.archived_at is null), '[]'::jsonb),
    'stores', coalesce((select jsonb_agg(jsonb_build_object(
        'id', st.id, 'name', st.name, 'description', st.description, 'logo_url', st.logo_url,
        'address', st.address, 'city_id', st.city_id, 'lat', st.lat, 'lng', st.lng,
        'instagram', st.instagram, 'is_active', st.is_active) order by st.created_at)
      from stores st where st.provider_id = v_uid and st.archived_at is null), '[]'::jsonb));
end;
$$;

create or replace function public.upsert_my_store(
  p_id uuid,
  p_name text,
  p_description text default null,
  p_address text default null,
  p_city_id text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_instagram text default null,
  p_logo_url text default null,
  p_is_active boolean default true
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
  v_id uuid;
  v_max int := (provider_limits(v_uid) ->> 'max_stores')::int;
begin
  if p_id is null then
    if (select count(*) from stores where provider_id = v_uid) >= v_max then
      return jsonb_build_object('ok', false, 'error', 'store_limit', 'max_stores', v_max);
    end if;
    insert into stores (provider_id, name, description, address, city_id, lat, lng, instagram, logo_url, is_active)
    values (v_uid, trim(p_name), p_description, p_address, (select id from cities where id = p_city_id),
            p_lat, p_lng, p_instagram, p_logo_url, coalesce(p_is_active, true))
    returning id into v_id;
  else
    update stores set name = trim(p_name), description = p_description, address = p_address,
      city_id = (select id from cities where id = p_city_id), lat = p_lat, lng = p_lng,
      instagram = p_instagram, logo_url = p_logo_url, is_active = coalesce(p_is_active, true)
    where id = p_id and provider_id = v_uid and archived_at is null
    returning id into v_id;
    if v_id is null then raise exception 'not found' using errcode = 'P0002'; end if;
  end if;
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create or replace function public.get_my_bookings(p_scope text default 'active') returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(booking_json(b, case when b.bride_id = auth.uid() then 'bride' else 'provider' end)
                            order by case when p_scope = 'active' then b.starts_at end asc,
                                     case when p_scope <> 'active' then b.starts_at end desc), '[]'::jsonb)
  from bookings b
  where (b.bride_id = auth.uid() or b.provider_id = auth.uid()) and b.archived_at is null
    and (case when p_scope = 'active' then booking_is_active(b.status) else not booking_is_active(b.status) end);
$$;

create or replace function public.get_booking(p_booking uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select booking_detail_json(b, case when b.bride_id = auth.uid() then 'bride' else 'provider' end)
  from bookings b
  where b.id = p_booking and (b.bride_id = auth.uid() or b.provider_id = auth.uid()) and b.archived_at is null;
$$;

revoke all on function public.admin_entity(text), public.admin_is_owner(),
  public.admin_archive_record(text, text, text), public.admin_restore_record(text, text),
  public.admin_delete_record(text, text), public.admin_update_record(text, text, jsonb) from public, anon;
grant execute on function public.admin_is_owner(), public.admin_archive_record(text, text, text),
  public.admin_restore_record(text, text), public.admin_delete_record(text, text),
  public.admin_update_record(text, text, jsonb) to authenticated;
