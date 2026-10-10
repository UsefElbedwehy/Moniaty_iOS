# منيتي · Munyati — iOS

Everything for the bride, in one place: a Saudi marketplace where brides discover and book
wedding services, and providers manage requests and schedules.

- Plan and decisions: [`docs/PLAN.md`](docs/PLAN.md)
- Backend (Supabase): [`supabase/README.md`](supabase/README.md)
- Logo and mockups: [`design/`](design/)

## Run it on your Mac

1. Xcode 16 or newer, and XcodeGen: `brew install xcodegen`
2. In this folder: `xcodegen generate`, then open `Munyati.xcodeproj`
3. Set your team: `DEVELOPMENT_TEAM` in `project.yml` (or Signing & Capabilities in Xcode)
4. Optional, for real data and push:
   - `App/Resources/BackendConfig.plist`: Supabase project URL + anon key
   - `App/Resources/GoogleService-Info.plist`: from the Firebase console
5. Run the **Munyati** scheme on an iOS 17+ simulator.

Without step 4 the app runs on built-in sample data with Firebase switched off, so you can
try the flows straight away. Test sign-in on sample data: any Saudi mobile (5XXXXXXXX) and the
code `123456`.

Tests: the App scheme's test action (Cmd-U) runs every package's tests on the simulator.
Core, Networking and Shared also run with `cd Packages/<Name> && swift test`; the feature
packages use iOS-only APIs, so run those from Xcode.

## Status

- **Phase 1 (foundation):** design system and logo, sign-in with role choice, the two
  four-tab shells, cities with "All", remote config and strings, analytics, push, deep links.
- **Phase 2 (discovery):** brides browse categories, search with filters (within budget,
  female staff only, sort), open service / provider / store pages, save favorites, set a
  budget, share links and explore the map. Providers fill in their join form, services (with
  photos) and stores in "My studio"; nothing is public until an admin approves them.
- **Phase 3 (booking):** brides request a free time slot; providers approve, decline or
  propose another time; brides transfer the full amount and upload the receipt; providers
  confirm it and mark the service done. Either side can cancel or report a problem. New
  providers get a demo booking, and providers set working hours and payout methods in
  "My studio". Deadlines run on pg_cron, and key events also go out by SMS.
- **Phase 4 (subscriptions):** Normal / Plus / Diamond plans paid through Tap, a 2-month
  free trial from approval, plan limits (services, stores, photos), boosted search and a
  featured badge, trial and renewal reminders, and an insights screen for providers.
- **Phase 5 (trust):** reviews both ways after a completed booking (names masked, checked
  before publishing), report and block from any provider, service, store, review or booking,
  and a support screen with tickets.
- **Phase 6 (admin dashboard):** `dashboard/`, a Next.js app in Arabic for running the business:
  approvals, bookings and disputes, moderation, payments, plans, content, settings, push
  campaigns, analytics, audit log and team roles. See `dashboard/README.md`.
- **Phase 7 (website):** `website/`, the munyati.co site with legal pages, support, account
  deletion and universal links. See `website/README.md`.
- **Your checklist:** `docs/OWNER_TODO.md`. **Continuing locally:** `docs/HANDOFF.md`.
