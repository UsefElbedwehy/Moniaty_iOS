# Munyati admin dashboard (منيتي — لوحة الإدارة)

Next.js 15 (App Router) + `@supabase/ssr`, Arabic-first RTL with an English (LTR) switch in the sidebar, no UI library. Text is written inline as `t("عربي", "English")` from `i18n()` (`lib/i18n.ts`); status labels live in `lib/labels.ts`. It lives here for now
so it ships with the backend contract it depends on (`supabase/migrations`); it can move to its own
`munyati_dashboard` repo later (`git subtree split --prefix dashboard`).

## Security model
- Admins sign in with **email + password** (Supabase Auth) and must be active in `admin_users`.
- The dashboard only has the **anon key**. Every query runs as the signed-in admin and is checked
  in Postgres: RLS (`is_admin()` / `has_admin_permission()`) for reads, `admin_*` SECURITY DEFINER
  RPCs for actions that notify users, change bookings or must be audited. **Never** add the
  service-role key here.
- Every admin change is in `admin_audit_log` (Audit page).
- Roles: owner (everything), ops, moderator, content, marketing, analyst. See the Team page.

## Pages
| Page | What |
|---|---|
| Home | Queues needing action (join requests, disputes, reviews, reports within 24 h, tickets, payments to check, duplicate receipts) and platform numbers |
| Providers | Filter, search, approve / reject / suspend (with a note to the provider), verified badge, pause a service, free months on a plan |
| Bookings / Disputes | Search by reference, timeline, receipt images (10-minute signed links), dispute decisions |
| Reviews | Moderation queue with full names (the app only ever gets masked names), publish / reject / hide, ban from reviewing |
| Reports / Support | Report queue with age, ticket replies (sent to the user as a notification) |
| Users | Search by phone or name, ban from reviewing |
| Subscriptions / Plans | Tap payments ledger (raw charge visible), plan prices, limits, features and badges |
| Cities & categories | Add or edit, order, activate, category icons uploaded to the `content` bucket |
| Pages & strings | CMS pages (Markdown) and app text overrides |
| Notifications | Push campaigns by audience and city |
| Settings | Timeouts, trial, reviews, SMS per event, force update, support contacts, raw JSON |
| Analytics / Audit / Team | Funnel, daily events, searches, errors; change history; admins and roles |

## Run
```sh
cp .env.example .env.local     # project URL + anon key
npm install
npm run dev                    # http://localhost:3000
npm run build && npm start     # production
```
## Hosting (Cloudflare Workers)
Live at https://munyati-admin.munyati-dashboard.workers.dev: Worker `munyati-admin` in Munyati's own
Cloudflare account (`moniaty.official@gmail.com`, account ID `0c80992cee84e730d01943c5cd956dad`),
built with OpenNext (`@opennextjs/cloudflare`, config in `wrangler.jsonc` and `open-next.config.ts`).
It moved from Vercel on 2026-11-14 because Vercel's free plan had disabled the deployment (HTTP 402).

- **Auto-deploy:** every push to `main` that touches `dashboard/` runs
  `.github/workflows/deploy-dashboard.yml` (also runnable by hand: `gh workflow run "Deploy to Cloudflare"`).
  It needs the repo secret `CLOUDFLARE_API_TOKEN` ("Edit Cloudflare Workers" token of that account) and
  the repo variables `CLOUDFLARE_ACCOUNT_ID`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
  `NEXT_PUBLIC_*` values are inlined at build time, so they must exist wherever the build runs.
- **Manual deploy:** `npx wrangler whoami` (must show the Munyati account), then `npm run deploy`.
- **Test the Workers build locally:** `npx opennextjs-cloudflare build && npx wrangler dev --port 8799`
  (or `npm run preview`).
- `compatibility_date` in `wrangler.jsonc` can't be later than the bundled `workerd` release date.
- Custom domain (`admin.munyati.co`): Cloudflare → Workers & Pages → munyati-admin → Settings → Domains.

## First admin
1. Supabase → Authentication → Users → **Add user → Create new user** with your email and a strong
   password, and tick **Auto Confirm User**. (Don't use *Invite user*: the dashboard has no page for
   accepting invites, so the invite link can't set a password.)
2. In the SQL editor: `insert into admin_users (user_id, role_id) select id, 'owner' from auth.users where email = 'you@munyati.co';`
3. Add teammates later from the Team page (create them in Supabase the same way first).
