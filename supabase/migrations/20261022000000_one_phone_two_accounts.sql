-- One phone, two accounts: a bride account and a provider account.
--
-- Until now a phone number was one account with one fixed role. Now the same number may hold one
-- bride account and one provider account (separate auth users and profiles; verify-otp picks the
-- one for the side chosen at sign-in). The rule that comes with it: from her bride account she
-- can book any provider except her own provider account.
--
--   * profiles: phone is unique per role instead of overall;
--   * is_same_person(a, b): the same account, or two live accounts on the same phone;
--   * bookings: a check (customer <> provider) and a trigger (not the same phone) refuse
--     self-bookings on every path that writes bookings; demo bookings have no customer;
--   * create_booking: answers `own_service` for her own provider account;
--   * get_service: adds `is_own` so the apps hide the Book button there.
-- Reviews need a completed booking, so they can't be self-written either.

drop index if exists public.profiles_phone_active_key;
create unique index profiles_phone_role_active_key on public.profiles (phone, role) where deleted_at is null;

create or replace function public.is_same_person(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(p_a = p_b, false) or exists (
    select 1 from profiles a join profiles b on a.phone = b.phone
    where a.id = p_a and b.id = p_b and a.phone is not null);
$$;
revoke all on function public.is_same_person(uuid, uuid) from public, anon;
grant execute on function public.is_same_person(uuid, uuid) to authenticated, service_role;

alter table public.bookings
  add constraint bookings_not_self check (bride_id is null or bride_id <> provider_id) not valid;
alter table public.bookings validate constraint bookings_not_self;

create or replace function public.bookings_refuse_self() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.bride_id is not null and is_same_person(new.bride_id, new.provider_id) then
    raise exception 'a provider cannot book her own services' using errcode = '23514';  -- check_violation
  end if;
  return new;
end;
$$;
create trigger bookings_refuse_self before insert or update of bride_id, provider_id on public.bookings
  for each row execute function public.bookings_refuse_self();

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
                          bride_name, price, starts_at, ends_at, note, enforce_category_rule)
    values (new_reference_code(), v_uid, v_service.provider_id, v_service.id, v_service.category_id, v_service.store_id,
            v_service.title, v_bride.display_name, v_service.price, p_starts_at, v_ends, left(p_note, 500),
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

create or replace function public.get_service(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_service services%rowtype;
begin
  select * into v_service from services where id = p_id;
  -- coalesce: for a signed-out caller auth.uid() is null, and a bare comparison would make the
  -- whole test null, which `if` treats as false, so hidden services were returned.
  if not found or not (service_is_public(v_service) or coalesce(v_service.provider_id = auth.uid(), false)) then
    return null;
  end if;
  return service_card(v_service) || jsonb_build_object(
    'description', v_service.description,
    'duration_minutes', v_service.duration_minutes,
    'at_customer_location', v_service.at_customer_location,
    'image_urls', to_jsonb(v_service.image_urls),
    'videos', v_service.videos,
    -- True when the caller is the provider herself or her bride account on the same phone: the
    -- apps show a note instead of the Book button.
    'is_own', is_same_person(auth.uid(), v_service.provider_id),
    'provider', provider_summary(v_service.provider_id),
    'store', case when v_service.store_id is not null then store_summary(v_service.store_id) end,
    'more_from_provider', coalesce((
      select jsonb_agg(service_card(s) order by s.created_at desc)
      from (select * from services s where s.provider_id = v_service.provider_id and s.id <> v_service.id
              and service_is_public(s) order by s.created_at desc limit 6) s), '[]'::jsonb));
end;
$$;
