# Munyati admin dashboard (منيتي — لوحة الإدارة)

Next.js 15 (App Router) + `@supabase/ssr`, Arabic-first RTL, no UI library. It lives here for now
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
Deploy anywhere Next.js runs (Vercel is simplest). Set the two `NEXT_PUBLIC_*` variables there.

## First admin
1. Supabase → Authentication → Users → **Invite user** with your email, then set a password.
2. In the SQL editor: `insert into admin_users (user_id, role_id) select id, 'owner' from auth.users where email = 'you@munyati.co';`
3. Add teammates later from the Team page (invite them in Supabase first).
