-- Munyati Phase 2: discovery (docs/PLAN.md §4.4, §4.9, §4.10, §12 phase 2).
--
-- Providers' public profile, stores and services; favorites; the bride's budget; and the
-- read RPCs behind Home, search, detail screens and the Explore map. Providers manage their
-- business through `*_my_*` RPCs. Only approved providers' active services are public.

-- ---------------------------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------------------------

alter table public.providers
  add column logo_url text,
  add column cover_url text,
  add column address text,
  add column city_id text references public.cities(id) on delete set null,
  add column lat double precision,
  add column lng double precision,
  add column instagram text;

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  name text not null check (length(trim(name)) between 2 and 80),
  description text check (length(description) <= 1000),
  logo_url text,
  address text,
  city_id text references public.cities(id) on delete set null,
  lat double precision,
  lng double precision,
  instagram text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index stores_provider_idx on public.stores (provider_id);
create trigger stores_touch before update on public.stores for each row execute function public.touch_updated_at();

create type public.service_status as enum ('active', 'paused');

create table public.services (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  store_id uuid references public.stores(id) on delete set null,
  category_id text not null references public.categories(id),
  title text not null check (length(trim(title)) between 2 and 80),
  description text check (length(description) <= 2000),
  price numeric(10, 2) not null check (price >= 0 and price <= 1000000),
  duration_minutes int check (duration_minutes between 15 and 1440),
  female_staff_only boolean not null default false,
  at_customer_location boolean not null default false,
  image_urls text[] not null default '{}' check (cardinality(image_urls) <= 30),
  status public.service_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index services_provider_idx on public.services (provider_id);
create index services_category_price_idx on public.services (category_id, price) where status = 'active';
create trigger services_touch before update on public.services for each row execute function public.touch_updated_at();

create table public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  service_id uuid not null references public.services(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, service_id)
);

create table public.bride_budgets (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  total_amount numeric(12, 2) not null check (total_amount >= 0 and total_amount <= 100000000),
  wedding_date date,
  updated_at timestamptz not null default now()
);

alter table public.stores enable row level security;
alter table public.services enable row level security;
alter table public.favorites enable row level security;
alter table public.bride_budgets enable row level security;

-- Reads go through RPCs; these policies only let owners and admins see raw rows.
create policy stores_read on public.stores for select to authenticated using (provider_id = auth.uid() or public.is_admin());
create policy services_read on public.services for select to authenticated using (provider_id = auth.uid() or public.is_admin());
create policy favorites_read on public.favorites for select to authenticated using (user_id = auth.uid());
create policy bride_budgets_read on public.bride_budgets for select to authenticated using (profile_id = auth.uid() or public.is_admin());
revoke insert, update, delete on public.stores, public.services, public.favorites, public.bride_budgets from anon, authenticated;

-- Public `media` bucket: each provider uploads only under their own folder (<uid>/...).
insert into storage.buckets (id, name, public) values ('media', 'media', true) on conflict (id) do nothing;
create policy media_read on storage.objects for select to anon, authenticated using (bucket_id = 'media');
create policy media_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy media_owner_update on storage.objects for update to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy media_owner_delete on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------------------------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------------------------

-- How many active services / stores a provider may have. Phase 4 replaces this with the
-- provider's subscription plan; until then the trial allowance from app_config applies.
create function public.provider_limits(p_provider uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'max_services', coalesce((get_config() ->> 'trial_max_services')::int, 10),
    'max_stores', coalesce((get_config() ->> 'trial_max_stores')::int, 3));
$$;

-- A service is public when it is active, its category is active and its provider is approved.
create function public.service_is_public(p_service public.services) returns boolean
language sql stable security definer set search_path = public as $$
  select p_service.status = 'active'
     and exists (select 1 from providers p where p.id = p_service.provider_id and p.status = 'approved')
     and exists (select 1 from categories c where c.id = p_service.category_id and c.is_active);
$$;

-- Does the provider serve any of the given cities? An empty/null filter means "All".
create function public.provider_in_cities(p_provider uuid, p_city_ids text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(cardinality(p_city_ids), 0) = 0
      or exists (select 1 from provider_cities pc where pc.provider_id = p_provider and pc.city_id = any (p_city_ids));
$$;

-- The card shown in lists.
create function public.service_card(p_service public.services) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p_service.id,
    'title', p_service.title,
    'price', p_service.price,
    'image_url', p_service.image_urls[1],
    'category_id', p_service.category_id,
    'provider_id', p.id,
    'provider_name', p.business_name,
    'provider_logo_url', p.logo_url,
    'is_verified', p.is_verified,
    'female_staff_only', p_service.female_staff_only or p.female_staff_only,
    'is_favorite', exists (select 1 from favorites f where f.user_id = auth.uid() and f.service_id = p_service.id))
  from providers p where p.id = p_service.provider_id;
$$;

create function public.provider_summary(p_provider uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'name', p.business_name, 'logo_url', p.logo_url, 'is_verified', p.is_verified,
    'female_staff_only', p.female_staff_only,
    'city_ids', coalesce((select jsonb_agg(city_id order by city_id) from provider_cities where provider_id = p.id), '[]'::jsonb))
  from providers p where p.id = p_provider;
$$;

create function public.store_summary(p_store uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', s.id, 'name', s.name, 'logo_url', s.logo_url, 'address', s.address,
                            'city_id', s.city_id, 'lat', s.lat, 'lng', s.lng)
  from stores s where s.id = p_store;
$$;

-- ---------------------------------------------------------------------------------------------
-- Bride-facing RPCs (anon allowed: guests browse)
-- ---------------------------------------------------------------------------------------------

-- Search and category lists. `p_max_price` implements "within my budget".
create function public.search_services(
  p_query text default null,
  p_category_id text default null,
  p_city_ids text[] default null,
  p_max_price numeric default null,
  p_female_only boolean default false,
  p_sort text default 'recommended',     -- recommended | price_asc | price_desc | newest
  p_limit int default 30,
  p_offset int default 0
) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(service_card(s) order by
           case when p_sort = 'price_asc' then s.price end asc,
           case when p_sort = 'price_desc' then s.price end desc,
           case when p_sort = 'newest' then s.created_at end desc,
           p.is_verified desc, s.created_at desc), '[]'::jsonb)
  from (
    select s.* from services s
    join providers p on p.id = s.provider_id
    where service_is_public(s)
      and (p_category_id is null or s.category_id = p_category_id)
      and provider_in_cities(s.provider_id, p_city_ids)
      and (p_max_price is null or s.price <= p_max_price)
      and (not coalesce(p_female_only, false) or s.female_staff_only or p.female_staff_only)
      and (coalesce(trim(p_query), '') = ''
           or s.title ilike '%' || trim(p_query) || '%'
           or s.description ilike '%' || trim(p_query) || '%'
           or p.business_name ilike '%' || trim(p_query) || '%')
    order by
      case when p_sort = 'price_asc' then s.price end asc,
      case when p_sort = 'price_desc' then s.price end desc,
      case when p_sort = 'newest' then s.created_at end desc,
      p.is_verified desc, s.created_at desc
    limit least(greatest(coalesce(p_limit, 30), 1), 50) offset greatest(coalesce(p_offset, 0), 0)
  ) s
  join providers p on p.id = s.provider_id;
$$;

-- Home: categories with live counts, plus picks (within budget when given).
create function public.get_home(p_city_ids text[] default null, p_max_price numeric default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'name_ar', c.name_ar, 'name_en', c.name_en, 'icon_url', c.icon_url,
               'icon_symbol', c.icon_symbol, 'price_hint_ar', c.price_hint_ar, 'price_hint_en', c.price_hint_en,
               'service_count', (select count(*) from services s
                                 where s.category_id = c.id and service_is_public(s)
                                   and provider_in_cities(s.provider_id, p_city_ids)))
             order by c.sort_order)
      from categories c where c.is_active), '[]'::jsonb),
    'featured', search_services(null, null, p_city_ids, p_max_price, false, 'recommended', 10, 0),
    'newest', search_services(null, null, p_city_ids, null, false, 'newest', 10, 0));
$$;

create function public.get_service(p_id uuid) returns jsonb
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
    'provider', provider_summary(v_service.provider_id),
    'store', case when v_service.store_id is not null then store_summary(v_service.store_id) end,
    'more_from_provider', coalesce((
      select jsonb_agg(service_card(s) order by s.created_at desc)
      from (select * from services s where s.provider_id = v_service.provider_id and s.id <> v_service.id
              and service_is_public(s) order by s.created_at desc limit 6) s), '[]'::jsonb));
end;
$$;

create function public.get_provider(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_provider providers%rowtype;
begin
  select * into v_provider from providers where id = p_id;
  if not found or (v_provider.status <> 'approved' and v_provider.id <> auth.uid() and not is_admin()) then
    return null;
  end if;
  return provider_summary(p_id) || jsonb_build_object(
    'bio', v_provider.bio,
    'cover_url', v_provider.cover_url,
    'address', v_provider.address,
    'lat', v_provider.lat,
    'lng', v_provider.lng,
    'instagram', v_provider.instagram,
    'services', coalesce((select jsonb_agg(service_card(s) order by s.category_id, s.price)
                          from services s where s.provider_id = p_id and service_is_public(s)), '[]'::jsonb),
    'stores', coalesce((select jsonb_agg(store_summary(st.id) order by st.created_at)
                        from stores st where st.provider_id = p_id and st.is_active), '[]'::jsonb));
end;
$$;

create function public.get_store(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_store stores%rowtype;
begin
  select * into v_store from stores where id = p_id and is_active;
  if not found or not exists (select 1 from providers where id = v_store.provider_id and status = 'approved') then
    return null;
  end if;
  return store_summary(p_id) || jsonb_build_object(
    'description', v_store.description,
    'instagram', v_store.instagram,
    'provider', provider_summary(v_store.provider_id),
    'services', coalesce((select jsonb_agg(service_card(s) order by s.price)
                          from services s where s.store_id = p_id and service_is_public(s)), '[]'::jsonb));
end;
$$;

-- Explore map: lightweight pins inside the visible region.
create function public.get_map_pins(
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
      and exists (select 1 from services s where s.provider_id = p.id and service_is_public(s)
                    and (p_category_id is null or s.category_id = p_category_id))
    union all
    select jsonb_build_object('kind', 'store', 'id', st.id, 'name', st.name,
                              'lat', st.lat, 'lng', st.lng, 'logo_url', st.logo_url)
    from stores st join providers p on p.id = st.provider_id
    where st.is_active and p.status = 'approved'
      and st.lat between p_min_lat and p_max_lat and st.lng between p_min_lng and p_max_lng
      and (coalesce(cardinality(p_city_ids), 0) = 0 or st.city_id = any (p_city_ids))
      and (p_category_id is null or exists (select 1 from services s where s.store_id = st.id
                                            and s.category_id = p_category_id and service_is_public(s)))
    limit 300
  ) pins;
$$;

-- Favorites (signed-in accounts only; guests are asked to sign in by the app).
create function public.toggle_favorite(p_service_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not exists (select 1 from profiles where id = v_uid and deleted_at is null) then
    raise exception 'sign in required' using errcode = '28000';
  end if;
  if not exists (select 1 from services s where s.id = p_service_id and service_is_public(s)) then
    raise exception 'service not found' using errcode = 'P0002';
  end if;
  if exists (select 1 from favorites where user_id = v_uid and service_id = p_service_id) then
    delete from favorites where user_id = v_uid and service_id = p_service_id;
    return jsonb_build_object('is_favorite', false);
  end if;
  insert into favorites (user_id, service_id) values (v_uid, p_service_id);
  return jsonb_build_object('is_favorite', true);
end;
$$;

create function public.get_my_favorites() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(service_card(s) order by f.created_at desc), '[]'::jsonb)
  from favorites f join services s on s.id = f.service_id
  where f.user_id = auth.uid() and service_is_public(s);
$$;

-- Budget (requirement 13). `reserved` becomes the sum of approved bookings in Phase 3.
create function public.get_my_budget() returns jsonb
language sql stable security definer set search_path = public as $$
  select case when b.profile_id is null then null else jsonb_build_object(
    'total', b.total_amount,
    'reserved', 0,
    'remaining', b.total_amount,
    'wedding_date', b.wedding_date) end
  from (select auth.uid() as uid) u
  left join bride_budgets b on b.profile_id = u.uid;
$$;

create function public.set_my_budget(p_total numeric, p_wedding_date date default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not exists (select 1 from profiles where id = v_uid and role = 'bride' and deleted_at is null) then
    raise exception 'bride account required' using errcode = '42501';
  end if;
  if p_total is null or p_total < 0 then raise exception 'invalid amount' using errcode = '22023'; end if;
  insert into bride_budgets (profile_id, total_amount, wedding_date, updated_at)
  values (v_uid, p_total, p_wedding_date, now())
  on conflict (profile_id) do update set total_amount = excluded.total_amount,
    wedding_date = excluded.wedding_date, updated_at = now();
  return get_my_budget();
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Provider studio RPCs (the caller must be a provider; works while the join request is pending
-- so the provider can prepare their listing before approval)
-- ---------------------------------------------------------------------------------------------

create function public.require_provider() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not exists (select 1 from providers where id = v_uid and status <> 'suspended') then
    raise exception 'provider account required' using errcode = '42501';
  end if;
  return v_uid;
end;
$$;

create function public.get_my_business() returns jsonb
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
        'image_urls', to_jsonb(s.image_urls), 'status', s.status) order by s.created_at)
      from services s where s.provider_id = v_uid), '[]'::jsonb),
    'stores', coalesce((select jsonb_agg(jsonb_build_object(
        'id', st.id, 'name', st.name, 'description', st.description, 'logo_url', st.logo_url,
        'address', st.address, 'city_id', st.city_id, 'lat', st.lat, 'lng', st.lng,
        'instagram', st.instagram, 'is_active', st.is_active) order by st.created_at)
      from stores st where st.provider_id = v_uid), '[]'::jsonb));
end;
$$;

create function public.update_my_business(
  p_business_name text,
  p_bio text default null,
  p_category_ids text[] default '{}',
  p_city_ids text[] default '{}',
  p_address text default null,
  p_city_id text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_instagram text default null,
  p_logo_url text default null,
  p_cover_url text default null,
  p_cr_number text default null,
  p_freelance_doc_number text default null,
  p_female_staff_only boolean default false
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
begin
  if length(trim(coalesce(p_business_name, ''))) < 2 then
    raise exception 'business name required' using errcode = '22023';
  end if;
  update providers set
    business_name = trim(p_business_name),
    bio = left(p_bio, 2000),
    address = left(p_address, 300),
    city_id = (select id from cities where id = p_city_id),
    lat = p_lat, lng = p_lng,
    instagram = left(p_instagram, 100),
    logo_url = p_logo_url,
    cover_url = p_cover_url,
    -- Changing the registration number clears the verified badge until an admin re-checks it.
    is_verified = case when cr_number is distinct from nullif(trim(p_cr_number), '')
                        or freelance_doc_number is distinct from nullif(trim(p_freelance_doc_number), '')
                       then false else is_verified end,
    cr_number = nullif(trim(p_cr_number), ''),
    freelance_doc_number = nullif(trim(p_freelance_doc_number), ''),
    female_staff_only = coalesce(p_female_staff_only, false)
  where id = v_uid;

  delete from provider_categories where provider_id = v_uid;
  insert into provider_categories (provider_id, category_id)
  select v_uid, c.id from categories c where c.id = any (coalesce(p_category_ids, '{}'));

  delete from provider_cities where provider_id = v_uid;
  insert into provider_cities (provider_id, city_id)
  select v_uid, c.id from cities c where c.id = any (coalesce(p_city_ids, '{}')) and c.is_active;

  return jsonb_build_object('ok', true);
end;
$$;

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
  p_status text default 'active'
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
  v_id uuid;
  v_status service_status := case when p_status = 'paused' then 'paused'::service_status else 'active'::service_status end;
  v_max int := (provider_limits(v_uid) ->> 'max_services')::int;
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

  if p_id is null then
    insert into services (provider_id, store_id, category_id, title, description, price, duration_minutes,
                          female_staff_only, at_customer_location, image_urls, status)
    values (v_uid, p_store_id, p_category_id, trim(p_title), p_description, p_price, p_duration_minutes,
            coalesce(p_female_staff_only, false), coalesce(p_at_customer_location, false),
            coalesce(p_image_urls, '{}'), v_status)
    returning id into v_id;
  else
    update services set store_id = p_store_id, category_id = p_category_id, title = trim(p_title),
      description = p_description, price = p_price, duration_minutes = p_duration_minutes,
      female_staff_only = coalesce(p_female_staff_only, false),
      at_customer_location = coalesce(p_at_customer_location, false),
      image_urls = coalesce(p_image_urls, '{}'), status = v_status
    where id = p_id and provider_id = v_uid
    returning id into v_id;
    if v_id is null then raise exception 'not found' using errcode = 'P0002'; end if;
  end if;
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create function public.delete_my_service(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
begin
  delete from services where id = p_id and provider_id = v_uid;
  return jsonb_build_object('ok', found);
end;
$$;

create function public.upsert_my_store(
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
    where id = p_id and provider_id = v_uid
    returning id into v_id;
    if v_id is null then raise exception 'not found' using errcode = 'P0002'; end if;
  end if;
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create function public.delete_my_store(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
begin
  delete from stores where id = p_id and provider_id = v_uid;
  return jsonb_build_object('ok', found);
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------------------------

revoke all on function public.toggle_favorite(uuid), public.get_my_favorites(), public.get_my_budget(),
  public.set_my_budget(numeric, date), public.require_provider(), public.get_my_business(),
  public.update_my_business(text, text, text[], text[], text, text, double precision, double precision, text, text, text, text, text, boolean),
  public.upsert_my_service(uuid, text, text, numeric, text, int, boolean, boolean, uuid, text[], text),
  public.delete_my_service(uuid),
  public.upsert_my_store(uuid, text, text, text, text, double precision, double precision, text, text, boolean),
  public.delete_my_store(uuid)
from public, anon;
grant execute on function public.toggle_favorite(uuid), public.get_my_favorites(), public.get_my_budget(),
  public.set_my_budget(numeric, date), public.require_provider(), public.get_my_business(),
  public.update_my_business(text, text, text[], text[], text, text, double precision, double precision, text, text, text, text, text, boolean),
  public.upsert_my_service(uuid, text, text, numeric, text, int, boolean, boolean, uuid, text[], text),
  public.delete_my_service(uuid),
  public.upsert_my_store(uuid, text, text, text, text, double precision, double precision, text, text, boolean),
  public.delete_my_store(uuid)
to authenticated;

-- Trial allowance until Phase 4 plans (editable in app_config).
update public.app_config
set config = config || jsonb_build_object('trial_max_services', 10, 'trial_max_stores', 3)
where id = 1 and not (config ? 'trial_max_services');
