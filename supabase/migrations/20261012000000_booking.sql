-- Munyati Phase 3: booking core (docs/PLAN.md §4.2–§4.6, §10, owner decisions §16).
--
-- Availability, bookings with a server-enforced state machine, reschedule proposals, the
-- provider's payment methods (snapshotted onto each booking at approval), receipts in a
-- private bucket with duplicate detection, disputes, the one-active-booking-per-category rule,
-- the once-per-provider demo booking, timeouts, reminders and push/SMS notifications.
--
-- Every transition goes through `booking_transition()`, which checks who may move a booking
-- from which status and writes an append-only `booking_events` row (the audit trail).

create extension if not exists btree_gist;

-- ---------------------------------------------------------------------------------------------
-- Availability (provider weekly hours + days off)
-- ---------------------------------------------------------------------------------------------

create table public.availability_rules (
  id bigint generated always as identity primary key,
  provider_id uuid not null references public.providers(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),   -- 0 = Sunday (Saudi week start)
  start_time time not null,
  end_time time not null,
  check (end_time > start_time)
);
create index availability_rules_provider_idx on public.availability_rules (provider_id, weekday);

create table public.availability_days_off (
  provider_id uuid not null references public.providers(id) on delete cascade,
  day date not null,
  primary key (provider_id, day)
);

-- ---------------------------------------------------------------------------------------------
-- Payment methods (requirement 5): IBAN, instant-transfer alias, wallet
-- ---------------------------------------------------------------------------------------------

create table public.provider_payment_methods (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  kind text not null check (kind in ('iban', 'sarie_alias', 'wallet')),
  label text not null check (length(label) between 2 and 60),          -- bank or wallet name
  account_name text not null check (length(account_name) between 2 and 100),
  value text not null check (length(value) between 5 and 40),           -- IBAN or mobile number
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index provider_payment_methods_idx on public.provider_payment_methods (provider_id);
create trigger provider_payment_methods_touch before update on public.provider_payment_methods
for each row execute function public.touch_updated_at();

-- Saudi IBAN: "SA" + 22 digits, ISO 13616 mod-97 check.
create function public.is_valid_saudi_iban(p_iban text) returns boolean
language plpgsql immutable as $$
declare
  v text := upper(regexp_replace(coalesce(p_iban, ''), '\s', '', 'g'));
  v_rearranged text;
  v_numeric text := '';
  v_remainder int := 0;
  ch text;
begin
  if v !~ '^SA[0-9]{22}$' then return false; end if;
  v_rearranged := substr(v, 5) || substr(v, 1, 4);
  foreach ch in array regexp_split_to_array(v_rearranged, '') loop
    v_numeric := v_numeric || case when ch ~ '[A-Z]' then (ascii(ch) - 55)::text else ch end;
  end loop;
  foreach ch in array regexp_split_to_array(v_numeric, '') loop
    v_remainder := (v_remainder * 10 + ch::int) % 97;
  end loop;
  return v_remainder = 1;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Bookings
-- ---------------------------------------------------------------------------------------------

create type public.booking_status as enum (
  'requested', 'reschedule_proposed', 'awaiting_payment', 'payment_submitted',
  'payment_confirmed', 'completed', 'declined', 'cancelled_by_bride', 'cancelled_by_provider',
  'expired', 'disputed'
);

-- Statuses that hold a time slot and count for the one-per-category rule.
create function public.booking_is_active(p_status public.booking_status) returns boolean
language sql immutable as $$
  select p_status in ('requested', 'reschedule_proposed', 'awaiting_payment', 'payment_submitted',
                      'payment_confirmed', 'disputed');
$$;

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  reference_code text not null unique,                 -- written in the transfer note, e.g. MN-7K3QX
  bride_id uuid references public.profiles(id) on delete set null,   -- null for the demo booking
  provider_id uuid not null references public.providers(id) on delete cascade,
  service_id uuid references public.services(id) on delete set null,
  category_id text references public.categories(id),
  store_id uuid references public.stores(id) on delete set null,
  service_title text not null,                         -- snapshots: the booking keeps what was agreed
  bride_name text,
  price numeric(10, 2) not null check (price >= 0),
  deposit_amount numeric(10, 2),                       -- reserved for later (decision #4: full amount now)
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  note text check (length(note) <= 500),
  status public.booking_status not null default 'requested',
  is_demo boolean not null default false,
  enforce_category_rule boolean not null default true, -- false when the category allows parallel bookings
  payment_methods jsonb,                               -- snapshot taken at approval
  payment_due_at timestamptz,
  status_changed_at timestamptz not null default now(),
  escalated_at timestamptz,                            -- receipt not confirmed in time → admins
  reminded_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index bookings_bride_idx on public.bookings (bride_id, starts_at desc);
create index bookings_provider_idx on public.bookings (provider_id, starts_at desc);
create index bookings_status_idx on public.bookings (status, status_changed_at);
create trigger bookings_touch before update on public.bookings for each row execute function public.touch_updated_at();

-- No double booking for a provider (capacity 1) while a booking is active.
alter table public.bookings add constraint bookings_no_overlap
  exclude using gist (provider_id with =, tstzrange(starts_at, ends_at) with &&)
  where (booking_is_active(status) and not is_demo);

-- Rule #20: one active booking per bride per category (unless the category allows parallel).
create unique index bookings_one_active_per_category on public.bookings (bride_id, category_id)
  where booking_is_active(status) and enforce_category_rule and not is_demo;

create table public.booking_proposals (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  proposed_by uuid,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  note text check (length(note) <= 300),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected', 'expired')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index booking_proposals_booking_idx on public.booking_proposals (booking_id, created_at desc);

create table public.booking_events (
  id bigint generated always as identity primary key,
  booking_id uuid not null references public.bookings(id) on delete cascade,
  actor_id uuid,                                       -- null = system (timeouts)
  actor_role text not null check (actor_role in ('bride', 'provider', 'admin', 'system')),
  from_status public.booking_status,
  to_status public.booking_status not null,
  note text,
  created_at timestamptz not null default now()
);
create index booking_events_booking_idx on public.booking_events (booking_id, created_at);

create table public.payment_receipts (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  uploaded_by uuid,
  storage_path text,                                   -- receipts/<booking_id>/<uuid>.jpg (null for demo)
  amount numeric(10, 2) not null check (amount >= 0),
  transferred_at timestamptz,
  sender_bank text check (length(sender_bank) <= 60),
  sha256 text check (sha256 ~ '^[0-9a-f]{64}$'),
  is_duplicate boolean not null default false,         -- same image already used on another booking
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  reject_reason text check (length(reject_reason) <= 300),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index payment_receipts_booking_idx on public.payment_receipts (booking_id, created_at desc);
create index payment_receipts_sha_idx on public.payment_receipts (sha256);

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  opened_by uuid,
  opened_by_role text not null check (opened_by_role in ('bride', 'provider')),
  reason text not null check (reason in ('payment_not_received', 'receipt_fake', 'no_show', 'service_issue', 'refund', 'other')),
  details text check (length(details) <= 2000),
  previous_status public.booking_status not null,
  status text not null default 'open' check (status in ('open', 'resolved', 'rejected')),
  resolution text,
  resolved_by uuid,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index disputes_status_idx on public.disputes (status, created_at);

-- Transactional SMS queue: a database webhook sends each row through `send-sms` (OurSMS).
create table public.sms_outbox (
  id bigint generated always as identity primary key,
  phone text not null,
  body text not null,
  purpose text not null,
  created_at timestamptz not null default now()
);

alter table public.availability_rules enable row level security;
alter table public.availability_days_off enable row level security;
alter table public.provider_payment_methods enable row level security;
alter table public.bookings enable row level security;
alter table public.booking_proposals enable row level security;
alter table public.booking_events enable row level security;
alter table public.payment_receipts enable row level security;
alter table public.disputes enable row level security;
alter table public.sms_outbox enable row level security;

-- Parties read their own rows; admins read all. All writes go through the RPCs below.
create policy bookings_read on public.bookings for select to authenticated
  using (bride_id = auth.uid() or provider_id = auth.uid() or public.is_admin());
create policy booking_events_read on public.booking_events for select to authenticated
  using (exists (select 1 from public.bookings b where b.id = booking_id
                 and (b.bride_id = auth.uid() or b.provider_id = auth.uid())) or public.is_admin());
create policy payment_methods_read on public.provider_payment_methods for select to authenticated
  using (provider_id = auth.uid() or public.is_admin());
create policy availability_read on public.availability_rules for select to authenticated
  using (provider_id = auth.uid() or public.is_admin());
create policy disputes_read on public.disputes for select to authenticated using (public.is_admin());
create policy disputes_manage on public.disputes for update to authenticated
  using (public.has_admin_permission('payments.resolve')) with check (public.has_admin_permission('payments.resolve'));
create policy receipts_read on public.payment_receipts for select to authenticated using (public.is_admin());
revoke insert, update, delete on public.availability_rules, public.availability_days_off,
  public.provider_payment_methods, public.bookings, public.booking_proposals, public.booking_events,
  public.payment_receipts, public.sms_outbox from anon, authenticated;
revoke all on public.sms_outbox from anon, authenticated;

-- Private receipts bucket: files live under <booking_id>/; only that booking's bride uploads,
-- and only its bride, its provider and admins can read (no public URLs).
insert into storage.buckets (id, name, public) values ('receipts', 'receipts', false) on conflict (id) do nothing;

create function public.can_access_booking_file(p_name text, p_upload boolean) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from bookings b
    where b.id::text = split_part(p_name, '/', 1)
      and (b.bride_id = auth.uid() or (not p_upload and b.provider_id = auth.uid()))
  ) or (not p_upload and is_admin());
$$;

create policy receipts_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts' and public.can_access_booking_file(name, true));
create policy receipts_download on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and public.can_access_booking_file(name, false));

-- ---------------------------------------------------------------------------------------------
-- Notifications (push via the notifications webhook; key events also by SMS)
-- ---------------------------------------------------------------------------------------------

create function public.notify_user(
  p_user uuid, p_kind text, p_title_ar text, p_title_en text, p_body_ar text, p_body_en text,
  p_deep_link text, p_sms boolean default false
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_lang text;
  v_phone text;
begin
  if p_user is null then return; end if;
  select language, phone into v_lang, v_phone from profiles where id = p_user and deleted_at is null;
  if not found then return; end if;
  insert into notifications (user_id, kind, title, body, deep_link)
  values (p_user, p_kind,
          case when v_lang = 'en' then p_title_en else p_title_ar end,
          case when v_lang = 'en' then p_body_en else p_body_ar end,
          p_deep_link);
  -- SMS only for events the admin enabled (app_config.sms_events), decision #8.
  if p_sms and v_phone is not null
     and coalesce((get_config() -> 'sms_events' ->> p_kind)::boolean, false) then
    insert into sms_outbox (phone, body, purpose)
    values (v_phone, 'منيتي: ' || p_body_ar || ' ' || p_deep_link, p_kind);
  end if;
end;
$$;

create function public.notify_admins(p_kind text, p_title text, p_body text, p_deep_link text) returns void
language sql security definer set search_path = public as $$
  insert into notifications (audience, kind, title, body, deep_link) values ('admin', p_kind, p_title, p_body, p_deep_link);
$$;

create function public.booking_link(p_id uuid) returns text
language sql immutable as $$ select 'https://munyati.co/b/' || p_id::text $$;

-- ---------------------------------------------------------------------------------------------
-- State machine
-- ---------------------------------------------------------------------------------------------

-- Moves a booking to `p_to` if the caller's role allows it from the current status.
-- Returns the updated row. Raises 'invalid transition' (P0001) otherwise.
create function public.booking_transition(
  p_booking uuid, p_to public.booking_status, p_role text, p_note text default null
) returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v bookings%rowtype;
  v_allowed boolean;
begin
  select * into v from bookings where id = p_booking for update;
  if not found then raise exception 'booking not found' using errcode = 'P0002'; end if;

  if p_role = 'bride' and v.bride_id is distinct from auth.uid() then
    raise exception 'not your booking' using errcode = '42501';
  end if;
  if p_role = 'provider' and v.provider_id is distinct from auth.uid() then
    raise exception 'not your booking' using errcode = '42501';
  end if;

  v_allowed := case
    when p_role = 'provider' then (v.status, p_to) in (
      ('requested', 'awaiting_payment'), ('requested', 'declined'), ('requested', 'reschedule_proposed'),
      ('payment_submitted', 'payment_confirmed'), ('payment_submitted', 'awaiting_payment'),
      ('payment_confirmed', 'completed'),
      ('requested', 'cancelled_by_provider'), ('awaiting_payment', 'cancelled_by_provider'),
      ('reschedule_proposed', 'cancelled_by_provider'),
      ('awaiting_payment', 'disputed'), ('payment_submitted', 'disputed'), ('payment_confirmed', 'disputed'),
      ('completed', 'disputed'))
    when p_role = 'bride' then (v.status, p_to) in (
      ('reschedule_proposed', 'awaiting_payment'), ('reschedule_proposed', 'cancelled_by_bride'),
      ('awaiting_payment', 'payment_submitted'),
      ('requested', 'cancelled_by_bride'), ('awaiting_payment', 'cancelled_by_bride'),
      ('awaiting_payment', 'disputed'), ('payment_submitted', 'disputed'), ('payment_confirmed', 'disputed'),
      ('completed', 'disputed'))
    when p_role in ('system', 'admin') then true
    else false
  end;
  if not v_allowed then
    raise exception 'invalid transition % → %', v.status, p_to using errcode = 'P0001';
  end if;

  insert into booking_events (booking_id, actor_id, actor_role, from_status, to_status, note)
  values (p_booking, case when p_role = 'system' then null else auth.uid() end, p_role, v.status, p_to, p_note);

  update bookings set status = p_to, status_changed_at = now(),
    completed_at = case when p_to = 'completed' then now() else completed_at end
  where id = p_booking
  returning * into v;
  return v;
end;
$$;

create function public.new_reference_code() returns text
language plpgsql volatile as $$
declare
  v_alphabet text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';   -- no 0/O/1/I ambiguity
  v_code text;
begin
  loop
    v_code := 'MN-';
    for i in 1..5 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from bookings where reference_code = v_code);
  end loop;
  return v_code;
end;
$$;

create function public.config_hours(p_key text, p_default int) returns interval
language sql stable as $$
  select make_interval(hours => coalesce((get_config() -> 'timeouts_hours' ->> p_key)::int, p_default));
$$;

-- ---------------------------------------------------------------------------------------------
-- JSON shapes for the app
-- ---------------------------------------------------------------------------------------------

create function public.booking_json(p_booking public.bookings, p_viewer_role text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p_booking.id,
    'reference_code', p_booking.reference_code,
    'status', p_booking.status,
    'is_demo', p_booking.is_demo,
    'service_id', p_booking.service_id,
    'service_title', p_booking.service_title,
    'category_id', p_booking.category_id,
    'price', p_booking.price,
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

create function public.booking_detail_json(p_booking public.bookings, p_viewer_role text) returns jsonb
language sql stable security definer set search_path = public as $$
  select booking_json(p_booking, p_viewer_role) || jsonb_build_object(
    -- Payment details are shown to the bride only once the provider approved.
    'payment_methods', case when p_booking.status not in ('requested', 'reschedule_proposed', 'declined')
                            then coalesce(p_booking.payment_methods, '[]'::jsonb) else '[]'::jsonb end,
    'proposal', (select jsonb_build_object('id', bp.id, 'starts_at', bp.starts_at, 'ends_at', bp.ends_at,
                                           'note', bp.note, 'expires_at', bp.expires_at)
                 from booking_proposals bp where bp.booking_id = p_booking.id and bp.status = 'pending'
                 order by bp.created_at desc limit 1),
    'receipts', coalesce((select jsonb_agg(jsonb_build_object(
        'id', r.id, 'storage_path', r.storage_path, 'amount', r.amount, 'transferred_at', r.transferred_at,
        'sender_bank', r.sender_bank, 'status', r.status, 'reject_reason', r.reject_reason,
        'created_at', r.created_at) order by r.created_at desc)
      from payment_receipts r where r.booking_id = p_booking.id), '[]'::jsonb),
    'events', coalesce((select jsonb_agg(jsonb_build_object('to_status', e.to_status, 'actor_role', e.actor_role,
        'note', e.note, 'created_at', e.created_at) order by e.created_at)
      from booking_events e where e.booking_id = p_booking.id), '[]'::jsonb),
    'open_dispute', (select jsonb_build_object('reason', d.reason, 'created_at', d.created_at)
                     from disputes d where d.booking_id = p_booking.id and d.status = 'open' limit 1));
$$;

-- ---------------------------------------------------------------------------------------------
-- Provider settings RPCs: availability and payment methods
-- ---------------------------------------------------------------------------------------------

create function public.get_my_availability() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
begin
  return jsonb_build_object(
    'rules', coalesce((select jsonb_agg(jsonb_build_object('weekday', weekday,
               'start_time', to_char(start_time, 'HH24:MI'), 'end_time', to_char(end_time, 'HH24:MI'))
             order by weekday, start_time) from availability_rules where provider_id = v_uid), '[]'::jsonb),
    'days_off', coalesce((select jsonb_agg(day order by day) from availability_days_off
                          where provider_id = v_uid and day >= current_date), '[]'::jsonb));
end;
$$;

-- p_rules: [{"weekday":0,"start_time":"10:00","end_time":"22:00"}, ...]
create function public.set_my_availability(p_rules jsonb, p_days_off date[] default '{}') returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
begin
  delete from availability_rules where provider_id = v_uid;
  insert into availability_rules (provider_id, weekday, start_time, end_time)
  select v_uid, (r ->> 'weekday')::smallint, (r ->> 'start_time')::time, (r ->> 'end_time')::time
  from jsonb_array_elements(coalesce(p_rules, '[]'::jsonb)) r;
  delete from availability_days_off where provider_id = v_uid;
  insert into availability_days_off (provider_id, day)
  select v_uid, d from unnest(coalesce(p_days_off, '{}')) d where d >= current_date
  on conflict do nothing;
  return get_my_availability();
end;
$$;

create function public.get_my_payment_methods() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'label', label,
           'account_name', account_name, 'value', value, 'is_active', is_active) order by created_at)
         from provider_payment_methods where provider_id = v_uid), '[]'::jsonb);
end;
$$;

-- Edits never change bookings already approved: those carry their own snapshot.
create function public.upsert_my_payment_method(
  p_id uuid, p_kind text, p_label text, p_account_name text, p_value text, p_is_active boolean default true
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
  v_value text := upper(regexp_replace(coalesce(p_value, ''), '\s', '', 'g'));
  v_id uuid;
begin
  if p_kind = 'iban' and not is_valid_saudi_iban(v_value) then
    return jsonb_build_object('ok', false, 'error', 'invalid_iban');
  end if;
  if p_kind in ('sarie_alias', 'wallet') then
    v_value := regexp_replace(v_value, '^(\+?966|0)', '');
    if v_value !~ '^5[0-9]{8}$' then return jsonb_build_object('ok', false, 'error', 'invalid_mobile'); end if;
    v_value := '0' || v_value;
  end if;
  if p_id is null then
    insert into provider_payment_methods (provider_id, kind, label, account_name, value, is_active)
    values (v_uid, p_kind, trim(p_label), trim(p_account_name), v_value, coalesce(p_is_active, true))
    returning id into v_id;
  else
    update provider_payment_methods set kind = p_kind, label = trim(p_label), account_name = trim(p_account_name),
      value = v_value, is_active = coalesce(p_is_active, true)
    where id = p_id and provider_id = v_uid returning id into v_id;
    if v_id is null then raise exception 'not found' using errcode = 'P0002'; end if;
  end if;
  insert into admin_audit_log (admin_id, action, entity_type, entity_id, after)
  values (v_uid, 'provider_payment_method_saved', 'provider_payment_methods', v_id::text,
          jsonb_build_object('kind', p_kind, 'label', p_label, 'account_name', p_account_name));
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create function public.delete_my_payment_method(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
begin
  delete from provider_payment_methods where id = p_id and provider_id = v_uid;
  return jsonb_build_object('ok', found);
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Bride RPCs
-- ---------------------------------------------------------------------------------------------

-- Free start times for a service on a day (Riyadh time), in 30-minute steps.
create function public.get_available_slots(p_service_id uuid, p_day date) returns jsonb
language sql stable security definer set search_path = public as $$
  with s as (
    select sv.id, sv.provider_id, make_interval(mins => coalesce(sv.duration_minutes, 60)) as dur
    from services sv where sv.id = p_service_id and service_is_public(sv)
  ),
  windows as (
    select (p_day + r.start_time) at time zone 'Asia/Riyadh' as w_start,
           (p_day + r.end_time) at time zone 'Asia/Riyadh' as w_end, s.dur, s.provider_id
    from s join availability_rules r on r.provider_id = s.provider_id
    where r.weekday = extract(dow from p_day)::int
      and not exists (select 1 from availability_days_off o where o.provider_id = s.provider_id and o.day = p_day)
  ),
  candidates as (
    select gs as slot_start, gs + w.dur as slot_end, w.provider_id
    from windows w, generate_series(w.w_start, w.w_end - w.dur, interval '30 minutes') gs
  )
  select coalesce(jsonb_agg(c.slot_start order by c.slot_start), '[]'::jsonb)
  from candidates c
  where c.slot_start > now() + interval '2 hours'
    and not exists (select 1 from bookings b where b.provider_id = c.provider_id and not b.is_demo
                      and booking_is_active(b.status)
                      and tstzrange(b.starts_at, b.ends_at) && tstzrange(c.slot_start, c.slot_end));
$$;

create function public.create_booking(p_service_id uuid, p_starts_at timestamptz, p_note text default null) returns jsonb
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

create function public.respond_to_proposal(p_booking uuid, p_accept boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_proposal booking_proposals%rowtype;
  v bookings%rowtype;
begin
  select * into v_proposal from booking_proposals
  where booking_id = p_booking and status = 'pending' order by created_at desc limit 1 for update;
  if not found then raise exception 'no pending proposal' using errcode = 'P0002'; end if;

  if p_accept then
    begin
      update bookings set starts_at = v_proposal.starts_at, ends_at = v_proposal.ends_at
      where id = p_booking and bride_id = auth.uid();
    exception when exclusion_violation then
      return jsonb_build_object('ok', false, 'error', 'slot_unavailable');
    end;
    update booking_proposals set status = 'accepted' where id = v_proposal.id;
    v := booking_transition(p_booking, 'awaiting_payment', 'bride', 'proposal accepted');
    perform start_payment_window(p_booking);
    perform notify_user(v.provider_id, 'proposal_accepted', 'قبلت العروس الموعد الجديد', 'The bride accepted the new time',
      v.service_title, v.service_title, booking_link(p_booking));
  else
    update booking_proposals set status = 'rejected' where id = v_proposal.id;
    v := booking_transition(p_booking, 'cancelled_by_bride', 'bride', 'proposal rejected');
    perform notify_user(v.provider_id, 'proposal_rejected', 'رفضت العروس الموعد المقترح', 'The bride declined the proposed time',
      v.service_title, v.service_title, booking_link(p_booking));
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- p_storage_path: receipts/<booking_id>/<uuid>.jpg uploaded by the app first.
create function public.submit_receipt(
  p_booking uuid, p_storage_path text, p_amount numeric, p_transferred_at timestamptz,
  p_sender_bank text default null, p_sha256 text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v bookings%rowtype;
  v_duplicate boolean;
begin
  if split_part(p_storage_path, '/', 1) <> p_booking::text then
    raise exception 'receipt must be uploaded for this booking' using errcode = '22023';
  end if;
  v_duplicate := p_sha256 is not null and exists (
    select 1 from payment_receipts r where r.sha256 = lower(p_sha256) and r.booking_id <> p_booking);
  v := booking_transition(p_booking, 'payment_submitted', 'bride', null);
  insert into payment_receipts (booking_id, uploaded_by, storage_path, amount, transferred_at, sender_bank, sha256, is_duplicate)
  values (p_booking, auth.uid(), p_storage_path, p_amount, p_transferred_at, left(p_sender_bank, 60), lower(p_sha256), v_duplicate);
  perform notify_user(v.provider_id, 'receipt_submitted', 'إيصال تحويل بانتظار تأكيدك', 'A transfer receipt needs your confirmation',
    v.service_title || ' · ' || v.reference_code, v.service_title || ' · ' || v.reference_code, booking_link(p_booking), true);
  if v_duplicate or p_amount < v.price then
    perform notify_admins('receipt_flagged', 'إيصال يحتاج مراجعة',
      v.reference_code || case when v_duplicate then ' · صورة مستخدمة سابقاً' else ' · المبلغ أقل من المطلوب' end,
      booking_link(p_booking));
  end if;
  return jsonb_build_object('ok', true, 'is_duplicate', v_duplicate);
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Provider RPCs
-- ---------------------------------------------------------------------------------------------

create function public.start_payment_window(p_booking uuid) returns void
language sql security definer set search_path = public as $$
  update bookings set payment_due_at = now() + config_hours('payment', 48),
    payment_methods = coalesce((select jsonb_agg(jsonb_build_object('kind', m.kind, 'label', m.label,
                         'account_name', m.account_name, 'value', m.value) order by m.created_at)
                       from provider_payment_methods m where m.provider_id = bookings.provider_id and m.is_active), '[]'::jsonb)
  where id = p_booking;
$$;

create function public.approve_booking(p_booking uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v bookings%rowtype;
begin
  select * into v from bookings where id = p_booking and provider_id = auth.uid();
  if found and not v.is_demo and not exists (
      select 1 from provider_payment_methods where provider_id = auth.uid() and is_active) then
    return jsonb_build_object('ok', false, 'error', 'no_payment_method');
  end if;
  v := booking_transition(p_booking, 'awaiting_payment', 'provider', null);
  perform start_payment_window(p_booking);
  if v.is_demo then
    perform advance_demo(p_booking);
  else
    perform notify_user(v.bride_id, 'booking_approved', 'تم قبول طلبك 🎉', 'Your booking was approved',
      v.service_title || ' · الرجاء الدفع خلال ٤٨ ساعة', v.service_title || ' · please pay within 48 hours',
      booking_link(p_booking), true);
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

create function public.decline_booking(p_booking uuid, p_reason text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v bookings%rowtype;
begin
  v := booking_transition(p_booking, 'declined', 'provider', left(p_reason, 300));
  perform notify_user(v.bride_id, 'booking_declined', 'تعذّر قبول طلبك', 'Your request was declined',
    v.service_title, v.service_title, booking_link(p_booking));
  return jsonb_build_object('ok', true);
end;
$$;

create function public.propose_reschedule(p_booking uuid, p_starts_at timestamptz, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v bookings%rowtype;
begin
  select * into v from bookings where id = p_booking and provider_id = auth.uid();
  if not found then raise exception 'not your booking' using errcode = '42501'; end if;
  if p_starts_at < now() + interval '2 hours' then
    return jsonb_build_object('ok', false, 'error', 'too_soon');
  end if;
  if exists (select 1 from bookings b where b.provider_id = v.provider_id and b.id <> v.id and not b.is_demo
             and booking_is_active(b.status)
             and tstzrange(b.starts_at, b.ends_at) && tstzrange(p_starts_at, p_starts_at + (v.ends_at - v.starts_at))) then
    return jsonb_build_object('ok', false, 'error', 'slot_unavailable');
  end if;
  v := booking_transition(p_booking, 'reschedule_proposed', 'provider', left(p_note, 300));
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

create function public.confirm_payment(p_booking uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v bookings%rowtype;
begin
  v := booking_transition(p_booking, 'payment_confirmed', 'provider', null);
  update payment_receipts set status = 'accepted', reviewed_at = now()
  where booking_id = p_booking and status = 'pending';
  perform notify_user(v.bride_id, 'payment_confirmed', 'تم تأكيد استلام المبلغ', 'Payment confirmed',
    v.service_title || ' · ' || v.reference_code, v.service_title || ' · ' || v.reference_code, booking_link(p_booking), true);
  return jsonb_build_object('ok', true);
end;
$$;

create function public.reject_payment(p_booking uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v bookings%rowtype;
begin
  v := booking_transition(p_booking, 'awaiting_payment', 'provider', left(p_reason, 300));
  update payment_receipts set status = 'rejected', reject_reason = left(p_reason, 300), reviewed_at = now()
  where booking_id = p_booking and status = 'pending';
  perform notify_user(v.bride_id, 'payment_rejected', 'لم يتم تأكيد التحويل', 'Transfer not confirmed',
    coalesce(p_reason, v.service_title), coalesce(p_reason, v.service_title), booking_link(p_booking), true);
  return jsonb_build_object('ok', true);
end;
$$;

create function public.complete_booking(p_booking uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v bookings%rowtype;
begin
  select * into v from bookings where id = p_booking and provider_id = auth.uid();
  if found and not v.is_demo and v.starts_at > now() then
    return jsonb_build_object('ok', false, 'error', 'not_started');
  end if;
  v := booking_transition(p_booking, 'completed', 'provider', null);
  perform notify_user(v.bride_id, 'booking_completed', 'نتمنى أن الخدمة أعجبتك', 'We hope you loved it',
    v.service_title, v.service_title, booking_link(p_booking));
  return jsonb_build_object('ok', true);
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Either party
-- ---------------------------------------------------------------------------------------------

create function public.my_role_in(p_booking uuid) returns text
language sql stable security definer set search_path = public as $$
  select case when bride_id = auth.uid() then 'bride' when provider_id = auth.uid() then 'provider' end
  from bookings where id = p_booking;
$$;

create function public.cancel_booking(p_booking uuid, p_reason text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_role text := my_role_in(p_booking);
  v bookings%rowtype;
begin
  if v_role is null then raise exception 'not your booking' using errcode = '42501'; end if;
  v := booking_transition(p_booking, case when v_role = 'bride' then 'cancelled_by_bride' else 'cancelled_by_provider' end::booking_status,
                          v_role, left(p_reason, 300));
  update booking_proposals set status = 'expired' where booking_id = p_booking and status = 'pending';
  perform notify_user(case when v_role = 'bride' then v.provider_id else v.bride_id end, 'booking_cancelled',
    'تم إلغاء الحجز', 'Booking cancelled', v.service_title, v.service_title, booking_link(p_booking), true);
  return jsonb_build_object('ok', true);
end;
$$;

create function public.open_dispute(p_booking uuid, p_reason text, p_details text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_role text := my_role_in(p_booking);
  v_before bookings%rowtype;
  v bookings%rowtype;
begin
  if v_role is null then raise exception 'not your booking' using errcode = '42501'; end if;
  select * into v_before from bookings where id = p_booking;
  if v_before.is_demo then return jsonb_build_object('ok', false, 'error', 'demo'); end if;
  v := booking_transition(p_booking, 'disputed', v_role, p_reason);
  insert into disputes (booking_id, opened_by, opened_by_role, reason, details, previous_status)
  values (p_booking, auth.uid(), v_role, p_reason, left(p_details, 2000), v_before.status);
  perform notify_user(case when v_role = 'bride' then v.provider_id else v.bride_id end, 'dispute_opened',
    'تم فتح نزاع على الحجز', 'A dispute was opened', v.reference_code, v.reference_code, booking_link(p_booking));
  perform notify_admins('dispute_opened', 'نزاع جديد', v.reference_code || ' · ' || p_reason, booking_link(p_booking));
  return jsonb_build_object('ok', true);
end;
$$;

-- p_scope: 'active' | 'past'. Works for both roles (bride's own or provider's own bookings).
create function public.get_my_bookings(p_scope text default 'active') returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(booking_json(b, case when b.bride_id = auth.uid() then 'bride' else 'provider' end)
                            order by case when p_scope = 'active' then b.starts_at end asc,
                                     case when p_scope <> 'active' then b.starts_at end desc), '[]'::jsonb)
  from bookings b
  where (b.bride_id = auth.uid() or b.provider_id = auth.uid())
    and (case when p_scope = 'active' then booking_is_active(b.status) else not booking_is_active(b.status) end);
$$;

create function public.get_booking(p_booking uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select booking_detail_json(b, case when b.bride_id = auth.uid() then 'bride' else 'provider' end)
  from bookings b
  where b.id = p_booking and (b.bride_id = auth.uid() or b.provider_id = auth.uid());
$$;

-- ---------------------------------------------------------------------------------------------
-- Demo booking for new providers (requirement 24): once, at registration, clearly labelled,
-- excluded from analytics, ratings, rules and admin queues. The "demo bride" answers by
-- herself so the provider can walk the whole flow.
-- ---------------------------------------------------------------------------------------------

create function public.create_demo_booking() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  -- Riyadh wall-clock time: 3 days from today at 18:00.
  v_start timestamp := date_trunc('day', now() at time zone 'Asia/Riyadh') + interval '3 days 18 hours';
  v_id uuid;
begin
  if new.demo_booking_sent_at is not null then return new; end if;
  insert into bookings (reference_code, bride_id, provider_id, service_title, bride_name, price, starts_at, ends_at,
                        note, is_demo, enforce_category_rule)
  values (new_reference_code(), null, new.id, 'مكياج العروس (طلب تجريبي)', 'عروس تجريبية', 2800,
          v_start at time zone 'Asia/Riyadh', (v_start + interval '3 hours') at time zone 'Asia/Riyadh',
          'هذا طلب تجريبي للتعرّف على طريقة الحجز في منيتي. جرّبي القبول أو اقتراح موعد آخر.', true, false)
  returning id into v_id;
  insert into booking_events (booking_id, actor_role, to_status, note) values (v_id, 'system', 'requested', 'demo');
  update providers set demo_booking_sent_at = now() where id = new.id;
  perform notify_user(new.id, 'demo_booking', 'طلب تجريبي: جرّبي طريقة الحجز', 'Demo request: try how booking works',
    'هذا طلب تجريبي وليس عميلة حقيقية.', 'This is a demo, not a real customer.', booking_link(v_id));
  return new;
end;
$$;
create trigger providers_demo_booking after insert on public.providers
for each row execute function public.create_demo_booking();

-- After the provider acts on the demo, the demo bride responds: accepts a proposed time, and
-- "pays" with a sample receipt so the provider can practise confirming it.
create function public.advance_demo(p_booking uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v bookings%rowtype;
begin
  select * into v from bookings where id = p_booking and is_demo;
  if not found then return; end if;
  if v.status = 'reschedule_proposed' then
    update bookings b set starts_at = p.starts_at, ends_at = p.ends_at
    from booking_proposals p where p.booking_id = b.id and p.status = 'pending' and b.id = p_booking;
    update booking_proposals set status = 'accepted' where booking_id = p_booking and status = 'pending';
    perform booking_transition(p_booking, 'awaiting_payment', 'system', 'demo bride accepted');
    perform start_payment_window(p_booking);
  end if;
  insert into payment_receipts (booking_id, storage_path, amount, transferred_at, sender_bank)
  values (p_booking, null, v.price, now(), 'مصرف تجريبي');
  perform booking_transition(p_booking, 'payment_submitted', 'system', 'demo receipt');
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Budget now subtracts approved bookings (requirement 13)
-- ---------------------------------------------------------------------------------------------

create or replace function public.get_my_budget() returns jsonb
language sql stable security definer set search_path = public as $$
  with reserved as (
    select coalesce(sum(price), 0) as amount from bookings
    where bride_id = auth.uid() and not is_demo
      and status in ('awaiting_payment', 'payment_submitted', 'payment_confirmed', 'completed', 'disputed')
  )
  select case when b.profile_id is null then null else jsonb_build_object(
    'total', b.total_amount,
    'reserved', r.amount,
    'remaining', b.total_amount - r.amount,
    'wedding_date', b.wedding_date) end
  from (select auth.uid() as uid) u
  left join bride_budgets b on b.profile_id = u.uid
  cross join reserved r;
$$;

-- ---------------------------------------------------------------------------------------------
-- Timeouts and reminders (pg_cron every 15 minutes)
-- ---------------------------------------------------------------------------------------------

create function public.process_booking_timers() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r bookings%rowtype;
  v_expired int := 0;
  v_escalated int := 0;
  v_reminded int := 0;
begin
  for r in select * from bookings where not is_demo and (
      (status = 'requested' and status_changed_at < now() - config_hours('request', 48))
   or (status = 'awaiting_payment' and payment_due_at < now())
   or (status = 'reschedule_proposed' and exists (select 1 from booking_proposals p where p.booking_id = bookings.id
                                                   and p.status = 'pending' and p.expires_at < now())))
  loop
    update booking_proposals set status = 'expired' where booking_id = r.id and status = 'pending';
    perform booking_transition(r.id, 'expired', 'system', 'timeout');
    perform notify_user(r.bride_id, 'booking_expired', 'انتهت مهلة الحجز', 'Booking expired', r.service_title, r.service_title, booking_link(r.id));
    perform notify_user(r.provider_id, 'booking_expired', 'انتهت مهلة الحجز', 'Booking expired', r.service_title, r.service_title, booking_link(r.id));
    v_expired := v_expired + 1;
  end loop;

  for r in select * from bookings where not is_demo and status = 'payment_submitted' and escalated_at is null
           and status_changed_at < now() - config_hours('receipt_confirmation', 48)
  loop
    update bookings set escalated_at = now() where id = r.id;
    perform notify_admins('receipt_unconfirmed', 'إيصال لم تؤكده مقدّمة الخدمة', r.reference_code, booking_link(r.id));
    v_escalated := v_escalated + 1;
  end loop;

  for r in select * from bookings where not is_demo and status = 'payment_confirmed' and reminded_at is null
           and starts_at between now() + interval '20 hours' and now() + interval '28 hours'
  loop
    update bookings set reminded_at = now() where id = r.id;
    perform notify_user(r.bride_id, 'booking_reminder', 'موعدك غداً', 'Your appointment is tomorrow',
      r.service_title || ' · ' || to_char(r.starts_at at time zone 'Asia/Riyadh', 'HH24:MI'),
      r.service_title || ' · ' || to_char(r.starts_at at time zone 'Asia/Riyadh', 'HH24:MI'), booking_link(r.id), true);
    perform notify_user(r.provider_id, 'booking_reminder', 'لديكِ موعد غداً', 'You have an appointment tomorrow',
      r.service_title || ' · ' || to_char(r.starts_at at time zone 'Asia/Riyadh', 'HH24:MI'),
      r.service_title || ' · ' || to_char(r.starts_at at time zone 'Asia/Riyadh', 'HH24:MI'), booking_link(r.id));
    v_reminded := v_reminded + 1;
  end loop;

  return jsonb_build_object('expired', v_expired, 'escalated', v_escalated, 'reminded', v_reminded);
end;
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('booking-timers', '*/15 * * * *', $job$select public.process_booking_timers()$job$);
  end if;
end;
$$;

-- SMS on/off per event, editable from the dashboard (decision #8).
update public.app_config set config = config || jsonb_build_object('sms_events', jsonb_build_object(
  'booking_requested', true, 'booking_approved', true, 'reschedule_proposed', true, 'receipt_submitted', true,
  'payment_confirmed', true, 'payment_rejected', true, 'booking_cancelled', false, 'booking_reminder', true))
where id = 1 and not (config ? 'sms_events');

-- ---------------------------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------------------------

do $$
declare
  f text;
begin
  -- Internal helpers: no client access.
  foreach f in array array[
    'public.booking_transition(uuid, public.booking_status, text, text)',
    'public.notify_user(uuid, text, text, text, text, text, text, boolean)',
    'public.notify_admins(text, text, text, text)',
    'public.start_payment_window(uuid)', 'public.advance_demo(uuid)',
    'public.process_booking_timers()', 'public.booking_json(public.bookings, text)',
    'public.booking_detail_json(public.bookings, text)']
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
  -- Signed-in RPCs.
  foreach f in array array[
    'public.get_my_availability()', 'public.set_my_availability(jsonb, date[])',
    'public.get_my_payment_methods()',
    'public.upsert_my_payment_method(uuid, text, text, text, text, boolean)',
    'public.delete_my_payment_method(uuid)',
    'public.create_booking(uuid, timestamptz, text)', 'public.respond_to_proposal(uuid, boolean)',
    'public.submit_receipt(uuid, text, numeric, timestamptz, text, text)',
    'public.approve_booking(uuid)', 'public.decline_booking(uuid, text)',
    'public.propose_reschedule(uuid, timestamptz, text)', 'public.confirm_payment(uuid)',
    'public.reject_payment(uuid, text)', 'public.complete_booking(uuid)',
    'public.cancel_booking(uuid, text)', 'public.open_dispute(uuid, text, text)',
    'public.get_my_bookings(text)', 'public.get_booking(uuid)']
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
