-- =============================================================================================
-- Munyati — Home carousel banners (dashboard-managed).
--
-- The bride's Home shows a carousel: these banners first, then the app's built-in brand slides,
-- so it is never empty. Content admins manage banners in the dashboard (Banners page); the image
-- goes to the public `content` bucket. `link_url` is any app link (https://munyati.co/<p|s|store|c>/<id>)
-- or an outside https URL. `city_ids` null shows a banner in every city.
-- =============================================================================================

create table public.home_banners (
  id uuid primary key default gen_random_uuid(),
  title_ar text not null,
  title_en text not null,
  subtitle_ar text,
  subtitle_en text,
  cta_ar text,                         -- button text, e.g. 'احجزي الآن'
  cta_en text,
  image_url text,                      -- versioned path in the public `content` bucket
  link_url text,
  city_ids text[],                     -- null = every city
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint home_banners_link_https check (link_url is null or link_url ~ '^(https://|munyati://)'),
  constraint home_banners_window check (starts_at is null or ends_at is null or starts_at < ends_at)
);

create trigger home_banners_touch before update on public.home_banners for each row execute function public.touch_updated_at();
create trigger home_banners_audit after insert or update or delete on public.home_banners for each row execute function public.audit_admin_change();

alter table public.home_banners enable row level security;
-- The app reads banners only through get_home; the dashboard reads and writes the table.
create policy home_banners_read on public.home_banners for select to authenticated using (public.is_admin());
create policy home_banners_manage on public.home_banners for all to authenticated
  using (public.has_admin_permission('content.edit')) with check (public.has_admin_permission('content.edit'));

-- Banners live right now for the given cities, in the shape the apps decode.
create function public.home_banners_for(p_city_ids text[]) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', b.id, 'title_ar', b.title_ar, 'title_en', b.title_en,
           'subtitle_ar', b.subtitle_ar, 'subtitle_en', b.subtitle_en,
           'cta_ar', b.cta_ar, 'cta_en', b.cta_en,
           'image_url', b.image_url, 'link_url', b.link_url)
         order by b.sort_order, b.created_at desc), '[]'::jsonb)
  from home_banners b
  where b.is_active
    and (b.starts_at is null or b.starts_at <= now())
    and (b.ends_at is null or b.ends_at > now())
    and (b.city_ids is null or cardinality(b.city_ids) = 0 or p_city_ids is null or b.city_ids && p_city_ids);
$$;
revoke all on function public.home_banners_for(text[]) from public, anon, authenticated;

-- Home gains `banners`; everything else is unchanged (older apps ignore the new key).
create or replace function public.get_home(p_city_ids text[] default null, p_max_price numeric default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'banners', home_banners_for(p_city_ids),
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
