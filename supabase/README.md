# Munyati backend (Supabase)

Postgres schema, security rules and edge functions for the Munyati app. Region: **Frankfurt
(`eu-central-1`)** unless a latency test from Dammam shows Mumbai is clearly faster
(`docs/research/backend-stack-and-cost.md` §4).

## What's here

| Path | What |
|---|---|
| `migrations/20261010000000_core.sql` | Phase 1 schema: profiles + roles, provider join requests, cities, categories, remote config / strings / CMS pages, device tokens, notifications, analytics + error logs, phone OTP, SMS log, admin roles/permissions + audit log, RLS, RPCs, `content` storage bucket |
| `migrations/20261011000000_catalog.sql` | Phase 2: stores, services, favorites, budgets, search/detail/map RPCs, provider studio RPCs, public `media` bucket |
| `migrations/20261012000000_booking.sql` | Phase 3: availability, bookings state machine, proposals, payment methods (IBAN check), receipts (private `receipts` bucket, duplicate detection), disputes, demo booking, timers and reminders, push/SMS notifications |
| `migrations/20261013000000_subscriptions.sql` | Phase 4: plans (Normal / Plus / Diamond, dashboard-editable), entitlements by source (Tap now, App Store later), Tap payments ledger, 2-month trial on approval (one per phone), plan limits and listing visibility, upgrade credit, featured badge and search boost, trial/renewal reminders, provider insights |
| `migrations/20261014000000_trust.sql` | Phase 5: two-way reviews (server-side name masking, pre-moderation, banned words, ratings on cards), reports, blocks (hide each other everywhere and prevent bookings), support tickets, admin moderation RPCs |
| `migrations/20261015000000_admin.sql` | Phase 6: admin RPCs for the dashboard (provider review, service takedown, disputes, stats, analytics, push campaigns, team) |
| `migrations/20261010000100_reference_data.sql` | Admin roles, launch cities (Dammam, Khobar, Qatif), 25 categories (14 active), default app config, placeholder CMS pages |
| `functions/send-otp` | Sends the login code by OurSMS. Saudi mobiles only; limits enforced atomically in SQL |
| `functions/verify-otp` | Checks the code, creates the account (with role) or signs in, returns a session |
| `functions/send-push` | Database webhook on `notifications` insert → FCM push with a deep link |
| `functions/delete-account` | In-app account deletion |
| `functions/send-sms` | Database webhook on `sms_outbox` insert → transactional SMS (booking events) |
| `functions/tap-checkout` | Starts a plan payment (Tap hosted page, amount from the plan) and reports a payment's status, settling it with Tap if still open |
| `functions/tap-webhook` | Tap's server notification (POST) and browser return page (GET → `munyati://pay-return`). Always re-fetches the charge from Tap |
| `functions/_shared` | HTTP, phone, OTP, OurSMS and Tap helpers |

## First-time setup (once)

1. **Create the project** at supabase.com (Pro plan, Frankfurt). Copy the project URL and the
   **anon** key into `App/Resources/BackendConfig.plist`. Never put the service-role key in the app.
2. **Authentication settings:** enable *Allow anonymous sign-ins* (guest browsing).
3. **Extensions:** enable `pg_cron` (analytics partitions, booking timeouts and reminders every 15 minutes, subscription reminders daily) and `btree_gist` (no double booking).
4. **Push the schema** from this folder:
   ```sh
   supabase link --project-ref <project-ref>
   supabase db push
   ```
5. **Secrets** for the edge functions (`supabase secrets set NAME=value`):

   | Secret | Used by | Notes |
   |---|---|---|
   | `OTP_HASH_SECRET` | send-otp, verify-otp | Long random string |
   | `PASSWORD_SECRET` | verify-otp | Long random string, never change after launch |
   | `OURSMS_API_KEY` | send-otp | From the OurSMS dashboard |
   | `OURSMS_SENDER` | send-otp | Approved transactional sender, e.g. `Munyati` |
   | `OURSMS_SENDER_AD` | marketing (later) | Approved promotional sender, e.g. `Munyati-AD` |
   | `FIREBASE_PROJECT_ID` | send-push | Firebase project id |
   | `FIREBASE_SERVICE_ACCOUNT_JSON` | send-push | Service account with *Firebase Cloud Messaging API Admin* |
   | `PUSH_WEBHOOK_SECRET` | send-push | Random string, also set on the webhook header |
   | `SMS_WEBHOOK_SECRET` | send-sms | Random string, also set on the sms_outbox webhook header |
   | `TAP_SECRET_KEY` | tap-checkout, tap-webhook | `sk_test_…` while testing, then `sk_live_…`. Never in the app |
   | `TAP_API_BASE` | tap-checkout, tap-webhook | Optional, defaults to `https://api.tap.company` |
   | `DEV_PHONES`, `DEV_OTP_CODE` | send-otp, verify-otp | Optional test numbers (e.g. App Review accounts) with a fixed 6-digit code. Leave unset in production unless needed |

6. **Deploy the functions:**
   ```sh
   supabase functions deploy send-otp verify-otp send-push send-sms delete-account tap-checkout tap-webhook
   ```
7. **Push webhook:** Database → Webhooks → *Insert* on `public.notifications` → HTTP POST to the
   `send-push` function URL with header `x-webhook-secret: <PUSH_WEBHOOK_SECRET>`.
8. **SMS webhook:** Database → Webhooks → *Insert* on `public.sms_outbox` → `send-sms` URL with header
   `x-webhook-secret: <SMS_WEBHOOK_SECRET>`. Which booking events also go by SMS is set in
   `app_config.sms_events`.
9. **Tap:** nothing to configure in the Tap dashboard: each charge carries its own webhook and
   return URL (`functions/v1/tap-webhook`, deployed without JWT check, see `config.toml`). Set
   plan prices in `subscription_plans` (the seeded 99 / 249 / 499 SAR are placeholders) and test
   with Tap's test cards before switching to the live key.
10. **First admin:** after you sign in once in the app (or create a user), run in the SQL editor:
   ```sql
   insert into admin_users (user_id, role_id) values ('<your auth user id>', 'owner');
   ```

## Rules for changes

- New tables: enable RLS in the same migration; clients write only through RPCs.
- RPCs that "return nothing" return `jsonb` (`{"ok": true}`) so the app always gets a body.
- Admin-managed tables get the `audit_admin_change` trigger.
- Keep `analytics_event_type` in step with `AnalyticsEvent` in
  `Packages/Shared/Sources/Shared/Analytics/AnalyticsRecorder.swift`.
- Reference data migrations must be idempotent (`on conflict do nothing`).

## Testing migrations locally without Docker

Any Postgres 15/16 works with a small stub of Supabase's `auth`/`storage` schemas and roles
(this is how Phase 1 was verified):

```sql
create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
create schema auth; create schema storage;
create table auth.users (id uuid primary key, email text);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
create table storage.buckets (id text primary key, name text, public boolean);
create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text);
alter table storage.objects enable row level security;
grant usage on schema public, auth, storage to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
```
Then apply the migrations in order and impersonate users with
`set role authenticated; select set_config('request.jwt.claim.sub', '<uuid>', false);`.
