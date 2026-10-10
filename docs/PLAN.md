# Munyati (منيتي) — Product & Technical Plan

> Status: **v1.1 — owner decisions recorded (§16)**. Items once marked [DECIDE] are resolved there.
> Evidence for each recommendation is in `docs/research/*.md`.

## 1. Product in one paragraph

Munyati ("my wish") is an Arabic-first iOS app where **brides** in Saudi Arabia discover and book wedding services (makeup, henna, photographers, venues, kosha, sweets…). **Service providers** subscribe (Normal / Plus / Diamond, first 2 months free) to list their services and stores. A bride sets her **budget**, browses by **city** and **category**, and requests a booking for a date and time. The provider approves, declines or proposes a new time. After approval, the bride **pays the provider directly** (bank transfer or wallet, outside the app) and uploads the receipt. The provider confirms receipt, and admins can audit everything to resolve disputes. After the service is completed, both sides rate each other, with names shown masked.

**Brand:** use **Munyati / منيتي** everywhere (matches `munyati.co` and `contact@munyati.co`). Retire the spelling "Moniaty" except in the GitHub repo name. Bundle ID: `co.munyati.app`. Logo: B wordmark + A ring icon (`design/logo/README.md`).

## 2. Big decisions (recommendations)

| # | Topic | Recommendation | Why |
|---|---|---|---|
| D1 | Codebase base | Start from **Kolna Al-Khafji's** architecture: SPM packages, XcodeGen, Swift 6, iOS 17. Take selected pieces from Lamha. | It's the cleaner, more modular, more tested of the two apps (`research/kolna-ios-architecture.md`) |
| D2 | Backend | **Supabase Pro** (Postgres, Auth, Storage, Edge Functions), region **Frankfurt** after a quick latency test against Mumbai. Supabase has no Middle East region. | The data is relational and the hard rules (#2, #13, #20) are easy to enforce in Postgres. About $35–55/month at launch (`research/backend-stack-and-cost.md`). |
| D3 | Push | **FCM**, sent from a Supabase Edge Function (reuse Kolna `send-push`), with a deep link in every payload | Free and already built |
| D4 | Analytics | 3 layers: **Postgres** (business events, audit log, error log, shown in the dashboard) + **Firebase Analytics** (every tap and screen, free) + **Crashlytics** (crashes) | Covers "analytics for everything" at about $0 extra |
| D5 | Map | **Apple MapKit** + PostGIS | Free, already in Kolna |
| D6 | **Provider subscriptions** | **Tap** for now (owner decision, §16). Built so that adding Apple in-app purchase later is additive. | Apple recommends IAP (guideline 3.1.1) and Tap-only carries rejection risk; the entitlement layer is independent of the payment source (`research/app-store-policy.md` §1) |
| D7 | Bride → provider payment | Manual transfer + receipt upload, as you described. Munyati never touches the money. | Allowed by Apple (3.1.3(e)); wording must say "pay the provider directly" |
| D8 | OTP & marketing SMS | **OurSMS**, reusing Kolna's `send-otp` / `verify-otp`: hashed codes, rate limits, Saudi numbers only | Already in production. **Start sender-name registration now; it takes 2–3 weeks and needs your CR.** |
| D9 | Remote content | Strings, category icons, banners, onboarding images, CMS pages and config all come from the database and storage, with bundled fallbacks | Allowed by Apple because it's data, not code. Kolna already has most of it. |
| D10 | Admin dashboard | **New Next.js app** in its own repo (`munyati_dashboard`), Arabic-first RTL. Copy only the useful bits from `lamha_dahsboard`. | The Lamha dashboard has no RTL, roles or audit log, and has a leaked key in its history (§15) |
| D11 | Website | Static bilingual site on **munyati.co** in its own repo (`munyati_web`): landing, provider page, privacy, terms, support, account deletion and the universal-links file | Required for App Store review and for universal links |
| D12 | Design | **I design it in code**: SwiftUI design system from your colors and logo, with HTML mockups of key screens for your approval before building. Claude Design is optional (§13). | Faster and cheaper, and consistent with the components |

## 3. Users, roles & navigation

**Roles:** `bride` (customer) and `provider`, chosen once during sign-up (requirement 1). **Admins** live in a separate table and can never be created from the app. Guests can browse without an account; login (phone + OTP) is requested only when booking, favoriting or reviewing. Apple prefers this.

**4 native tabs (requirement 7)**, using the system `TabView`, Arabic RTL first:

| Tab | Bride | Provider |
|---|---|---|
| الرئيسية Home | Budget card, categories, featured and nearby providers, banners | Today's agenda, new requests, subscription status, insights |
| استكشف Explore | Map of providers and stores (MapKit), city and category filters | Same map (to see competitors and the market) |
| حجوزاتي My Bookings | Her bookings by status with a timeline | Request inbox + calendar of approved bookings |
| حسابي Profile & Settings | Budget, cities, language, notifications, support, report, delete account | Services, stores, payment methods, plan & billing, working hours, profile |

## 4. Core flows

### 4.1 Sign-up
1. Splash, then onboarding (3 slides, images from CMS).
2. **Choose role**: «أنا عروس» / «أنا مقدّمة خدمة» ("I'm a bride" / "I'm a service provider").
3. Phone (+966 5x) → OTP (OurSMS) → name.
4. **Bride:** choose cities (multi-select or All), optional wedding date, **budget** (skippable, editable later), then Home.
5. **Provider:** business name, categories, cities, (optional) CR or freelance-certificate number for a "verified" badge, first service. The 2-month trial starts and the **demo booking arrives** (§4.6).

### 4.2 Booking state machine (requirement 4)
```
requested ──provider──► approved(awaiting_payment) ──bride uploads receipt──► payment_submitted
    │                         ▲                                                   │
    │ provider proposes        │ bride accepts                     provider confirms│  provider rejects
    ▼                          │                                                   ▼          │
reschedule_proposed ───────────┘                                         payment_confirmed     ▼
    │ bride rejects → cancelled                                                │      back to awaiting_payment
    ▼                                                                          ▼      (reason shown)
declined / cancelled_by_bride / cancelled_by_provider / expired           completed ──► reviews unlocked
                        any payment state ──either side──► disputed ──admin──► resolved
```
- Every transition goes through one server function that checks who is allowed to do what, and writes an append-only `booking_events` row. That table doubles as the audit trail admins see.
- **Timeouts** (configurable in the dashboard):
  - An unanswered request expires after 48 h.
  - An unanswered reschedule proposal expires after 24 h.
  - If the bride doesn't pay within 48 h of approval, she gets reminders and then the booking expires.
  - If the provider doesn't confirm a receipt within 48 h, it auto-escalates to admin.
- **Double-booking guard:** the database rejects overlapping time slots for a provider when capacity = 1.
- **Push + in-app notification** on every transition, each with a deep link to the booking.

### 4.3 Manual payment & receipts (requirements 5, 22)
- The provider adds payment methods: **IBAN** (validated SA + 22 digits), **instant-transfer alias** (سريع by mobile number), or a **wallet** (STC Bank, urpay, …), plus the **account-holder name**.
- After approval, the bride sees: the amount, the provider's methods, and a **booking reference code** (e.g. `MN-7K3QX`) to write in the transfer note.
- The bride uploads the screenshot **and** enters the amount, time and sending bank. The image goes to a **private** bucket and is shown through short-lived signed links.
- **Anti-fraud:**
  - Every receipt image is hashed, and reused or near-duplicate receipts are flagged.
  - Payment details are snapshotted onto the booking at approval.
  - Payment methods are frozen while a payment is pending; editing them needs an OTP and creates an audit row.
  - The provider must tap «تم استلام المبلغ في حسابي» ("I received the amount in my account").
  - Admins see a provider risk score.
- **Disputes:** either side can open one within X days, with evidence. It freezes the booking and the reviews. An admin resolves it and every action is audited.
- **Refunds** use the same flow in reverse (provider → bride), with a receipt.
- **Full amount only** for now; `deposit_amount` is reserved in the data model for later (§16).

### 4.4 Budget (requirement 13)
- The bride sets her total budget during onboarding (skippable). It can be edited from Home or Profile.
- **Remaining = budget − the price of each active or approved booking.** The amount is reserved when a booking is approved and released if it's cancelled.
- Home and Explore have a **"within my budget"** switch that shows services whose price ≤ remaining. A budget card shows spent and remaining by category.
- Suggested ranges per category (e.g. "makeup: usually 350–3,000 SAR") are shown as hints only.

### 4.5 One booking per category (requirement 20)
- A database rule: a bride can have **only one active booking per category** (requested → payment_confirmed, or disputed) until it is completed or cancelled. It applies across all providers.
- Per-category flag `allows_parallel_bookings`, editable in the dashboard, can exempt a category later if needed (e.g. henna night + wedding). It defaults to false: only the same category is blocked (§16).
- The app disables "Book" and explains which booking is blocking it.

### 4.6 Demo booking for new providers (requirement 24)
- Sent **once per provider**, automatically on registration, from a fictional "عروس تجريبية" ("demo bride"). It's clearly labelled «طلب تجريبي» ("demo request") on the card, the detail screen and the notification.
- The provider can go through the whole flow: approve, propose a new time, see a sample receipt, confirm, complete.
- It's excluded from analytics, ratings, the budget rule, the category rule and admin queues.
- No fake-urgency upsell copy (Apple rule).
- Combined with an in-app tip tour, this is the main "see the value" moment that leads into the subscription.

### 4.7 Subscriptions (requirements 2, 8, 11, 23)
- Plans are **Normal / Plus / Diamond**, monthly (yearly later), in **one Apple subscription group**, so upgrades and downgrades are handled by Apple.
- The **2-month free trial** is an Apple introductory offer (2 months is a supported length). It's also tracked per provider account on our side to stop trial abuse.
- **The dashboard can edit:** plan names, descriptions, feature lists, **max services per plan**, max stores, badges, order and visibility.
- **Only App Store Connect can change:** iOS prices and trial length. The app always shows Apple's live price.
- **Plans (approved, editable):**

| | Normal | Plus | Diamond |
|---|---|---|---|
| Active services | 1 | 3 | 10 |
| Linked stores | 0 | 1 | 3 |
| Portfolio photos per service | 6 | 15 | 30 |
| Search placement | standard | boosted | top + "featured" badge |
| Insights (views, taps, conversion) | basic | full | full + export |
| Home banner slots | — | — | monthly |

- Enforced on the server: a provider can't publish more services than their plan allows. On downgrade, services above the limit are **paused** (not deleted) and the provider chooses which stay live.
- **Ending the trial:**
  - A countdown banner starts 14 days before the trial ends.
  - A value summary appears ("this month: 230 profile views, 4 requests").
  - A paywall comparing plans opens when the provider tries to add another service.
  - Push and SMS reminders go out at 7, 3 and 1 days before the end.
  - After the trial without a subscription, services are hidden (not deleted) until the provider subscribes.

### 4.8 Reviews (requirement 15)
- Unlocked only after a booking is **completed**. Each side gets one review per booking: bride → provider (stars + text + optional photos) and provider → bride (stars + private note).
- **Names are masked like Maalim Al-Khafji**, every word becomes its first 2 letters + `****` (e.g. «نو**** مح****»). **Masking happens on the server**: Kolna masks only in the app, so full names leak through its API, and we fix that here. Admins see full names.
- Reviews go through moderation (approval queue, hide, ban), reusing Kolna's workflow.

### 4.9 Cities & categories (requirements 16, 17, 18)
- **Cities** are a dashboard-managed table (Arabic and English names, map center, active flag, order).
  - The bride picks one or more cities, or «الكل» ("All"). Every list, search and map query filters by that choice.
  - Providers pick the cities they serve.
  - Launch cities: **Dammam, Khobar, Qatif** (editable).
- **Categories** are a dashboard-managed table: Arabic and English names, **icon from storage (changeable anytime)**, cover image, order, active flag, the parallel-bookings flag and the store flag.
  - Seed list: 14 launch categories plus 11 inactive ones (`research/saudi-market-and-legal.md` §1.2).

### 4.10 Stores (requirement 14)
- A provider can link stores (name, logo, address, location on the map, city, Instagram / WhatsApp). Each store has a profile page and its services.
- Stores appear as pins in Explore. The number of stores is limited by the plan.

### 4.11 Support, report, flag (requirement 28)
- **Report** is available on any provider, service, store, review, booking or user. It goes to the admin queue, and admins act on reports within 24 h (Apple rule 1.2).
- Users can **block** a user.
- **Support:** an FAQ (CMS), a WhatsApp / email contact from config, and an in-app support ticket tied to a booking.
- **Delete account** in-app (required by Apple). It keeps only the records the law requires.

### 4.12 Deep links & universal links (requirements 26, 27)
- One router for push taps, universal links and in-app links.
- URLs:
  - `https://munyati.co/p/{provider}`: provider profile
  - `/s/{service}`: service
  - `/store/{id}`: store
  - `/c/{category}`: category
  - `/b/{booking}`: booking (for logged-in parties only)
  - `/invite/{code}`
- The `apple-app-site-association` file is hosted on munyati.co. If the app isn't installed, the same URL opens a web page with a "Download" button.
- The **share button** on providers, services and stores uses `ShareLink` with the universal link.

### 4.13 Remote content without a build (requirement 19)
These can all change from the dashboard without an app update:
- strings (Arabic and English overrides)
- category icons and covers
- home banners and sections
- onboarding images
- cities
- plan descriptions
- CMS pages (terms, privacy, FAQ)
- support contacts
- feature flags
- force-update / maintenance mode

The app ships with defaults and refreshes and caches on launch. Apple allows this because it's data, not code. We never use flags to hide reviewed features such as the paywall.

## 5. Analytics (requirement 9)

| Layer | Tool | What |
|---|---|---|
| Business truth | Postgres + nightly roll-ups | Users by role and city, providers by plan, services per category, booking funnel (view → request → approved → paid → completed), approval / decline / reschedule rates, response times, trial → paid conversion, MRR, disputes, budget distribution, top searches, SMS cost |
| Curated events | Postgres `analytics_events` (monthly partitions) | About 30 typed events: `service_view`, `provider_view`, `booking_started` / `submitted`, `whatsapp_tap`, `share_tap`, `search`, `category_open`, `city_filter_changed`, `budget_set`, `banner_click`, `paywall_view`, `plan_purchase`… These also power the **provider Insights screen** (a selling point for Plus and Diamond). |
| Every tap and screen | Firebase Analytics, behind one `Track` wrapper | Screens, taps, funnels, retention |
| Errors | Crashlytics + Postgres `error_logs` (client and server) + `admin_audit_log` | Crashes, API failures with screen and app version, every admin action |

Demo bookings and test accounts are excluded everywhere. Analytics need **no tracking prompt**, because there's no IDFA and no ads.

## 6. Backend data model (Supabase / Postgres)

Reused from Kolna: `profiles`, `categories`, `app_config`, `cms_pages`, `home_sections`/banners, `notifications`, `device_tokens`, `phone_otp`, reviews (+ moderation, bans), `analytics_events`, force update, delete account.

New tables:

| Area | Tables |
|---|---|
| Geography | `cities`, `provider_cities` (PostGIS points on providers and stores) |
| Supply | `providers`, `stores`, `services`, `service_images`, `provider_verifications` |
| Availability | `availability_rules` (weekly hours), `availability_exceptions` (days off) |
| Booking | `bookings` (price, payment snapshot, `is_demo`, reference code), `booking_events`, `booking_proposals` |
| Payments | `provider_payment_methods`, `payment_receipts` (sha256 + perceptual hash), `disputes`, `dispute_messages` |
| Budget | `bride_budgets` (+ remaining calculated in one function) |
| Monetization | `subscription_plans` (admin-editable, `apple_product_id`), `provider_subscriptions` (source: app_store / tap_web / admin_comp) |
| Trust | `reports`, `blocks`, `support_tickets` |
| Comms | `sms_campaigns`, `sms_messages`, `push_campaigns`, consent flags on profiles |
| Content | `app_strings`, `cms_assets` |
| Ops | `admin_users`, `admin_roles`, `admin_role_permissions`, `admin_audit_log`, `error_logs` |

Rules enforced **in the database**, not just in the app:
- plan service limits
- one active booking per category (#20)
- no overlapping slots
- allowed status transitions
- receipts readable only by the bride, the provider and admins
- review names masked
- admin permissions

**Edge functions:**
- `send-otp` / `verify-otp` (OurSMS)
- `send-push` (FCM)
- `verify-apple-transaction` + `apple-notifications` (App Store Server Notifications v2)
- `tap-web-checkout` + `tap-webhook` (optional, web only)
- `sms-campaign` (OurSMS)
- `receipt-upload` / `receipt-url` (signed links)
- `delete-account`
- scheduled jobs: expiries, reminders, trial end, analytics roll-ups

Don't port these Kolna/Lamha defects (`research/kolna-backend.md` §15):
- admin RPCs without permission checks
- client-only name masking
- self-editable role column
- plaintext OTP (Lamha)
- a default dev phone number when an environment variable is missing

## 7. iOS app architecture

Kolna layout, renamed and extended (`research/kolna-ios-architecture.md` §21–22):
```
Moniaty_iOS/
  project.yml                  XcodeGen (bundle co.munyati.app, Swift 6, iOS 17)
  App/                         composition root, TabView shell, DeepLink router, push, Track wrapper
  Packages/
    Core/ Networking/ Shared/  (copied; + remote strings, city filter store, StoreKit service)
    DesignSystem/              (re-skinned: Munyati colors, Arabic type scale, components)
    Authentication/            (+ role picker, bride/provider onboarding)
    Features/
      Home/  Explore/  Catalog/  Booking/  Availability/
      ProviderStudio/ (services, stores, payment methods, plans & paywall, insights, demo tour)
      Reviews/  Profile/ (settings, cities, budget, support, report, delete account)
  supabase/                    migrations + edge functions (same repo, like Kolna)
  docs/                        PLAN.md, research/, ADRs
  CLAUDE.md                    instructions so every future session knows the architecture
```
**Arabic-first RTL** with English. Light theme with burgundy accents, plus dark mode.

## 8. Admin dashboard (`munyati_dashboard`, Next.js, Arabic RTL)

Modules (details in `research/admin-dashboard.md` §12):
- **Overview:** KPIs and charts
- **Operations:** bookings, payment receipts and disputes, reports, reviews
- **Providers:** verification, stores, subscriptions, plans editor
- **Users:** brides, all users, ban
- **Content:** cities, categories (icon upload), strings, images, pages, app settings / force update, demo-booking template
- **Marketing:** push campaigns, **SMS campaigns via OurSMS** (opt-in audiences by role, city and plan; cost estimate; sending window 09:00–19:00; `Munyati-AD` sender)
- **Analytics:** funnel, users, categories, revenue, errors
- **Admin:** team with roles and permissions (owner, ops, moderator, content, marketing, analyst), mandatory 2-factor login, audit log

A global city filter applies to every page. It's hosted at `admin.munyati.co`.

## 9. Website (`munyati_web` → munyati.co)

Bilingual static site in the Munyati brand:
- **Landing page:** hero, how it works for brides, categories, App Store button
- **For providers page:** benefits, plans, trial
- **Privacy policy** (PDPL compliant, discloses hosting in the EU)
- **Terms:** for brides and for providers, including cancellation policy templates and a zero-tolerance content clause
- **Support / FAQ / contact** (contact@munyati.co, WhatsApp, consumer complaints line 1900)
- **Account deletion page**
- **E-commerce law disclosures** (CR, business.sa verification)
- `.well-known/apple-app-site-association`
- Web fallback pages for shared links

## 10. Notifications catalogue

| Event | To | Deep link |
|---|---|---|
| New request / reschedule accepted or rejected | Provider | `/b/{id}` |
| Approved / declined / new time proposed | Bride | `/b/{id}` |
| Payment due reminder (24 h, 6 h) | Bride | `/b/{id}` |
| Receipt uploaded / payment confirmed / receipt rejected | Provider / bride | `/b/{id}` |
| Appointment tomorrow | Both | `/b/{id}` |
| Rate your experience | Both | `/b/{id}/review` |
| Dispute opened / resolved | Both + admins | `/b/{id}` |
| Demo booking (once) | New provider | `/b/{id}` |
| Trial ending (14/7/3/1 days), renewal failed | Provider | `/plans` |
| Report / review moderation outcome | Author | relevant screen |
| Campaigns (push/SMS) | Opted-in audiences | any typed route |

## 11. App Store readiness checklist
- **IAP for provider plans:**
  - restore purchases
  - full paywall disclosures (price, renewal terms, trial length, terms and privacy links)
  - Apple's price shown
  - no mention of web prices in the app
- **Manual payment wording:** "pay the provider directly"; never imply Munyati holds or guarantees the money.
- **User-generated content (rule 1.2):** pre-moderation and filtering, report, block, published contact, terms acceptance.
- **Privacy:** in-app account deletion, privacy labels, privacy manifest, no tracking prompt (no IDFA). Sign in with Apple is not needed for phone-only login.
- **Review notes:** 3 demo accounts with fixed OTP numbers (bride, subscribed provider, new provider), seeded bookings in every state, and explanations of the manual payment flow, the IAP plans and the demo booking.
- **Recommended:** book a free **App Review consultation** with Apple before building billing.

## 12. Delivery phases

| Phase | Scope | Output |
|---|---|---|
| **0. Setup (you, now)** | Company CR + business.sa; Apple Developer account; **OurSMS sender names `Munyati` + `Munyati-AD`** (2–3 weeks, start now); Supabase project (after latency test); Firebase project; create repos `munyati_dashboard` + `munyati_web` and give Claude access; DNS for munyati.co; decisions in §16 | Accounts ready |
| **1. Foundation** | Kolna skeleton renamed to Munyati, design system re-skinned, logo/app icon, TabView shell, auth with role + OTP, deep-link router, Track wrapper, remote config/strings; core DB (profiles, cities, categories, config, CMS, admin roles, audit); `CLAUDE.md` | App runs, both roles log in |
| **2. Discovery** | Providers, stores, services CRUD (provider), catalog + search + city filter + budget (bride), Explore map, favorites, share links | Brides can browse real data |
| **3. Booking core** | Availability, booking state machine, reschedule proposals, notifications, My Bookings, payment methods, receipts, confirmation, completion, disputes, one-per-category rule, demo booking | End-to-end booking works |
| **4. Monetization** | StoreKit 2 plans + trial, server entitlement, limits, paywall, trial-end journey, insights screen | Providers can subscribe |
| **5. Trust & polish** | Two-way reviews (masked), reports/blocks, support, delete account, offline states, accessibility, Arabic copy pass, analytics events complete | Store-ready quality |
| **6. Dashboard** (parallel from phase 1) | Phase-1 modules first (cities, categories, plans, providers, bookings, receipts/disputes, users, settings, CMS), then reviews/reports/push, then analytics/errors/SMS | Admin can run the business |
| **7. Website** (parallel) | Landing, legal pages, AASA, link fallbacks | munyati.co live |
| **8. Launch** | TestFlight with real providers in the launch cities, App Review submission, ASO (name «منيتي - Munyati», subtitle «كل تجهيزات العروس في مكان واحد») | Live on App Store |

### Progress
- **Phase 1 — done:** app shell, design system, auth with roles, core database (`supabase/migrations/20261010*`).
- **Phase 2 — done:** catalog, search, budget, favorites, map, share links; provider studio
  (`supabase/migrations/20261011000000_catalog.sql`, `Packages/Features/{Catalog,ProviderStudio}`).
  Until Phase 4 plans exist, providers get the trial allowance from `app_config`
  (`trial_max_services` 10, `trial_max_stores` 3).
- **Phase 3 — done:** booking requests with free slots, approve / decline / propose another
  time, full-amount transfer with receipt upload (private `receipts` bucket, duplicate-hash
  check), confirm or reject payment, completion, cancellation, disputes, a demo booking for
  every new provider, timers via pg_cron, SMS for key events, and the provider's working hours
  and payout methods (`supabase/migrations/20261012000000_booking.sql`, `Packages/Features/Booking`).
- **Phase 4 — done, with Tap instead of StoreKit (decision #2):** plans with dashboard-editable
  limits, the 2-month trial starting on approval (one per phone number), Tap hosted checkout with
  server-side pricing and re-fetched charge status, upgrade now with credit / smaller plan after
  the current one, paused services above the limit, hidden listing after the trial or plan ends,
  search boost and featured badge, reminders at 14/7/3/1 days, and the insights screen
  (`supabase/migrations/20261013000000_subscriptions.sql`, `functions/tap-*`, `ProviderStudio`).
  Plans don't renew automatically (no saved cards); providers pay again, prompted by reminders.
  Seeded prices (99 / 249 / 499 SAR a month) are placeholders for the owner to set.
- **Phase 5 — done (trust):** two-way reviews after completion (bride → provider public after
  moderation, provider → bride private), names masked on the server, ratings on cards and
  provider pages, provider replies; report anything; block (both sides hidden, no bookings);
  support screen with tickets (also from a booking); zero-tolerance line at sign-up; admin RPCs
  for moderation, reports, bans and ticket replies (`supabase/migrations/20261014000000_trust.sql`,
  `Packages/Features/Trust`). Settings: `reviews_premoderation`, `review_window_days`, `banned_words`.
- **Phase 6 — done (dashboard):** Next.js admin in `dashboard/` (kept in this repo for now; the
  `munyati_dashboard` repo didn't exist yet). All modules from §8 except SMS marketing campaigns,
  which wait for the `Munyati-AD` sender and opt-in flow. Admin actions in
  `supabase/migrations/20261015000000_admin.sql`; anon key only, permissions enforced in Postgres.

## 13. Design approach (answer to "premium app or Claude Design?")
- **I can design it here.** The brand already has a palette (burgundy `#8A0D3A`, gold `#DFC389`, cream `#F2E5D2`, ivory `#FAFAEC`) and a logo.
- **Next step:** I build a **Munyati design system** in the code. Details:
  - **Fonts:** an Arabic display face for headings and a clean Arabic UI face (e.g. IBM Plex Sans Arabic or Tajawal).
  - **Style elements:** generous spacing and soft cards, plus gold hairline accents and the diamond/sparkle motif from the logo.
  - **Interface:** native iOS controls.
- **Before coding,** I produce **clickable HTML mockups of the key screens** for your approval:
  - onboarding / role choice
  - bride Home with budget card
  - category → provider → service
  - booking request
  - payment & receipt
  - My Bookings timeline
  - provider inbox
  - paywall
- **Use Claude Design only if** you want to explore the visual style yourself on a canvas. You did that for Maalim Al-Khafji and it worked; its output becomes the visual reference I build from. Either way, the plan doesn't change.

## 14. Cost summary (monthly, USD)
| | Launch | 20k users | 200k users |
|---|---|---|---|
| Supabase + hosting | 35–55 | 100–150 | 650–900 |
| OurSMS OTP (estimate, confirm with OurSMS) | ~70 | ~215 | ~1,100 |
| Firebase (push, analytics, crashes), MapKit | 0 | 0 | 0 |
| Apple fee on provider subscriptions | 15% of subscription revenue | | |
SMS, not the server, becomes the biggest cost. Keep login sessions long so users rarely need a new OTP.

## 15. Risks & notes
- **Security (existing project):** `lamha_dahsboard/.env.example` contains a real Supabase **service-role key** committed to git. **Rotate it in Supabase now** and remove it from the repo. It bypasses all database security. Also upgrade that dashboard's Next.js (14.2.5 has a known middleware-bypass vulnerability).
- **OurSMS sender name** requires a CR whose name matches "Munyati". The `.co` domain doesn't count as proof. OTP can't launch without it.
- **Mobily** sometimes blocks `-AD` promotional SMS, so expect lower delivery rates on marketing.
- **Receipt fraud** is the main operational risk. The mitigations in §4.3 plus fast admin response matter more than code.
- **Legal:** Munyati needs its own CR, business.sa verification, a PDPL privacy policy and E-Commerce Law disclosures. Get a short local legal review before launch.
- **Portfolio photos of brides** need the provider's consent checkbox and a report option.

## 16. Owner decisions (recorded)
| # | Topic | Decision |
|---|---|---|
| 1 | Cities | **Dammam, Khobar, Qatif** at launch. Fully editable from the dashboard. |
| 2 | Provider subscriptions | **Tap** for now (owner's choice; revisit later). ⚠️ The App Store may reject Tap-paid plans that unlock in-app features (guideline 3.1.1). To keep the switch cheap, entitlements live in `provider_subscriptions` with a `source` column (`tap` / `app_store` / `admin_comp`), and the app reads only the entitlement, never the payment method. Adding StoreKit later is then additive. |
| 3 | Plans | As suggested in §4.7 (Normal 1 / Plus 3 / Diamond 10 services); editable from the dashboard |
| 4 | Payment | **Full amount only** for now. `bookings` keeps a nullable `deposit_amount` so deposits can be enabled later. |
| 5 | Category rule | Only the **same category** is blocked until completion; different categories run in parallel. `allows_parallel_bookings` exists but defaults to false for every category. |
| 6 | Provider verification | **Application + admin approval**: a provider fills in a join form (business info, categories, cities, CR or freelance-certificate number, documents). The status is `pending` until an admin reviews, contacts them and approves; only then are their services publicly listed. The demo booking arrives at registration, so they can explore while pending. Verified providers get a badge. |
| 7 | Female staff only | An **optional filter** the bride can switch on (services carry a `female_staff_only` flag); never forced |
| 8 | Timeouts | Request 48 h, proposal 24 h, payment 48 h, receipt confirmation 48 h (dashboard-editable). Receipts are visible to the bride, the provider and admins in the booking timeline. **Key booking events also go out by OurSMS** (transactional sender) as a fallback when push is off: approval with payment due, receipt uploaded, payment confirmed, appointment reminder. Configurable per event in the dashboard. |
| 9 | Guest browsing | Yes; login is needed only to book, favorite, review or report |
| 10 | Name | **منيتي - Munyati** everywhere |
| 11 | Design | Designed here: HTML mockups first, then the SwiftUI design system |
