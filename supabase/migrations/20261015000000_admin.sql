-- =============================================================================================
-- Munyati — Phase 6: admin actions for the dashboard (docs/PLAN.md §8).
--
-- Most admin reads use the existing RLS policies (`is_admin()` / `has_admin_permission()`), so
-- the dashboard reads tables directly with the admin's own session. Writes that must notify
-- someone, change a booking's state or leave an audit trail go through these RPCs.
-- Admins sign in to the dashboard with email + password (Supabase Auth) and must be listed in
-- `admin_users`. The service-role key is never used by the dashboard.
-- =============================================================================================

-- Small helper: record an admin action in the audit log.
create function public.admin_audit(p_action text, p_entity text, p_id text, p_after jsonb) returns void
language sql security definer set search_path = public as $$
  insert into admin_audit_log (admin_id, action, entity_type, entity_id, after)
  values (auth.uid(), p_action, p_entity, p_id, p_after);
$$;

-- ---------------------------------------------------------------------------------------------
-- Providers and services
-- ---------------------------------------------------------------------------------------------

-- Approve, reject or suspend a provider, optionally set the verified badge (decision #6).
-- Approval starts the free trial (trigger from the subscriptions migration).
create function public.admin_review_provider(p_provider uuid, p_status text, p_note text default null,
                                             p_verified boolean default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v providers%rowtype;
begin
  perform require_admin_permission('providers.review');
  if p_status not in ('pending', 'approved', 'rejected', 'suspended') then
    raise exception 'invalid status' using errcode = '22023';
  end if;
  update providers set status = p_status::provider_status, review_note = p_note,
    is_verified = coalesce(p_verified, is_verified), reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_provider returning * into v;
  if not found then raise exception 'not found' using errcode = 'P0002'; end if;
  perform admin_audit('review', 'providers', p_provider::text,
    jsonb_build_object('status', p_status, 'note', p_note, 'verified', v.is_verified));
  if p_status = 'approved' then
    perform notify_user(p_provider, 'provider_approved', 'تم تفعيل حسابك 🎉', 'Your account is approved',
      'خدماتك ظاهرة الآن للعرائس، وبدأت فترتك المجانية.', 'Your services are now visible to brides and your free trial has started.',
      'https://munyati.co/plans', true);
  elsif p_status = 'rejected' then
    perform notify_user(p_provider, 'provider_rejected', 'لم تتم الموافقة على طلبك', 'Your request was not approved',
      coalesce(p_note, 'راجعي بيانات نشاطك وأعيدي الإرسال.'), coalesce(p_note, 'Please review your business details and try again.'),
      null, true);
  elsif p_status = 'suspended' then
    perform notify_user(p_provider, 'provider_suspended', 'تم إيقاف حسابك مؤقتاً', 'Your account is suspended',
      coalesce(p_note, 'تواصلي مع الدعم لمزيد من التفاصيل.'), coalesce(p_note, 'Contact support for details.'), null, true);
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- Take a service down (or bring it back) after a report.
create function public.admin_set_service_status(p_service uuid, p_status text, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v services%rowtype;
begin
  perform require_admin_permission('reports.handle');
  update services set status = p_status::service_status where id = p_service returning * into v;
  if not found then raise exception 'not found' using errcode = 'P0002'; end if;
  perform admin_audit('set_status', 'services', p_service::text, jsonb_build_object('status', p_status, 'note', p_note));
  if p_status = 'paused' then
    perform notify_user(v.provider_id, 'service_paused', 'تم إيقاف خدمة', 'A service was paused',
      v.title || coalesce(' · ' || p_note, ''), v.title || coalesce(' · ' || p_note, ''), null);
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Disputes
-- ---------------------------------------------------------------------------------------------

-- Outcomes: reject (no fault found, booking returns to where it was), restore (same, but the
-- dispute is upheld), completed, cancelled_by_bride, cancelled_by_provider.
create function public.admin_resolve_dispute(p_dispute uuid, p_outcome text, p_note text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  d disputes%rowtype;
  v bookings%rowtype;
  v_to booking_status;
begin
  perform require_admin_permission('payments.resolve');
  if coalesce(trim(p_note), '') = '' then raise exception 'note required' using errcode = '22023'; end if;
  select * into d from disputes where id = p_dispute and status = 'open' for update;
  if not found then raise exception 'not found or already closed' using errcode = 'P0002'; end if;
  v_to := case p_outcome
    when 'reject' then d.previous_status
    when 'restore' then d.previous_status
    when 'completed' then 'completed'::booking_status
    when 'cancelled_by_bride' then 'cancelled_by_bride'::booking_status
    when 'cancelled_by_provider' then 'cancelled_by_provider'::booking_status
  end;
  if v_to is null then raise exception 'invalid outcome' using errcode = '22023'; end if;

  v := booking_transition(d.booking_id, v_to, 'admin', p_note);
  update disputes set status = case when p_outcome = 'reject' then 'rejected' else 'resolved' end,
    resolution = p_outcome || ': ' || p_note, resolved_by = auth.uid(), resolved_at = now()
  where id = p_dispute;
  perform admin_audit('resolve', 'disputes', p_dispute::text, jsonb_build_object('outcome', p_outcome, 'note', p_note));
  perform notify_user(v.bride_id, 'dispute_resolved', 'تم إغلاق البلاغ', 'Your report was resolved', p_note, p_note, booking_link(v.id), true);
  perform notify_user(v.provider_id, 'dispute_resolved', 'تم إغلاق البلاغ', 'The report was resolved', p_note, p_note, booking_link(v.id), true);
  return jsonb_build_object('ok', true, 'status', v_to);
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Overview, analytics and campaigns
-- ---------------------------------------------------------------------------------------------

-- Numbers for the dashboard home (demo bookings excluded everywhere).
create function public.admin_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admins only' using errcode = '42501'; end if;
  return jsonb_build_object(
    'brides', (select count(*) from profiles where role = 'bride' and deleted_at is null),
    'providers', (select jsonb_object_agg(status, n) from (select status, count(*) n from providers group by status) t),
    'providers_listed', (select count(*) from providers p where provider_is_listed(p.id)),
    'services_active', (select count(*) from services s where service_is_public(s)),
    'bookings_30d', (select coalesce(jsonb_object_agg(status, n), '{}') from (select status, count(*) n from bookings
                       where not is_demo and created_at > now() - interval '30 days' group by status) t),
    'bookings_value_30d', (select coalesce(sum(price), 0) from bookings where not is_demo
                             and created_at > now() - interval '30 days' and status in ('payment_confirmed', 'completed')),
    'subscriptions_active', (select coalesce(jsonb_object_agg(plan_id, n), '{}') from (
                               select plan_id, count(distinct provider_id) n from provider_subscriptions
                               where status = 'active' and starts_at <= now() and ends_at > now() group by plan_id) t),
    'on_trial', (select count(*) from providers where status = 'approved' and trial_ends_at > now()),
    'revenue_30d', (select coalesce(sum(amount), 0) from subscription_payments where status = 'captured'
                      and captured_at > now() - interval '30 days'),
    'queues', jsonb_build_object(
      'providers_pending', (select count(*) from providers where status = 'pending'),
      'disputes_open', (select count(*) from disputes where status = 'open'),
      'reviews_pending', (select count(*) from reviews where status = 'pending'),
      'reports_open', (select count(*) from reports where status = 'open'),
      'tickets_open', (select count(*) from support_tickets where status = 'open'),
      'payments_review', (select count(*) from subscription_payments where status = 'review'),
      'receipts_duplicate', (select count(*) from payment_receipts where is_duplicate and status = 'pending')));
end;
$$;

-- Daily event counts, the booking funnel, top searches and top errors over `p_days`.
create function public.admin_analytics(p_days int default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_since timestamptz := now() - make_interval(days => least(greatest(coalesce(p_days, 30), 1), 365));
begin
  perform require_admin_permission('analytics.read');
  return jsonb_build_object(
    'daily', coalesce((select jsonb_agg(jsonb_build_object('day', day, 'event', event_type, 'n', n) order by day)
      from (select (created_at at time zone 'Asia/Riyadh')::date as day, event_type, count(*) n from analytics_events
            where created_at >= v_since group by 1, 2) t), '[]'),
    'signups', coalesce((select jsonb_agg(jsonb_build_object('day', day, 'role', role, 'n', n) order by day)
      from (select (created_at at time zone 'Asia/Riyadh')::date as day, role, count(*) n from profiles
            where created_at >= v_since group by 1, 2) t), '[]'),
    'funnel', jsonb_build_object(
      'service_views', (select count(*) from analytics_events where event_type = 'service_view' and created_at >= v_since),
      'booking_started', (select count(*) from analytics_events where event_type = 'booking_started' and created_at >= v_since),
      'requested', (select count(*) from bookings where not is_demo and created_at >= v_since),
      'approved', (select count(*) from bookings where not is_demo and created_at >= v_since
                     and status in ('awaiting_payment', 'payment_submitted', 'payment_confirmed', 'completed', 'disputed')),
      'paid', (select count(*) from bookings where not is_demo and created_at >= v_since
                 and status in ('payment_confirmed', 'completed')),
      'completed', (select count(*) from bookings where not is_demo and created_at >= v_since and status = 'completed')),
    'top_searches', coalesce((select jsonb_agg(jsonb_build_object('query', q, 'n', n) order by n desc)
      from (select lower(trim(props ->> 'query')) q, count(*) n from analytics_events
            where event_type = 'search' and created_at >= v_since and coalesce(trim(props ->> 'query'), '') <> ''
            group by 1 order by 2 desc limit 20) t), '[]'),
    'top_errors', coalesce((select jsonb_agg(jsonb_build_object('code', code, 'n', n, 'last', last) order by n desc)
      from (select code, count(*) n, max(created_at) last from error_logs where created_at >= v_since
            group by 1 order by 2 desc limit 20) t), '[]'),
    'by_city', coalesce((select jsonb_agg(jsonb_build_object('city_id', city_id, 'n', n) order by n desc)
      from (select pc.city_id, count(*) n from profile_cities pc join profiles p on p.id = pc.profile_id
            where p.role = 'bride' and p.deleted_at is null group by 1) t), '[]'));
end;
$$;

-- Push campaign: one notification row per recipient (each one is pushed by the send-push webhook).
-- Audience: 'all' | 'brides' | 'providers'; cities optional (brides' chosen cities / providers'
-- served cities). Returns how many users it reached.
create function public.admin_send_campaign(p_audience text, p_city_ids text[], p_title text, p_body text,
                                           p_deep_link text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_count int;
begin
  perform require_admin_permission('push.send');
  if coalesce(trim(p_title), '') = '' or coalesce(trim(p_body), '') = '' then
    raise exception 'title and body required' using errcode = '22023';
  end if;
  insert into notifications (user_id, kind, title, body, deep_link)
  select p.id, 'campaign', trim(p_title), trim(p_body), nullif(trim(p_deep_link), '')
  from profiles p
  where p.deleted_at is null and not p.is_banned
    and (p_audience = 'all' or (p_audience = 'brides' and p.role = 'bride') or (p_audience = 'providers' and p.role = 'provider'))
    and (coalesce(cardinality(p_city_ids), 0) = 0
         or exists (select 1 from profile_cities pc where pc.profile_id = p.id and pc.city_id = any (p_city_ids))
         or exists (select 1 from provider_cities pc where pc.provider_id = p.id and pc.city_id = any (p_city_ids)));
  get diagnostics v_count = row_count;
  perform admin_audit('send', 'campaigns', null, jsonb_build_object('audience', p_audience, 'cities', p_city_ids,
    'title', p_title, 'body', p_body, 'deep_link', p_deep_link, 'recipients', v_count));
  return jsonb_build_object('ok', true, 'recipients', v_count);
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- Team (permission team.manage; owners have it)
-- ---------------------------------------------------------------------------------------------

-- The admin must first exist in Supabase Auth (invited by email from the Supabase dashboard).
create function public.admin_add_admin(p_email text, p_role text) returns jsonb
language plpgsql security definer set search_path = public, auth as $$
declare
  v_user uuid;
begin
  perform require_admin_permission('team.manage');
  select id into v_user from auth.users where lower(email) = lower(trim(p_email));
  if v_user is null then return jsonb_build_object('ok', false, 'error', 'no_auth_user'); end if;
  insert into admin_users (user_id, role_id, created_by) values (v_user, p_role, auth.uid())
  on conflict (user_id) do update set role_id = excluded.role_id, is_active = true;
  perform admin_audit('add', 'admin_users', v_user::text, jsonb_build_object('email', p_email, 'role', p_role));
  return jsonb_build_object('ok', true);
end;
$$;

-- Admins with their emails (auth.users isn't readable by clients).
create function public.admin_list_admins() returns jsonb
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not is_admin() then raise exception 'admins only' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('user_id', a.user_id, 'email', u.email, 'role_id', a.role_id,
                                                      'is_active', a.is_active, 'created_at', a.created_at) order by a.created_at)
                   from admin_users a join auth.users u on u.id = a.user_id), '[]');
end;
$$;

create function public.admin_set_admin_active(p_user uuid, p_active boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform require_admin_permission('team.manage');
  if p_user = auth.uid() then return jsonb_build_object('ok', false, 'error', 'cannot_change_self'); end if;
  update admin_users set is_active = p_active where user_id = p_user;
  perform admin_audit(case when p_active then 'activate' else 'deactivate' end, 'admin_users', p_user::text, null);
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
  execute 'revoke all on function public.admin_audit(text, text, text, jsonb) from public, anon, authenticated';
  foreach f in array array[
    'public.admin_review_provider(uuid, text, text, boolean)', 'public.admin_set_service_status(uuid, text, text)',
    'public.admin_resolve_dispute(uuid, text, text)', 'public.admin_stats()', 'public.admin_analytics(int)',
    'public.admin_send_campaign(text, text[], text, text, text)',
    'public.admin_add_admin(text, text)', 'public.admin_list_admins()', 'public.admin_set_admin_active(uuid, boolean)']
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
