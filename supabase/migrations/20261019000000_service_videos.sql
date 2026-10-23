-- =============================================================================================
-- Munyati — videos on services.
--
-- A service shows its photos and then up to 3 short videos (the apps cap each at 60 seconds and
-- compress to 720p before upload). Each video is `{url, poster_url, duration_seconds}`: the apps
-- make the poster frame at upload so lists never have to download a video to draw it.
-- Providers upload into their own folder of the public `media` bucket; admins can add or remove
-- media from the dashboard (uploaded to `content/services/<service id>/`).
-- =============================================================================================

alter table public.services
  add column videos jsonb not null default '[]'::jsonb
  constraint services_videos_shape check (jsonb_typeof(videos) = 'array' and jsonb_array_length(videos) <= 3);

-- Keeps only well-formed https entries in the shape the apps decode; null when anything is off.
create function public.normalize_service_videos(p_videos jsonb) returns jsonb
language plpgsql immutable set search_path = public as $$
declare
  v_out jsonb := '[]'::jsonb;
  v jsonb;
begin
  if p_videos is null then return '[]'::jsonb; end if;
  if jsonb_typeof(p_videos) <> 'array' or jsonb_array_length(p_videos) > 3 then return null; end if;
  for v in select * from jsonb_array_elements(p_videos) loop
    if jsonb_typeof(v) <> 'object' or coalesce(v ->> 'url', '') !~ '^https://'
       or (v ? 'poster_url' and v ->> 'poster_url' is not null and v ->> 'poster_url' !~ '^https://') then
      return null;
    end if;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'url', v ->> 'url',
      'poster_url', v ->> 'poster_url',
      'duration_seconds', case when jsonb_typeof(v -> 'duration_seconds') = 'number'
                               then least(greatest(round((v ->> 'duration_seconds')::numeric)::int, 0), 3600) end));
  end loop;
  return v_out;
end;
$$;

-- Every URL in `p_videos` is the provider's own upload, or was already on the service (an
-- admin may have added it from the dashboard).
create function public.service_videos_allowed(p_videos jsonb, p_uid uuid, p_existing jsonb) returns boolean
language sql immutable set search_path = public as $$
  select not exists (
    select 1
    from jsonb_array_elements(p_videos) v, lateral (values (v ->> 'url'), (v ->> 'poster_url')) u(url)
    where u.url is not null
      and u.url not like '%/storage/v1/object/public/media/' || p_uid::text || '/%'
      and not exists (select 1 from jsonb_array_elements(coalesce(p_existing, '[]'::jsonb)) e
                      where e ->> 'url' = u.url or e ->> 'poster_url' = u.url));
$$;

-- `p_videos` is new and optional: null keeps the service's current videos, so app versions that
-- predate videos never wipe them. (Dropped and recreated rather than overloaded: two candidates
-- would make PostgREST's named-argument call ambiguous.)
drop function public.upsert_my_service(uuid, text, text, numeric, text, int, boolean, boolean, uuid, text[], text);
create function public.upsert_my_service(
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
    where id = p_id and provider_id = v_uid
    returning id into v_id;
    if v_id is null then raise exception 'not found' using errcode = 'P0002'; end if;
  end if;
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;
revoke all on function public.upsert_my_service(uuid, text, text, numeric, text, int, boolean, boolean, uuid, text[], text, jsonb) from public, anon;
grant execute on function public.upsert_my_service(uuid, text, text, numeric, text, int, boolean, boolean, uuid, text[], text, jsonb) to authenticated;

-- The bride's service page and the provider's own business both gain `videos`.
create or replace function public.get_service(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_service services%rowtype;
begin
  select * into v_service from services where id = p_id;
  if not found or not (service_is_public(v_service) or v_service.provider_id = auth.uid()) then
    return null;
  end if;
  return service_card(v_service) || jsonb_build_object(
    'description', v_service.description,
    'duration_minutes', v_service.duration_minutes,
    'at_customer_location', v_service.at_customer_location,
    'image_urls', to_jsonb(v_service.image_urls),
    'videos', v_service.videos,
    'provider', provider_summary(v_service.provider_id),
    'store', case when v_service.store_id is not null then store_summary(v_service.store_id) end,
    'more_from_provider', coalesce((
      select jsonb_agg(service_card(s) order by s.created_at desc)
      from (select * from services s where s.provider_id = v_service.provider_id and s.id <> v_service.id
              and service_is_public(s) order by s.created_at desc limit 6) s), '[]'::jsonb));
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
      from services s where s.provider_id = v_uid), '[]'::jsonb),
    'stores', coalesce((select jsonb_agg(jsonb_build_object(
        'id', st.id, 'name', st.name, 'description', st.description, 'logo_url', st.logo_url,
        'address', st.address, 'city_id', st.city_id, 'lat', st.lat, 'lng', st.lng,
        'instagram', st.instagram, 'is_active', st.is_active) order by st.created_at)
      from stores st where st.provider_id = v_uid), '[]'::jsonb));
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Dashboard: an admin replaces a service's photos and videos (moderation, or helping a provider).
-- ---------------------------------------------------------------------------------------------

create function public.admin_set_service_media(p_service uuid, p_image_urls text[], p_videos jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_videos jsonb := normalize_service_videos(p_videos);
begin
  perform require_admin_permission('providers.review');
  if v_videos is null then return jsonb_build_object('ok', false, 'error', 'invalid_video'); end if;
  if cardinality(coalesce(p_image_urls, '{}')) > 30
     or exists (select 1 from unnest(coalesce(p_image_urls, '{}')) u where u !~ '^https://') then
    return jsonb_build_object('ok', false, 'error', 'invalid_photo');
  end if;
  -- The plan's photo limit (services_photo_limit trigger) still applies when photos are added.
  update services set image_urls = coalesce(p_image_urls, '{}'), videos = v_videos where id = p_service;
  if not found then raise exception 'not found' using errcode = 'P0002'; end if;
  perform admin_audit('set_media', 'services', p_service::text,
    jsonb_build_object('image_urls', to_jsonb(coalesce(p_image_urls, '{}')), 'videos', v_videos));
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.admin_set_service_media(uuid, text[], jsonb) from public, anon;
grant execute on function public.admin_set_service_media(uuid, text[], jsonb) to authenticated;

-- Admins who review providers may upload service media to `content/services/…` (the `content`
-- bucket otherwise needs content.edit).
create policy content_service_media_write on storage.objects for insert to authenticated
  with check (bucket_id = 'content' and (storage.foldername(name))[1] = 'services'
              and public.has_admin_permission('providers.review'));
create policy content_service_media_delete on storage.objects for delete to authenticated
  using (bucket_id = 'content' and (storage.foldername(name))[1] = 'services'
         and public.has_admin_permission('providers.review'));
