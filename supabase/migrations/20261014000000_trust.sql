-- =============================================================================================
-- Munyati — Phase 5: trust (docs/PLAN.md §4.8, §4.11, App Store guideline 1.2).
--
-- * Two-way reviews, one per side per completed booking (not the demo). Bride → provider is
--   public after moderation (stars, text, optional photos). Provider → bride is a private note
--   for admins only.
-- * Reviewer names are masked ON THE SERVER: every word becomes its first 2 letters + "****"
--   (the Maalim Al-Khafji rule). Only the author sees their own name; admins use admin RPCs.
-- * Pre-moderation by default (app_config.reviews_premoderation) plus a banned-words filter.
-- * Report anything (provider, service, store, review, booking, user) → admin queue (24 h).
-- * Block a user: the two no longer see each other's services or reviews and can't book.
-- * Support tickets, optionally tied to a booking.
-- =============================================================================================

-- New curated analytics events (keep in step with AnalyticsEvent in Shared).
alter type public.analytics_event_type add value if not exists 'review_submitted';
alter type public.analytics_event_type add value if not exists 'report_submitted';
alter type public.analytics_event_type add value if not exists 'user_blocked';
alter type public.analytics_event_type add value if not exists 'support_ticket_created';

-- ---------------------------------------------------------------------------------------------
-- Masking
-- ---------------------------------------------------------------------------------------------

-- «نورة محمد القحطاني» → «نو**** مح**** ال****». Empty → null.
create function public.mask_name(p_name text) returns text
language sql immutable as $$
  select nullif(string_agg(left(w, 2) || '****', ' '), '')
  from regexp_split_to_table(trim(coalesce(p_name, '')), '\s+') w
  where w <> '';
$$;

-- ---------------------------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------------------------

create type public.review_direction as enum ('bride_to_provider', 'provider_to_bride');
create type public.review_status as enum ('pending', 'approved', 'rejected', 'hidden');

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  direction public.review_direction not null,
  author_id uuid references public.profiles(id) on delete set null,
  provider_id uuid not null references public.providers(id) on delete cascade,
  bride_id uuid references public.profiles(id) on delete set null,
  rating int not null check (rating between 1 and 5),
  body text check (char_length(body) <= 1000),
  photo_urls text[] not null default '{}' check (cardinality(photo_urls) <= 4),
  status public.review_status not null default 'pending',
  flagged_words text[],                         -- what the filter caught (moderation hint)
  moderation_note text,
  moderated_by uuid references auth.users(id),
  moderated_at timestamptz,
  provider_reply text check (char_length(provider_reply) <= 500),
  provider_replied_at timestamptz,
  created_at timestamptz not null default now(),
  unique (booking_id, direction)
);
create index reviews_provider_idx on public.reviews (provider_id, created_at desc) where status = 'approved';
create index reviews_queue_idx on public.reviews (created_at) where status = 'pending';

alter table public.providers add column if not exists rating_avg numeric(3, 2);
alter table public.providers add column if not exists rating_count int not null default 0;

create type public.report_target as enum ('provider', 'service', 'store', 'review', 'booking', 'user');
create type public.report_status as enum ('open', 'actioned', 'dismissed');

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  target_type public.report_target not null,
  target_id text not null,
  reason text not null check (reason in ('spam', 'inappropriate', 'fake', 'harassment', 'fraud', 'other')),
  details text check (char_length(details) <= 1000),
  status public.report_status not null default 'open',
  resolution_note text,
  handled_by uuid references auth.users(id),
  handled_at timestamptz,
  created_at timestamptz not null default now()
);
create index reports_open_idx on public.reports (created_at) where status = 'open';
create unique index reports_one_open_per_target on public.reports (reporter_id, target_type, target_id) where status = 'open';

create table public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index blocks_blocked_idx on public.blocks (blocked_id);

create type public.ticket_status as enum ('open', 'answered', 'closed');

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  booking_id uuid references public.bookings(id) on delete set null,
  subject text not null check (char_length(subject) between 3 and 120),
  message text not null check (char_length(message) between 3 and 2000),
  status public.ticket_status not null default 'open',
  admin_reply text,
  replied_by uuid references auth.users(id),
  replied_at timestamptz,
  created_at timestamptz not null default now()
);
create index support_tickets_user_idx on public.support_tickets (user_id, created_at desc);
create index support_tickets_open_idx on public.support_tickets (created_at) where status = 'open';

alter table public.reviews enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;
alter table public.support_tickets enable row level security;

-- Clients go through RPCs; admins read the queues directly (the dashboard).
create policy reviews_admin_read on public.reviews for select to authenticated using (public.has_admin_permission('reviews.moderate'));
create policy reports_admin_read on public.reports for select to authenticated using (public.has_admin_permission('reports.handle'));
create policy tickets_admin_read on public.support_tickets for select to authenticated using (public.has_admin_permission('reports.handle'));

update public.app_config set config = config
  || jsonb_build_object('reviews_premoderation', true,
                        'review_window_days', 30,
                        'banned_words', jsonb_build_array())
where id = 1 and not (config ? 'reviews_premoderation');

-- ---------------------------------------------------------------------------------------------
-- Blocking (applies to the caller: auth.uid())
-- ---------------------------------------------------------------------------------------------

create function public.is_blocked_pair(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_a is not null and p_b is not null and exists (
    select 1 from blocks where (blocker_id = p_a and blocked_id = p_b) or (blocker_id = p_b and blocked_id = p_a));
$$;

-- Phase 4 version + blocks: a blocked pair don't see each other's services anywhere (search,
-- home, map, provider and store pages) and can't book them, since create_booking uses this too.
create or replace function public.service_is_public(p_service public.services) returns boolean
language sql stable security definer set search_path = public as $$
  select p_service.status = 'active'
     and provider_is_listed(p_service.provider_id)
     and exists (select 1 from categories c where c.id = p_service.category_id and c.is_active)
     and not is_blocked_pair(auth.uid(), p_service.provider_id);
$$;

-- ---------------------------------------------------------------------------------------------
-- Ratings on cards and provider pages
-- ---------------------------------------------------------------------------------------------

create function public.refresh_provider_rating(p_provider uuid) returns void
language sql security definer set search_path = public as $$
  update providers p set
    rating_count = r.n,
    rating_avg = r.avg
  from (select count(*)::int n, round(avg(rating)::numeric, 2) avg from reviews
        where provider_id = p_provider and direction = 'bride_to_provider' and status = 'approved') r
  where p.id = p_provider;
$$;

create function public.reviews_after_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform refresh_provider_rating(coalesce(new.provider_id, old.provider_id));
  return null;
end;
$$;
create trigger reviews_rating after insert or update of status, rating or delete on public.reviews
  for each row execute function public.reviews_after_change();

create or replace function public.provider_summary(p_provider uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'name', p.business_name, 'logo_url', p.logo_url, 'is_verified', p.is_verified,
    'female_staff_only', p.female_staff_only,
    'rating_avg', p.rating_avg, 'rating_count', p.rating_count,
    'city_ids', coalesce((select jsonb_agg(city_id order by city_id) from provider_cities where provider_id = p.id), '[]'::jsonb))
  from providers p where p.id = p_provider;
$$;

create or replace function public.service_card(p_service public.services) returns jsonb
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
    'is_featured', provider_is_featured(p.id),
    'rating_avg', p.rating_avg,
    'rating_count', p.rating_count,
    'female_staff_only', p_service.female_staff_only or p.female_staff_only,
    'is_favorite', exists (select 1 from favorites f where f.user_id = auth.uid() and f.service_id = p_service.id))
  from providers p where p.id = p_service.provider_id;
$$;

-- ---------------------------------------------------------------------------------------------
-- Reviews
-- ---------------------------------------------------------------------------------------------

-- Words from app_config.banned_words found in the text (case-insensitive).
create function public.banned_words_in(p_text text) returns text[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(w), '{}') from jsonb_array_elements_text(coalesce(get_config() -> 'banned_words', '[]')) w
  where p_text is not null and position(lower(w) in lower(p_text)) > 0;
$$;

-- The public JSON of a review: masked author unless it's the viewer's own.
create function public.review_json(r public.reviews) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', r.id, 'rating', r.rating, 'body', r.body, 'photo_urls', to_jsonb(r.photo_urls),
    'author_name', case when r.author_id = auth.uid() then coalesce(pr.display_name, '') else coalesce(mask_name(pr.display_name), '') end,
    'is_mine', r.author_id is not distinct from auth.uid(),
    'service_title', b.service_title,
    'provider_reply', r.provider_reply,
    'status', r.status,
    'created_at', r.created_at)
  from bookings b left join profiles pr on pr.id = r.author_id
  where b.id = r.booking_id;
$$;

-- Either side of a completed booking, once, within the review window.
create function public.submit_review(p_booking uuid, p_rating int, p_body text default null, p_photo_urls text[] default '{}')
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v bookings%rowtype;
  v_direction review_direction;
  v_flagged text[];
  v_status review_status;
  v_id uuid;
begin
  if v_uid is null then raise exception 'sign in required' using errcode = '42501'; end if;
  select * into v from bookings where id = p_booking;
  if not found or v_uid not in (v.bride_id, v.provider_id) then
    raise exception 'not your booking' using errcode = '42501';
  end if;
  if v.is_demo or v.status <> 'completed' then
    return jsonb_build_object('ok', false, 'error', 'not_completed');
  end if;
  if v.status_changed_at < now() - make_interval(days => coalesce((get_config() ->> 'review_window_days')::int, 30)) then
    return jsonb_build_object('ok', false, 'error', 'window_closed');
  end if;
  if exists (select 1 from profiles where id = v_uid and is_banned) then
    return jsonb_build_object('ok', false, 'error', 'banned');
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    return jsonb_build_object('ok', false, 'error', 'invalid_rating');
  end if;
  v_direction := case when v_uid = v.bride_id then 'bride_to_provider' else 'provider_to_bride' end;
  if exists (select 1 from reviews where booking_id = p_booking and direction = v_direction) then
    return jsonb_build_object('ok', false, 'error', 'already_reviewed');
  end if;
  -- Photos must be the author's own uploads in the public media bucket.
  if exists (select 1 from unnest(coalesce(p_photo_urls, '{}')) u
             where u not like '%/storage/v1/object/public/media/' || v_uid::text || '/%') then
    return jsonb_build_object('ok', false, 'error', 'invalid_photo');
  end if;

  v_flagged := banned_words_in(p_body);
  -- Private notes about brides go straight to "approved" (only admins read them).
  v_status := case
    when v_direction = 'provider_to_bride' then 'approved'
    when cardinality(v_flagged) > 0 or coalesce((get_config() ->> 'reviews_premoderation')::boolean, true) then 'pending'
    else 'approved' end;

  insert into reviews (booking_id, direction, author_id, provider_id, bride_id, rating, body, photo_urls, status, flagged_words)
  values (p_booking, v_direction, v_uid, v.provider_id, v.bride_id, p_rating, nullif(trim(p_body), ''),
          coalesce(p_photo_urls, '{}'), v_status, nullif(v_flagged, '{}'))
  returning id into v_id;

  if v_direction = 'bride_to_provider' then
    perform notify_admins('review_pending', 'تقييم جديد ' || repeat('★', p_rating),
      left(coalesce(p_body, ''), 240), 'https://munyati.co/admin/reviews/' || v_id);
  end if;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', v_status);
end;
$$;

-- The caller's review of a booking and whether they can still write one.
create function public.get_my_review(p_booking uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v bookings%rowtype;
  r reviews%rowtype;
begin
  select * into v from bookings where id = p_booking and v_uid in (bride_id, provider_id);
  if not found then return null; end if;
  select * into r from reviews where booking_id = p_booking and author_id = v_uid;
  return jsonb_build_object(
    'review', case when r.id is not null then review_json(r) end,
    'can_review', r.id is null and not v.is_demo and v.status = 'completed'
      and v.status_changed_at >= now() - make_interval(days => coalesce((get_config() ->> 'review_window_days')::int, 30)));
end;
$$;

-- Public reviews of a provider (anon allowed), newest first, minus blocked authors.
create function public.get_provider_reviews(p_provider uuid, p_limit int default 20, p_offset int default 0)
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'rating_avg', (select rating_avg from providers where id = p_provider),
    'rating_count', (select rating_count from providers where id = p_provider),
    'distribution', (select jsonb_object_agg(s, (select count(*) from reviews r where r.provider_id = p_provider
                       and r.direction = 'bride_to_provider' and r.status = 'approved' and r.rating = s))
                     from generate_series(1, 5) s),
    'items', coalesce((select jsonb_agg(review_json(r) order by r.created_at desc) from (
        select * from reviews r
        where r.provider_id = p_provider and r.direction = 'bride_to_provider' and r.status = 'approved'
          and not is_blocked_pair(auth.uid(), r.author_id)
        order by r.created_at desc
        limit least(greatest(coalesce(p_limit, 20), 1), 50) offset greatest(coalesce(p_offset, 0), 0)) r), '[]'::jsonb));
$$;

-- Provider: one public reply per review.
create function public.reply_to_review(p_review uuid, p_reply text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  update reviews set provider_reply = nullif(trim(p_reply), ''), provider_replied_at = now()
  where id = p_review and provider_id = auth.uid() and direction = 'bride_to_provider' and status = 'approved';
  if not found then raise exception 'not found' using errcode = 'P0002'; end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- Admin moderation (permission reviews.moderate).
create function public.admin_moderate_review(p_review uuid, p_status text, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r reviews%rowtype;
begin
  perform require_admin_permission('reviews.moderate');
  update reviews set status = p_status::review_status, moderation_note = p_note, moderated_by = auth.uid(), moderated_at = now()
  where id = p_review returning * into r;
  if not found then raise exception 'not found' using errcode = 'P0002'; end if;
  insert into admin_audit_log (admin_id, action, entity_type, entity_id, after)
  values (auth.uid(), 'moderate', 'reviews', p_review::text, jsonb_build_object('status', p_status, 'note', p_note));
  if r.direction = 'bride_to_provider' then
    if p_status = 'approved' then
      perform notify_user(r.author_id, 'review_published', 'تم نشر تقييمك', 'Your review is live',
        'شكراً لمشاركة تجربتك.', 'Thanks for sharing your experience.', booking_link(r.booking_id));
      perform notify_user(r.provider_id, 'review_received', 'تقييم جديد ' || repeat('★', r.rating), 'New review ' || repeat('★', r.rating),
        left(coalesce(r.body, ''), 120), left(coalesce(r.body, ''), 120), 'https://munyati.co/p/' || r.provider_id);
    elsif p_status = 'rejected' then
      perform notify_user(r.author_id, 'review_rejected', 'لم يُنشر تقييمك', 'Your review was not published',
        coalesce(p_note, 'لا يتوافق مع إرشادات المحتوى.'), coalesce(p_note, 'It does not meet the content guidelines.'),
        booking_link(r.booking_id));
    end if;
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- Admin: full names for moderation accountability.
create function public.admin_get_reviews(p_status text default 'pending', p_limit int default 50, p_offset int default 0)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform require_admin_permission('reviews.moderate');
  return coalesce((select jsonb_agg(to_jsonb(r) || jsonb_build_object('author_name', pr.display_name,
                                                                      'provider_name', p.business_name) order by r.created_at)
    from (select * from reviews where status = p_status::review_status order by created_at
          limit least(greatest(coalesce(p_limit, 50), 1), 200) offset greatest(coalesce(p_offset, 0), 0)) r
    left join profiles pr on pr.id = r.author_id
    left join providers p on p.id = r.provider_id), '[]'::jsonb);
end;
$$;

create function public.admin_set_review_ban(p_user uuid, p_banned boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform require_admin_permission('reviews.moderate');
  update profiles set is_banned = p_banned where id = p_user;
  insert into admin_audit_log (admin_id, action, entity_type, entity_id, after)
  values (auth.uid(), case when p_banned then 'ban' else 'unban' end, 'profiles', p_user::text, null);
  return jsonb_build_object('ok', true);
end;
$$;

-- Ask the provider for their note about the bride when a booking completes (the bride already
-- gets "We hope you loved it" from complete_booking, which opens the booking with "Rate").
create function public.bookings_review_prompt() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' and not new.is_demo then
    perform notify_user(new.provider_id, 'review_prompt', 'كيف كانت تجربتك؟', 'How did it go?',
      'قيّمي تجربتك مع العروس (ملاحظة خاصة لا تظهر لها).', 'Rate your experience with the bride (a private note she won''t see).',
      booking_link(new.id));
  end if;
  return null;
end;
$$;
create trigger bookings_review_prompt after update of status on public.bookings
  for each row execute function public.bookings_review_prompt();

-- ---------------------------------------------------------------------------------------------
-- Reports and blocks
-- ---------------------------------------------------------------------------------------------

create function public.report_content(p_target_type text, p_target_id text, p_reason text, p_details text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', 'sign_in_required');
  end if;
  if (select count(*) from reports where reporter_id = v_uid and created_at > now() - interval '1 day') >= 20 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  insert into reports (reporter_id, target_type, target_id, reason, details)
  values (v_uid, p_target_type::report_target, p_target_id, p_reason, nullif(trim(p_details), ''))
  on conflict (reporter_id, target_type, target_id) where status = 'open' do nothing
  returning id into v_id;
  if v_id is not null then
    perform notify_admins('report', 'بلاغ جديد: ' || p_target_type || ' · ' || p_reason,
      left(coalesce(p_details, ''), 240), 'https://munyati.co/admin/reports/' || v_id);
  end if;
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create function public.admin_resolve_report(p_report uuid, p_status text, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r reports%rowtype;
begin
  perform require_admin_permission('reports.handle');
  update reports set status = p_status::report_status, resolution_note = p_note, handled_by = auth.uid(), handled_at = now()
  where id = p_report returning * into r;
  if not found then raise exception 'not found' using errcode = 'P0002'; end if;
  insert into admin_audit_log (admin_id, action, entity_type, entity_id, after)
  values (auth.uid(), 'resolve', 'reports', p_report::text, jsonb_build_object('status', p_status, 'note', p_note));
  perform notify_user(r.reporter_id, 'report_resolved', 'شكراً لبلاغك', 'Thanks for your report',
    'راجع فريق منيتي بلاغك واتخذ الإجراء المناسب.', 'The Munyati team reviewed your report and took action.', null);
  return jsonb_build_object('ok', true);
end;
$$;

-- p_user may be a provider id (= their profile id) or a bride id seen on a booking.
create function public.block_user(p_user uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or v_uid = p_user then raise exception 'invalid' using errcode = '22023'; end if;
  if not exists (select 1 from profiles where id = p_user) then raise exception 'not found' using errcode = 'P0002'; end if;
  insert into blocks (blocker_id, blocked_id) values (v_uid, p_user) on conflict do nothing;
  return jsonb_build_object('ok', true);
end;
$$;

create function public.unblock_user(p_user uuid) returns jsonb
language sql security definer set search_path = public as $$
  delete from blocks where blocker_id = auth.uid() and blocked_id = p_user;
  select jsonb_build_object('ok', true);
$$;

-- Blocks the other side of one of the caller's bookings, without revealing their id.
create function public.block_booking_party(p_booking uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_other uuid;
begin
  select case when auth.uid() = bride_id then provider_id when auth.uid() = provider_id then bride_id end
  into v_other from bookings where id = p_booking and not is_demo;
  if v_other is null then raise exception 'not found' using errcode = 'P0002'; end if;
  insert into blocks (blocker_id, blocked_id) values (auth.uid(), v_other) on conflict do nothing;
  return jsonb_build_object('ok', true);
end;
$$;

-- Names here are the caller's own block list: business names for providers, masked for brides.
create function public.get_my_blocks() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'user_id', b.blocked_id,
           'name', coalesce(p.business_name, mask_name(pr.display_name), ''),
           'created_at', b.created_at) order by b.created_at desc), '[]'::jsonb)
  from blocks b
  left join providers p on p.id = b.blocked_id
  left join profiles pr on pr.id = b.blocked_id
  where b.blocker_id = auth.uid();
$$;

-- ---------------------------------------------------------------------------------------------
-- Support tickets
-- ---------------------------------------------------------------------------------------------

create function public.create_support_ticket(p_subject text, p_message text, p_booking uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', 'sign_in_required');
  end if;
  if p_booking is not null and not exists (select 1 from bookings where id = p_booking and v_uid in (bride_id, provider_id)) then
    raise exception 'not your booking' using errcode = '42501';
  end if;
  if (select count(*) from support_tickets where user_id = v_uid and created_at > now() - interval '1 day') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  insert into support_tickets (user_id, booking_id, subject, message)
  values (v_uid, p_booking, trim(p_subject), trim(p_message)) returning id into v_id;
  perform notify_admins('support_ticket', 'تذكرة دعم: ' || left(trim(p_subject), 80), left(trim(p_message), 240),
    'https://munyati.co/admin/support/' || v_id);
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create function public.get_my_support_tickets() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', t.id, 'subject', t.subject, 'message', t.message, 'status', t.status,
           'admin_reply', t.admin_reply, 'replied_at', t.replied_at, 'created_at', t.created_at,
           'booking_reference', b.reference_code) order by t.created_at desc), '[]'::jsonb)
  from support_tickets t left join bookings b on b.id = t.booking_id
  where t.user_id = auth.uid();
$$;

create function public.admin_reply_ticket(p_ticket uuid, p_reply text, p_close boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  t support_tickets%rowtype;
begin
  perform require_admin_permission('reports.handle');
  update support_tickets set admin_reply = trim(p_reply), replied_by = auth.uid(), replied_at = now(),
    status = case when p_close then 'closed'::ticket_status else 'answered'::ticket_status end
  where id = p_ticket returning * into t;
  if not found then raise exception 'not found' using errcode = 'P0002'; end if;
  perform notify_user(t.user_id, 'support_reply', 'رد فريق الدعم', 'Support replied',
    left(trim(p_reply), 160), left(trim(p_reply), 160), null);
  return jsonb_build_object('ok', true);
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------------------------

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.refresh_provider_rating(uuid)', 'public.reviews_after_change()', 'public.bookings_review_prompt()',
    'public.review_json(public.reviews)', 'public.banned_words_in(text)']
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
  -- Signed-in RPCs.
  foreach f in array array[
    'public.submit_review(uuid, int, text, text[])', 'public.get_my_review(uuid)',
    'public.reply_to_review(uuid, text)',
    'public.admin_moderate_review(uuid, text, text)', 'public.admin_get_reviews(text, int, int)',
    'public.admin_set_review_ban(uuid, boolean)',
    'public.report_content(text, text, text, text)', 'public.admin_resolve_report(uuid, text, text)',
    'public.block_user(uuid)', 'public.unblock_user(uuid)', 'public.block_booking_party(uuid)', 'public.get_my_blocks()',
    'public.create_support_ticket(text, text, uuid)', 'public.get_my_support_tickets()',
    'public.admin_reply_ticket(uuid, text, boolean)']
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
