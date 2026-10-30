-- How a provider takes bookings, and searching by an available date.
--
-- Each provider chooses one of three modes (Studio → أوقات العمل):
--   weekly   (default, as before): weekly hours + days off; the bride picks a free slot.
--   dates    : the exact calendar dates she is available, each with its hours; brides can book
--              only those.
--   request  : the bride picks any date and time (08:00–24:00, half-hour steps, not overlapping
--              the provider's other bookings), and the provider accepts, declines or proposes
--              another time, as for every request.
--
-- `get_available_slots` follows the mode, so `create_booking`'s check and older apps keep
-- working unchanged. Search gains `p_date`: only services with a free slot that day; cards carry
-- `booking_mode` so the apps can mark on-request providers.

alter table public.providers add column booking_mode text not null default 'weekly'
  check (booking_mode in ('weekly', 'dates', 'request'));

create table public.availability_dates (
  id bigint generated always as identity primary key,
  provider_id uuid not null references public.providers(id) on delete cascade,
  day date not null,
  start_time time not null,
  end_time time not null,
  check (end_time > start_time)
);
create index availability_dates_provider_idx on public.availability_dates (provider_id, day);
alter table public.availability_dates enable row level security;
create policy availability_dates_read on public.availability_dates for select to authenticated
  using (provider_id = auth.uid() or public.is_admin());
revoke insert, update, delete on public.availability_dates from anon, authenticated;

-- The provider's open windows on a day (Riyadh time), by her mode.
create function public.provider_windows(p_provider uuid, p_day date)
returns table (w_start timestamptz, w_end timestamptz)
language sql stable security definer set search_path = public as $$
  select (p_day + r.start_time) at time zone 'Asia/Riyadh', (p_day + r.end_time) at time zone 'Asia/Riyadh'
  from providers p join availability_rules r on r.provider_id = p.id
  where p.id = p_provider and p.booking_mode = 'weekly'
    and r.weekday = extract(dow from p_day)::int
    and not exists (select 1 from availability_days_off o where o.provider_id = p.id and o.day = p_day)
  union all
  select (p_day + d.start_time) at time zone 'Asia/Riyadh', (p_day + d.end_time) at time zone 'Asia/Riyadh'
  from providers p join availability_dates d on d.provider_id = p.id
  where p.id = p_provider and p.booking_mode = 'dates' and d.day = p_day
  union all
  select (p_day + time '08:00') at time zone 'Asia/Riyadh', (p_day + 1) at time zone 'Asia/Riyadh'
  from providers p
  where p.id = p_provider and p.booking_mode = 'request';
$$;

-- Free start times for a service on a day (Riyadh time), in 30-minute steps, by the mode.
create or replace function public.get_available_slots(p_service_id uuid, p_day date) returns jsonb
language sql stable security definer set search_path = public as $$
  with s as (
    select sv.id, sv.provider_id, make_interval(mins => coalesce(sv.duration_minutes, 60)) as dur
    from services sv where sv.id = p_service_id and service_is_public(sv)
  ),
  candidates as (
    select gs as slot_start, gs + s.dur as slot_end, s.provider_id
    from s, provider_windows(s.provider_id, p_day) w,
         generate_series(w.w_start, w.w_end - s.dur, interval '30 minutes') gs
  )
  select coalesce(jsonb_agg(distinct c.slot_start), '[]'::jsonb)
  from candidates c
  where c.slot_start > now() + interval '2 hours'
    and not exists (select 1 from bookings b where b.provider_id = c.provider_id and not b.is_demo
                      and booking_is_active(b.status)
                      and tstzrange(b.starts_at, b.ends_at) && tstzrange(c.slot_start, c.slot_end));
$$;

-- The days in the next p_days with at least one free slot, and the mode (for the date picker).
create function public.get_available_days(p_service_id uuid, p_days int default 60) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'mode', (select p.booking_mode from services s join providers p on p.id = s.provider_id where s.id = p_service_id),
    'days', coalesce((
      select jsonb_agg(d::date order by d)
      from generate_series((now() at time zone 'Asia/Riyadh')::date,
                           (now() at time zone 'Asia/Riyadh')::date + least(greatest(coalesce(p_days, 60), 1), 120),
                           interval '1 day') d
      where jsonb_array_length(get_available_slots(p_service_id, d::date)) > 0), '[]'::jsonb));
$$;

-- Provider side ------------------------------------------------------------------------------

create or replace function public.get_my_availability() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
begin
  return jsonb_build_object(
    'mode', (select booking_mode from providers where id = v_uid),
    'rules', coalesce((select jsonb_agg(jsonb_build_object('weekday', weekday,
               'start_time', to_char(start_time, 'HH24:MI'), 'end_time', to_char(end_time, 'HH24:MI'))
             order by weekday, start_time) from availability_rules where provider_id = v_uid), '[]'::jsonb),
    'days_off', coalesce((select jsonb_agg(day order by day) from availability_days_off
                          where provider_id = v_uid and day >= current_date), '[]'::jsonb),
    'dates', coalesce((select jsonb_agg(jsonb_build_object('day', day,
               'start_time', to_char(start_time, 'HH24:MI'), 'end_time', to_char(end_time, 'HH24:MI'))
             order by day, start_time) from availability_dates
             where provider_id = v_uid and day >= (now() at time zone 'Asia/Riyadh')::date), '[]'::jsonb));
end;
$$;

create function public.set_my_booking_mode(p_mode text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
begin
  if p_mode not in ('weekly', 'dates', 'request') then raise exception 'invalid mode' using errcode = '22023'; end if;
  update providers set booking_mode = p_mode where id = v_uid;
  return get_my_availability();
end;
$$;

-- p_dates: [{"day":"2026-11-12","start_time":"14:00","end_time":"22:00"}, ...]; replaces the
-- upcoming dates (past ones are dropped).
create function public.set_my_available_dates(p_dates jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
begin
  if jsonb_array_length(coalesce(p_dates, '[]'::jsonb)) > 400 then raise exception 'too many dates' using errcode = '22023'; end if;
  delete from availability_dates where provider_id = v_uid;
  insert into availability_dates (provider_id, day, start_time, end_time)
  select v_uid, (d ->> 'day')::date, (d ->> 'start_time')::time, (d ->> 'end_time')::time
  from jsonb_array_elements(coalesce(p_dates, '[]'::jsonb)) d
  where (d ->> 'day')::date >= (now() at time zone 'Asia/Riyadh')::date;
  return get_my_availability();
end;
$$;

-- Cards and search ----------------------------------------------------------------------------

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
    'booking_mode', p.booking_mode,
    'is_favorite', exists (select 1 from favorites f where f.user_id = auth.uid() and f.service_id = p_service.id))
  from providers p where p.id = p_service.provider_id;
$$;

drop function public.search_services(text, text, text[], numeric, boolean, text, int, int);

-- As before, plus p_date: only services with a free slot that day (on-request providers count).
create function public.search_services(
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

revoke all on function public.provider_windows(uuid, date) from public, anon, authenticated;
revoke all on function public.set_my_booking_mode(text), public.set_my_available_dates(jsonb) from public, anon;
grant execute on function public.set_my_booking_mode(text), public.set_my_available_dates(jsonb) to authenticated;
grant execute on function public.get_available_days(uuid, int) to anon, authenticated;
grant execute on function public.search_services(text, text, text[], numeric, boolean, text, int, int, date) to anon, authenticated;
