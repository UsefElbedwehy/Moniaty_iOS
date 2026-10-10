-- Munyati core schema (Phase 1, docs/PLAN.md §6 and §12).
--
-- Accounts and roles, cities, categories, provider join requests, remote config / strings /
-- CMS pages, device tokens and notifications, analytics and error logs, phone OTP, and the
-- admin permission model with an audit log.
--
-- Conventions (from the Kolna backend, minus its known pitfalls):
-- * Every table has RLS on. Clients read through narrow policies or SECURITY DEFINER RPCs.
-- * Users can never write `profiles.role` or any admin table directly.
-- * Admin authority lives in `admin_users` + permissions, checked by `has_admin_permission()`.
-- * Void-looking RPCs return jsonb so every response has a body.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------------------------
-- Types and helpers
-- ---------------------------------------------------------------------------------------------

create type public.user_role as enum ('bride', 'provider');
create type public.provider_status as enum ('pending', 'approved', 'rejected', 'suspended');

create function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Admin model (needed by the policies below)
-- ---------------------------------------------------------------------------------------------

create table public.admin_roles (
  id text primary key,                 -- owner, ops, moderator, content, marketing, analyst
  name_ar text not null,
  name_en text not null
);

create table public.admin_role_permissions (
  role_id text not null references public.admin_roles(id) on delete cascade,
  permission text not null,            -- e.g. 'content.edit', 'providers.review', 'sms.send'
  primary key (role_id, permission)
);

create table public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role_id text not null references public.admin_roles(id),
  is_active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admin_users where user_id = auth.uid() and is_active);
$$;

-- The owner role holds every permission implicitly.
create function public.has_admin_permission(p_permission text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from admin_users au
    left join admin_role_permissions rp on rp.role_id = au.role_id and rp.permission = p_permission
    where au.user_id = auth.uid()
      and au.is_active
      and (au.role_id = 'owner' or rp.permission is not null)
  );
$$;

create function public.require_admin_permission(p_permission text) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.has_admin_permission(p_permission) then
    raise exception 'permission denied: %', p_permission using errcode = '42501';
  end if;
end;
$$;

create table public.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid,
  action text not null,                -- insert / update / delete / approve / reject / ...
  entity_type text not null,
  entity_id text,
  before jsonb,
  after jsonb,
  reason text,
  created_at timestamptz not null default now()
);
create index admin_audit_log_entity_idx on public.admin_audit_log (entity_type, entity_id, created_at desc);

-- Generic audit trigger for admin-managed tables: records who changed what.
create function public.audit_admin_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_id text;
begin
  v_id := coalesce(to_jsonb(new) ->> 'id', to_jsonb(old) ->> 'id', to_jsonb(new) ->> 'key', to_jsonb(old) ->> 'key');
  insert into admin_audit_log (admin_id, action, entity_type, entity_id, before, after)
  values (auth.uid(), lower(tg_op), tg_table_name, v_id,
          case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
          case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end);
  return coalesce(new, old);
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Cities and categories (dashboard-managed, requirements 16-18)
-- ---------------------------------------------------------------------------------------------

create table public.cities (
  id text primary key,                 -- slug, e.g. 'dammam'
  name_ar text not null,
  name_en text not null,
  lat double precision,
  lng double precision,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id text primary key,                 -- slug, e.g. 'makeup'
  name_ar text not null,
  name_en text not null,
  icon_url text,                       -- versioned path in the public `content` bucket
  icon_symbol text,                    -- SF Symbol fallback until an icon is uploaded
  cover_url text,
  price_hint_ar text,                  -- e.g. '٣٥٠ – ٣٬٠٠٠ ر.س' (budget hint only)
  price_hint_en text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  -- Rule #20 exemption: brides may hold several active bookings in this category.
  allows_parallel_bookings boolean not null default false,
  -- Usually sold through a linked store (requirement 14).
  is_store_category boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger cities_touch before update on public.cities for each row execute function public.touch_updated_at();
create trigger categories_touch before update on public.categories for each row execute function public.touch_updated_at();
create trigger cities_audit after insert or update or delete on public.cities for each row execute function public.audit_admin_change();
create trigger categories_audit after insert or update or delete on public.categories for each row execute function public.audit_admin_change();

-- ---------------------------------------------------------------------------------------------
-- Profiles and provider join requests (requirements 1, 6)
-- ---------------------------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text,
  first_name text,
  last_name text,
  display_name text,
  role public.user_role not null,
  language text not null default 'ar' check (language in ('ar', 'en')),
  sms_marketing_opt_in boolean not null default false,
  sms_marketing_opt_in_at timestamptz,
  is_banned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index profiles_phone_active_key on public.profiles (phone) where deleted_at is null;
create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();

create table public.profile_cities (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  city_id text not null references public.cities(id) on delete cascade,
  primary key (profile_id, city_id)
);

-- A provider's join request and business identity. Created automatically for provider
-- accounts; listed publicly only once an admin approves it (decision #6).
create table public.providers (
  id uuid primary key references public.profiles(id) on delete cascade,
  status public.provider_status not null default 'pending',
  business_name text,
  bio text,
  cr_number text,                      -- commercial registration (optional)
  freelance_doc_number text,           -- وثيقة العمل الحر (optional)
  is_verified boolean not null default false,
  female_staff_only boolean not null default false,
  trial_ends_at timestamptz,           -- set on approval: approval + app_config.trial_days
  demo_booking_sent_at timestamptz,    -- requirement 24, used from Phase 3
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index providers_status_idx on public.providers (status);
create trigger providers_touch before update on public.providers for each row execute function public.touch_updated_at();

create table public.provider_categories (
  provider_id uuid not null references public.providers(id) on delete cascade,
  category_id text not null references public.categories(id) on delete cascade,
  primary key (provider_id, category_id)
);

create table public.provider_cities (
  provider_id uuid not null references public.providers(id) on delete cascade,
  city_id text not null references public.cities(id) on delete cascade,
  primary key (provider_id, city_id)
);

-- New provider accounts get their (pending) join request row.
create function public.create_provider_row() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role = 'provider' then
    insert into providers (id, business_name) values (new.id, new.display_name)
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$;
create trigger profiles_create_provider after insert on public.profiles
for each row execute function public.create_provider_row();

-- ---------------------------------------------------------------------------------------------
-- Remote config, strings and CMS pages (requirement 19)
-- ---------------------------------------------------------------------------------------------

create table public.app_config (
  id int primary key default 1 check (id = 1),
  config jsonb not null,
  updated_at timestamptz not null default now()
);
create trigger app_config_touch before update on public.app_config for each row execute function public.touch_updated_at();
create trigger app_config_audit after insert or update or delete on public.app_config for each row execute function public.audit_admin_change();

create table public.app_strings (
  key text not null,
  lang text not null check (lang in ('ar', 'en')),
  value text not null,
  updated_at timestamptz not null default now(),
  primary key (key, lang)
);
create trigger app_strings_touch before update on public.app_strings for each row execute function public.touch_updated_at();
create trigger app_strings_audit after insert or update or delete on public.app_strings for each row execute function public.audit_admin_change();

create table public.cms_pages (
  slug text not null,                  -- terms, privacy, about, faq, provider-terms
  lang text not null check (lang in ('ar', 'en')),
  title text not null,
  body_markdown text not null,
  is_published boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (slug, lang)
);
create trigger cms_pages_touch before update on public.cms_pages for each row execute function public.touch_updated_at();
create trigger cms_pages_audit after insert or update or delete on public.cms_pages for each row execute function public.audit_admin_change();

-- ---------------------------------------------------------------------------------------------
-- Push: device tokens and notifications (requirement 26)
-- ---------------------------------------------------------------------------------------------

create table public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'ios',
  updated_at timestamptz not null default now()
);
create index device_tokens_user_idx on public.device_tokens (user_id);

-- Inserting a row sends a push through the `send-push` edge function (Database Webhook).
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  audience text not null default 'user' check (audience in ('user', 'admin')),
  kind text not null,
  title text not null,
  subtitle text,
  body text not null,
  image_url text,
  deep_link text,                      -- e.g. https://munyati.co/b/<booking id>
  is_read boolean not null default false,
  opened_at timestamptz,
  created_at timestamptz not null default now(),
  check (audience = 'admin' or user_id is not null)
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

-- ---------------------------------------------------------------------------------------------
-- Analytics and error logs (requirement 9, docs/PLAN.md §5)
-- ---------------------------------------------------------------------------------------------

-- Keep in step with `AnalyticsEvent` in Packages/Shared/.../AnalyticsRecorder.swift.
create type public.analytics_event_type as enum (
  'app_open', 'role_selected', 'sign_up_completed', 'category_open', 'provider_view',
  'service_view', 'store_view', 'search', 'city_filter_changed', 'budget_set', 'banner_click',
  'share_tap', 'whatsapp_tap', 'call_tap', 'booking_started', 'booking_submitted',
  'paywall_view', 'plan_purchase_started'
);

-- Partitioned by month so old raw events can be dropped cheaply after roll-up.
create table public.analytics_events (
  id bigint generated always as identity,
  event_type public.analytics_event_type not null,
  user_id uuid,
  role public.user_role,
  entity_id text,
  context_id text,
  props jsonb,
  created_at timestamptz not null default now(),
  primary key (id, created_at)
) partition by range (created_at);
create table public.analytics_events_default partition of public.analytics_events default;
create index analytics_events_type_time_idx on public.analytics_events (event_type, created_at);
create index analytics_events_entity_idx on public.analytics_events (entity_id, event_type, created_at);

-- Creates the monthly partition for the given month if missing (run monthly by pg_cron).
create function public.ensure_analytics_partition(p_month date) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_start date := date_trunc('month', p_month)::date;
  v_end date := (date_trunc('month', p_month) + interval '1 month')::date;
  v_name text := format('analytics_events_%s', to_char(v_start, 'YYYY_MM'));
begin
  if to_regclass('public.' || v_name) is null then
    execute format('create table public.%I partition of public.analytics_events for values from (%L) to (%L)',
                   v_name, v_start, v_end);
  end if;
end;
$$;
select public.ensure_analytics_partition(current_date);
select public.ensure_analytics_partition((current_date + interval '1 month')::date);

create table public.error_logs (
  id bigint generated always as identity primary key,
  source text not null check (source in ('client', 'server')),
  user_id uuid,
  code text not null,
  message text not null,
  screen text,
  app_version text,
  os_version text,
  context jsonb,
  created_at timestamptz not null default now()
);
create index error_logs_time_idx on public.error_logs (created_at desc);
create index error_logs_code_idx on public.error_logs (code, created_at desc);

-- ---------------------------------------------------------------------------------------------
-- Phone OTP and SMS log (requirement 10). Service role only.
-- ---------------------------------------------------------------------------------------------

create table public.phone_otp (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  code_hash text not null,
  ip text,
  attempts int not null default 0,
  used boolean not null default false,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index phone_otp_phone_idx on public.phone_otp (phone, created_at desc);
create index phone_otp_ip_idx on public.phone_otp (ip, created_at desc);

create table public.sms_log (
  id bigint generated always as identity primary key,
  phone text not null,
  kind text not null check (kind in ('otp', 'transactional', 'promotional')),
  purpose text not null,               -- login, booking_approved, campaign:<id>, ...
  segments int not null default 1,
  status text not null,
  provider_status int,
  provider_response text,
  created_at timestamptz not null default now()
);
create index sms_log_time_idx on public.sms_log (created_at desc);

-- Issues a code, enforcing every limit under a per-phone advisory lock so concurrent requests
-- cannot race past them: 60 s cooldown, 5/hour and 10/day per phone, 20/hour per IP, and a
-- global breaker of 300 codes per 10 minutes against SMS pumping.
create function public.otp_issue(p_phone text, p_ip text, p_code_hash text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_last timestamptz;
begin
  perform pg_advisory_xact_lock(hashtext('otp:' || p_phone));

  if (select count(*) from phone_otp where created_at > now() - interval '10 minutes') >= 300 then
    return jsonb_build_object('ok', false, 'error', 'busy');
  end if;

  select max(created_at) into v_last from phone_otp where phone = p_phone;
  if v_last > now() - interval '60 seconds' then
    return jsonb_build_object('ok', false, 'error', 'cooldown',
                              'retry_after', ceil(60 - extract(epoch from now() - v_last)));
  end if;
  if (select count(*) from phone_otp where phone = p_phone and created_at > now() - interval '1 hour') >= 5 then
    return jsonb_build_object('ok', false, 'error', 'hourly');
  end if;
  if (select count(*) from phone_otp where phone = p_phone and created_at > now() - interval '1 day') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'daily');
  end if;
  if p_ip is not null and p_ip <> 'unknown'
     and (select count(*) from phone_otp where ip = p_ip and created_at > now() - interval '1 hour') >= 20 then
    return jsonb_build_object('ok', false, 'error', 'ip');
  end if;

  update phone_otp set used = true where phone = p_phone and not used;
  insert into phone_otp (phone, code_hash, ip, expires_at)
  values (p_phone, p_code_hash, p_ip, now() + interval '10 minutes');
  return jsonb_build_object('ok', true);
end;
$$;

-- Checks a code against the latest live one. Counts failed attempts atomically (row lock) and
-- burns the code after 5 failures. Does not consume a correct code: registration reuses it.
create function public.otp_check(p_phone text, p_code_hash text) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_row phone_otp%rowtype;
begin
  select * into v_row from phone_otp
  where phone = p_phone and not used
  order by created_at desc
  limit 1
  for update;

  if not found or v_row.expires_at < now() then
    return 'expired';
  end if;
  if v_row.attempts >= 5 then
    update phone_otp set used = true where id = v_row.id;
    return 'locked';
  end if;
  if v_row.code_hash <> p_code_hash then
    update phone_otp set attempts = attempts + 1, used = (attempts + 1 >= 5) where id = v_row.id;
    return 'invalid';
  end if;
  return 'ok';
end;
$$;

create function public.otp_consume(p_phone text) returns void
language sql security definer set search_path = public as $$
  update phone_otp set used = true where phone = p_phone and not used;
$$;

-- Lets verify-otp recover an auth user whose profile insert failed earlier.
create function public.auth_user_id_for_email(p_email text) returns uuid
language sql stable security definer set search_path = public, auth as $$
  select id from auth.users where email = lower(p_email) limit 1;
$$;

-- ---------------------------------------------------------------------------------------------
-- Client RPCs
-- ---------------------------------------------------------------------------------------------

create function public.get_config() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select config from app_config where id = 1), '{}'::jsonb);
$$;

create function public.get_app_strings(p_lang text default 'ar')
returns table (key text, value text)
language sql stable security definer set search_path = public as $$
  select s.key, s.value from app_strings s where s.lang = p_lang;
$$;

create function public.get_cms_page(p_slug text, p_locale text default 'ar') returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('slug', p.slug, 'title', p.title, 'body_markdown', p.body_markdown)
  from cms_pages p
  where p.slug = p_slug and p.is_published
  order by (p.lang = p_locale) desc, (p.lang = 'ar') desc
  limit 1;
$$;

create function public.get_cities()
returns table (id text, name_ar text, name_en text, lat double precision, lng double precision)
language sql stable security definer set search_path = public as $$
  select c.id, c.name_ar, c.name_en, c.lat, c.lng
  from cities c where c.is_active
  order by c.sort_order, c.name_ar;
$$;

create function public.get_categories()
returns table (
  id text, name_ar text, name_en text, icon_url text, icon_symbol text, cover_url text,
  price_hint_ar text, price_hint_en text, allows_parallel_bookings boolean, is_store_category boolean
)
language sql stable security definer set search_path = public as $$
  select c.id, c.name_ar, c.name_en, c.icon_url, c.icon_symbol, c.cover_url,
         c.price_hint_ar, c.price_hint_en, c.allows_parallel_bookings, c.is_store_category
  from categories c where c.is_active
  order by c.sort_order, c.name_ar;
$$;

-- The caller's profile. Anonymous (guest) sessions have no profile row and browse as brides.
create function public.get_my_profile() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_profile profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  select * into v_profile from profiles where id = v_uid and deleted_at is null;
  if not found then
    return jsonb_build_object(
      'id', v_uid, 'role', null, 'display_name', null, 'phone', null,
      'city_ids', '[]'::jsonb,
      'is_anonymous', coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false),
      'provider_status', null);
  end if;
  return jsonb_build_object(
    'id', v_profile.id,
    'display_name', v_profile.display_name,
    'phone', v_profile.phone,
    'role', v_profile.role,
    'language', v_profile.language,
    'sms_marketing_opt_in', v_profile.sms_marketing_opt_in,
    'city_ids', coalesce((select jsonb_agg(city_id order by city_id) from profile_cities where profile_id = v_uid), '[]'::jsonb),
    'is_anonymous', false,
    'provider_status', (select status from providers where id = v_uid));
end;
$$;

-- Edits the safe profile fields. Role, phone and ban state are never client-editable.
create function public.update_my_profile(
  p_first_name text default null,
  p_last_name text default null,
  p_language text default null,
  p_sms_marketing_opt_in boolean default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not signed in' using errcode = '28000'; end if;
  update profiles set
    first_name = coalesce(nullif(trim(p_first_name), ''), first_name),
    last_name = coalesce(nullif(trim(p_last_name), ''), last_name),
    display_name = trim(coalesce(nullif(trim(p_first_name), ''), first_name) || ' ' ||
                        coalesce(nullif(trim(p_last_name), ''), last_name)),
    language = case when p_language in ('ar', 'en') then p_language else language end,
    sms_marketing_opt_in = coalesce(p_sms_marketing_opt_in, sms_marketing_opt_in),
    sms_marketing_opt_in_at = case
      when p_sms_marketing_opt_in is distinct from sms_marketing_opt_in and p_sms_marketing_opt_in is not null
      then now() else sms_marketing_opt_in_at end
  where id = v_uid and deleted_at is null;
  return jsonb_build_object('ok', found);
end;
$$;

-- Saves the bride's city filter. An empty list means "All cities".
create function public.set_my_cities(p_city_ids text[] default '{}') returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not exists (select 1 from profiles where id = v_uid and deleted_at is null) then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  delete from profile_cities where profile_id = v_uid;
  insert into profile_cities (profile_id, city_id)
  select v_uid, c.id from cities c where c.id = any (coalesce(p_city_ids, '{}')) and c.is_active;
  return jsonb_build_object('ok', true);
end;
$$;

create function public.register_device_token(p_token text, p_platform text default 'ios') returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if p_token is null or length(p_token) < 10 or length(p_token) > 4096 then
    raise exception 'invalid token' using errcode = '22023';
  end if;
  insert into device_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), coalesce(p_platform, 'ios'), now())
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
  return jsonb_build_object('ok', true);
end;
$$;

create function public.unregister_device_token(p_token text) returns jsonb
language sql security definer set search_path = public as $$
  delete from device_tokens where token = p_token and user_id = auth.uid();
  select jsonb_build_object('ok', true);
$$;

-- Curated analytics events. Guests are recorded too (anonymous sessions have a uid).
create function public.record_analytics_event(
  p_event_type text,
  p_entity_id text default null,
  p_context_id text default null,
  p_props jsonb default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_type analytics_event_type;
begin
  begin
    v_type := p_event_type::analytics_event_type;
  exception when invalid_text_representation then
    return jsonb_build_object('ok', false, 'error', 'unknown event');
  end;
  if p_props is not null and (jsonb_typeof(p_props) <> 'object' or length(p_props::text) > 2000) then
    p_props := null;
  end if;
  insert into analytics_events (event_type, user_id, role, entity_id, context_id, props)
  values (v_type, auth.uid(), (select role from profiles where id = auth.uid()),
          left(p_entity_id, 100), left(p_context_id, 100), p_props);
  return jsonb_build_object('ok', true);
end;
$$;

-- Client-side handled errors. Capped at 60 per user per hour so a crash loop can't flood it.
create function public.log_client_error(
  p_code text,
  p_message text,
  p_screen text default null,
  p_app_version text default null,
  p_os_version text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and (
    select count(*) from error_logs where user_id = auth.uid() and created_at > now() - interval '1 hour'
  ) >= 60 then
    return jsonb_build_object('ok', false, 'error', 'rate limited');
  end if;
  insert into error_logs (source, user_id, code, message, screen, app_version, os_version)
  values ('client', auth.uid(), left(coalesce(p_code, 'unknown'), 100), left(coalesce(p_message, ''), 2000),
          left(p_screen, 100), left(p_app_version, 40), left(p_os_version, 40));
  return jsonb_build_object('ok', true);
end;
$$;

-- In-app account deletion (called by the delete-account edge function before the auth user is
-- removed). Personal data is wiped; records the law requires will be kept anonymised once
-- bookings exist (Phase 3).
create function public.delete_my_account() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not signed in' using errcode = '28000'; end if;
  delete from device_tokens where user_id = v_uid;
  delete from profile_cities where profile_id = v_uid;
  update providers set status = 'suspended', business_name = null, bio = null,
                       cr_number = null, freelance_doc_number = null
  where id = v_uid;
  update profiles set phone = null, first_name = null, last_name = null,
                      display_name = null, sms_marketing_opt_in = false, deleted_at = now()
  where id = v_uid;
  return jsonb_build_object('ok', true);
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------------------------

alter table public.admin_roles enable row level security;
alter table public.admin_role_permissions enable row level security;
alter table public.admin_users enable row level security;
alter table public.admin_audit_log enable row level security;
alter table public.cities enable row level security;
alter table public.categories enable row level security;
alter table public.profiles enable row level security;
alter table public.profile_cities enable row level security;
alter table public.providers enable row level security;
alter table public.provider_categories enable row level security;
alter table public.provider_cities enable row level security;
alter table public.app_config enable row level security;
alter table public.app_strings enable row level security;
alter table public.cms_pages enable row level security;
alter table public.device_tokens enable row level security;
alter table public.notifications enable row level security;
alter table public.analytics_events enable row level security;
alter table public.error_logs enable row level security;
alter table public.phone_otp enable row level security;
alter table public.sms_log enable row level security;

-- Admin tables: admins read; only the owner manages team membership.
create policy admin_roles_read on public.admin_roles for select to authenticated using (public.is_admin());
create policy admin_role_permissions_read on public.admin_role_permissions for select to authenticated using (public.is_admin());
create policy admin_users_read on public.admin_users for select to authenticated using (public.is_admin());
create policy admin_users_manage on public.admin_users for all to authenticated
  using (public.has_admin_permission('team.manage')) with check (public.has_admin_permission('team.manage'));
create policy admin_audit_read on public.admin_audit_log for select to authenticated using (public.has_admin_permission('audit.read'));

-- Catalog: everyone reads active rows; content admins manage.
create policy cities_read on public.cities for select to anon, authenticated using (is_active or public.is_admin());
create policy cities_manage on public.cities for all to authenticated
  using (public.has_admin_permission('content.edit')) with check (public.has_admin_permission('content.edit'));
create policy categories_read on public.categories for select to anon, authenticated using (is_active or public.is_admin());
create policy categories_manage on public.categories for all to authenticated
  using (public.has_admin_permission('content.edit')) with check (public.has_admin_permission('content.edit'));

-- Profiles: read own (writes only through RPCs); admins read all.
create policy profiles_read_own on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
create policy profile_cities_read_own on public.profile_cities for select to authenticated using (profile_id = auth.uid() or public.is_admin());

-- Providers: read own join request; reviewers manage. Public listing arrives in Phase 2.
create policy providers_read_own on public.providers for select to authenticated using (id = auth.uid() or public.is_admin());
create policy providers_review on public.providers for update to authenticated
  using (public.has_admin_permission('providers.review')) with check (public.has_admin_permission('providers.review'));
create policy provider_categories_read on public.provider_categories for select to authenticated using (provider_id = auth.uid() or public.is_admin());
create policy provider_cities_read on public.provider_cities for select to authenticated using (provider_id = auth.uid() or public.is_admin());

-- Remote content: read through RPCs; content admins manage.
create policy app_config_manage on public.app_config for all to authenticated
  using (public.has_admin_permission('content.edit')) with check (public.has_admin_permission('content.edit'));
create policy app_strings_manage on public.app_strings for all to authenticated
  using (public.has_admin_permission('content.edit')) with check (public.has_admin_permission('content.edit'));
create policy cms_pages_read on public.cms_pages for select to anon, authenticated using (is_published or public.is_admin());
create policy cms_pages_manage on public.cms_pages for all to authenticated
  using (public.has_admin_permission('content.edit')) with check (public.has_admin_permission('content.edit'));

-- Notifications: users read their own; marketing admins create campaigns.
create policy notifications_read_own on public.notifications for select to authenticated
  using (user_id = auth.uid() or (audience = 'admin' and public.is_admin()));
create policy notifications_admin_insert on public.notifications for insert to authenticated
  with check (public.has_admin_permission('push.send'));

-- Logs: analysts read; nobody writes directly (RPCs and the service role only).
create policy analytics_read on public.analytics_events for select to authenticated using (public.has_admin_permission('analytics.read'));
create policy error_logs_read on public.error_logs for select to authenticated using (public.has_admin_permission('analytics.read'));
create policy sms_log_read on public.sms_log for select to authenticated using (public.has_admin_permission('sms.read'));
-- device_tokens and phone_otp: no policies at all (RPCs / service role only).

-- Defence in depth: clients never write these tables directly, whatever a future policy says.
revoke insert, update, delete on public.profiles, public.profile_cities, public.device_tokens,
  public.analytics_events, public.error_logs, public.phone_otp, public.sms_log from anon, authenticated;
revoke all on public.phone_otp, public.sms_log, public.device_tokens from anon;

-- Service-role-only functions.
revoke all on function public.otp_issue(text, text, text) from public, anon, authenticated;
revoke all on function public.otp_check(text, text) from public, anon, authenticated;
revoke all on function public.otp_consume(text) from public, anon, authenticated;
revoke all on function public.auth_user_id_for_email(text) from public, anon, authenticated;
revoke all on function public.ensure_analytics_partition(date) from public, anon, authenticated;
grant execute on function public.otp_issue(text, text, text), public.otp_check(text, text),
  public.otp_consume(text), public.auth_user_id_for_email(text), public.ensure_analytics_partition(date) to service_role;

-- Signed-in-only RPCs (anonymous guests have a session too, so they count as authenticated).
revoke all on function public.get_my_profile(), public.update_my_profile(text, text, text, boolean),
  public.set_my_cities(text[]), public.register_device_token(text, text), public.unregister_device_token(text),
  public.delete_my_account() from public, anon;
grant execute on function public.get_my_profile(), public.update_my_profile(text, text, text, boolean),
  public.set_my_cities(text[]), public.register_device_token(text, text), public.unregister_device_token(text),
  public.delete_my_account() to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Storage: public `content` bucket for category icons, banners and CMS images
-- ---------------------------------------------------------------------------------------------

insert into storage.buckets (id, name, public) values ('content', 'content', true)
on conflict (id) do nothing;

create policy content_read on storage.objects for select to anon, authenticated using (bucket_id = 'content');
create policy content_admin_write on storage.objects for insert to authenticated
  with check (bucket_id = 'content' and public.has_admin_permission('content.edit'));
create policy content_admin_update on storage.objects for update to authenticated
  using (bucket_id = 'content' and public.has_admin_permission('content.edit'));
create policy content_admin_delete on storage.objects for delete to authenticated
  using (bucket_id = 'content' and public.has_admin_permission('content.edit'));
