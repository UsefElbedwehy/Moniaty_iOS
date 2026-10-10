# Munyati (منيتي) — instructions for Claude

Munyati is an Arabic-first iOS marketplace where **brides** in Saudi Arabia book wedding services
from **service providers** (makeup, photography, venues, henna…). Providers subscribe to list
services; brides book a date/time, pay the provider directly by bank transfer or wallet, and
upload the receipt. Repo name is `Moniaty_iOS`, but the brand is **Munyati / منيتي** everywhere
(domain munyati.co, bundle id `co.munyati.app`).

## Read first
- `docs/PLAN.md`: product spec, booking state machine, data model, phases. **§16 holds the
  owner's decisions; follow them** (e.g. provider subscriptions via Tap for now; full payment
  only; providers need admin approval; cities Dammam/Khobar/Qatif, editable).
- `docs/research/*.md`: background research (App Store rules, OurSMS, costs, Saudi market,
  and analyses of the owner's earlier apps Kolna Al-Khafji and Lamha).
- `design/mockups/` and `design/logo/README.md`: approved screen mockups and logo usage.
- `supabase/README.md`: backend setup and rules.

## Architecture (from Kolna Al-Khafji)
- SwiftUI, iOS 17+, Swift 6 strict concurrency, MVVM + coordinators, local SPM packages,
  **XcodeGen** (`project.yml` is the source of truth; `*.xcodeproj` is generated and ignored).
- `Packages/Core` (ViewState, AppError, coordinator, remote config model) ·
  `Networking` (the only module that knows URLs; `APIEndpoint` namespaces) ·
  `Shared` (analytics recorder, auth gate, cache, image loading, `RemoteStrings`) ·
  `DesignSystem` (Munyati colors/fonts/components, brand assets) ·
  `Authentication` (role choice → phone → OTP → name).
  Feature packages live under `Packages/Features/<Name>`: `Catalog` (bride discovery: home,
  search, details, favorites, budget, map; `CatalogRoute` destinations), `ProviderStudio`
  (provider's Home tab: join form, services, stores, photo upload) and `Booking` (requests,
  the booking lifecycle for both roles, receipts, disputes, working hours, payout methods;
  `BookingRoute` destinations). Each has a Remote and a Mock repository; the App picks one in
  `AppEnvironment`. Next: subscriptions, then reviews.
- `App/` is the composition root: `AppEnvironment` builds repositories and is the **only**
  place that imports Firebase or knows Supabase. Features receive protocols and closures.
- The app talks to Supabase over plain HTTPS (PostgREST RPCs + edge functions); it does
  **not** use the Supabase SDK.

## Conventions
- **Arabic first, RTL**, English second. Every user-facing string is localized (ar + en).
  App-target strings go through `L10n` (dashboard overrides via `RemoteStrings`); package
  strings use their module bundle.
- Use DesignSystem tokens (`Color.ds…`, `Font.ds…`, `DSSpacing`, `DSRadius`), never literals.
  Burgundy `#8A0D3A` primary, gold `#DFC389` for ornaments only (never small text on ivory).
- Analytics: curated events via `@Environment(\.analytics)` (`AnalyticsEvent` must match the
  Postgres enum); screens with `.trackScreen(_:)`; handled errors with `analytics.error`.
- Deep links: one parser, `App/Sources/Composition/DeepLink.swift`
  (`https://munyati.co/<p|s|store|c|b>/<id>`, `munyati://…`). Push payloads carry `deep_link`.
- Backend: RLS on every table, client writes only through RPCs, void RPCs return `jsonb`,
  admin checks via `has_admin_permission()`, admin tables audited. Migrations are additive.
- Phone numbers: Saudi mobiles only (`+9665XXXXXXXX`).

## Working in the cloud sandbox
- There is no Swift/Xcode toolchain on Linux: Swift code cannot be compiled here. Keep changes
  careful and small, mirror existing patterns, and say plainly that the owner must build in
  Xcode (`brew install xcodegen && xcodegen generate`, then open `Munyati.xcodeproj`).
- SQL **can** be verified: Postgres 16 is available locally; see "Testing migrations locally"
  in `supabase/README.md`.
- Edge functions can be type-checked with Deno from npm (`npm i deno`), then `deno check`.
- Develop on the session's `claude/*` branch; never push to `main` without being asked.
