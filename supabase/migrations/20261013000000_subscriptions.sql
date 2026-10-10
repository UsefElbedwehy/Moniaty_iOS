-- =============================================================================================
-- Munyati — Phase 4: provider subscriptions (docs/PLAN.md §4.7, decisions #2 and #3).
--
-- * Plans Normal / Plus / Diamond, editable from the dashboard (limits, features, prices).
-- * Entitlements live in `provider_subscriptions` with a `source` (tap / app_store /
--   admin_comp). The app reads only the entitlement, never the payment method, so adding
--   StoreKit later is additive (decision #2).
-- * Payments go through Tap's hosted checkout. Edge functions own every Tap call and the
--   secret key; `settle_subscription_payment` (service role only) is the one place that turns
--   a captured charge into time on a plan. It is idempotent.
-- * Periods are monthly and are not renewed automatically: the provider pays again to renew,
--   and reminders go out before the end. Paying during the free trial starts after the trial;
--   an upgrade starts now and turns the unused time of the old plan into extra days.
-- * The 2-month trial starts when an admin approves the provider. A phone number gets one
--   trial, even after the account is deleted and created again.
-- * A provider is listed (services visible to brides) while on trial or subscribed. After
--   that, services are hidden, not deleted. On a smaller plan, services above the limit are
--   paused, and the provider chooses which stay live.
-- =============================================================================================

-- ---------------------------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------------------------

create type public.subscription_source as enum ('tap', 'app_store', 'admin_comp');
-- replaced: cut short by an upgrade (its unused value moved to the new period).
create type public.subscription_status as enum ('active', 'replaced', 'cancelled', 'refunded');
-- review: captured, but the amount or currency did not match; an admin decides.
create type public.subscription_payment_status as enum ('initiated', 'captured', 'failed', 'review');

create table public.subscription_plans (
  id text primary key,                         -- 'normal' | 'plus' | 'diamond'
  name_ar text not null,
  name_en text not null,
  description_ar text,
  description_en text,
  features_ar text[] not null default '{}',
  features_en text[] not null default '{}',
  price_sar numeric(10, 2) not null check (price_sar >= 0),
  period_months int not null default 1 check (period_months between 1 and 12),
  max_services int not null check (max_services >= 0),
  max_stores int not null check (max_stores >= 0),
  max_photos_per_service int not null check (max_photos_per_service >= 1),
  search_boost int not null default 0 check (search_boost between 0 and 10),  -- 0 standard
  is_featured boolean not null default false,  -- "featured" badge on cards
  insights_level text not null default 'basic' check (insights_level in ('basic', 'full', 'export')),
  rank int not null,                           -- bigger plan = higher rank (upgrade vs downgrade)
  is_recommended boolean not null default false,
  apple_product_id text unique,                -- for StoreKit later
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger subscription_plans_touch before update on public.subscription_plans for each row execute function public.touch_updated_at();
create trigger subscription_plans_audit after insert or update or delete on public.subscription_plans for each row execute function public.audit_admin_change();

-- One row per Tap checkout attempt. Kept when the provider deletes the account (bookkeeping).
create table public.subscription_payments (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid references public.providers(id) on delete set null,
  plan_id text not null references public.subscription_plans(id),
  amount numeric(10, 2) not null check (amount > 0),
  currency text not null default 'SAR',
  months int not null default 1,
  status public.subscription_payment_status not null default 'initiated',
  tap_charge_id text unique,
  tap_status text,
  raw jsonb,                                   -- the charge as Tap returned it
  created_at timestamptz not null default now(),
  captured_at timestamptz
);
create index subscription_payments_provider_idx on public.subscription_payments (provider_id, created_at desc);

create table public.provider_subscriptions (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  plan_id text not null references public.subscription_plans(id),
  source public.subscription_source not null,
  status public.subscription_status not null default 'active',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  payment_id uuid references public.subscription_payments(id),
  granted_by uuid references auth.users(id),
  note text,
  created_at timestamptz not null default now(),
  check (ends_at >= starts_at)
);
create index provider_subscriptions_provider_idx on public.provider_subscriptions (provider_id, ends_at desc) where status = 'active';

-- Phones that already used the free trial (survives account deletion: no FK on purpose).
create table public.trial_claims (
  phone text primary key,
  provider_id uuid,
  claimed_at timestamptz not null default now()
);

-- Reminders already sent, so the daily job sends each one once.
create table public.subscription_reminders (
  provider_id uuid not null references public.providers(id) on delete cascade,
  kind text not null,                          -- e.g. 'trial_ending_7', 'listing_hidden'
  due_on date not null,                        -- the end date the reminder is about
  sent_at timestamptz not null default now(),
  primary key (provider_id, kind, due_on)
);

alter table public.subscription_plans enable row level security;
alter table public.subscription_payments enable row level security;
alter table public.provider_subscriptions enable row level security;
alter table public.trial_claims enable row level security;
alter table public.subscription_reminders enable row level security;

-- Plans are public (guests can read "for providers" info); admins edit them.
create policy plans_read on public.subscription_plans for select to anon, authenticated
  using (is_active or public.has_admin_permission('subscriptions.manage'));
create policy plans_admin on public.subscription_plans for all to authenticated
  using (public.has_admin_permission('subscriptions.manage'))
  with check (public.has_admin_permission('subscriptions.manage'));
-- Providers read their own periods and payments through RPCs; admins read everything.
create policy provider_subscriptions_admin_read on public.provider_subscriptions for select to authenticated
  using (public.has_admin_permission('subscriptions.manage'));
create policy subscription_payments_admin_read on public.subscription_payments for select to authenticated
  using (public.has_admin_permission('subscriptions.manage'));

insert into public.admin_role_permissions (role_id, permission) values ('ops', 'subscriptions.manage')
on conflict do nothing;

-- Approved plans (decision #3). Prices are placeholders until the owner sets them in the dashboard.
insert into public.subscription_plans (id, name_ar, name_en, description_ar, description_en, features_ar, features_en,
  price_sar, max_services, max_stores, max_photos_per_service, search_boost, is_featured, insights_level, rank,
  is_recommended, sort_order) values
  ('normal', 'العادية', 'Normal', 'للبداية بخدمة واحدة', 'Start with one service',
   array['خدمة واحدة', '٦ صور لكل خدمة', 'ظهور عادي', 'إحصائيات أساسية'],
   array['1 service', '6 photos per service', 'Standard placement', 'Basic insights'],
   99, 1, 0, 6, 0, false, 'basic', 1, false, 1),
  ('plus', 'بلس', 'Plus', 'الأكثر اختياراً', 'Most popular',
   array['٣ خدمات', 'متجر واحد', '١٥ صورة لكل خدمة', 'ظهور مُعزَّز', 'إحصائيات كاملة'],
   array['3 services', '1 store', '15 photos per service', 'Boosted placement', 'Full insights'],
   249, 3, 1, 15, 1, false, 'full', 2, true, 2),
  ('diamond', 'دايموند', 'Diamond', 'لأكبر حضور', 'For the biggest presence',
   array['١٠ خدمات', '٣ متاجر', '٣٠ صورة لكل خدمة', 'أعلى الظهور وشارة مميّزة', 'بنر شهري في الرئيسية', 'إحصائيات كاملة'],
   array['10 services', '3 stores', '30 photos per service', 'Top placement and a featured badge', 'A monthly Home banner', 'Full insights'],
   499, 10, 3, 30, 2, true, 'export', 3, false, 3)
on conflict (id) do nothing;

-- The trial gives the features of this plan (dashboard-editable), and SMS for the reminders.
update public.app_config set config = config
  || jsonb_build_object('trial_plan_id', 'diamond')
  || jsonb_build_object('sms_events', coalesce(config -> 'sms_events', '{}'::jsonb)
       || jsonb_build_object('trial_ending', true, 'subscription_ending', true, 'listing_hidden', true,
                             'subscription_started', false))
where id = 1 and not (config ? 'trial_plan_id');

-- ---------------------------------------------------------------------------------------------
-- Entitlement helpers
-- ---------------------------------------------------------------------------------------------

-- The paid period running now (null fields when none).
create function public.current_subscription(p_provider uuid) returns public.provider_subscriptions
language sql stable security definer set search_path = public as $$
  select * from provider_subscriptions
  where provider_id = p_provider and status = 'active' and starts_at <= now() and ends_at > now()
  order by starts_at desc limit 1;
$$;

-- When everything already paid for (current and queued periods) ends.
create function public.paid_until(p_provider uuid) returns timestamptz
language sql stable security definer set search_path = public as $$
  select max(ends_at) from provider_subscriptions
  where provider_id = p_provider and status = 'active' and ends_at > now();
$$;

-- The plan whose limits apply now: the paid one, else the trial plan. Pending providers get the
-- trial plan's limits too, so they can prepare their profile before approval.
create function public.provider_plan(p_provider uuid) returns public.subscription_plans
language sql stable security definer set search_path = public as $$
  select pl.* from subscription_plans pl
  where pl.id = coalesce((current_subscription(p_provider)).plan_id, get_config() ->> 'trial_plan_id', 'diamond');
$$;

-- Approved and either on trial or subscribed: their services are visible to brides.
create function public.provider_is_listed(p_provider uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from providers p
    where p.id = p_provider and p.status = 'approved'
      and (p.trial_ends_at > now()
           or exists (select 1 from provider_subscriptions s where s.provider_id = p.id and s.status = 'active'
                        and s.starts_at <= now() and s.ends_at > now())));
$$;

-- Search placement and the featured badge come from a paid plan only.
create function public.provider_boost(p_provider uuid) returns int
language sql stable security definer set search_path = public as $$
  select coalesce((select pl.search_boost from subscription_plans pl
                   where pl.id = (current_subscription(p_provider)).plan_id), 0);
$$;

create function public.provider_is_featured(p_provider uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select pl.is_featured from subscription_plans pl
                   where pl.id = (current_subscription(p_provider)).plan_id), false);
$$;

create function public.plan_json(p public.subscription_plans) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'id', p.id, 'name_ar', p.name_ar, 'name_en', p.name_en,
    'description_ar', p.description_ar, 'description_en', p.description_en,
    'features_ar', to_jsonb(p.features_ar), 'features_en', to_jsonb(p.features_en),
    'price_sar', p.price_sar, 'period_months', p.period_months,
    'max_services', p.max_services, 'max_stores', p.max_stores, 'max_photos', p.max_photos_per_service,
    'is_featured', p.is_featured, 'insights_level', p.insights_level, 'rank', p.rank,
    'is_recommended', p.is_recommended);
$$;

-- What the studio shows: state (pending | trial | subscribed | expired), plan and dates.
create function public.provider_entitlement(p_provider uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_provider providers%rowtype;
  v_current provider_subscriptions%rowtype := current_subscription(p_provider);
  v_next provider_subscriptions%rowtype;
begin
  select * into v_provider from providers where id = p_provider;
  select * into v_next from provider_subscriptions
  where provider_id = p_provider and status = 'active' and starts_at > now()
  order by starts_at limit 1;
  return jsonb_build_object(
    'state', case
      when v_current.id is not null then 'subscribed'
      when v_provider.status <> 'approved' then 'pending'
      when v_provider.trial_ends_at > now() then 'trial'
      else 'expired' end,
    'plan_id', (provider_plan(p_provider)).id,
    'source', v_current.source,
    'trial_ends_at', v_provider.trial_ends_at,
    'period_ends_at', v_current.ends_at,
    'paid_until', paid_until(p_provider),
    'next_plan_id', v_next.plan_id,
    'next_starts_at', v_next.starts_at,
    'is_listed', provider_is_listed(p_provider));
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Replacements of Phase 2 functions (same signatures): plan limits and listing visibility
-- ---------------------------------------------------------------------------------------------

create or replace function public.provider_limits(p_provider uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'plan_id', pl.id,
    'max_services', coalesce(pl.max_services, (get_config() ->> 'trial_max_services')::int, 10),
    'max_stores', coalesce(pl.max_stores, (get_config() ->> 'trial_max_stores')::int, 3),
    'max_photos', coalesce(pl.max_photos_per_service, 30))
  from (select 1) one left join lateral (select * from provider_plan(p_provider)) pl on true;
$$;

create or replace function public.service_is_public(p_service public.services) returns boolean
language sql stable security definer set search_path = public as $$
  select p_service.status = 'active'
     and provider_is_listed(p_service.provider_id)
     and exists (select 1 from categories c where c.id = p_service.category_id and c.is_active);
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
    'female_staff_only', p_service.female_staff_only or p.female_staff_only,
    'is_favorite', exists (select 1 from favorites f where f.user_id = auth.uid() and f.service_id = p_service.id))
  from providers p where p.id = p_service.provider_id;
$$;

-- "Recommended" now puts boosted plans first (Plus, then Diamond on top).
create or replace function public.search_services(
  p_query text default null,
  p_category_id text default null,
  p_city_ids text[] default null,
  p_max_price numeric default null,
  p_female_only boolean default false,
  p_sort text default 'recommended',
  p_limit int default 30,
  p_offset int default 0
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

create or replace function public.get_provider(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_provider providers%rowtype;
begin
  select * into v_provider from providers where id = p_id;
  if not found or (not provider_is_listed(p_id) and v_provider.id is distinct from auth.uid() and not is_admin()) then
    return null;
  end if;
  return provider_summary(p_id) || jsonb_build_object(
    'bio', v_provider.bio,
    'cover_url', v_provider.cover_url,
    'address', v_provider.address,
    'lat', v_provider.lat,
    'lng', v_provider.lng,
    'instagram', v_provider.instagram,
    'is_featured', provider_is_featured(p_id),
    'services', coalesce((select jsonb_agg(service_card(s) order by s.category_id, s.price)
                          from services s where s.provider_id = p_id and service_is_public(s)), '[]'::jsonb),
    'stores', coalesce((select jsonb_agg(store_summary(st.id) order by st.created_at)
                        from stores st where st.provider_id = p_id and st.is_active), '[]'::jsonb));
end;
$$;

create or replace function public.get_store(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_store stores%rowtype;
begin
  select * into v_store from stores where id = p_id and is_active;
  if not found or not provider_is_listed(v_store.provider_id) then
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
      and exists (select 1 from services s where s.provider_id = p.id and service_is_public(s)
                    and (p_category_id is null or s.category_id = p_category_id))
    union all
    select jsonb_build_object('kind', 'store', 'id', st.id, 'name', st.name,
                              'lat', st.lat, 'lng', st.lng, 'logo_url', st.logo_url)
    from stores st
    where st.is_active and provider_is_listed(st.provider_id)
      and st.lat between p_min_lat and p_max_lat and st.lng between p_min_lng and p_max_lng
      and (coalesce(cardinality(p_city_ids), 0) = 0 or st.city_id = any (p_city_ids))
      and (p_category_id is null or exists (select 1 from services s where s.store_id = st.id
                                            and s.category_id = p_category_id and service_is_public(s)))
    limit 300
  ) pins;
$$;

-- Photos per service follow the plan (the app also limits the picker).
create function public.enforce_photo_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_max int := ((provider_limits(new.provider_id)) ->> 'max_photos')::int;
begin
  if cardinality(new.image_urls) > v_max
     and (tg_op = 'INSERT' or cardinality(new.image_urls) > cardinality(old.image_urls)) then
    raise exception 'photo_limit:%', v_max using errcode = '22023';
  end if;
  return new;
end;
$$;
create trigger services_photo_limit before insert or update of image_urls on public.services
  for each row execute function public.enforce_photo_limit();

-- ---------------------------------------------------------------------------------------------
-- Trial
-- ---------------------------------------------------------------------------------------------

-- Approval starts the trial (app_config.trial_days). A phone that already had a trial gets none.
create function public.start_provider_trial() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_phone text;
begin
  if new.status = 'approved' and new.trial_ends_at is null then
    select phone into v_phone from profiles where id = new.id;
    if v_phone is not null and exists (select 1 from trial_claims where phone = v_phone and provider_id is distinct from new.id) then
      new.trial_ends_at := now();
    else
      new.trial_ends_at := now() + make_interval(days => coalesce((get_config() ->> 'trial_days')::int, 60));
      if v_phone is not null then
        insert into trial_claims (phone, provider_id) values (v_phone, new.id) on conflict (phone) do nothing;
      end if;
    end if;
  end if;
  return new;
end;
$$;
create trigger providers_trial before insert or update of status on public.providers
  for each row execute function public.start_provider_trial();

-- Providers approved before this migration start their trial now.
update public.providers set trial_ends_at = now() + make_interval(days => coalesce((public.get_config() ->> 'trial_days')::int, 60))
where status = 'approved' and trial_ends_at is null;

-- ---------------------------------------------------------------------------------------------
-- Granting time on a plan
-- ---------------------------------------------------------------------------------------------

-- Pauses services and hides stores above the current plan's limits (newest edits stay live).
create function public.enforce_plan_limits(p_provider uuid) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_limits jsonb := provider_limits(p_provider);
  v_paused int;
  v_hidden int;
begin
  with extra as (
    select id from services where provider_id = p_provider and status = 'active'
    order by updated_at desc offset (v_limits ->> 'max_services')::int)
  update services set status = 'paused' where id in (select id from extra);
  get diagnostics v_paused = row_count;
  with extra as (
    select id from stores where provider_id = p_provider and is_active
    order by created_at offset (v_limits ->> 'max_stores')::int)
  update stores set is_active = false where id in (select id from extra);
  get diagnostics v_hidden = row_count;
  if v_paused + v_hidden > 0 then
    perform notify_user(p_provider, 'plan_limits', 'تم إيقاف بعض خدماتك مؤقتاً', 'Some services were paused',
      'باقتك الحالية تسمح بعدد أقل. اختاري الخدمات التي تبقى ظاهرة من استوديو أعمالي.',
      'Your current plan allows fewer. Choose which stay live in My studio.', 'https://munyati.co/plans');
  end if;
  return v_paused + v_hidden;
end;
$$;

-- Adds `p_months` of `p_plan`. Rules:
-- * nothing paid running now → starts now, or when the trial ends if the provider is on trial;
-- * same plan or a smaller one → queued after everything already paid for;
-- * a bigger plan → starts now; the unused time of the current and queued periods is converted
--   at list prices into extra time on the new plan.
create function public.grant_subscription(
  p_provider uuid, p_plan text, p_months int, p_source public.subscription_source,
  p_payment uuid default null, p_granted_by uuid default null, p_note text default null
) returns public.provider_subscriptions
language plpgsql security definer set search_path = public as $$
declare
  v_plan subscription_plans%rowtype;
  v_provider providers%rowtype;
  v_current provider_subscriptions%rowtype;
  v_current_rank int;
  v_start timestamptz := now();
  v_credit_seconds numeric := 0;
  v_row provider_subscriptions%rowtype;
  r record;
begin
  select * into v_plan from subscription_plans where id = p_plan;
  if not found then raise exception 'unknown plan' using errcode = '22023'; end if;
  if coalesce(p_months, 0) < 1 then raise exception 'invalid months' using errcode = '22023'; end if;
  -- One grant at a time per provider.
  select * into v_provider from providers where id = p_provider for update;
  if not found then raise exception 'unknown provider' using errcode = 'P0002'; end if;

  v_current := current_subscription(p_provider);
  if v_current.id is not null then
    select rank into v_current_rank from subscription_plans where id = v_current.plan_id;
  end if;

  if v_current.id is not null and v_plan.rank > v_current_rank then
    for r in select s.*, pl.price_sar from provider_subscriptions s join subscription_plans pl on pl.id = s.plan_id
             where s.provider_id = p_provider and s.status = 'active' and s.ends_at > now()
    loop
      v_credit_seconds := v_credit_seconds + extract(epoch from r.ends_at - greatest(r.starts_at, now()))
        * case when v_plan.price_sar > 0 then r.price_sar / v_plan.price_sar else 1 end;
      update provider_subscriptions set status = 'replaced', ends_at = greatest(starts_at, now()) where id = r.id;
    end loop;
  else
    v_start := greatest(now(),
                        coalesce(paid_until(p_provider), now()),
                        case when v_current.id is null and v_provider.trial_ends_at > now() then v_provider.trial_ends_at else now() end);
  end if;

  insert into provider_subscriptions (provider_id, plan_id, source, starts_at, ends_at, payment_id, granted_by, note)
  values (p_provider, p_plan, p_source, v_start,
          v_start + make_interval(months => p_months) + make_interval(secs => round(v_credit_seconds)),
          p_payment, p_granted_by, p_note)
  returning * into v_row;

  perform enforce_plan_limits(p_provider);
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Tap payments (called by the edge functions)
-- ---------------------------------------------------------------------------------------------

-- Provider: opens a payment for a plan; the edge function then creates the Tap charge.
-- The amount always comes from the plan here, never from the client.
create function public.start_subscription_payment(p_plan text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
  v_plan subscription_plans%rowtype;
  v_provider providers%rowtype;
  v_id uuid;
begin
  select * into v_provider from providers where id = v_uid;
  if v_provider.status <> 'approved' then
    return jsonb_build_object('ok', false, 'error', 'not_approved');
  end if;
  select * into v_plan from subscription_plans where id = p_plan and is_active;
  if not found or v_plan.price_sar <= 0 then
    return jsonb_build_object('ok', false, 'error', 'plan_unavailable');
  end if;
  if (select count(*) from subscription_payments
      where provider_id = v_uid and created_at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'too_many_attempts');
  end if;
  insert into subscription_payments (provider_id, plan_id, amount, months)
  values (v_uid, v_plan.id, v_plan.price_sar, v_plan.period_months)
  returning id into v_id;
  return jsonb_build_object(
    'ok', true, 'id', v_id, 'amount', v_plan.price_sar, 'currency', 'SAR', 'months', v_plan.period_months,
    'plan_name', v_plan.name_en || ' · ' || v_plan.name_ar,
    'business_name', v_provider.business_name,
    'phone', (select phone from profiles where id = v_uid));
end;
$$;

-- Service role: remembers which Tap charge belongs to a payment.
create function public.attach_tap_charge(p_payment uuid, p_charge_id text) returns void
language sql security definer set search_path = public as $$
  update subscription_payments set tap_charge_id = p_charge_id where id = p_payment and tap_charge_id is null;
$$;

-- Provider: the status of one of their payments (the edge function settles it if still open).
create function public.get_my_subscription_payment(p_id uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', id, 'status', status, 'tap_charge_id', tap_charge_id, 'plan_id', plan_id)
  from subscription_payments where id = p_id and provider_id = auth.uid();
$$;

-- Service role: applies Tap's authoritative charge status (re-fetched from Tap, never taken
-- from a webhook body). Idempotent: a captured payment grants time exactly once.
create function public.settle_subscription_payment(
  p_charge_id text, p_status text, p_amount numeric, p_currency text, p_raw jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_pay subscription_payments%rowtype;
  v_status text := upper(coalesce(p_status, ''));
  v_plan subscription_plans%rowtype;
begin
  select * into v_pay from subscription_payments where tap_charge_id = p_charge_id for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'unknown_charge'); end if;
  if v_pay.status in ('captured', 'review') then
    return jsonb_build_object('ok', true, 'status', v_pay.status);
  end if;

  if v_status = 'CAPTURED' then
    if p_amount is null or p_amount < v_pay.amount or upper(coalesce(p_currency, '')) <> upper(v_pay.currency) then
      update subscription_payments set status = 'review', tap_status = v_status, raw = p_raw, captured_at = now()
      where id = v_pay.id;
      perform notify_admins('subscription_payment_review', 'دفعة اشتراك تحتاج مراجعة',
        coalesce(p_amount::text, '?') || ' ' || coalesce(p_currency, '?') || ' ≠ ' || v_pay.amount || ' ' || v_pay.currency,
        'https://munyati.co/admin/subscriptions/' || v_pay.id);
      return jsonb_build_object('ok', true, 'status', 'review');
    end if;
    update subscription_payments set status = 'captured', tap_status = v_status, raw = p_raw, captured_at = now()
    where id = v_pay.id;
    if v_pay.provider_id is not null then
      perform grant_subscription(v_pay.provider_id, v_pay.plan_id, v_pay.months, 'tap', v_pay.id);
      select * into v_plan from subscription_plans where id = v_pay.plan_id;
      perform notify_user(v_pay.provider_id, 'subscription_started', 'تم تفعيل باقتك', 'Your plan is active',
        'باقة ' || v_plan.name_ar || ' مفعّلة. شكراً لك!', 'The ' || v_plan.name_en || ' plan is active. Thank you!',
        'https://munyati.co/plans', true);
    end if;
    return jsonb_build_object('ok', true, 'status', 'captured');
  elsif v_status in ('FAILED', 'DECLINED', 'CANCELLED', 'VOID', 'RESTRICTED', 'ABANDONED', 'TIMEDOUT', 'UNKNOWN') then
    update subscription_payments set status = 'failed', tap_status = v_status, raw = p_raw where id = v_pay.id;
    return jsonb_build_object('ok', true, 'status', 'failed');
  end if;
  -- INITIATED / IN_PROGRESS: a later webhook or poll settles it.
  update subscription_payments set tap_status = v_status where id = v_pay.id;
  return jsonb_build_object('ok', true, 'status', v_pay.status);
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Provider RPCs
-- ---------------------------------------------------------------------------------------------

create function public.get_my_subscription() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
begin
  return jsonb_build_object(
    'entitlement', provider_entitlement(v_uid),
    'limits', provider_limits(v_uid),
    'usage', jsonb_build_object(
      'active_services', (select count(*) from services where provider_id = v_uid and status = 'active'),
      'active_stores', (select count(*) from stores where provider_id = v_uid and is_active)),
    'plans', coalesce((select jsonb_agg(plan_json(p) order by p.sort_order) from subscription_plans p where p.is_active), '[]'::jsonb),
    'periods', coalesce((select jsonb_agg(jsonb_build_object(
        'plan_id', s.plan_id, 'source', s.source, 'starts_at', s.starts_at, 'ends_at', s.ends_at) order by s.starts_at)
      from provider_subscriptions s where s.provider_id = v_uid and s.status = 'active' and s.ends_at > now()), '[]'::jsonb),
    'payments', coalesce((select jsonb_agg(x order by x ->> 'created_at' desc) from (
        select jsonb_build_object('id', p.id, 'plan_id', p.plan_id, 'amount', p.amount, 'currency', p.currency,
                                  'status', p.status, 'created_at', p.created_at, 'captured_at', p.captured_at) x
        from subscription_payments p
        where p.provider_id = v_uid and p.status <> 'initiated'
        order by p.created_at desc limit 12) t), '[]'::jsonb));
end;
$$;

-- Views, contacts and bookings over the last `p_days`. Normal gets the basic numbers;
-- Plus and Diamond (and the trial) also get contacts, the funnel and a per-service table.
create function public.get_my_insights(p_days int default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := require_provider();
  v_since timestamptz := now() - make_interval(days => least(greatest(coalesce(p_days, 30), 1), 365));
  v_level text := (provider_plan(v_uid)).insights_level;
  v_profile_views int;
  v_service_views int;
  v_requests int;
  v_result jsonb;
begin
  select count(*) into v_profile_views from analytics_events
  where event_type = 'provider_view' and entity_id = v_uid::text and created_at >= v_since
    and user_id is distinct from v_uid;
  select count(*) into v_service_views from analytics_events
  where event_type = 'service_view' and context_id = v_uid::text and created_at >= v_since
    and user_id is distinct from v_uid;
  select count(*) into v_requests from bookings
  where provider_id = v_uid and not is_demo and created_at >= v_since;

  v_result := jsonb_build_object('level', coalesce(v_level, 'basic'), 'days', extract(day from now() - v_since)::int,
    'profile_views', v_profile_views, 'service_views', v_service_views, 'requests', v_requests);
  if coalesce(v_level, 'basic') = 'basic' then
    return v_result;
  end if;

  return v_result || jsonb_build_object(
    'contact_taps', (select count(*) from analytics_events
                     where event_type in ('whatsapp_tap', 'call_tap', 'share_tap') and created_at >= v_since
                       and user_id is distinct from v_uid
                       and (entity_id = v_uid::text
                            or entity_id in (select id::text from services where provider_id = v_uid))),
    'favorites', (select count(*) from favorites f join services s on s.id = f.service_id
                  where s.provider_id = v_uid and f.created_at >= v_since),
    'approved', (select count(*) from bookings where provider_id = v_uid and not is_demo and created_at >= v_since
                   and status in ('awaiting_payment', 'payment_submitted', 'payment_confirmed', 'completed', 'disputed')),
    'completed', (select count(*) from bookings where provider_id = v_uid and not is_demo and created_at >= v_since
                    and status = 'completed'),
    'revenue', (select coalesce(sum(price), 0) from bookings where provider_id = v_uid and not is_demo
                  and created_at >= v_since and status in ('payment_confirmed', 'completed')),
    'services', coalesce((select jsonb_agg(row order by (row ->> 'views')::int desc) from (
        select jsonb_build_object(
          'id', s.id, 'title', s.title,
          'views', (select count(*) from analytics_events e where e.event_type = 'service_view'
                      and e.entity_id = s.id::text and e.created_at >= v_since and e.user_id is distinct from v_uid),
          'requests', (select count(*) from bookings b where b.service_id = s.id and not b.is_demo
                         and b.created_at >= v_since)) as row
        from services s where s.provider_id = v_uid) t), '[]'::jsonb));
end;
$$;

-- Admin: complimentary time on a plan (e.g. launch partners), audited.
create function public.admin_grant_subscription(p_provider uuid, p_plan text, p_months int, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_row provider_subscriptions%rowtype;
begin
  perform require_admin_permission('subscriptions.manage');
  v_row := grant_subscription(p_provider, p_plan, p_months, 'admin_comp', null, auth.uid(), p_note);
  insert into admin_audit_log (admin_id, action, entity_type, entity_id, after)
  values (auth.uid(), 'grant', 'provider_subscriptions', v_row.id::text, to_jsonb(v_row));
  return jsonb_build_object('ok', true, 'id', v_row.id);
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Daily job: plan limits that start later, trial and renewal reminders, end of listing
-- ---------------------------------------------------------------------------------------------

create function public.days_until(p_at timestamptz) returns int
language sql stable as $$
  select ((p_at at time zone 'Asia/Riyadh')::date - (now() at time zone 'Asia/Riyadh')::date);
$$;

-- Sends the reminder once; returns false if it was already sent.
create function public.remind_once(p_provider uuid, p_kind text, p_due timestamptz) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  insert into subscription_reminders (provider_id, kind, due_on)
  values (p_provider, p_kind, (p_due at time zone 'Asia/Riyadh')::date);
  return true;
exception when unique_violation then
  return false;
end;
$$;

create function public.process_subscriptions() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r record;
  v_days int;
  v_enforced int := 0;
  v_reminded int := 0;
begin
  -- A queued smaller plan may have started since yesterday.
  for r in select p.id from providers p
           where p.status = 'approved'
             and (select count(*) from services s where s.provider_id = p.id and s.status = 'active')
                 > ((provider_limits(p.id)) ->> 'max_services')::int
  loop
    v_enforced := v_enforced + enforce_plan_limits(r.id);
  end loop;

  -- Trial ending in 14 / 7 / 3 / 1 days, with nothing paid to follow it.
  for r in select p.id, p.trial_ends_at from providers p
           where p.status = 'approved' and p.trial_ends_at > now() and p.trial_ends_at < now() + interval '15 days'
             and paid_until(p.id) is null
  loop
    v_days := days_until(r.trial_ends_at);
    if v_days in (14, 7, 3, 1) and remind_once(r.id, 'trial_ending_' || v_days, r.trial_ends_at) then
      perform notify_user(r.id, 'trial_ending', 'تنتهي فترتك المجانية قريباً', 'Your free trial ends soon',
        'باقي ' || v_days || ' يوم على نهاية الفترة المجانية. اختاري باقتك لتبقى خدماتك ظاهرة للعرائس.',
        v_days || ' days left in your free trial. Choose a plan to keep your services visible to brides.',
        'https://munyati.co/plans', v_days <= 7);
      v_reminded := v_reminded + 1;
    end if;
  end loop;

  -- Paid time ending in 7 / 3 / 1 days, with nothing queued after it.
  for r in select p.id, paid_until(p.id) as until from providers p
           where p.status = 'approved' and paid_until(p.id) between now() and now() + interval '8 days'
  loop
    v_days := days_until(r.until);
    if v_days in (7, 3, 1) and remind_once(r.id, 'subscription_ending_' || v_days, r.until) then
      perform notify_user(r.id, 'subscription_ending', 'اشتراكك ينتهي قريباً', 'Your plan ends soon',
        'باقي ' || v_days || ' يوم على نهاية اشتراكك. جدّديه لتبقى خدماتك ظاهرة.',
        v_days || ' days left on your plan. Renew it to keep your services visible.',
        'https://munyati.co/plans', true);
      v_reminded := v_reminded + 1;
    end if;
  end loop;

  -- Listing ended in the last day (trial or paid time over, nothing after it).
  for r in select p.id, greatest(p.trial_ends_at,
                                 (select max(ends_at) from provider_subscriptions s where s.provider_id = p.id and s.status = 'active')) as ended
           from providers p
           where p.status = 'approved' and not provider_is_listed(p.id)
  loop
    if r.ended between now() - interval '1 day' and now()
       and remind_once(r.id, 'listing_hidden', r.ended) then
      perform notify_user(r.id, 'listing_hidden', 'خدماتك مخفية الآن', 'Your services are hidden',
        'انتهت فترتك. خدماتك محفوظة وستظهر للعرائس فور اشتراكك.',
        'Your period ended. Your services are saved and come back as soon as you subscribe.',
        'https://munyati.co/plans', true);
      v_reminded := v_reminded + 1;
    end if;
  end loop;

  return jsonb_build_object('enforced', v_enforced, 'reminded', v_reminded);
end;
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- 09:00 Riyadh.
    perform cron.schedule('subscriptions-daily', '0 6 * * *', $job$select public.process_subscriptions()$job$);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------------------------

do $$
declare
  f text;
begin
  -- Internal and service-role-only.
  foreach f in array array[
    'public.grant_subscription(uuid, text, int, public.subscription_source, uuid, uuid, text)',
    'public.enforce_plan_limits(uuid)', 'public.process_subscriptions()',
    'public.remind_once(uuid, text, timestamptz)',
    'public.attach_tap_charge(uuid, text)',
    'public.settle_subscription_payment(text, text, numeric, text, jsonb)',
    'public.provider_entitlement(uuid)', 'public.current_subscription(uuid)', 'public.paid_until(uuid)',
    'public.provider_plan(uuid)', 'public.start_provider_trial()', 'public.enforce_photo_limit()']
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
  -- Signed-in RPCs.
  foreach f in array array[
    'public.start_subscription_payment(text)', 'public.get_my_subscription_payment(uuid)',
    'public.get_my_subscription()', 'public.get_my_insights(int)',
    'public.admin_grant_subscription(uuid, text, int, text)']
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
