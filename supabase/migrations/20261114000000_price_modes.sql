-- Munyati — three ways to show a service's price.
--
--   fixed       «٥٠٠ ر.س»            the bride pays this price (as before)
--   from        «يبدأ من ٥٠٠ ر.س»    `price` is the starting price; the final price is >= it
--   on_request  «السعر عند الطلب»    `price` is the provider's EXPECTED price: never shown to brides,
--                                    used only for "within my budget", sorting and the budget
--
-- `services.price` stays the one number search/filters use, so the budget filter keeps working for
-- every mode. For `from` and `on_request` the provider sets the final price when she approves the
-- booking or proposes a new time (`bookings.price_set_at`); the bride sees it before paying, and the
-- receipt check and budget use it. A guard stops such a booking reaching awaiting_payment without it.
-- Additive: existing services and bookings are `fixed`.

alter table public.services
  add column if not exists price_mode text not null default 'fixed'
    constraint services_price_mode_check check (price_mode in ('fixed', 'from', 'on_request'));
alter table public.bookings
  add column if not exists price_mode text not null default 'fixed'
    constraint bookings_price_mode_check check (price_mode in ('fixed', 'from', 'on_request')),
  add column if not exists price_set_at timestamptz;

-- The price brides may see: hidden for on_request.
create or replace function public.service_public_price(p_service public.services) returns numeric
language sql immutable set search_path = public as $$
  select case when p_service.price_mode = 'on_request' then null else p_service.price end;
$$;

-- The final price must exist before the bride is asked to pay.
create or replace function public.bookings_require_final_price() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.status = 'awaiting_payment' and new.status is distinct from old.status
     and new.price_mode <> 'fixed' and new.price_set_at is null and not new.is_demo then
    raise exception 'final price required' using errcode = '22023';
  end if;
  return new;
end;
$$;
drop trigger if exists bookings_require_final_price on public.bookings;
create trigger bookings_require_final_price before update of status on public.bookings
  for each row execute function public.bookings_require_final_price();

-- Validates the final price a provider sets; null when it is fine, else the error code.
create or replace function public.final_price_error(p_booking public.bookings, p_price numeric) returns text
language sql immutable set search_path = public as $$
  select case
    when p_booking.price_mode = 'fixed' or p_booking.is_demo then null
    when p_price is null then 'price_required'
    when p_price <= 0 or p_price > 1000000 then 'invalid_price'
    when p_booking.price_mode = 'from' and p_price < p_booking.price then 'price_below_start'
  end;
$$;

-- Cards: the visible price (null for on_request) and the mode.
create or replace function public.service_card(p_service public.services) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p_service.id,
    'title', p_service.title,
    'price', service_public_price(p_service),
    'price_mode', p_service.price_mode,
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
    'booking_mode', p.booking_mode,
    'is_favorite', exists (select 1 from favorites f where f.user_id = auth.uid() and f.service_id = p_service.id))
  from providers p where p.id = p_service.provider_id;
$$;
-- The provider's own services: her real price (expected price for on_request) and the mode.
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
        'price', s.price, 'price_mode', s.price_mode, 'duration_minutes', s.duration_minutes, 'female_staff_only', s.female_staff_only,
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
-- p_price_mode: null keeps the current mode on edit ('fixed' for a new service), so older app
-- versions that don't send it never reset a provider's choice.
drop function if exists public.upsert_my_service(uuid, text, text, numeric, text, int, boolean, boolean, uuid, text[], text, jsonb);
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
  p_videos jsonb default null,
  p_price_mode text default null
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
  if p_price_mode is not null and p_price_mode not in ('fixed', 'from', 'on_request') then
    raise exception 'unknown price mode' using errcode = '22023';
  end if;
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
                          female_staff_only, at_customer_location, image_urls, videos, status, price_mode)
    values (v_uid, p_store_id, p_category_id, trim(p_title), p_description, p_price, p_duration_minutes,
            coalesce(p_female_staff_only, false), coalesce(p_at_customer_location, false),
            coalesce(p_image_urls, '{}'), coalesce(v_videos, '[]'::jsonb), v_status, coalesce(p_price_mode, 'fixed'))
    returning id into v_id;
  else
    update services set store_id = p_store_id, category_id = p_category_id, title = trim(p_title),
      description = p_description, price = p_price, duration_minutes = p_duration_minutes,
      female_staff_only = coalesce(p_female_staff_only, false),
      at_customer_location = coalesce(p_at_customer_location, false),
      image_urls = coalesce(p_image_urls, '{}'), videos = coalesce(v_videos, videos), status = v_status,
      price_mode = coalesce(p_price_mode, price_mode)
    where id = p_id and provider_id = v_uid and archived_at is null   -- archived by an admin: read-only
    returning id into v_id;
    if v_id is null then raise exception 'not found' using errcode = 'P0002'; end if;
  end if;
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;
revoke all on function public.upsert_my_service(uuid, text, text, numeric, text, int, boolean, boolean, uuid, text[], text, jsonb, text) from public, anon;
grant execute on function public.upsert_my_service(uuid, text, text, numeric, text, int, boolean, boolean, uuid, text[], text, jsonb, text) to authenticated;

-- The booking keeps the service's mode; its price starts as the service price (the estimate).
create or replace function public.create_booking(p_service_id uuid, p_starts_at timestamptz, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_bride profiles%rowtype;
  v_service services%rowtype;
  v_category categories%rowtype;
  v_booking bookings%rowtype;
  v_blocking bookings%rowtype;
  v_ends timestamptz;
begin
  select * into v_bride from profiles where id = v_uid and role = 'bride' and deleted_at is null and not is_banned;
  if not found then raise exception 'bride account required' using errcode = '42501'; end if;
  select * into v_service from services where id = p_service_id;
  if not found or not service_is_public(v_service) then
    return jsonb_build_object('ok', false, 'error', 'service_unavailable');
  end if;
  -- Not from her own provider account (same phone); the bookings trigger is the hard guarantee.
  if is_same_person(v_uid, v_service.provider_id) then
    return jsonb_build_object('ok', false, 'error', 'own_service');
  end if;
  select * into v_category from categories where id = v_service.category_id;
  v_ends := p_starts_at + make_interval(mins => coalesce(v_service.duration_minutes, 60));

  -- The slot must still be offered (inside working hours and free).
  if not (get_available_slots(p_service_id, (p_starts_at at time zone 'Asia/Riyadh')::date) @> to_jsonb(p_starts_at)) then
    return jsonb_build_object('ok', false, 'error', 'slot_unavailable');
  end if;

  -- Rule #20 with a helpful answer (the unique index is the hard guarantee).
  if not v_category.allows_parallel_bookings then
    select * into v_blocking from bookings
    where bride_id = v_uid and category_id = v_category.id and booking_is_active(status) and not is_demo
    limit 1;
    if found then
      return jsonb_build_object('ok', false, 'error', 'category_active', 'blocking_booking_id', v_blocking.id);
    end if;
  end if;

  begin
    insert into bookings (reference_code, bride_id, provider_id, service_id, category_id, store_id, service_title,
                          bride_name, price, price_mode, starts_at, ends_at, note, enforce_category_rule)
    values (new_reference_code(), v_uid, v_service.provider_id, v_service.id, v_service.category_id, v_service.store_id,
            v_service.title, v_bride.display_name, v_service.price, v_service.price_mode, p_starts_at, v_ends, left(p_note, 500),
            not v_category.allows_parallel_bookings)
    returning * into v_booking;
  exception
    when exclusion_violation then return jsonb_build_object('ok', false, 'error', 'slot_unavailable');
    when unique_violation then return jsonb_build_object('ok', false, 'error', 'category_active');
    when check_violation then return jsonb_build_object('ok', false, 'error', 'own_service');
  end;

  insert into booking_events (booking_id, actor_id, actor_role, to_status) values (v_booking.id, v_uid, 'bride', 'requested');
  perform notify_user(v_service.provider_id, 'booking_requested',
    'طلب حجز جديد', 'New booking request',
    v_service.title || ' · ' || to_char(p_starts_at at time zone 'Asia/Riyadh', 'YYYY-MM-DD HH24:MI'),
    v_service.title || ' · ' || to_char(p_starts_at at time zone 'Asia/Riyadh', 'YYYY-MM-DD HH24:MI'),
    booking_link(v_booking.id), true);
  return jsonb_build_object('ok', true, 'id', v_booking.id, 'reference_code', v_booking.reference_code);
end;
$$;
-- Brides don't see the expected price of an on_request booking until the provider sets the final one.
-- `price_is_final`: false while the price can still change (from / on_request before approval).
create or replace function public.booking_json(p_booking public.bookings, p_viewer_role text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p_booking.id,
    'reference_code', p_booking.reference_code,
    'status', p_booking.status,
    'is_demo', p_booking.is_demo,
    'service_id', p_booking.service_id,
    'service_title', p_booking.service_title,
    'category_id', p_booking.category_id,
    'price', case when p_viewer_role = 'bride' and p_booking.price_mode = 'on_request'
                    and p_booking.price_set_at is null and not p_booking.is_demo
                  then null else p_booking.price end,
    'price_mode', p_booking.price_mode,
    'price_is_final', p_booking.price_mode = 'fixed' or p_booking.price_set_at is not null or p_booking.is_demo,
    'starts_at', p_booking.starts_at,
    'ends_at', p_booking.ends_at,
    'note', p_booking.note,
    'payment_due_at', p_booking.payment_due_at,
    'status_changed_at', p_booking.status_changed_at,
    'provider', jsonb_build_object('id', p.id, 'name', p.business_name, 'logo_url', p.logo_url, 'is_verified', p.is_verified),
    -- Providers see the bride's name masked until payment is confirmed (privacy, §4.8).
    'bride_name', case
      when p_booking.is_demo then coalesce(p_booking.bride_name, 'عروس تجريبية')
      when p_viewer_role = 'provider' and p_booking.status not in ('payment_confirmed', 'completed', 'disputed')
        then (select string_agg(left(w, 2) || '****', ' ') from regexp_split_to_table(coalesce(p_booking.bride_name, ''), '\s+') w)
      else p_booking.bride_name end)
  from providers p where p.id = p_booking.provider_id;
$$;
-- Approve: for from / on_request the provider sends the final price (p_price).
drop function if exists public.approve_booking(uuid);
create or replace function public.approve_booking(p_booking uuid, p_price numeric default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v bookings%rowtype;
begin
  select * into v from bookings where id = p_booking and provider_id = auth.uid();
  if found and not v.is_demo and not exists (
      select 1 from provider_payment_methods where provider_id = auth.uid() and is_active) then
    return jsonb_build_object('ok', false, 'error', 'no_payment_method');
  end if;
  if found and final_price_error(v, p_price) is not null then
    return jsonb_build_object('ok', false, 'error', final_price_error(v, p_price));
  end if;
  if found and v.price_mode <> 'fixed' and not v.is_demo and v.status = 'requested' then
    update bookings set price = p_price, price_set_at = now() where id = p_booking;
  end if;
  v := booking_transition(p_booking, 'awaiting_payment', 'provider', null);
  perform start_payment_window(p_booking);
  if v.is_demo then
    perform advance_demo(p_booking);
  else
    perform notify_user(v.bride_id, 'booking_approved', 'تم قبول طلبك 🎉', 'Your booking was approved',
      v.service_title || ' · ' || trim_scale(v.price)::text || ' ر.س · الرجاء الدفع خلال ٤٨ ساعة',
      v.service_title || ' · SAR ' || trim_scale(v.price)::text || ' · please pay within 48 hours',
      booking_link(p_booking), true);
  end if;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.approve_booking(uuid, numeric) from public, anon;
grant execute on function public.approve_booking(uuid, numeric) to authenticated;

-- A new time from the provider moves the booking to awaiting_payment when the bride accepts, so the
-- final price is set here too (she sees it with the proposal).
drop function if exists public.propose_reschedule(uuid, timestamptz, text);
create or replace function public.propose_reschedule(p_booking uuid, p_starts_at timestamptz, p_note text default null,
  p_price numeric default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v bookings%rowtype;
begin
  select * into v from bookings where id = p_booking and provider_id = auth.uid();
  if not found then raise exception 'not your booking' using errcode = '42501'; end if;
  if v.status = 'requested' and final_price_error(v, p_price) is not null then
    return jsonb_build_object('ok', false, 'error', final_price_error(v, p_price));
  end if;
  if p_starts_at < now() + interval '2 hours' then
    return jsonb_build_object('ok', false, 'error', 'too_soon');
  end if;
  if exists (select 1 from bookings b where b.provider_id = v.provider_id and b.id <> v.id and not b.is_demo
             and booking_is_active(b.status)
             and tstzrange(b.starts_at, b.ends_at) && tstzrange(p_starts_at, p_starts_at + (v.ends_at - v.starts_at))) then
    return jsonb_build_object('ok', false, 'error', 'slot_unavailable');
  end if;
  v := booking_transition(p_booking, 'reschedule_proposed', 'provider', left(p_note, 300));
  if v.price_mode <> 'fixed' and not v.is_demo and v.price_set_at is null then
    update bookings set price = p_price, price_set_at = now() where id = p_booking returning * into v;
  end if;
  insert into booking_proposals (booking_id, proposed_by, starts_at, ends_at, note, expires_at)
  values (p_booking, auth.uid(), p_starts_at, p_starts_at + (v.ends_at - v.starts_at), left(p_note, 300),
          now() + config_hours('proposal', 24));
  if v.is_demo then
    perform advance_demo(p_booking);
  else
    perform notify_user(v.bride_id, 'reschedule_proposed', 'موعد بديل مقترح', 'A new time was proposed',
      v.service_title || ' · ' || to_char(p_starts_at at time zone 'Asia/Riyadh', 'YYYY-MM-DD HH24:MI'),
      v.service_title || ' · ' || to_char(p_starts_at at time zone 'Asia/Riyadh', 'YYYY-MM-DD HH24:MI'),
      booking_link(p_booking), true);
  end if;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.propose_reschedule(uuid, timestamptz, text, numeric) from public, anon;
grant execute on function public.propose_reschedule(uuid, timestamptz, text, numeric) to authenticated;

-- Admins can change a service's price mode from the dashboard's record editor.
create or replace function public.admin_update_record(p_entity text, p_id text, p_changes jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_meta jsonb := admin_entity(p_entity);
  v_allowed text[] := case p_entity
    when 'user'     then array['display_name', 'first_name', 'last_name']
    when 'provider' then array['business_name', 'bio', 'address', 'instagram', 'cr_number', 'freelance_doc_number',
                               'female_staff_only', 'is_verified', 'review_note']
    when 'service'  then array['title', 'description', 'price', 'duration_minutes', 'category_id', 'female_staff_only',
                               'at_customer_location', 'status', 'price_mode']
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
