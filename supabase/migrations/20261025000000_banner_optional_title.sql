-- Home banners: the title becomes optional, so a banner can be a designed image on its own.
--
-- * A banner needs an image or a title in both languages (never neither).
-- * The apps show a banner without a title as the image alone: no fade, no text; a tap still
--   opens its link.
-- * Apps decode the title as text, so `home_banners_for` sends '' rather than null; builds made
--   before this change then show the image with an empty title instead of failing to load Home.

alter table public.home_banners alter column title_ar drop not null;
alter table public.home_banners alter column title_en drop not null;

alter table public.home_banners drop constraint if exists home_banners_has_content;
alter table public.home_banners add constraint home_banners_has_content check (
  nullif(trim(image_url), '') is not null
  or (nullif(trim(title_ar), '') is not null and nullif(trim(title_en), '') is not null)
) not valid;
alter table public.home_banners validate constraint home_banners_has_content;

create or replace function public.home_banners_for(p_city_ids text[]) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', b.id, 'title_ar', coalesce(b.title_ar, ''), 'title_en', coalesce(b.title_en, ''),
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
