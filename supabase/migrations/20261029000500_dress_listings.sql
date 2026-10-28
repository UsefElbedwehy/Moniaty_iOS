-- «فساتين»: dresses for rent, listed by the admin only.
--
-- * A dress owner pays to have her dress listed for 30 days (the price and Munyati's contact
--   number are in app_config `dress_listing`, shown as a notice in the section). The admin then
--   adds the dress in the dashboard: a photo, the price and the owner's contact number, in one of
--   three lists: wedding (زفاف), jalwa (جلوات) or evening (سهرة).
-- * A dress shows from `starts_on` for 30 days, then hides itself; the dashboard can renew it.
-- * The dresses category becomes an admin-listings category: providers can no longer choose it
--   or add services to it, and any services already in it stop showing. Tapping it in the apps
--   opens the three lists instead of providers' services.

-- The category ------------------------------------------------------------------------------

alter table public.categories add column admin_listings boolean not null default false;

update public.categories
set admin_listings = true, name_ar = 'فساتين', name_en = 'Dresses'
where id = 'dresses';

-- Providers don't see it among the categories they can pick.
create or replace function public.get_categories()
returns table (
  id text, name_ar text, name_en text, icon_url text, icon_symbol text, cover_url text,
  price_hint_ar text, price_hint_en text, allows_parallel_bookings boolean, is_store_category boolean
)
language sql stable security definer set search_path = public as $$
  select c.id, c.name_ar, c.name_en, c.icon_url, c.icon_symbol, c.cover_url,
         c.price_hint_ar, c.price_hint_en, c.allows_parallel_bookings, c.is_store_category
  from categories c where c.is_active and not c.admin_listings
  order by c.sort_order, c.name_ar;
$$;

-- …can't add it to their business or their services…
create function public.reject_admin_listings_category() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from categories where id = new.category_id and admin_listings) then
    raise exception 'category is listed by the admin only' using errcode = '42501';
  end if;
  return new;
end;
$$;
create trigger provider_categories_admin_listings before insert or update of category_id on public.provider_categories
  for each row execute function public.reject_admin_listings_category();
create trigger services_admin_listings before insert or update of category_id on public.services
  for each row execute function public.reject_admin_listings_category();

-- …and services already in it no longer show anywhere (search, home, map, pages, booking).
create or replace function public.service_is_public(p_service public.services) returns boolean
language sql stable security definer set search_path = public as $$
  select p_service.status = 'active'
     and provider_is_listed(p_service.provider_id)
     and exists (select 1 from categories c where c.id = p_service.category_id and c.is_active and not c.admin_listings)
     and not is_blocked_pair(auth.uid(), p_service.provider_id);
$$;

-- The listings -------------------------------------------------------------------------------

create table public.dress_listings (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('wedding', 'jalwa', 'evening')),
  image_url text not null,
  price numeric(10, 2) not null check (price >= 0 and price <= 1000000),
  contact_phone text not null check (contact_phone ~ '^\+9665[0-9]{8}$'),
  starts_on date not null default current_date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index dress_listings_kind_idx on public.dress_listings (kind, starts_on desc);
create trigger dress_listings_touch before update on public.dress_listings for each row execute function public.touch_updated_at();
create trigger dress_listings_audit after insert or update or delete on public.dress_listings for each row execute function public.audit_admin_change();

alter table public.dress_listings enable row level security;
-- The apps read through get_dress_listings; content admins manage the table in the dashboard.
create policy dress_listings_read on public.dress_listings for select to authenticated using (public.is_admin());
create policy dress_listings_manage on public.dress_listings for all to authenticated
  using (public.has_admin_permission('content.edit')) with check (public.has_admin_permission('content.edit'));

-- Listed for 30 days from starts_on (Saudi time): shown on starts_on and the 29 days after.
create function public.dress_listing_is_live(p public.dress_listings) returns boolean
language sql stable set search_path = public as $$
  select p.is_active
     and p.starts_on <= (now() at time zone 'Asia/Riyadh')::date
     and p.starts_on + 30 > (now() at time zone 'Asia/Riyadh')::date;
$$;

-- One list (or all three when p_kind is null), newest first, plus the notice for dress owners.
create function public.get_dress_listings(p_kind text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'listings', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', d.id, 'kind', d.kind, 'image_url', d.image_url, 'price', d.price,
               'contact_phone', d.contact_phone, 'ends_on', d.starts_on + 29)
             order by d.starts_on desc, d.created_at desc)
      from dress_listings d
      where dress_listing_is_live(d) and (p_kind is null or d.kind = p_kind)), '[]'::jsonb),
    -- {"price": 20, "days": 30, "phone": "+9665…"}; null hides the notice.
    'notice', case when nullif(get_config() #>> '{dress_listing,phone}', '') is not null
                   then get_config() -> 'dress_listing' end);
$$;

-- Home: the category says it is admin listings, and its count is the live dresses ------------

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
                         and provider_in_cities(s.provider_id, p_city_ids)) end)
             order by c.sort_order)
      from categories c where c.is_active), '[]'::jsonb),
    'featured', search_services(null, null, p_city_ids, p_max_price, false, 'recommended', 10, 0),
    'newest', search_services(null, null, p_city_ids, null, false, 'newest', 10, 0));
$$;

-- The notice's defaults; the number is filled in from the dashboard (Settings).
update public.app_config
set config = jsonb_set(config, '{dress_listing}', '{"price": 20, "days": 30, "phone": null}'::jsonb, true)
where id = 1 and not (config ? 'dress_listing');

revoke all on function public.get_dress_listings(text), public.dress_listing_is_live(public.dress_listings),
  public.reject_admin_listings_category() from public;
grant execute on function public.get_dress_listings(text) to anon, authenticated;
