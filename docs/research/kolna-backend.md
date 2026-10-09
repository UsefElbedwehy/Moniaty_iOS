# Kolna / Maalim Al-Khafji Supabase backend: what Munyati can reuse

Source analysed: `kolna-al-khafji-ios/supabase/` (78 migrations, 4 Edge Functions, 3 seed files), plus the iOS client code that consumes it where this was needed to explain behaviour (name masking, icon keys, remote config). Nothing was run against the live project (`tdwbchuupsqkdbmfwzec`). Everything below comes from reading the SQL/TS in the repo.

> **Caveat on live state.** Six early migrations have a `PROPOSED MIGRATION — NOT YET APPLIED` header: `20260716090000_admin_config_cms`, `20260719100000_search_insights`, `20260722100000_recategorize`, `20260722110000_trending_and_tags`, `20260722120000_banner_place_link` and `20260723100000_post_flag_and_admin_create`. Later migrations treat these objects as live. For example, `20260726110000_fix_missing_admin_write_grants.sql` fixes dashboard writes to `app_config`, `20260909120000_fix_favorite_save_count.sql` mentions "134 real favorites", and `20260760100000` seeds logos with live storage URLs. So they were almost certainly applied, but I could not confirm this against the database. The Database Webhook that drives push is configured in the Supabase dashboard and does not appear in any migration (see section 9).

---

## 0. Summary

- **Architecture style.** The backend is RPC-first. The iOS app never sends PostgREST `select` strings. SQL functions build the exact nested JSON the DTOs expect: snake_case keys, `public.iso8601()` timestamps and keyset pagination. RLS is the security boundary. Admin powers are `SECURITY DEFINER` RPCs with an explicit `is_admin()` gate. This carries over well to Munyati.
- **Reusable with little or no change:** phone OTP via OurSMS (`send-otp`/`verify-otp`); FCM push via a DB-webhook Edge Function (`send-push`); device tokens; the notification inbox, audiences, per-kind settings gate and campaigns; delete-account; CMS pages (bilingual); the `app_config` singleton (feature flags, force update, contact methods); home sections and banners; review moderation (pending/approved/declined, soft delete, bans, reactions); guest (anonymous) handling; the analytics event plumbing; the admin overview-stats RPC pattern.
- **Needs rework:** the categories model (icons are *bundled asset keys*, so a new icon needs an app release); cities (free text plus an unused `app_config.cities text[]`, with no table and no multi-select filter); reviews (one direction only, user to place, not tied to a completed booking); analytics (a fixed Postgres enum of 6 events with no properties, no error logs and no sessions); the admin model (only a binary `user`/`admin` role).
- **Name masking ("private mode").** Kolna now masks reviewer names **on the client only**. The API returns the full `display_name` to anyone, including guests using the anon key. Munyati should mask **server-side**. The exact algorithm and history are in section 8.5.
- **Missing entirely** (all core to Munyati): bookings and their state machine, reschedule proposals, availability/slots, subscription plans and entitlements, Tap subscription billing (it exists in Lamha, not here), payout methods, payment proofs, disputes, budgets, a cities table, stores (multiple per provider), reports/flags, the demo booking, SMS marketing campaigns, an admin audit log and client error logs.

---

## 1. Inventory

| Area | Files |
|---|---|
| Core schema, RLS, storage, RPC | `kolna-al-khafji-ios/supabase/migrations/20260713120000_init_schema.sql`, `…120100_rls.sql`, `…120200_storage.sql`, `…120300_rpc.sql` |
| Feature migrations | 74 more files, `20260714…` → `20260912110000_reviews_pagination.sql` |
| Edge Functions | `supabase/functions/send-otp/index.ts`, `verify-otp/index.ts`, `send-push/index.ts` (+ `README.md`), `delete-account/index.ts` |
| Seeds | `supabase/seed.sql` (dev: categories + form schemas + demo auth user), `seed_reference_data.sql` (production-safe catalogue only), `seed_demo.sql` (demo business/places/reviews, demo user made admin) |
| Config | `supabase/config.toml` (Postgres 15, seed `./seed.sql`) |
| Scheduled jobs | `pg_cron` job `cleanup-anonymous-guests`, daily at 03:30 UTC (`20260742100000_cleanup_anonymous_users.sql`) |

The Kolna admin dashboard source is **not** in this workspace. Migrations reference `CategoryIconPicker.tsx`, `AppearanceEditor.tsx`, `CreatePlaceForm.tsx` and `ApprovalDetail.tsx`, but I could not read them. `lamha_dahsboard` is a separate project (Lamha).

---

## 2. Schema overview

### 2.1 Tables and relationships (final state)

```
auth.users 1─1 profiles (id, phone, display_name, first_name, last_name, avatar_url, city,
                         role user_role{user,admin}, is_banned, created_at)
   │  trigger on_auth_user_created → handle_new_user() inserts profile
   │
profiles 1─1 businesses (owner_id UNIQUE; name, bio, logo_url, is_verified, since_year,
   │                     response_time, phone, whatsapp)
   │
profiles 1─* places (owner_id; business_id → businesses ON DELETE SET NULL;
   │                category_id → categories (RESTRICT); title, status place_status
   │                {pending,live,rejected,archived,deleted}, rejection_reason, restore_status,
   │                archived_at, deleted_at, price, price_unit, currency 'SAR', city (free text),
   │                district, latitude, longitude, availability{today,tomorrow,weekend},
   │                check_in_time, is_promoted, promoted_until, is_featured, is_trending,
   │                view_count, save_count, submitted_at, updated_at)
   │      ├─* place_images (url, is_cover, sort_order)
   │      ├─* place_videos (url, sort_order)
   │      ├─* place_field_values (field_id, label, type, string/number/bool/option/options/range)
   │      ├─* place_contact_methods (kind contact_kind{phone,whatsapp,email}, value)
   │      ├─* place_categories (extra categories; PK place_id+category_id)
   │      ├─* place_hours (day_of_week 0-6, opens/closes "HH:mm" text, sort_order) — admin-only writes
   │      ├─* place_delivery_platforms (platform_id → delivery_platforms, url) — admin-only writes
   │      ├─* reviews (user_id, rating 1-5, comment, status{pending,approved,declined},
   │      │            deleted_at, deleted_by{user,admin}; partial UNIQUE(place_id,user_id) where not deleted)
   │      │      └─* review_reactions (user_id, reaction{like,dislike}; PK review_id+user_id)
   │      ├─* favorites (user_id; PK user_id+place_id)
   │      └─* promotion_requests (user_id, requested_days, status{pending,approved,rejected})
   │
profiles 1─* notifications (user_id NULLABLE, audience{user,admin}, kind (CHECK list), title,
   │                        subtitle, body, image_url, place_id, business_id, review_id,
   │                        is_read, opened_at)
profiles 1─* device_tokens (token PK, platform{ios,android})
profiles 1─* payments (admin-recorded ledger; place_id, user_id, amount, currency, method, note,
                       paid_at, recorded_by)

categories (id text slug PK, name [Arabic], name_en, icon_system_name [frozen SF Symbol],
            icon_key [bundled Hugeicons key], sort_order, is_enabled)
   └─* category_form_fields (PK category_id+id; label, kind form_field_kind, placeholder, unit,
                             options text[], options_en text[], is_required, is_filter, sort_order)

delivery_platforms (id slug, name, logo_url [storage URL], sort_order)
app_config (singleton id=1) ─ app_config_contact_methods
home_sections ─* home_banner_slides (image_url, title, subtitle, link_url, place_id, status{draft,live})
cms_pages (slug PK, title, body_markdown, title_ar, body_markdown_ar, status{draft,published})
notification_settings (kind PK, enabled)   notification_campaigns (segment, recipient_count, created_by…)
search_log (term, category_id, city, availability, user_id)
analytics_events (event_type analytics_event_type, entity_id, context_id, user_id)
phone_otp (phone, code [HMAC], attempts, used, expires_at)  — RLS on, zero policies (service role only)
```

### 2.2 Conventions worth keeping

- **Text slug PKs for reference data** (`categories.id = 'coffee-tea'`; categories created from the dashboard get ids like `cat_b2kr74t8`) and **uuid PKs for user content**.
- **`ON DELETE CASCADE` from `profiles`** for everything a user owns, and `SET NULL` for admin and analytics references (`payments`, `search_log`, `analytics_events`, `notification_campaigns.created_by`). This is what makes `delete_my_account()` a one-liner (section 11).
- **Status columns and transition triggers**: `notify_place_status` fires `when (old.status is distinct from new.status …)`. This is the same pattern Munyati needs for bookings.
- **Soft delete with restore**: `places.restore_status` and `admin_set_place_state(p_place_id, 'archive'|'delete'|'restore')` (`20260909140100_place_archive_and_soft_delete.sql`) put an ad back in its *previous* status, never straight to live.

### 2.3 API layer (RPC assemblers)

- `place_to_json(p places)` builds one nested place (images, videos, field values, contacts, hours, delivery platforms, business summary, `avg_rating` and `review_count` from **approved, non-deleted** reviews only).
- `get_places(p_status, p_cursor, p_limit, p_search, p_category, p_city, p_availability, p_tag, p_trending_only, p_field_id, p_field_bool, p_featured)` uses keyset pagination on `(updated_at, id)` with an opaque cursor `"<iso>|<uuid>"`, ordered by `is_promoted desc, updated_at desc`. The response is `{items, next_cursor, has_more}`.
- `get_home_places()` returns `{featured, recent}`, with counts from `app_config.home_featured_count/home_recent_count`.
- **Pitfalls not to copy.** `get_places` was dropped and recreated **6 times** because each new filter param creates a new overload that PostgREST rejects as ambiguous. `place_to_json` was redefined in full **~12 times**, and one redefinition silently dropped the hidden-review filter (documented in `20260753100000`). For Munyati, take a single `p_filters jsonb` argument, and compose JSON from smaller functions or views so a change does not mean restating the whole body.

---

## 3. RLS policy style and the admin role model

### 3.1 How admins are identified

```sql
-- 20260713120000_init_schema.sql
create type public.user_role as enum ('user', 'admin');
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;
```

- There is a single role column on `profiles`. Admins sign into the same app, and the dashboard uses the same Supabase Auth.
- `am_i_admin()` (`20260743100000`) lets the app show an admin badge.
- `admin_set_user_role(p_user_id, p_role)` (`20260740100000`) only accepts `'user'|'admin'` and refuses to change the caller's own role.
- `admin_set_user_banned(p_user_id, p_banned)` (`20260753100000`) refuses self-ban.
- Bootstrap is manual SQL: `update public.profiles set role = 'admin' where id = '…'` (supabase/README.md).

### 3.2 The RLS idioms used everywhere

| Idiom | Example |
|---|---|
| Public read, admin write | `categories_read … for select using (true)` + `categories_admin_write … for all to authenticated using (public.is_admin()) with check (public.is_admin())` |
| Visibility by status plus owner plus admin (permissive policies OR together) | `places_select_live using (status='live')`, `places_select_own using (owner_id = auth.uid() and status <> 'deleted')`, `places_select_admin using (is_admin())` |
| Owner may edit only in a specific state | `places_update_own_rejected using (owner_id = auth.uid() and status='rejected') with check (… status in ('pending','rejected'))` |
| Child tables inherit the parent's visibility | `place_images_read using (exists (select 1 from places p where p.id = place_id and (p.status='live' or p.owner_id=auth.uid() or is_admin())))` |
| Insert-only telemetry | `search_log`, `analytics_events`: `grant insert … to anon, authenticated` + `with check (true)`, no SELECT policy; read only through admin RPCs |
| Server-only tables | `phone_otp`: RLS enabled, **zero policies**; only the service role (Edge Functions) touches it |
| Column-level grants for self-service | `revoke update on public.profiles from authenticated; grant update (display_name, city, avatar_url) on public.profiles to authenticated;` (`20260753100000`). Before this, a user could PATCH their own `role` to `admin`. |
| Admin RPC template | `language plpgsql security definer set search_path = ''` + `if not public.is_admin() then raise exception 'admin only' using errcode = '42501'; end if;` |
| Service-role-only RPC | `admin_device_tokens()`: `revoke execute … from public, anon, authenticated; grant execute … to service_role;` |

Lessons recorded in the migrations themselves, worth applying from day 1 in Munyati:
- **A grant is checked before RLS.** `20260726110000_fix_missing_admin_write_grants.sql` exists because admin-write policies were in place but the table-level `grant insert, update, delete` was missing, so every dashboard write failed.
- **A `security invoker` counter update silently no-ops under RLS.** `record_place_view` (fixed in `20260746100000`) and `toggle_favorite` (fixed in `20260909120000`) both updated `places` as a non-owner, matched 0 rows, and still returned success. Make counter RPCs `security definer` and keep them narrow.
- **pgcrypto lives in the `extensions` schema on Supabase**, so `set search_path = public, extensions` is needed for `crypt()`/`gen_salt()` (`20260724150000`).

### 3.3 Admin RPC catalogue (all `is_admin()`-gated unless noted)

`admin_create_profile`, `admin_create_place`, `admin_upsert_business`, `admin_set_place_business`, `admin_set_place_state`, `get_admin_overview_stats`, `admin_list_users`, `admin_set_user_role`, `admin_set_user_banned`, `admin_set_review_status`, `admin_delete_review`, `admin_send_campaign`, `admin_delete_campaign`, `admin_mark_notification_read`, `admin_mark_all_notifications_read`, `admin_delete_notification`, `get_search_insights`, `get_top_places_insights`, `get_active_users_stats`, `get_engagement_insights`.

**Security gap. Do not copy:** `admin_get_place_reviews(uuid)` and `admin_get_business_reviews(uuid)` (last defined in `20260767100000_soft_delete_reviews.sql`) are `security definer`, granted to `authenticated`, and have **no `is_admin()` check**. Supabase anonymous guests also have the `authenticated` role, so any guest can call them and receive full reviewer names plus declined and deleted reviews.

### 3.4 What the model lacks for Munyati

- No separation between the **app persona** (customer vs provider, chosen at signup) and **staff permissions**. Munyati needs something like `profiles.account_type ('customer','provider')` plus a staff role set (`super_admin`, `ops`, `finance/disputes`, `support`, `marketing`).
- **No admin audit trail.** The only "who did it" fields are `payments.recorded_by`, `notification_campaigns.created_by` and `reviews.deleted_by` (a text value `'user'|'admin'`, not an admin id).
- `admin_create_profile` inserts **directly into `auth.users`** with `crypt()`. This depends on GoTrue's internal schema. Munyati should create users through an Edge Function with `auth.admin.createUser`.

---

## 4. Remote-updatable content: what already changes without an app release

| Content | Table / RPC | Consumed by the iOS app? | Notes |
|---|---|---|---|
| Feature flags | `app_config.feature_flags jsonb` via `get_config()` | **Yes**: `App/Sources/Composition/RemoteConfigStore.swift` reads `postAdEnabled` (fail-open), `nationalDayThemeEnabled` (fail-closed), `requireSignInForAds` (fail-closed) | `requireSignInForAds` is not seeded by any migration; presumably it was set from the dashboard. Defaults seeded: `guestBrowsing`, `mapExplore`, `featuredPlacement` (`20260716090000`), `postAdEnabled` (`20260723100000`), `nationalDayThemeEnabled` (`20260905060000`). |
| Force update | `app_config.min_required_version, update_message, force_update, store_url` → `get_config().update` (`20260763100000_force_update.sql`) | **Yes**: `RemoteConfigStore.forceUpdateRequired` (numeric version compare, fail-closed) | Header says it is "same shape as … Lamha Ads". |
| Seasonal theme | flag `nationalDayThemeEnabled` | Yes | The skin assets are bundled in the build; only the on/off switch is remote. |
| Branding | `app_config.app_name, logo_url, primary_color_hex, accent_color_hex` | Decoded into `Core/Configuration/RemoteConfig.swift`, but I found **no consumer** that applies the colours | Treat as not implemented. |
| Cities / regions / currencies / languages | `app_config.cities text[]` (default `{Khafji}`), `regions`, `supported_currencies`, `supported_languages` | Decoded; I found no consumer of `cities` | `places.city` is free text and filtered by exact match (`p.city = p_city`). |
| Support contacts | `app_config_contact_methods (kind phone/whatsapp/email, value, sort_order)` | Yes (via `get_config().support.contact_methods`) | |
| CMS pages (Help/About/Terms/Privacy) | `cms_pages` + `get_cms_page(p_slug, p_locale default 'en')` | Yes (`APIEndpoint.cms.getPage`) | Bilingual: `title`/`body_markdown` (EN) + `title_ar`/`body_markdown_ar`; falls back to EN when AR is empty (`20260730100000_cms_pages_bilingual.sql`). Seeded slugs: `privacy-policy`, `terms-of-service`, `help`, `about`. Only `published` rows are publicly readable. |
| Home layout + hero banners | `home_sections (id, title, kind, is_enabled, sort_order)`, `home_banner_slides (image_url, title, subtitle, link_url, place_id, status draft/live)` → `get_home_sections()` | Yes (`RemoteHomeSectionsRepository`, `HomeViewModel.fetchHeroSlides`) | **Banner images are remote URLs**, so they are already fully remote. `place_id` lets a slide deep-link in-app (`20260722120000`). |
| Home rail sizes | `app_config.home_featured_count/home_recent_count` (1-12) → `get_home_places()` | Yes | |
| Categories (names, order, enable) | `categories` → `get_categories()` | Yes | Icons are **not** fully remote (section 5). |
| Dynamic listing fields and filters | `category_form_fields` (+ `options_en`, `is_filter`) → `get_category_form_schema()` | Yes | The app maps unknown `kind` to `.text`, so new kinds are safe for old builds (`20260909130000`). |
| Third-party logos | `delivery_platforms.logo_url` (storage URL in `place-images/admin/delivery-platforms/*`) | Yes | **This is the precedent for remote images.** |
| Notification types on/off | `notification_settings` | Server-side gate | Section 9. |
| **UI strings** | — | **No**: per `Docs/ADR/0002-localization-bundle-pattern.md`, all copy lives in each package's bundled `Localizable.strings` | Not remotely updatable. |

**Munyati requirement 19 (strings, PNGs and category logos without a build):** the `app_config`, `cms_pages`, `home_banner_slides` and `delivery_platforms.logo_url` patterns are reusable as-is. Still missing:
1. `categories.icon_url` pointing to a public storage bucket, with `icon_key` as the bundled fallback.
2. A `remote_strings (key, ar, en, updated_at)` table (or a JSON blob in storage) plus a `content_version` in `get_config()` so the client knows when to invalidate its cache. Bundled strings stay as the fallback.

---

## 5. Categories model

- **Table:** `categories (id text PK, name, name_en, icon_system_name, icon_key, sort_order, is_enabled, created_at)`.
  - `name` is **Arabic**, and `name_en` was added later in `20260738100000_users_and_bilingual_categories.sql`. This naming is inconsistent with `cms_pages`, which uses EN plus an `_ar` suffix. Munyati should pick `name_ar` + `name_en` from the start.
- **RPC:** `get_categories()` returns enabled rows: `{id, name, name_en, icon_system_name, icon_key, order}`. Public read, admin write. Deleting a category with places fails on the FK (by design, `places.category_id` is RESTRICT).
- **Dynamic fields ("same engine, different fields"):** `category_form_fields` with `kind` from `('text','number','toggle','segmented','singleSelect','multiSelect','time','multilineText')`, `options text[]` (canonical stored values) plus `options_en text[]` (index-aligned display labels), `is_required` (**only a "*" label; not enforced by app, dashboard or DB**, per `20260757100000`), and `is_filter` (exposes a toggle field as an Explore filter chip, `20260762100000`).
  - Values live in `place_field_values` and are filtered through `get_places(p_tag, p_field_id, p_field_bool)`.
  - `label` is a **single (English) column** with no Arabic label column.
  - Trigger `trg_seed_description_field` auto-adds a `description` (`multilineText`) field to every new category.
- **Multi-category:** `places.category_id` is the primary category and owns the field schema. `place_categories` adds extra categories for discoverability only (`20260726100000_multi_category.sql`). `get_places(p_category)` matches either.
- **How category icons are delivered: bundled icon keys, not storage URLs.**
  - Originally `icon_system_name` held SF Symbol names.
  - The 1.0.5 build switched to a bundled Hugeicons asset set (`Packages/Shared/Sources/Shared/Icons/CategoryIcon.swift`: `Image(name, bundle: .module).renderingMode(.template)`, fallback key `map-pin` when the key is nil or empty). The dashboard picks from the same fixed list (`CategoryIconPicker.tsx`, referenced but not in this workspace).
  - Remapping `icon_system_name` in place broke the live 1.0.4 build (`20260906140000` → reverted in `20260907100000`). The fix was an **additive** `icon_key` column (`20260907110000_category_icon_key_additive.sql`), with `icon_system_name` frozen for old clients.
  - **Consequence:** an admin can only choose among icons already shipped in the build. A brand-new category logo needs an app release. That fails Munyati requirement 19. Add `icon_url` (SVG/PDF/PNG in a public `category-icons` bucket), and keep the additive-column lesson for any future change to field meaning.

---

## 6. Storage buckets and policies

| Bucket | Public | Path convention | Policies |
|---|---|---|---|
| `place-images` (`20260713120200_storage.sql`) | yes | `<uid>/<place_id>/<uuid>.jpg`; admin assets under `admin/…` | public SELECT; INSERT only where `(storage.foldername(name))[1] = auth.uid()::text`; UPDATE/DELETE by folder owner **or** `is_admin()` |
| `avatars` (`20260714130000_features.sql`) | yes | `<uid>/…` | public SELECT; owner-only INSERT/UPDATE/DELETE (no admin override) |
| `place-videos` (`20260724100000_admin_dashboard_upgrade.sql`) | yes | `<uid>/…` | identical to `place-images` |

- No bucket sets `file_size_limit` or `allowed_mime_types`. Munyati should set both.
- There is **no private bucket**. Munyati's payment receipts must not be public: they need a private `payment-proofs` bucket, with paths like `<booking_id>/<uuid>.jpg` and a SELECT policy that joins to `bookings` (customer, provider or admin), served through signed URLs.
- Client upload flow (supabase/README.md): upload to Storage first, then pass the public URLs in the RPC payload (`images: [{url, is_cover}]`).

---

## 7. (Places to Munyati mapping)

The closest analogue to Munyati's provider and services is **`businesses` (one per owner, `is_verified` badge, logo/bio/since_year/response_time) → `places` (the listing)**:

- The submit → `pending` → admin approve → `live` / `rejected` → owner edits and resubmits flow (`submit_place`, `resubmit_place`, `places_update_own_rejected`, `notify_place_status`, `notify_ad_submitted`) maps directly onto **service approval**.
- `place_hours` (multiple slots per weekday, `closes < opens` means "crosses midnight") is a starting shape for provider working hours. It is **not** a bookable-slot model (section 17).
- `admin_create_place` with a placeholder owner (`55555555-5555-5555-5555-555555555555`, created in `20260723100000`) is the pattern for **system-owned rows**. It is reusable for Munyati's "demo bride" account that sends the demo booking.

---

## 8. Reviews

### 8.1 Data model (final state)

`reviews (id, place_id, user_id, rating 1..5, comment, status text {pending,approved,declined} default 'pending', deleted_at, deleted_by {user,admin}, created_at)`. There is one *active* review per user per place: `create unique index reviews_active_one_per_user_place on reviews (place_id, user_id) where deleted_at is null` (`20260767100000`).

### 8.2 Approval workflow (`20260765100000_review_approval_workflow.sql`)

- `add_review(p_place_id, p_rating, p_comment)`:
  - rejects null `auth.uid()`
  - rejects anonymous callers (`auth.jwt()->>'is_anonymous'`)
  - rejects banned users
  - rejects a second active review (`errcode 23505`)
  - otherwise inserts as `pending`.
- Public lists show `status = 'approved'` **or the caller's own review** (so the author sees "pending" or "declined" instead of the review silently vanishing).
- Ratings and counts include only `approved and deleted_at is null`.
- The admin acts through `admin_set_review_status(p_id, 'pending'|'approved'|'declined')`, which ignores deleted rows.
- **In-place editing was removed** (`20260767100000`) so an approved review cannot be rewritten into abuse. To change a review, the user deletes it and posts a new one, which starts as pending again.

### 8.3 Soft delete

`delete_my_review(p_place_id)` and `admin_delete_review(p_id)` set `deleted_at`/`deleted_by`. Admin lists (`admin_get_*_reviews`) still return deleted rows for history, sorted active first, then pending first. `notifications.review_id` lets the dashboard show "review deleted" instead of a dead link.

### 8.4 Bans and reactions (`20260753100000_review_bans_reactions_masking.sql`)

- **Ban:** `profiles.is_banned` is enforced twice: in `add_review` (friendly error) and in RLS (`reviews_write_own … with check (user_id = auth.uid() and not exists (… is_banned))`).
- **Reactions:** `review_reactions (review_id, user_id, reaction like/dislike)`. `toggle_review_reaction(p_review_id, p_reaction)` adds, switches or clears the reaction, blocks anonymous users, and returns `{review_id, like_count, dislike_count, my_reaction}`.
- **Pagination:** `get_reviews_page(p_place_id, p_limit, p_offset, p_sort 'newest'|'highest'|'lowest')` returns `{items, total, has_more}` (offset-based, `20260912110000`). The legacy `get_reviews(uuid)` is frozen for the 1.0.4 build.
- **Review notifications:** `notify_new_review()` sends:
  - one admin-audience row with Reviewer / Rating ★★★★☆ / Place / Comment (capped at 240 chars)
  - a copy to the place owner
  - a copy to the business owner if that is a different person (`20260906130000`).
  - It fires on INSERT, i.e. while the review is still **pending**, so owners are notified about reviews that may later be declined.

### 8.5 Reviewer-name masking, exactly

There is **no per-user "private mode" toggle** anywhere in the Kolna backend or app. I searched for `private_mode`, `is_private`, `hide_name` and `privateMode` and found nothing. "Private mode" in practice means: **every reviewer's name is masked for every viewer except the reviewer themself.** The implementation went through four versions:

| Migration | Where | Algorithm | `first_name='Ahmed', last_name='Alotaibi'` | display_name only `'Sara'` | No profile |
|---|---|---|---|---|---|
| `20260753100000_review_bans_reactions_masking.sql` | SQL (`get_reviews`, `get_business_reviews` became `security definer` so author identity resolves past profiles RLS) | `left(first_name,2) \|\| ' ' \|\| left(last_name,2)`, else `left(display_name,2)`, else `'Guest'` | `Ah Al` | `Sa` | `Guest` |
| `20260754100000_mask_name_suffix.sql` | SQL | same + one trailing `'****'` when a profile exists | `Ah Al****` | `Sa****` | `Guest` |
| `20260755100000_mask_name_suffix_both_parts.sql` | SQL | `left(first,2)\|\|'****'\|\|' '\|\|left(last,2)\|\|'****'`, else `left(display_name,2)\|\|'****'` | `Ah**** Al****` | `Sa****` | `Guest` |
| **`20260756100000_reviews_full_name_backend.sql` (current)** | **iOS client only** | RPC returns `author_name = coalesce(display_name,'Guest')` **unmasked**. `Review.displayAuthorName` masks it on device | see below | | |

The current client algorithm (`kolna-al-khafji-ios/Packages/Features/Places/Sources/Places/Domain/Entities/PlaceDiscovery.swift`, around line 138):

```swift
public var displayAuthorName: String {
    guard !isMine, authorName != "Guest" else { return authorName }      // own review / no profile → as-is
    let parts = authorName.split(separator: " ", omittingEmptySubsequences: true)
    guard !parts.isEmpty else { return authorName }
    return parts.map { "\($0.prefix(2))****" }.joined(separator: " ")    // every word → first 2 chars + ****
}
```

Worked examples:
- `"Ahmed Ali"` → `"Ah**** Al****"` (the example in the code comment)
- `"نورة محمد القحطاني"` → `"نو**** مح**** ال****"` (every word is masked, not just first and last; `prefix(2)` counts grapheme clusters, so Arabic works)
- `"Sara"` → `"Sa****"`
- The viewer's own review → their full name. A missing profile → `Guest`.
- `display_name` is set at OTP signup as `"First Last"` (`verify-otp`), but users can later edit it freely through `update_profile`, so the masked output reflects whatever they typed.
- The admin dashboard uses `admin_get_*_reviews`, which return the **full** name intentionally ("moderation accountability").

**Why this matters for Munyati.** Because masking now happens only on the client, `get_reviews`, `get_reviews_page` and `get_business_reviews` hand the **full real name** (and `author_avatar_url`) to any anon-key caller. The real name is one `curl` away. Munyati's reviewers are mostly brides, and providers will review brides too, so:
1. Mask in SQL using the v3 rule, applied per word:
   ```sql
   string_agg(left(w, 2) || '****', ' ')
     from regexp_split_to_table(trim(display_name), '\s+') w
   ```
   Return the unmasked name only when `r.user_id = auth.uid()`, or through admin-gated RPCs **with** an `is_admin()` check.
2. Do not expose reviewer avatars publicly; show initials instead.
3. Gate the admin review RPCs (section 3.3 gap).
4. Optional: a `profiles.review_display_mode ('masked','full')` column if the owner later wants a real opt-in or opt-out "private mode". The default must be masked.

### 8.6 What Munyati needs beyond this

Kolna reviews are **one direction (user → place) and can be posted at any time**. Munyati requirement 15 needs **two-way, booking-scoped reviews, allowed only after the booking is completed**:

```text
reviews (booking_id FK, reviewer_id, reviewee_id, direction {customer_to_provider, provider_to_customer},
         rating, comment, status, deleted_at…, UNIQUE (booking_id, reviewer_id))
```

The insert check `bookings.status = 'completed'` and `reviewer ∈ {customer, provider}` belongs in the RPC and the RLS policy. Keep the moderation, soft-delete, ban and reaction machinery as it is.

---

## 9. Notifications

### 9.1 Tables

- `notifications`: `user_id` nullable, `audience {user, admin}`, `kind` (CHECK list), `title`, `subtitle`, `body`, `image_url`, deep-link ids `place_id`/`business_id`/`review_id`, `is_read`, `opened_at`.
  - Rows are written **only** by `security definer` triggers or RPCs. There is no INSERT grant.
  - Admin-audience rows (`user_id null`) form a shared admin inbox.
- `device_tokens (token PK, user_id, platform)`.
  - `register_device_token(p_token, p_platform)` is `security definer` and upserts on token, so if a different user signs in on the same phone, the token is re-owned.
  - `unregister_device_token` is called on sign-out.
- `notification_settings (kind PK, enabled)` (`20260737100000`): a single `BEFORE INSERT` trigger, `notifications_gate()`, returns NULL for a disabled kind. No row is written and no push is sent. `admin_message` has no settings row, so it is never gated.
- `notification_campaigns` (`20260732100000`): one admin-visible row per send.
  - `admin_send_campaign(p_title, p_subtitle, p_body, p_image_url, p_place_id, p_segment 'all'|'business_owners'|'category', p_category_id)` resolves the segment **at send time** into a temp table, writes the campaign row, then fans out one `notifications` row per recipient.
  - The `category` segment means owners **or favoriters** of live places in that category.
  - This is the closest existing thing to "SMS marketing from the dashboard" (push only).

### 9.2 Event kinds (final CHECK list)

`place_approved, place_rejected, review_received, promotion_approved, promotion_rejected, payment_logged, ad_submitted, business_submitted, user_registered, ad_received, business_received, welcome, admin_message, business_verified, review_submitted`.

Each new kind needs `drop constraint … add constraint` (done 3 times). For Munyati, use a `notification_kinds` lookup table (FK) instead.

### 9.3 Triggers that create rows

`notify_place_status` (places status change), `notify_ad_submitted` (insert pending), `notify_business_submitted`, `notify_business_verified`, `notify_user_registered` (skips admins and anonymous guests), `notify_new_review`, `notify_promotion_status`, `notify_payment_logged`.

**All titles and bodies are hard-coded English** (for example `'Your listing is live'`). Munyati is Arabic-first and needs bilingual templates resolved per recipient locale, e.g. a `notification_templates (kind, title_ar, title_en, body_ar, body_en)` table plus `profiles.locale`.

### 9.4 App RPCs

- `get_notifications(p_limit)`: own user rows, plus all admin rows when the caller is an admin.
- `mark_notification_read`, `mark_all_notifications_read`, `mark_notification_opened` (push tap, used for open-rate analytics), `delete_notification`, `delete_all_notifications`.
- **Bug, do not copy:** in `get_notifications`, the `limit p_limit` is applied to the single `jsonb_agg` result row, not to the notifications. `p_limit` is therefore ignored and the whole inbox comes back. Paginate inside a subquery instead.

### 9.5 Push delivery: how FCM is called (`supabase/functions/send-push/index.ts`)

1. Trigger: a **Supabase Database Webhook** (configured in the dashboard, not in SQL) on `INSERT` into `notifications`. It calls the `send-push` function with header `x-webhook-secret: $PUSH_WEBHOOK_SECRET`. The function returns 401 if the header does not match.
2. Recipients: for `audience='admin'`, `rpc/admin_device_tokens` (service_role only); otherwise `GET /rest/v1/device_tokens?user_id=eq.<id>`.
3. Auth to Google is hand-rolled and dependency-free:
   - an RS256-signed JWT from `FIREBASE_SERVICE_ACCOUNT_JSON` (scope `firebase.messaging`)
   - exchanged at `https://oauth2.googleapis.com/token`
   - the access token is cached per warm instance.
4. Send: `POST https://fcm.googleapis.com/v1/projects/$FIREBASE_PROJECT_ID/messages:send`, one request per token, with:
   - `notification {title, body, image?}`
   - `data {kind, notification_id, place_id?, business_id?, image?, subtitle?}` (the deep-link keys)
   - `apns.payload.aps {mutable-content: 1, sound: default, alert {title, subtitle?, body}}` (a Notification Service Extension attaches the image).
5. Tokens that come back as `UNREGISTERED` or `INVALID_ARGUMENT` are deleted.

Secrets: `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `PUSH_WEBHOOK_SECRET` (plus the auto-injected `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`). Setup steps are in `send-push/README.md`.

**For Munyati:** reuse this function nearly as-is. Changes:
- Add `booking_id` (and dispute or subscription ids), or better a single `deeplink` column (e.g. `https://munyati.co/b/<id>`, which works for requirements 26 and 27), to `notifications` and to the `data` payload.
- Ship the webhook as SQL (`supabase_functions.http_request` trigger, or `pg_net`) so it is reproducible across environments.
- Batch the fan-out for broadcasts: a 10k-user campaign is 10k webhook invocations today.

---

## 10. Phone OTP (`send-otp` / `verify-otp` + `phone_otp`)

- **SMS provider: OurSMS.** It is called directly, not through GoTrue's phone provider (OurSMS is not a built-in Supabase provider).
  ```
  POST https://api.oursms.com/msgs/sms
  Authorization: Bearer $OURSMS_API_KEY
  { src: $OURSMS_SENDER, dests: [phone], body, msgClass: "transactional", priority: 1, validity: 10, maxParts: 1 }
  ```
  - The sender name must be approved in the OurSMS portal, otherwise error 6307. Errors 1001 (bad key) and 1008 (no balance) are mapped to Arabic messages.
  - Body: `كلنا الخفجي: رمز التحقق هو {code}\nصالح لمدة 10 دقائق`.
- **send-otp:**
  - Normalizes the number: Arabic-Indic digits to ASCII; `05x`/`5x`/`00`/`966` forms to `+966…`; also accepts `+965` and `+20`, the latter for debug only.
  - Rate limits: 60 s cooldown, 5 per hour, 10 per day per number.
  - Burns earlier unused codes.
  - Generates the code with a CSPRNG and stores **HMAC-SHA256(`otp:<phone>:<code>`, OTP_HASH_SECRET)**, never the plaintext. Expiry is 10 minutes.
- **verify-otp:**
  - Looks up the latest unused, unexpired row. It burns the row after 5 failed attempts. "Wrong code" and "expired" return the same error message.
  - New numbers without a name get `{requires_registration: true}` and the code is **not consumed**, so the app can collect first and last name and call again.
  - **How the session is minted:** the user is a Supabase **email/password** user with a synthetic email `<digits>@phone.kolnaalkhafji.app` and password = **HMAC-SHA256(`kolna:<phone>`, PASSWORD_SECRET)**. The function creates the user with `auth.admin.createUser({email_confirm: true, user_metadata: {phone, display_name}})`, upserts the profile with `phone, first_name, last_name, display_name`, then calls `signInWithPassword` using the anon client and returns `{access_token, refresh_token, expires_in, user}`. The app refreshes with `/auth/v1/token?grant_type=refresh_token`.
- **App-review bypass:** `DEV_PHONES` (env, **default `+966500000000` if unset**) accepts code `000000` without sending an SMS.
- Things to fix when porting to Munyati:
  1. Make `DEV_PHONES` default to empty in production.
  2. Rotating `PASSWORD_SECRET` locks out every phone user, so document it as permanent.
  3. The "already registered" recovery path uses `auth.admin.listUsers({perPage: 1000})`, which breaks past 1000 users. Look up by email instead.
  4. `profiles.phone` is not UNIQUE; add a unique index.
  5. `phone_otp` has no cleanup job; add a `pg_cron` purge.
  6. Change the brand string in the SMS body, the synthetic email domain (e.g. `@phone.munyati.co`) and the HMAC salt.
  7. Requirement 1 (customer vs provider): pass `account_type` in the verify call alongside first and last name, and write it to the profile on creation.

---

## 11. Delete account (`supabase/functions/delete-account/index.ts` + `delete_my_account()`)

1. Deploy with JWT verification on. The function validates the bearer through `auth.getUser()`.
2. As the user, it calls `rpc('delete_my_account')`, which runs `delete from profiles where id = auth.uid()` and cascades to businesses, places and their children, reviews, favorites, promotion_requests, notifications and device_tokens. Analytics and payment references are `SET NULL`.
3. As the service role, it calls `auth.admin.deleteUser(user.id)`.

Reusable as-is. For Munyati, **think before cascading**: bookings, payment proofs, disputes and reviews about a provider are evidence the other party and the admins rely on (requirement 5). Anonymize instead of deleting those rows (null the PII, keep `deleted_user` markers), and block deletion while there are active bookings or open disputes.

---

## 12. Payments migration (`20260724140000_payments.sql`)

What it models: an **offline, admin-entered ledger** of what sellers paid the marketplace (by bank transfer or similar) to post an ad. There is no in-app payment flow in Kolna.

```sql
payments (id, place_id → places SET NULL, user_id → profiles SET NULL, amount numeric >= 0,
          currency 'SAR', method text, note text, paid_at, recorded_by → profiles, created_at)
```

- RLS: `payments_admin_all`, so every operation including SELECT is admin-only.
- Trigger `notify_payment_logged` tells the place owner (or `user_id`) "A payment of X SAR was recorded".
- **There is no Tap integration in Kolna.** Tap lives in Lamha (`create-ad-charge`, `tap-webhook`, `payment-return`), per the task context; I did not analyse it here.
- The ledger shape is reusable as `subscription_payments` (provider → Munyati, via Tap). It does **not** cover bride → provider manual transfers with receipt screenshots (section 17).

---

## 13. Analytics

| Mechanism | Migration | Captures | Read via (all admin-gated, `security definer`) |
|---|---|---|---|
| Counters on `places` | init + `20260719100000`, fixes `20260746100000`, `20260909120000` | `view_count` (`record_place_view(p_id)`, live places only), `save_count` (recounted inside `toggle_favorite`) | `get_top_places_insights(p_limit)`: top viewed / top saved |
| `search_log` | `20260719100000_search_insights.sql` | `term, category_id, city, availability, user_id, created_at`. `log_search(...)` no-ops when nothing meaningful was queried (the default feed is not logged) | `get_search_insights(p_days, p_limit)`: `total_searches`, `top_terms`, `by_category`, `by_city`. Public `popular_searches(p_limit)` returns only aggregated terms (90 days) |
| `analytics_events` | `20260906150000_engagement_analytics.sql` + `20260912100000_analytics_event_context.sql` | Enum `analytics_event_type {app_open, place_directions, place_whatsapp, delivery_link_click, banner_impression, banner_click}`, `entity_id` (place, platform or banner), `context_id` (e.g. the ad a delivery link was tapped on), `user_id` (includes anonymous guests). Written by `record_analytics_event(p_event_type, p_entity_id, p_context_id)` | `get_active_users_stats()`: DAU/WAU/MAU = distinct `user_id` with `app_open` in 1/7/30 days, plus a 30-day daily trend. `get_engagement_insights()`: click and impression totals, notifications sent vs opened, top 10 places by directions/WhatsApp, delivery clicks by platform and by place (`20260912100100`) |
| Push open rate | `20260906150000` | `notifications.opened_at` via `mark_notification_opened` | inside `get_engagement_insights` |
| Supply overview | `20260724100000`, `20260769100000` | — | `get_admin_overview_stats()`: places by status, businesses, real (non-anonymous) users, total and average listed price, live places by category, listings per day for 30 days |

- **Client side:** `Packages/Shared/Sources/Shared/Analytics/AnalyticsRecorder.swift` is an injected, fire-and-forget environment value whose raw values mirror the Postgres enum. Previews and tests use `.disabled`.
- **Aggregation** is computed live on every dashboard call. There are no rollups, materialized views, partitions or retention policy.

**Gaps against Munyati requirement 9** ("analytics for everything: logs, taps, clicks, number of services, categories, users provider vs customer, error logs"):
- **Rigid event set.** A new event needs `alter type … add value`, a migration and a client release. Use `event_name text` + `properties jsonb` + `session_id`, `screen`, `app_version`, `os_version`, `platform`, `locale`, `city_id`.
- **No error logs at all**, client or server. Add `client_error_logs` / `server_error_logs` (or Crashlytics) with an admin view.
- **Spoofable rows.** Direct table INSERT is open to `anon, authenticated` with `with check (true)`, so a client can write rows with an arbitrary `user_id` and flood the table. Revoke the table grant and insert only through the RPC, ideally with per-user rate limits.
- **No rollups.** Add a daily rollup table populated by `pg_cron` before volumes grow.
- **No persona split.** Munyati KPIs (provider vs customer counts, services per category, bookings funnel, conversion, trial → paid) need the `account_type` split and booking and subscription tables first. The `get_admin_overview_stats` *pattern* (one JSON RPC per dashboard card group) is reusable.

---

## 14. Guest / anonymous users

- **Sign-in:** the app calls GoTrue anonymous sign-up (`APIEndpoint.authentication.signUpAnonymous` → `POST /auth/v1/signup`; the Anonymous provider must be enabled). The guest gets a real `auth.uid()`, a `profiles` row (via `handle_new_user`), and a JWT with `is_anonymous: true`. The role is still `authenticated`.
- **Gates:** `add_review` and `toggle_review_reaction` check `auth.jwt()->>'is_anonymous'`. `notify_user_registered` skips anonymous users (`20260745100000`). `admin_list_users` and the overview "users" count exclude `auth.users.is_anonymous`. `toggle_favorite` and `submit_place` do **not** block guests; the README says guests can own places.
- **Cleanup:** `cleanup_anonymous_users()` deletes anonymous users inactive for 30+ days (by `last_sign_in_at`, falling back to `created_at`). It runs via `pg_cron` daily at 03:30 UTC and cascades their data.
- **Guest to real account:** a guest who later signs in gets a **separate** user. Guest favorites are not merged (inferred from the trigger comments; I did not verify merge logic in the client).
- **For Munyati:** reuse as-is for browsing. Gate booking, payment proof upload, reviews, reports and budget persistence behind non-anonymous accounts, both in RPCs (`is_anonymous` check) and in RLS. Every `authenticated`-granted `security definer` RPC must assume a guest can call it (section 3.3).

---

## 15. Defects and pitfalls in Kolna (do not port)

1. `admin_get_place_reviews` and `admin_get_business_reviews`: `security definer`, no `is_admin()` check, callable by guests (section 3.3).
2. Review masking is client-only, so full names leak through public RPCs (section 8.5).
3. `get_notifications(p_limit)` ignores `p_limit` (section 9.4).
4. Telemetry tables accept direct inserts with arbitrary `user_id` (section 13).
5. `send-otp`/`verify-otp` default `DEV_PHONES = +966500000000` when the env var is unset (section 10).
6. `verify-otp` `listUsers({perPage:1000})` fallback (section 10).
7. `profiles.role` was self-editable until `20260753100000`. Start Munyati with column-level grants (section 3.2).
8. The push webhook exists only in dashboard configuration (section 9.5).
9. Notification text is English-only (section 9.3). Field labels have no Arabic column (section 5).
10. RPC overload churn: `get_places` and `place_to_json` were restated in full on every change (section 2.3).
11. `is_required` on dynamic fields is not enforced anywhere (section 5).
12. `admin_create_profile` writes to `auth.users` directly (section 3.4).

---

## 16. Reuse table

| Piece | Kolna source | Verdict | What to change for Munyati |
|---|---|---|---|
| `is_admin()` + admin RPC template + RLS idioms | `20260713120000`, `20260713120100`, every `admin_*` | **Reuse, extend** | Add staff roles; make an `is_staff(role)` helper; add column-level grants on `profiles` from the first migration |
| `profiles` + `handle_new_user` trigger | `20260713120000`, `20260752100000` | **Adapt** | Add `account_type {customer,provider}`, `locale`, `city_ids`, `budget_*` (or a separate table), `sms_marketing_opt_in`; UNIQUE phone |
| RPC JSON assemblers + `iso8601()` + keyset cursor | `20260713120300`, `get_places` | **Reuse pattern** | One `p_filters jsonb` param; avoid restating huge functions |
| Phone OTP via OurSMS | `functions/send-otp`, `functions/verify-otp`, `20260750100000_phone_otp.sql` | **Reuse ~as-is** | Branding, domain, salts, empty `DEV_PHONES` default, `account_type` at registration, unique phone, OTP purge cron |
| Anonymous guests + cleanup cron | `20260741…`, `20260742…`, `20260745…` | **Reuse** | Gate booking, payment, review and report RPCs on non-anonymous |
| Delete account | `functions/delete-account`, `delete_my_account()` | **Adapt** | Anonymize bookings, proofs, disputes and reviews instead of cascading; block while bookings are active |
| Device tokens | `20260727100000_device_tokens.sql` | **Reuse as-is** | — |
| `send-push` (FCM v1, webhook) | `functions/send-push` | **Reuse, small changes** | `deeplink`/`booking_id` in data; webhook as SQL; batched broadcast |
| Notifications inbox, audience, settings gate, campaigns | `20260725…`, `20260731…`, `20260732…`, `20260737…`, `20260751…` | **Adapt** | Kinds table instead of CHECK; bilingual templates; booking, payment and subscription kinds; fix limit bug; segments by `account_type`, city, plan, trial state |
| `app_config` singleton + `get_config()` (flags, force update, contacts, home counts) | `20260716090000`, `20260763100000`, `20260768100000` | **Reuse** | Drop `cities text[]` (use a table); add `content_version`, trial length, demo-booking toggle |
| CMS pages (bilingual) | `20260716090000`, `20260730100000` | **Reuse as-is** | The same rows can feed munyati.co privacy, terms and support pages (requirement 29) |
| Home sections + banner slides | `20260716090000`, `20260722120000` | **Reuse** | Link a slide to a provider, service or category; filter by city |
| Categories + dynamic form fields + `place_categories` | `20260713120000`, `20260738…`, `20260739…`, `20260762…`, `20260726…` | **Adapt** | `name_ar`/`name_en`; `label_ar`/`label_en`; **`icon_url` in storage** with `icon_key` fallback; enforce `is_required` |
| Storage buckets (owner-folder policy) | `20260713120200`, `20260714130000`, `20260724100000` | **Reuse pattern** | Add size and MIME limits; add **private** `payment-proofs` and `dispute-evidence` buckets |
| Listing approval flow (`places` pending → live) | `submit_place`, `resubmit_place`, `notify_place_status` | **Adapt** as service approval | Plus a plan-entitlement check (max services) |
| `businesses` (verified provider profile) | `20260714140000` | **Adapt** | Becomes `providers`; stores become a separate 1-to-many table |
| `place_hours` | `20260770100000` | **Starting point only** | Needs slot capacity, exceptions and booking overlap prevention |
| Reviews (approval, soft delete, bans, reactions, pagination) | `20260753…`–`20260767…`, `20260912110000` | **Adapt** | Booking-scoped, two-way, completed-only; server-side masking; gate admin RPCs |
| Payments ledger | `20260724140000_payments.sql` | **Adapt** | Becomes `subscription_payments` fed by Tap (Lamha functions) |
| Analytics (`analytics_events`, `search_log`, counters, insights RPCs) | `20260719…`, `20260906150000`, `20260912100000/100100` | **Adapt** | Free-form `event_name` + `properties`; sessions and app version; RPC-only insert; rollups; error logs |
| Admin overview stats RPC | `get_admin_overview_stats` | **Reuse pattern** | Provider vs customer counts, bookings funnel, plan mix, trial conversion |
| Soft delete / archive with restore | `20260909140100` | **Reuse pattern** | For services, stores and providers |
| Placeholder system user | `55555555-…` in `20260723100000` | **Reuse pattern** | "Demo bride" for the demo booking |
| Promotion requests | `20260714130000` | Optional | Could become a "featured provider" paid add-on later |
| Delivery platforms | `20260758…`–`20260760…`, `20260909100000` | Not needed | Only its remote-logo pattern is useful |

---

## 17. Backend pieces Munyati needs that do not exist in Kolna

Sketches only; names are suggestions.

1. **Cities (requirements 16, 17).**
   - `cities (id text PK, name_ar, name_en, is_enabled, sort_order, lat, lng)`.
   - `provider_cities` / `service_cities` join tables.
   - Customer filter: `p_city_ids text[]` where `NULL` means "All".
   - Persist the chosen filter on the profile.
   - Seed with the owner's list. **Confirm spellings with the owner first:** "Damam" is likely الدمام (Dammam) and "Khaibar" is likely خيبر (Khaybar). "Tafeef" is ambiguous (possibly الطائف, Taif); unverified.
2. **Providers and stores (requirements 2, 3, 14).**
   - `providers` (≈ `businesses`, plus `status`, `trial_ends_at`, `demo_booking_sent_at`).
   - `stores (id, provider_id, name, logo_url, address, city_id, lat, lng)`, many per provider.
   - `services (… provider_id, store_id?, category_id, price, duration_minutes, status …)`.
3. **Subscription plans and entitlements (requirements 2, 8, 11, 23, 24).**
   - `subscription_plans (id 'normal'|'plus'|'diamond', name_ar/en, price_monthly, price_yearly NULL, max_services int, features jsonb, is_active, sort_order)`, admin-editable.
   - `provider_subscriptions (provider_id, plan_id, status {trialing, active, past_due, cancelled, expired}, trial_ends_at, current_period_start/end, tap_* ids)`.
   - `subscription_payments` (Tap charges, adapted from the Kolna `payments` ledger and the Lamha `tap-webhook`).
   - The entitlement check lives in `create_service`/`publish_service`: count of active services ≤ plan `max_services` (plus any paid extra slots).
   - A `pg_cron` job expires trials, hides services and sends reminders.
   - The trial is 2 months from provider creation (`app_config.trial_days`).
4. **Availability.**
   - `availability_rules` (weekday slots, from the `place_hours` shape) + `availability_exceptions` (date overrides and closures).
   - `bookings.slot tstzrange` with an exclusion constraint (`btree_gist`) to stop double booking when capacity is 1.
5. **Bookings and their state machine (requirement 4).**
   - `bookings (id, customer_id, provider_id, service_id, category_id [denormalized], starts_at, ends_at, price_snapshot, status, is_demo, …)`.
   - Status values: `requested → approved | declined | reschedule_proposed → (accepted → approved) | (rejected → cancelled); approved → awaiting_payment → payment_submitted → payment_confirmed → completed; + cancelled_by_*, expired, disputed`.
   - Allowed transitions are enforced in one `security definer` function, the same way `admin_set_place_state` centralises transitions.
   - `booking_events` is an append-only log (actor, from, to, note) and doubles as the audit trail.
6. **Reschedule proposals.** `booking_proposals (booking_id, proposed_by, starts_at, ends_at, status {pending, accepted, rejected, superseded, expired}, expires_at)`. Accepting one atomically moves the booking slot.
7. **One active booking per category (requirement 20).**
   ```sql
   create unique index one_active_per_category
     on bookings (customer_id, category_id)
     where status in ('requested','reschedule_proposed','approved','awaiting_payment','payment_submitted','payment_confirmed','disputed')
       and not is_demo;
   ```
8. **Budget (requirement 13).**
   - `customer_budgets (customer_id PK, total_amount, currency, wedding_date?)`.
   - `remaining = total − Σ price_snapshot of non-cancelled bookings`, computed by an RPC or view.
   - `get_services(p_max_price := remaining)`.
   - Remaining budget is per bride across categories, which pairs with item 7.
9. **Payout methods (requirement 5).** `provider_payout_methods (provider_id, kind {bank_iban, stc_pay, urpay, other}, account_name, iban/phone, is_default)`. Readable by a customer **only** through an RPC for a booking in `awaiting_payment` or later; never public.
10. **Payment proofs (requirements 5, 22).**
    - `payment_proofs (booking_id, uploaded_by, storage_path, amount, transfer_reference, status {pending, accepted, rejected}, reviewed_by, reviewed_at, reject_reason)`.
    - A private bucket with booking-scoped SELECT policies and signed URLs.
    - Every state change is visible to admins.
11. **Disputes (requirement 5).** `disputes (booking_id, opened_by, reason_code, details, status {open, investigating, resolved, rejected}, assigned_to, resolution, timestamps)` + `dispute_messages` + evidence attachments in a private bucket.
12. **Reports and flags (requirement 28).** A generic `reports (reporter_id, target_type {provider, service, store, review, user, booking}, target_id, reason_code, details, status, handled_by, handled_at)` + admin queue RPCs + optional auto-hide thresholds. Also `support_tickets` if in-app support is wanted (Kolna only has contact methods and a CMS help page).
13. **Demo booking (requirement 24).** An `after insert` trigger on `providers` (guarded by `demo_booking_sent_at` so it runs once) inserts a `bookings` row with `is_demo = true` from a system "demo bride" profile (the `55555555` placeholder pattern). Demo rows are excluded from analytics, budgets, reviews, the item 7 rule and disputes. The demo can optionally walk through a sample payment proof. Auto-archive after completion.
14. **SMS marketing campaigns (requirement 10).**
    - `sms_campaigns (body, segment, city_ids, plan_ids, account_type, recipient_count, status, scheduled_at, sent_at, created_by, cost)` + `sms_messages (campaign_id, phone, status, provider_message_id, error)`.
    - A `send-sms-campaign` Edge Function batching OurSMS `dests`.
    - `profiles.sms_marketing_opt_in` + opt-out handling.
    - The OurSMS `msgClass` value for promotional traffic and Saudi CST rules for marketing SMS (sender registration, opt-out, allowed hours) are **not verified here**; check the OurSMS docs before building.
15. **Admin audit log.** `admin_audit_log (actor_id, action, target_type, target_id, before jsonb, after jsonb, created_at)`, written by every admin RPC (or a generic trigger on admin-edited tables).
16. **Error logs (requirement 9).** `client_error_logs (user_id, session_id, app_version, os_version, device, screen, code, message, context jsonb, created_at)` through a rate-limited insert RPC; `server_error_logs` written by Edge Functions; dashboard views.
17. **Analytics v2.** Generic events (`event_name`, `properties jsonb`, session and app metadata), daily rollups through `pg_cron`, and KPI RPCs: provider vs customer counts, services and categories, bookings funnel, trial → paid conversion, payment-proof dispute rate.
18. **Remote strings and assets (requirement 19).** `remote_strings` (or a versioned JSON in storage), `categories.icon_url`, and `content_version` in `get_config()`.
19. **Deep links (requirements 26, 27).** A `notifications.deeplink` column (universal-link URLs on `munyati.co`). The `.well-known/apple-app-site-association` pattern exists in Lamha, not Kolna.
