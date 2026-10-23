# Admin dashboard: what Munyati can reuse from `lamha_dahsboard`

Scope: `/home/user/lamha_dahsboard` (Next.js 14 + `@supabase/ssr`, Lamha's admin console) and the backend it calls in `/home/user/lamha_backup_ios/supabase/functions/admin-content/index.ts`. Where Kolna (Maalim Al-Khafji) has a better admin pattern, I cite it from `/home/user/kolna-al-khafji-ios/supabase/migrations`. Kolna's dashboard source is not in this workspace (see `docs/research/kolna-backend.md` §1), so I could not compare against its UI.

---

## 0. Summary

- **Size and maturity.** It is a small, hand-written console of about 3.3k lines of TS/TSX/CSS in one git commit (`64ef004 Dashboard: Android kill switch page`). It has 9 dashboard routes, 6 components, no UI library, no tests, no ESLint config, no i18n, and is dark-only with an LTR English UI.
- **Auth.** Supabase email/password. `middleware.ts` only checks that a session exists. The admin check (`user_roles.role = 'admin'`) runs in the server layout `app/(dashboard)/layout.tsx` for UX, and again inside every `admin-content` edge-function call, which is the real authority.
- **Data access.** Almost every page goes through one service-role edge function, `admin-content`, as an `{action, ...payload}` RPC (`lib/adminApi.ts`). Two exceptions read or write tables directly with the user's JWT: the Library page (`media_assets`) and the Android page (`app_settings`). Both depend on RLS policies I could not see, because the Lamha migrations in the workspace do not define them.
- **Reusable for Munyati:** the Supabase SSR client and middleware wiring, the `adminApi` call wrapper, the signed direct-to-storage upload (`sign_cover_upload` + `uploadCover`), the list-page anatomy (stat strip, toolbar, chips, table, empty state), the inline CRUD-panel pattern (categories/people), the reorder pattern, the read-only payments ledger with filters and totals, formatters, `StatCard`/`StatusBadge`/`Icon`, and the "kill switch / force update" settings form.
- **Missing for Munyati:** RTL/Arabic-first UI, granular admin roles, an audit log, server-side pagination and search, charts and analytics, push and SMS campaign UIs (the Lamha backend has push functions but the dashboard has no send form), user and provider management, moderation queues, CMS strings and assets, and city scoping on every list.
- **Security issue to act on now (Lamha, not Munyati):** `.env.example` is committed to git and contains the live `SUPABASE_SERVICE_ROLE_KEY` for project `guikaajxwautofhxkfyx`. That key bypasses all RLS and should be rotated. The locked Next.js version, 14.2.5, is also below 14.2.25, the patch for the middleware-bypass advisory CVE-2025-29927. The layout-level role check limits the impact, but the version should still be upgraded.
- **Recommendation:** build Munyati's dashboard as a **fresh Next.js app (15 or the current stable major) in its own repo**, and copy in only the files listed in §13. Do not fork the repo, for three reasons:
  1. The git history carries the leaked key.
  2. All the domain code (media, episodes, coverage, ads) is Lamha-specific.
  3. Munyati needs RTL, roles, tables with server pagination, and charts, which are foundational choices the Lamha codebase did not make.

  Put admin authority in **Postgres (`is_admin()` / `has_admin_permission()` + `admin_*` SECURITY DEFINER RPCs, as in Kolna)**, and keep edge functions only for work that needs third-party secrets (OurSMS, FCM, Tap).

---

## 1. Inventory

| Path | Lines | What it is |
|---|---|---|
| `lamha_dahsboard/package.json` | 23 | `next 14.2.5`, `react ^18.3.1`, `@supabase/ssr ^0.5.2`, `@supabase/supabase-js ^2.45.0`. Scripts: dev/build/start/lint. No other deps. |
| `lamha_dahsboard/middleware.ts` | 29 | Session refresh plus a login redirect. |
| `lamha_dahsboard/lib/supabase/{client,server}.ts` | 8 / 19 | Browser and server Supabase clients (`@supabase/ssr`). |
| `lamha_dahsboard/lib/adminApi.ts` | 143 | Typed wrapper around the `admin-content` edge function, plus `uploadCover()`. |
| `lamha_dahsboard/lib/upload.ts` | 80 | Media upload state machine: `create-upload`, then an XHR PUT/POST with progress, then `mark-uploaded`. |
| `lamha_dahsboard/lib/format.ts` | 57 | `fmtDuration`, `fmtSize`, `fmtDate`, `fmtDateTime`, `fmtNum`, `fmtMoney`, `splitSize`. |
| `lamha_dahsboard/app/globals.css` | 388 | The whole design system, hand-written CSS. |
| `lamha_dahsboard/app/login/page.tsx` | 51 | Email/password sign-in. |
| `lamha_dahsboard/app/(dashboard)/layout.tsx` | 34 | Auth and admin gate, plus the sidebar shell. |
| `lamha_dahsboard/app/(dashboard)/page.tsx` | 71 | Media Library, a server component that reads `media_assets` directly. |
| `.../upload/page.tsx` | 173 | Drag-and-drop media upload, or "add from link". |
| `.../episodes/{page,edit/page}.tsx` | 188 / 188 | Episode list and editor. |
| `.../programs/{page,edit/page}.tsx` | 193 / 213 | Program (show) list and editor. |
| `.../coverage/{page,edit,reorder,settings}/page.tsx` | 203 / 509 / 121 / 191 | Coverage events grid, event and clip editor, reorder, categories plus limits. |
| `.../people/page.tsx` | 172 | Hosts and guests CRUD. These are **content people, not app users**. |
| `.../payments/page.tsx` | 184 | Tap ad-payments ledger, read-only, with a request-status override. |
| `.../android/page.tsx` | 175 | Android kill switch (`app_settings.android_*`). |
| `lamha_dahsboard/components/` | | `Nav`, `Icon` (inline SVG paths), `StatCard`, `StatusBadge`, `LibraryTable`, `AssetPicker`. |
| `lamha_dahsboard/public/pay-return.html` | 60 | Tap return page that bounces to `lamha://pay-return?tap_id=…`. Excluded from the middleware matcher. |
| `lamha_dahsboard/.env.example` | 4 | **Contains real URL, anon key and service-role key** (see §11). |

The README (`lamha_dahsboard/README.md`) still describes the project as a "foundation" with stubbed CRUD. The code has since grown past that, so the README is out of date.

---

## 2. Auth and admin gating

**Layer 1: `middleware.ts` (authentication only).**

```ts
const { data: { user } } = await supabase.auth.getUser();
const onLogin = req.nextUrl.pathname.startsWith("/login");
if (!user && !onLogin) return NextResponse.redirect(new URL("/login", req.url));
if (user && onLogin) return NextResponse.redirect(new URL("/", req.url));
```

- It follows the standard `@supabase/ssr` cookie `getAll`/`setAll` pattern and calls `getUser()`, which validates with the Auth server, rather than `getSession()`.
- The matcher excludes `_next/static`, `_next/image`, `favicon.ico`, `*.svg` and `pay-return.html`.
- It does **not** check the role. Any Supabase user (including app end-users, if they can sign in with email/password) passes the middleware.

**Layer 2: `app/(dashboard)/layout.tsx` (authorization, UX level).**

```ts
const { data: role } = await supabase
  .from("user_roles").select("role").eq("user_id", user.id).maybeSingle();
if (role?.role !== "admin") { return (<div className="auth">…No access…</div>); }
```

- The role model is a `user_roles(user_id, role)` table with one role per user. `maybeSingle()` errors if a user has two rows, so in effect only a single `admin` role exists.
- Non-admins see a "No access" card. They are not signed out.

**Layer 3: `admin-content` edge function (authoritative).** In `lamha_backup_ios/supabase/functions/admin-content/index.ts`, every call does the following:
1. It builds an anon client with the caller's `Authorization` header and calls `auth.getUser()`.
2. It looks up `user_roles` with the **service-role** client and returns 403 unless `role === "admin"`.
3. It does all reads and writes with the service-role client (RLS bypassed).

**Variations in other Lamha functions:**
- `send-push-notification` checks `user_roles.role = 'admin'` **or** a hard-coded `user.email === "admin@lamha.app"` (line 218).
- `send-manual-notification` checks `user_roles`.

The two admin-check implementations are copy-pasted and have drifted from each other.

**Kolna's alternative (better for Munyati).**
- `public.is_admin()` is a `SECURITY DEFINER` SQL function over `profiles.role = 'admin'` (`kolna-al-khafji-ios/supabase/migrations/20260713120000_init_schema.sql:150`).
- Every admin operation is an `admin_*` RPC that starts with `if not public.is_admin() then raise exception … using errcode = '42501'` (e.g. `get_admin_overview_stats` in `20260724100000_admin_dashboard_upgrade.sql:181`).
- There are also `am_i_admin()`, `admin_set_user_role`, `admin_set_user_banned` and `admin_list_users`.

Because the check lives in the database, it cannot drift between functions, and it works with the user's JWT, so no service-role key is needed in the web tier.

---

## 3. Data access pattern

| Pattern | Where | Notes |
|---|---|---|
| **Edge-function "action RPC"** `POST /functions/v1/admin-content {action, …}` | `lib/adminApi.ts`, used by episodes, programs, coverage, people, payments, `AssetPicker`, upload "from link" | One 467-line `switch(action)` in Deno. About 28 actions: `get_options`, `list_/get_/upsert_/delete_` for people, episodes, programs, events, clips and coverage categories; `get_/set_coverage_settings`; `sign_cover_upload`; `reconcile_uploads`; `list_ad_requests`; `set_ad_request_status`; `list_ad_payments`; `delete_ad_request`. Server-side validation is done by hand (whitelisted columns, enum checks, Arabic error strings). |
| **Direct table read, server component** | `app/(dashboard)/page.tsx`: `supabase.from("media_assets").select(…).limit(200)` | Uses the user JWT, so it depends on RLS allowing admins to read `media_assets`. |
| **Direct table write, client component** | `app/(dashboard)/android/page.tsx`: `supabase.from("app_settings").update({...}).eq("id","default")` | Uses the user JWT. It depends on an RLS policy that lets admins update `app_settings`. I could not verify that policy: the Lamha migrations in the workspace (2 files) do not define `app_settings`. |
| **Separate edge functions** | `lib/upload.ts` calls `create-upload` and `mark-uploaded` | Used for media pipelines. |

**Characteristics of the action RPC.**
- Every list action returns the whole table, capped by `.limit(500)` / `.limit(200)` or with no limit at all. All filtering, search and stats happen client-side in `useMemo`, as in `payments/page.tsx` and `coverage/page.tsx`. There is no server pagination, sorting or count.
- Responses are untyped (`Record<string, any>`). `lib/adminApi.ts` hand-writes TS types (`EventRow`, `AdPayment`, …) that are not generated from the schema.
- Reorder issues N `get_event` and N `upsert_event` round-trips, one pair per moved row, with no transaction (`coverage/reorder/page.tsx` `saveOrder`).
- CORS is `Access-Control-Allow-Origin: *`. This is acceptable because auth is a bearer JWT, not cookies.
- Errors are returned as `{error}` with 400/401/403/500 and surfaced as banners.

**Assessment for Munyati.** The action-RPC pattern works, but it has three costs:
- A service-role god-function whose authorization is one `if` at the top.
- No per-action permissions.
- No transactional multi-row writes.

Kolna's `admin_*` Postgres RPCs give typed, transactional, permission-checked operations callable with the admin's own JWT via `supabase.rpc()`. Use them for all CRUD, moderation and analytics. Keep edge functions only for work that needs secrets or external HTTP: OurSMS, FCM, Tap, and possibly signed upload URLs.

---

## 4. Page structure and reusable UI patterns

**Shell.** `app/(dashboard)/layout.tsx` renders a CSS-grid shell (`.shell { grid-template-columns: 248px 1fr }`), a sticky sidebar (`.side`) and `.main` (max-width 1180px). `components/Nav.tsx` builds sectioned nav from a static `sections` array (`Media`, `Content`, `App`, `Billing`), with active-state matching by `startsWith` and a sign-out footer.

**List-page anatomy**, consistent across `coverage/page.tsx`, `programs/page.tsx`, `episodes/page.tsx` and `payments/page.tsx`:
1. `.head`: eyebrow (bilingual, e.g. `تغطيات لمحة · Coverage`), `h1`, subtitle, and `.head-actions` buttons.
2. `.banner error|ok`: error and success messages.
3. `.stats`: a row of `StatCard`s with tones `amber | green | red | blue | plain`.
4. `.toolbar`: `.search` input plus a `.segment` status filter with counts.
5. `.chips`: category filter chips with counts.
6. `.table` inside `.card`/`.panel`, or a `.grid` of `.evt` cover cards.
7. `.empty`: icon, title, copy and CTA for "no data" and "no match"; `.skel` shimmer for loading.

**Forms.**
- Two patterns: full-page editors under `/<entity>/edit?id=…` wrapped in `<Suspense>` (needed for `useSearchParams`), and inline editor cards above a table (`people/page.tsx`, the `CategoriesPanel` in `coverage/settings/page.tsx`).
- Helpers: `.form-grid cols-2`, `.form-section` with `.sec-head`, `.field`/`.label`/`.help`/`.help.warn`, `.toggle-row` with `.switch`, `confirm()` for destructive actions.
- State is a single `useState<Record<string, any>>` object with no form library and no schema validation. Validation is done by hand and duplicated server-side.

**Uploads.**
- **Images** use `uploadCover(file)` in `lib/adminApi.ts`. It calls `sign_cover_upload`, which does `admin.storage.from("covers").createSignedUploadUrl(path)` with a random UUID filename, then `fetch(uploadUrl, {method:"PUT"})`, and returns the public URL. This is reusable as-is for category icons, city images and CMS images.
- **Large media** use `lib/upload.ts`: a direct-to-storage XHR with progress plus a `create-upload`/`mark-uploaded` finalize step. Munyati does not need video, but the progress XHR helper (`xhrSend`) is useful for bigger assets.
- **Picker:** `components/AssetPicker.tsx` is a rich media picker with previews and "used by" badges. It is too media-specific for Munyati.

**Reorder.** `coverage/reorder/page.tsx` swaps rows with up/down buttons and saves `sort_order` per changed row. `coverage/edit/page.tsx` `moveClip` persists on each move. The UX is reusable. Replace the persistence with one `admin_reorder(table, ids[])` RPC so it runs in a single transaction.

**Settings singleton form.** `android/page.tsx` loads a single row, tracks "live" vs edited values, validates, saves, and shows a live-state banner. This maps directly to Munyati's force-update / maintenance / remote-config screen.

---

## 5. Payments page (`app/(dashboard)/payments/page.tsx`)

- **Source:** `adminApi.listAdPayments()`, i.e. the `list_ad_payments` action. It selects from `ad_payments` with `ad_requests(store_name, order_number)` embedded, newest first, `.limit(500)`. A service role is needed because `ad_payments` RLS limits reads to the owner (comment in `admin-content`).
- **Filters:** status (`all|paid|initiated|failed`) and a from/to date range. The "to" date includes the whole day (`+ 24h - 1ms`). Filtering is client-side.
- **Stats:** shown, paid, failed, and total paid **grouped by currency**.
- **Table columns:** order #, store, amount (`fmtMoney`, tabular nums), status pill, provider, created, paid, `tap_charge_id` (mono).
- **The only write is `set_ad_request_status(id, 'active'|'pending_payment'|'rejected')`**, applied to the *request*, never the payment row. The backend comment and `DASHBOARD_HANDOFF.md` §4 say: "`create-ad-charge` owns pricing and `tap-webhook` owns 'paid'". `delete_ad_request` refuses if a payment row exists, to keep the audit trail.
- **What is missing:** no detail drawer (the `raw` Tap payload is fetched but never shown), no CSV export, no pagination, no link to the user, no refund flow, and no record of *which admin* overrode a status or *why*.

**Munyati mapping.**
- **Tap subscription payments** (provider pays Normal/Plus/Diamond, requirement 21): the ledger is directly reusable as a "Subscription payments" ledger, with the same "webhook owns paid" rule.
- **Booking payments** (requirement 5/22): these are manual transfers with receipt screenshots, a different and new workflow (§12, module 7). Reuse only the ledger layout, filters and currency totals.

---

## 6. "People" page

`app/(dashboard)/people/page.tsx` manages **podcast hosts and guests** (`people` table: `name_ar`, `name_en`, `role host|guest|both`, `avatar_url`, `is_active`). It is **not** a user-management screen. Lamha's dashboard has **no app-user list**, no ban/role management and no user search.

What is reusable is the pattern: an inline add/edit card, a bilingual name, an avatar upload via `uploadCover`, an active toggle, and stat cards by role. For actual user management, Kolna has the backend side: `admin_list_users`, `admin_set_user_role` and `admin_set_user_banned` (`kolna-al-khafji-ios/supabase/migrations/20260738100000_users_and_bilingual_categories.sql`, `20260740100000_admin_set_user_role.sql`).

---

## 7. Push and notification sending

- **The dashboard has no push UI.** `Nav.tsx` has no notifications entry, and nothing calls a push function.
- **The Lamha backend has two admin-gated FCM senders:**
  - `send-push-notification` sends to one `user_id` (all devices) or one FCM `topic` via FCM HTTP v1. It uses a hand-signed service-account JWT (`FIREBASE_SERVICE_ACCOUNT` secret) and deletes `UNREGISTERED`/`NOT_FOUND` tokens.
  - `send-manual-notification`.
- **Segmentation:** `20260705000000_device_tokens_segments.sql` adds `language`, `region_id`, `city_id` and `topics text[]` (GIN index) to `device_tokens`, so admins can target either by FCM topic (`city_<id>`, `lang_ar`, …) or by SQL filter. **That migration file contains unresolved git merge-conflict markers (`<<<<<<< HEAD` … `>>>>>>>`), so it cannot be applied as committed.**
- **`DASHBOARD_HANDOFF.md` §0.3** says: "Nothing to build in the dashboard beyond a 'send' form if you want one."
- **Kolna is further along:** `notification_campaigns`, `admin_send_campaign`, `admin_send_notification`, `admin_delete_campaign` and `admin_device_tokens` RPCs, with push driven by a DB webhook on `notifications` insert (`docs/research/kolna-backend.md` §9).

For Munyati's push campaigns, use **Kolna's campaign tables and RPCs** together with **Lamha's `device_tokens` segment columns** (fixed), and build a new dashboard UI.

---

## 8. Styling approach

- Everything is in `app/globals.css`, with no Tailwind or component library. The header comment describes it as an "operator console design system": a dark slate canvas, a single amber accent `--accent: #f2a93b`, semantic `--ready/--failed/--info`, `--mono` for technical data, and a "status strip" of stat cards on every list.
- Tokens are CSS custom properties on `:root`. There is **no light theme** and no `prefers-color-scheme`.
- Class names are semantic (`.btn`, `.btn-primary`, `.btn-ghost`, `.btn-danger`, `.pill.ready|processing|failed|neutral`, `.stat.amber|green|red|blue`, `.table`, `.segment`, `.chips`, `.toggle-row`, `.switch`, `.skel`, `.empty`, `.banner`).
- There is a lot of inline `style={{…}}` in the TSX for layout tweaks.
- **Responsive support is minimal.** There are only 2 layout media queries (`max-width: 720px` for `.form-grid.cols-2` and `max-width: 860px`), plus 2 `prefers-reduced-motion` rules. Tables rely on `overflow: auto`.
- Fonts: `--sans: "Inter", system-ui, …`. No web font is loaded and there is no Arabic font.
- Icons: `components/Icon.tsx`, about 23 hand-drawn stroke paths in one record. It has no dependency, but adding icons is tedious.

For Munyati, the visual identity has to change: brand colors `#8A0D3A` burgundy, `#DFC389` gold, `#F2E5D2` cream and `#FAFAEC` ivory suggest a light, warm theme, not a dark slate one. The CSS also uses physical directions in 18 places (`border-right`, `left:`, `text-align: left`, `margin-left`, `background-position: right`), so it would need an RTL rewrite. The token approach and the page anatomy are worth keeping. The CSS file itself is not.

---

## 9. Deployment target and environment variables

- **Deployment target:** I found **no deployment config** in the repo: no `vercel.json`, no `netlify.toml`, no Dockerfile, no GitHub workflow. `next.config.mjs` is `{ reactStrictMode: true }`. A plain `next build` app with middleware fits Vercel naturally, but **I could not verify where it is deployed**. `public/pay-return.html` implies the dashboard's domain also serves the Tap return page, so the domain must be public.
- **Env vars** (from `.env.example` and code):
  - `NEXT_PUBLIC_SUPABASE_URL`: used by both clients, the middleware and the edge-function base URL.
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
  - `SUPABASE_SERVICE_ROLE_KEY`: the comment says "used by route handlers that mint upload targets", but **no code in the dashboard reads it** (`grep` finds no `process.env.SUPABASE_SERVICE_ROLE_KEY`). There are no route handlers (`app/api`). The variable is unused, and committing it was pure exposure.
- **Edge-function secrets** live in the Supabase project: `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`, `FIREBASE_SERVICE_ACCOUNT` and Tap keys.

---

## 10. RTL and Arabic support

- `app/layout.tsx` sets `<html lang="en">` and has no `dir`. All chrome (nav, buttons, headers, errors) is in English.
- Arabic is handled field by field: `dir="rtl"` on Arabic inputs, textareas and table cells (`name_ar`, `title_ar`, …). Eyebrows are bilingual (`تغطيات لمحة · Coverage`). Server validation errors come back in Arabic (`"اسم التغطية مطلوب"`), so the UI mixes languages.
- Data model convention: `name_ar` (required) plus `name_en` (optional). This matches Kolna's bilingual columns and is what Munyati should keep.
- There is no i18n library, no locale switch, no Arabic font, no Hijri or `ar-SA` date formatting (`fmtDate` uses `toLocaleDateString(undefined, …)`, so the output depends on the browser), and no logical CSS properties.

Munyati's admins are Saudi operations staff, so the dashboard should be **Arabic-first (`dir="rtl"`) with an English toggle**. That has to be designed in from the start.

---

## 11. Quality gaps (ranked)

1. **Live service-role key committed** in `lamha_dahsboard/.env.example` (tracked by git, in the only commit). Anyone with repo access has full DB access to Lamha. **Rotate the key in Supabase and replace the file with placeholders.** For Munyati, never put real values in `.env.example`, and add secret scanning.
2. **Next.js 14.2.5** is affected by CVE-2025-29927 (fixed in 14.2.25). The middleware can be bypassed with a crafted `x-middleware-subrequest` header. The impact here is limited because the layout and edge functions also check, but the version needs upgrading.
3. **Single binary admin role.** There are no permissions per area (payments vs content vs marketing), and `send-push-notification` has a hard-coded email allow-list (`admin@lamha.app`).
4. **No audit log.** Status overrides, deletes and settings changes are not attributed to an admin or given a reason. For Munyati's payment-dispute role (requirement 5) this is required.
5. **No pagination or server-side search.** Hard `.limit(500)`/`.limit(200)` caps silently truncate data, for example in the payments ledger after 500 rows.
6. **Non-transactional multi-row writes** (reorder), plus an N+1 `get_*` before each `upsert_*` to avoid clobbering fields.
7. **Two inconsistent data paths:** service-role edge function vs direct JWT writes that rely on RLS not visible in the repo (`app_settings`, `media_assets`).
8. **Untyped API surface:** hand-maintained TS types, `Record<string, any>` forms, and no generated Supabase types.
9. **No tooling:** `next lint` is scripted but there is no ESLint config or dependency, and there are no tests, CI or Prettier.
10. **UX gaps:** `alert()`/`confirm()` for destructive flows, no toasts, no detail drawers, the Tap `raw` payload is fetched but never shown, and there is no export.
11. **Backend hygiene seen in the same repo:** an unresolved merge conflict in `20260705000000_device_tokens_segments.sql`, only 2 of the Lamha migrations are present (most of the schema and RLS is not versioned in this repo), and the README is stale.

---

## 12. Munyati admin dashboard design

### 12.1 Foundational decisions

**a) Fresh app, not a fork.** Start a new repo (e.g. `munyati_dashboard`) with `create-next-app` on Next.js 15, or on the current stable major if newer. I believe Next 16 renames `middleware.ts` to `proxy.ts`, but I could not verify that from this environment, so check before scaffolding. Then copy in the specific files in §13. Reasons:

1. **Leaked key in history.** A fork carries the leaked Lamha key in its git history.
2. **Domain code.** About 80% of the code (media, episodes, coverage, ads) is Lamha-specific and would be deleted anyway.
3. **Foundations the fork lacks.** RTL, a light brand theme, roles, a data-table system and charts would mean rewriting `globals.css`, `Nav`, every table and every form. That is cheaper to do from scratch.
4. **Framework version.** Next 15 means React 19, async `cookies()` (so `lib/supabase/server.ts` needs `const store = await cookies()`), and an up-to-date `@supabase/ssr`.
5. **Reuse is small.** What is worth keeping is about 300 lines and is easy to lift.

**b) Stack additions.** Lamha uses none of these; they are recommendations:
- **UI:** Tailwind CSS plus shadcn/ui (Radix primitives, which support `dir="rtl"`). The alternative is to keep a token CSS file but rewrite it with logical properties. Theme tokens: primary `#8A0D3A`, accent `#DFC389`, surface `#FAFAEC`, muted `#F2E5D2`, with a dark variant.
- **Tables:** TanStack Table with server pagination, sort, filter and CSV export.
- **Forms:** react-hook-form plus zod, sharing schemas with RPC param validation.
- **Charts:** Recharts, or Tremor, for analytics.
- **i18n:** next-intl with an Arabic default, an English toggle, and an Arabic web font (e.g. IBM Plex Sans Arabic or Tajawal, a design decision).
- **Types:** `supabase gen types typescript` committed and regenerated in CI.
- **Hosting:** Vercel, with the custom domain `admin.munyati.co`. Keep the landing site (`munyati.co`) as a separate project so marketing deploys cannot break the admin.

**c) Data access.**
- Use `supabase.rpc('admin_…')` with the admin's own JWT for all reads and writes. Every RPC is `SECURITY DEFINER`, starts with `perform public.require_admin_permission('<perm>')`, writes an audit row, and returns typed JSON with `total_count` for pagination. This is Kolna's `is_admin()` + `admin_*` pattern, extended with permissions.
- Use Server Components for initial reads and Server Actions or client calls for mutations. No service-role key in the Next app.
- Use edge functions **only** where a secret or external API is involved:
  - `admin-sms-campaign` (OurSMS)
  - `admin-push-campaign` / `send-push` (FCM)
  - `tap-webhook` / `create-subscription-charge` (Tap)
  - `admin-sign-upload` only if Storage policies cannot express "admins may upload to `category-icons/`". They can (`storage.objects` insert policy `using (public.is_admin())`), so direct `supabase.storage.from(bucket).upload()` from the browser is simpler.

**d) Roles and permissions** (new; replaces Lamha's single `admin`):

```
admin_roles(id text pk, name_ar, name_en)
  -- seed: owner, ops (bookings/payments/disputes), moderator (reviews/reports/providers verification),
  --       content (cities/categories/CMS/plans), marketing (SMS/push), analyst (read-only)
admin_role_permissions(role_id, permission text)   -- e.g. 'payments.resolve', 'sms.send', 'plans.edit'
admin_users(user_id uuid pk -> auth.users, role_id, is_active, created_by, created_at)
has_admin_permission(p text) returns boolean  -- security definer
is_admin() := exists(select 1 from admin_users where user_id = auth.uid() and is_active)
```

Admins should be separate from `profiles.account_type` (bride/provider), so an app user can never become an admin by editing a profile column. Enforce MFA (Supabase TOTP) for admin logins. The dashboard reads permissions once in the layout and hides nav items. The DB is the authority.

**e) Audit log** (new): `admin_audit_log(id, admin_id, action, entity_type, entity_id, before jsonb, after jsonb, reason text, ip, user_agent, created_at)`. Write it inside every `admin_*` RPC (or with a generic trigger on admin-managed tables), and require `reason` for destructive and money-related actions.

**f) City scoping** (requirement 16): every list RPC takes `p_city_ids uuid[] default null` (null means all). The dashboard has a global city multi-select in the top bar, with an "All" option, persisted in a cookie.

### 12.2 Module catalogue

Legend: **Copy** = lift from Lamha with light edits. **Adapt** = same UX pattern, new data. **New** = nothing comparable in Lamha.

| # | Module | Req. | From Lamha | New work |
|---|---|---|---|---|
| 1 | Overview (home KPIs) | 9 | **Adapt** the `StatCard` strip from `app/(dashboard)/page.tsx` | One `admin_overview(p_city_ids, p_from, p_to)` RPC (Kolna `get_admin_overview_stats` pattern); charts |
| 2 | Cities | 16, 17 | **Adapt** `coverage/settings` `CategoriesPanel` (inline CRUD) plus `coverage/reorder` | `cities(id, name_ar, name_en, is_active, sort_order, center lat/lng)`; soft-disable rather than delete when in use; seed Dammam, Khaybar, Taif (spellings to confirm) |
| 3 | Categories | 18, 19, 20 | **Adapt** `CategoriesPanel` plus `uploadCover` (icon upload) plus reorder | `icon_url`, `cover_url`, `is_active`, `sort_order`, bilingual names; icon preview at app sizes; "services in category" count; delete blocked when services exist |
| 4 | Subscription plans | 2, 8, 11, 23 | **Adapt** the `coverage/settings` `DisplaySettingsPanel` (clamped numeric settings) and the `android` singleton form | `subscription_plans(code normal/plus/diamond, name_ar/en, price_sar_monthly, price_sar_yearly null, max_services, max_stores, features jsonb, badge, is_active, sort_order)`; global `trial_days=60`; plan-change preview of affected providers; Tap product mapping |
| 5 | Providers and verification | 1, 2, 14, 24 | **Adapt** list anatomy (stats, segment, chips, table) and the `people` avatar/inline-edit pattern | Provider queue (pending/approved/suspended); documents viewer (CR / freelance certificate, signed URLs); approve/reject with reason; subscription status, trial end date, services used vs plan limit; impersonation-free "view as" preview; demo-booking status |
| 6 | Stores | 14 | **Adapt** provider table | `stores(provider_id, …)` CRUD/verify; link/unlink |
| 7 | Bookings browser | 4, 20 | **Adapt** payments filters (status + date range) and table | Full status timeline (requested, approved / declined / reschedule_proposed, accepted, awaiting_payment, proof_uploaded, paid_confirmed, completed / cancelled / disputed); filters by city, category, provider, bride; admin cancel/override with reason; flag "same-category active booking" violations |
| 8 | Payment proofs and disputes | 5, 22 | **Adapt** `payments/page.tsx` ledger (filters, totals) and the "override only the request, never the money row" rule | Proof viewer (screenshot from private bucket via signed URL, zoom, image hash to detect reused screenshots); provider bank/wallet details at time of booking (snapshot); dispute cases `disputes(booking_id, opened_by, reason, status, assigned_admin, resolution, messages)`; SLA timers; resolve actions (mark paid, refund instructed, ban user, suspend provider) all audited |
| 9 | Subscription payments (Tap) | 21 | **Copy** `payments/page.tsx` almost as-is (rename to subscriptions; keep `tap_charge_id`, status, totals by currency) | Detail drawer showing `raw`; CSV export; server pagination |
| 10 | Reports and flags | 28 | **None** | `reports(target_type user/provider/service/review/store, target_id, reporter_id, reason, details, status, assigned_admin)`; queue with bulk actions; link to target; actions hide / warn / suspend / ban |
| 11 | Reviews moderation | 15 | **None in Lamha** (Kolna has the backend: `admin_set_review_status`, `admin_hide_review`, `admin_delete_review`, approval workflow, masking) | Two-sided reviews (bride→provider, provider→bride) only after `completed`; moderation queue; admins see full names, app shows masked names (Kolna masking, see `kolna-backend.md` §8.5) |
| 12 | Users (brides and providers) | 1, 9 | **Adapt** the `people` table look | Search by phone/name, account type, city, status; ban/unban (Kolna `admin_set_user_banned`); view bookings, reviews and reports; budget value (requirement 13) read-only; delete-account requests |
| 13 | CMS: strings, images, pages | 19, 29 | **Adapt** `android/page.tsx` (singleton form with live-vs-edited state) plus `uploadCover` | `cms_strings(key, ar, en, updated_at)` with a version bump that the iOS app polls; `cms_assets(key, url, w, h)`; `cms_pages(slug privacy/terms/about/faq, body_ar, body_en, published)` (Kolna `cms_pages` bilingual); the landing site and the app both read pages from here |
| 14 | App settings / remote config | 19 | **Copy** `android/page.tsx` pattern (kill switch → iOS force update + maintenance mode) | `app_config` feature flags (Kolna `get_config`); min supported version; support contact (contact@munyati.co); demo-booking template text |
| 15 | Push campaigns | 26 | **None in UI.** Backend: Lamha `send-push-notification` + `device_tokens` segments; Kolna `notification_campaigns` / `admin_send_campaign` | Composer (ar/en, deep link picker from a typed route list `munyati://…` / `https://munyati.co/…`), audience builder (role, city, category interest, plan, trial status), preview count, schedule, send history with delivery stats |
| 16 | SMS campaigns (OurSMS) | 10 | **None** | `sms_campaigns`, `sms_messages` (per recipient status), opt-in/opt-out flag on profiles, audience builder shared with push, cost estimate (segments × recipients), test send, rate-limited sender edge function. OTP traffic stays separate. OurSMS API details, sender-name registration and any Saudi marketing-SMS rules (such as an "-AD" sender suffix or sending-hour limits) are **not verified here** and must be confirmed with OurSMS / CST |
| 17 | Analytics | 9 | **Adapt** `StatCard` only | Event tables (`analytics_events` à la Kolna `record_analytics_event`, partitioned monthly, rollups via `pg_cron` into `analytics_daily`); dashboards: users by role/city/day, active providers by plan, services per category, booking funnel (view → request → approved → paid → completed), approval/decline/reschedule rates, time-to-approve, trial → paid conversion, budget distribution, top searches, screen/tap heatmaps per screen, revenue (subscriptions). Exclude `is_demo` bookings and the demo bride everywhere |
| 18 | Error logs | 9 | **None** | `client_error_logs` + `server_error_logs` (as proposed in `kolna-backend.md` §17 item 16); grouping by code/version/screen; spike chart; link to user |
| 19 | Audit log | 5 | **None** | Viewer over `admin_audit_log` with entity filters and before/after diff |
| 20 | Admin team and roles | | **None** (Lamha: single `user_roles` row) | Invite admin (email + forced MFA), assign role, deactivate; permission matrix view |
| 21 | Demo booking for new providers | 24 | **None** | Template editor (service name, date offset, message) in settings; backend trigger on provider approval creates one `is_demo=true` booking from a system "demo bride"; dashboard shows which providers completed it (onboarding funnel) |

### 12.3 Module notes that need more than a table row

- **Payment-proof audit (module 8)** is the most sensitive screen.
  - Store screenshots in a **private** bucket (`payment-proofs/<booking_id>/…`), never a public URL as Lamha `covers` does. Read them through short-lived signed URLs, as `admin-content` `get_options` does for media.
  - Snapshot the provider's transfer details (IBAN / wallet / STC Pay, etc.) onto the booking at approval time, so a provider who later edits their bank details cannot rewrite history.
  - Show the expected amount, the bride's claimed amount, and upload time against the approval time.
  - Admin actions follow Lamha's rule that only the request/booking state is overridable, never the money facts. Every action needs a reason and goes to `admin_audit_log`.
- **Plan limits (module 4)** must be enforced in the DB (a trigger on `services` insert checks the active plan's `max_services`), not only in the app. The dashboard shows "providers over limit after this change" before saving a lower limit.
- **Same-category rule (requirement 20)** should be a DB constraint (a partial unique index on `(bride_id, category_id) where status in (active statuses)`). The bookings browser shows the reason when an override is attempted.
- **Remote content (module 13).** Category icons and CMS images use direct Storage uploads (adapted `uploadCover`). The app caches by URL plus `updated_at`, so changing a logo needs no build. Strings use a `cms_strings` version number that the app checks on launch. This replaces Lamha's approach of hard-coding labels in the dashboard.
- **Analytics (module 17).**
  - Lamha has no charts or event pipeline. Kolna has `analytics_events` but computes aggregates live on every call, with no rollups or retention (`kolna-backend.md` §13).
  - For Munyati, ingest through a rate-limited RPC or edge function batch endpoint, partition by month, keep 13 months raw, and have `pg_cron` roll up nightly into daily tables that the dashboard reads.
  - Firebase Analytics/Crashlytics can run alongside for device-level crash detail, but the owner wants numbers in the admin, so first-party tables are the source for the dashboard.

### 12.4 Suggested navigation (Arabic-first, permission-filtered)

```
الرئيسية Overview
التشغيل Operations: Bookings · Payment proofs & disputes · Reports & flags · Reviews
المزوّدون Providers: Providers · Stores · Subscriptions (Tap ledger) · Plans
المستخدمون Users: Brides · All users
المحتوى Content: Cities · Categories · CMS strings · Images · Pages · App settings
التسويق Marketing: Push campaigns · SMS campaigns · Audiences
التحليلات Analytics: Users · Bookings funnel · Categories & services · Revenue · Errors
الإدارة Admin: Team & roles · Audit log
```

### 12.5 Build order

1. **Phase 1 (with app MVP):** scaffold, auth with MFA, roles, audit log, cities, categories, plans, providers verification, bookings browser, payment proofs and disputes, users, app settings / force update, CMS pages (privacy and terms are needed for App Store review).
2. **Phase 2:** reviews moderation, reports and flags, Tap subscription ledger, push campaigns, CMS strings and images, demo-booking template.
3. **Phase 3:** analytics dashboards with rollups, error logs, SMS marketing (after OurSMS sender registration).

---

## 13. Reuse table

| Item (repo-relative) | Verdict | What to change |
|---|---|---|
| `lamha_dahsboard/lib/supabase/client.ts` | **As-is** | none |
| `lamha_dahsboard/lib/supabase/server.ts` | **Adapt** | `await cookies()` on Next 15+ |
| `lamha_dahsboard/middleware.ts` | **Adapt** | Keep the cookie refresh; add an `admin_users` check via `am_i_admin()` RPC (or keep it in the layout); update the matcher; rename to `proxy.ts` if on a Next version that requires it |
| `app/(dashboard)/layout.tsx` gate | **Adapt** | `user_roles` lookup becomes an `admin_my_permissions()` RPC; render nav from permissions |
| `app/login/page.tsx` | **Adapt** | RTL, brand, MFA step, "forgot password" |
| `lib/adminApi.ts` `call()` wrapper | **Adapt** | Keep for edge functions (SMS/push/Tap); use `supabase.rpc` with generated types for everything else |
| `uploadCover()` + `sign_cover_upload` | **Adapt** | Bucket per purpose (`category-icons`, `cms`, `city-images`); image-type and size validation; or replace with direct `storage.upload` under admin-only Storage policy |
| `lib/upload.ts` `xhrSend` | **As-is (helper only)** | Drop the media-specific `create-upload`/`mark-uploaded` flow |
| `lib/format.ts` | **Adapt** | `ar-SA` locale, SAR default, optional Hijri, Asia/Riyadh time zone |
| `components/StatCard.tsx`, `StatusBadge.tsx` | **Adapt** | Retheme; map Munyati booking/proof/report statuses |
| `components/Icon.tsx` | **Replace** | Use `lucide-react` (pairs with shadcn) |
| `components/Nav.tsx` | **Adapt** | Permission-filtered sections, RTL, collapsible on mobile |
| `app/globals.css` | **Do not copy** | Keep only the idea (tokens, status-pill semantics, stat strip); rebuild on Tailwind tokens with logical properties |
| `payments/page.tsx` | **Adapt** | Becomes the Tap subscription ledger; layout reused for booking proofs |
| `coverage/settings/page.tsx` (`CategoriesPanel`, `DisplaySettingsPanel`) | **Adapt** | Template for cities, categories and plan editors |
| `coverage/reorder/page.tsx` | **Adapt** | One transactional `admin_reorder` RPC, drag handle (dnd-kit) |
| `android/page.tsx` | **Adapt** | iOS force-update + maintenance + feature flags |
| `people/page.tsx` | **Pattern only** | Inline CRUD with avatar; not user management |
| `AssetPicker.tsx`, `LibraryTable.tsx`, episodes/programs/coverage/upload pages | **Do not reuse** | Lamha media domain |
| `public/pay-return.html` | **Adapt (website repo)** | Becomes `munyati.co/pay-return` for Tap subscription checkout, deep link `munyati://pay-return`; better as a universal-link path served from the landing site than from the admin domain |
| Backend: `admin-content` action switch | **Do not reuse** | Replace with permission-checked `admin_*` RPCs |
| Backend: `send-push-notification` FCM v1 signer | **Adapt** | Remove the hard-coded admin email; reuse the JWT signer and dead-token cleanup |
| Backend: `device_tokens` segment columns | **Adapt** | Fix the merge conflict; use `city_id uuid` referencing `cities`, plus `account_type` and `language` |

**Missing entirely and must be built:**
- roles, permissions and admin MFA
- audit log
- server-paginated data tables and CSV export
- RTL/i18n
- charts and analytics rollups
- error-log views
- moderation queues (reviews, reports)
- disputes workflow and private proof storage
- SMS (OurSMS) campaigns
- push campaign UI
- CMS strings and images versioning
- plan-limit enforcement
- demo-booking template
- city scoping on every list

---

## 14. Not verified / open questions

- The deployment host of `lamha_dahsboard`: no config is in the repo.
- RLS policies on Lamha `app_settings` and `media_assets`, which the dashboard writes and reads directly: the schema is not in the workspace.
- OurSMS API shape, marketing-SMS regulations (sender ID, opt-out wording, allowed hours) and pricing.
- The exact Next.js current major and whether `middleware.ts` has been renamed in it.
- City spellings: the owner wrote "Damam - Khaibar - Tafeef". These are presumably الدمام (Dammam), خيبر (Khaybar) and الطائف (Taif). Confirm with the owner before seeding.
- Whether App Store rules affect selling provider subscriptions through Tap rather than in-app purchase. This is out of scope for the dashboard but affects the subscriptions module, so flag it to the owner.
