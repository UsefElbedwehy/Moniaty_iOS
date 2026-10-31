-- Brides and wedding guests (المعازيم).
--
-- Customer accounts now say whom they are browsing for, and providers say whom they serve:
--   'bride'  : the bride herself (e.g. a bridal makeup artist);
--   'guests' : the wedding guests (e.g. makeup for guests, food);
--   'both'   : both.
-- Customers are still `bride` accounts (booking, receipts and reviews are unchanged); the landing
-- screen offers «عروس» and «معازيم», and either can switch later in Profile.
--
-- Home, search and the map show a customer only providers that serve her audience ('both' sees
-- everyone; providers that serve 'both' are shown to everyone). Guests without an account and
-- provider accounts see everyone. Pages reached by a link (service, provider, store) and
-- favorites stay open to all.
--
-- Existing customers start as 'bride'; existing providers as 'both', so nobody disappears from
-- the lists until they choose.

alter table public.profiles add column audience text not null default 'bride'
  check (audience in ('bride', 'guests', 'both'));
alter table public.providers add column audience text not null default 'both'
  check (audience in ('bride', 'guests', 'both'));

-- Does this provider serve the signed-in customer's audience? True for anyone who isn't a
-- customer account (anonymous guests, providers, signed out).
create function public.provider_serves_me(p_provider_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((
    select pr.audience = 'both' or me.audience = 'both' or pr.audience = me.audience
    from profiles me, providers pr
    where me.id = auth.uid() and me.role = 'bride' and me.deleted_at is null and pr.id = p_provider_id), true);
$$;

-- One RPC for both sides: a customer's browsing audience, or the audience a provider serves.
create function public.set_my_audience(p_audience text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_role user_role;
begin
  if p_audience is null or p_audience not in ('bride', 'guests', 'both') then
    raise exception 'invalid audience' using errcode = '22023';
  end if;
  select role into v_role from profiles where id = v_uid and deleted_at is null;
  if not found then raise exception 'not signed in' using errcode = '28000'; end if;
  if v_role = 'provider' then
    update providers set audience = p_audience where id = v_uid;
  else
    update profiles set audience = p_audience where id = v_uid;
  end if;
  return jsonb_build_object('ok', true, 'audience', p_audience);
end;
$$;

-- The profile carries the audience (the provider's for provider accounts).
create or replace function public.get_my_profile() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_profile profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  select * into v_profile from profiles where id = v_uid and deleted_at is null;
  if not found then
    return jsonb_build_object(
      'id', v_uid, 'role', null, 'display_name', null, 'phone', null,
      'city_ids', '[]'::jsonb,
      'is_anonymous', coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false),
      'provider_status', null, 'audience', null);
  end if;
  return jsonb_build_object(
    'id', v_profile.id,
    'display_name', v_profile.display_name,
    'phone', v_profile.phone,
    'role', v_profile.role,
    'language', v_profile.language,
    'sms_marketing_opt_in', v_profile.sms_marketing_opt_in,
    'city_ids', coalesce((select jsonb_agg(city_id order by city_id) from profile_cities where profile_id = v_uid), '[]'::jsonb),
    'is_anonymous', false,
    'provider_status', (select status from providers where id = v_uid),
    'audience', case when v_profile.role = 'provider'
                     then (select audience from providers where id = v_uid) else v_profile.audience end);
end;
$$;

-- Studio's business carries the audience too.
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
    'audience', v_provider.audience,
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

-- The lists: search (and Home's featured/newest, which use it), Home's category counts, the map.
create or replace function public.search_services(
  p_query text default null,
  p_category_id text default null,
  p_city_ids text[] default null,
  p_max_price numeric default null,
  p_female_only boolean default false,
  p_sort text default 'recommended',
  p_limit int default 30,
  p_offset int default 0,
  p_date date default null
) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(service_card(s) order by
           case when p_sort = 'price_asc' then s.price end asc,
           case when p_sort = 'price_desc' then s.price end desc,
           case when p_sort = 'newest' then s.created_at end desc,
           case when coalesce(p_sort, 'recommended') = 'recommended' then provider_boost(s.provider_id) end desc nulls last,
           p.is_verified desc, s.created_at desc), '[]'::jsonb)
  from (
    select s.* from services s
    join providers p on p.id = s.provider_id
    where service_is_public(s)
      and provider_serves_me(s.provider_id)
      and (p_category_id is null or s.category_id = p_category_id)
      and provider_in_cities(s.provider_id, p_city_ids)
      and (p_max_price is null or s.price <= p_max_price)
      and (not coalesce(p_female_only, false) or s.female_staff_only or p.female_staff_only)
      and (coalesce(trim(p_query), '') = ''
           or s.title ilike '%' || trim(p_query) || '%'
           or s.description ilike '%' || trim(p_query) || '%'
           or p.business_name ilike '%' || trim(p_query) || '%')
      and (p_date is null or jsonb_array_length(get_available_slots(s.id, p_date)) > 0)
    order by
      case when p_sort = 'price_asc' then s.price end asc,
      case when p_sort = 'price_desc' then s.price end desc,
      case when p_sort = 'newest' then s.created_at end desc,
      case when coalesce(p_sort, 'recommended') = 'recommended' then provider_boost(s.provider_id) end desc nulls last,
      p.is_verified desc, s.created_at desc
    limit least(greatest(coalesce(p_limit, 30), 1), 50) offset greatest(coalesce(p_offset, 0), 0)
  ) s
  join providers p on p.id = s.provider_id;
$$;

create or replace function public.get_home(p_city_ids text[] default null, p_max_price numeric default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'banners', home_banners_for(p_city_ids),
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'name_ar', c.name_ar, 'name_en', c.name_en, 'icon_url', c.icon_url,
               'icon_symbol', c.icon_symbol, 'price_hint_ar', c.price_hint_ar, 'price_hint_en', c.price_hint_en,
               'admin_listings', c.admin_listings,
               'service_count', case when c.admin_listings
                 then (select count(*) from dress_listings d where dress_listing_is_live(d))
                 else (select count(*) from services s
                       where s.category_id = c.id and service_is_public(s)
                         and provider_serves_me(s.provider_id)
                         and provider_in_cities(s.provider_id, p_city_ids)) end)
             order by c.sort_order)
      from categories c where c.is_active), '[]'::jsonb),
    'featured', search_services(null, null, p_city_ids, p_max_price, false, 'recommended', 10, 0),
    'newest', search_services(null, null, p_city_ids, null, false, 'newest', 10, 0));
$$;

create or replace function public.get_map_pins(
  p_min_lat double precision, p_min_lng double precision,
  p_max_lat double precision, p_max_lng double precision,
  p_city_ids text[] default null,
  p_category_id text default null
) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(pin), '[]'::jsonb) from (
    select jsonb_build_object('kind', 'provider', 'id', p.id, 'name', p.business_name,
                              'lat', p.lat, 'lng', p.lng, 'logo_url', p.logo_url) as pin
    from providers p
    where p.status = 'approved' and p.lat between p_min_lat and p_max_lat and p.lng between p_min_lng and p_max_lng
      and provider_in_cities(p.id, p_city_ids)
      and provider_serves_me(p.id)
      and exists (select 1 from services s where s.provider_id = p.id and service_is_public(s)
                    and (p_category_id is null or s.category_id = p_category_id))
    union all
    select jsonb_build_object('kind', 'store', 'id', st.id, 'name', st.name,
                              'lat', st.lat, 'lng', st.lng, 'logo_url', st.logo_url)
    from stores st
    where st.is_active and provider_is_listed(st.provider_id)
      and provider_serves_me(st.provider_id)
      and st.lat between p_min_lat and p_max_lat and st.lng between p_min_lng and p_max_lng
      and (coalesce(cardinality(p_city_ids), 0) = 0 or st.city_id = any (p_city_ids))
      and (p_category_id is null or exists (select 1 from services s where s.store_id = st.id
                                            and s.category_id = p_category_id and service_is_public(s)))
    limit 300
  ) pins;
$$;

revoke all on function public.provider_serves_me(uuid) from public, anon, authenticated;
revoke all on function public.set_my_audience(text) from public, anon;
grant execute on function public.set_my_audience(text) to authenticated;
