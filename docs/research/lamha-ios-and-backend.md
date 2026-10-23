# Lamha Ads (iOS + Supabase): what Munyati can reuse

Source analysed: `/home/user/lamha_backup_ios` (HEAD `41a3858 "update"`), covering the iOS target `Lamha Ads/`, `supabase/` (24 edge functions, `schema.sql`, 2 migrations, 1 RPC dump), `DASHBOARD_HANDOFF.md` and `.well-known/`. I ignored `.claude/worktrees/` as asked, but it is committed to git (268 tracked files; see §15).
I checked each finding against Kolna Al-Khafji (`/home/user/kolna-al-khafji-ios`) so this report lists only what Kolna **does not** already provide, or where Lamha's version differs in a way that matters.

---

## 0. TL;DR

| Area | Lamha has | Kolna has it? | Verdict for Munyati |
|---|---|---|---|
| Tap Payments (hosted page, webhook, return page, status poll) | Yes, complete one-off charge flow | **No.** Kolna's `payments` table is only an admin-recorded offline log (`kolna-al-khafji-ios/supabase/migrations/20260724140000_payments.sql`) | **Take it** and adapt it into a provider-subscription billing flow. It needs an idempotent period-extension RPC and an amount check. |
| Universal links + URL-based deep-link router | Yes (AASA, `DeepLinkState`, `onOpenURL` / `onContinueUserActivity`) | **No.** Kolna's entitlements have no `associated-domains`, and its push routing uses only fixed keys (`place_id`/`business_id`/`notification_id` in `App/Sources/Push/AppDelegate.swift`) | **Take the pattern** and rewrite it for UUID ids, a host check, and a single `deep_link` push key |
| FCM topic segmentation (`all`, `ios`, `lang_*`, `region_*`, `city_*`) + segmented `device_tokens` | Yes | Kolna registers tokens but has no topic subscription (grep for `subscribe(toTopic` finds nothing) | **Take it** and change it to multi-city topics (`city_<id>` for each selected city) |
| Google Maps / Places | Yes (SDK v10.13, Places SDK + REST) | Kolna uses MapKit | **Do not take.** Use MapKit (Kolna) and port only the center-pin picker UX |
| QR single-use token (show / scan) | Yes (discount codes) | No | Optional: use it for an appointment check-in that proves "service completed" |
| Signed upload / signed read edge functions | Yes, but admin-only and audio/video only; the read path has no ownership check | Kolna uploads to public buckets (`SupabaseImageUploader`) | **Adapt the pattern** into private `payment-receipts` upload/read functions with party-or-admin authorization |
| OTP via OurSMS | Yes | **Yes, and better** (HMAC-hashed codes, attempt limit, sender read from env) | Use Kolna's. From Lamha take only `change-phone` (OTP to the new number) |
| `admin-content` single action endpoint | Yes | Kolna uses RLS and `is_admin()` policies | Take the pattern only for service-role-only operations (payments, disputes, receipts, SMS campaigns) |
| Firebase Analytics typed wrapper (`Track`) | Yes (14 call sites) | Kolna uses Supabase `analytics_events` and `record_analytics_event` RPC | Take the `Track` vocabulary idea for GA4 funnels, alongside Kolna's server-side events |
| `AppLogger` (OSLog categories) | Yes (7 categories) | Kolna has `Core/Logging/Logger.swift` | Not needed |
| `DiskCache<T>` | Yes | Kolna has `Shared/Persistence/CacheStore.swift` | Not needed |
| Emira UI kit | 12 components, 4 theme files, 4 modifiers | Kolna `DesignSystem` package is larger (30 files) | Mostly redundant. Port only `OTPInputField`/`PhoneInputField`/`EnglishPhoneField` if Kolna's `UIKitNumberField` lacks the needed behaviour |
| Scheduled reminders (`send-auto-reminder`) | Yes (FCM v1, dedup table) | Not seen in Kolna | **Take the pattern** for booking reminders and trial-expiry nudges |

---

## 1. Repo snapshot (facts)

- Single Xcode target `Lamha Ads`. Bundle `com.trndsky.lamha`, app deployment target **iOS 16.0**, `SWIFT_VERSION = 5.0` (test targets say 26.2; `Lamha Ads.xcodeproj/project.pbxproj`). The project uses file-system-synchronized groups; there is no XcodeGen.
- SPM dependencies: firebase-ios-sdk ≥12.15 (Core, Messaging, Analytics), googlemaps/ios-maps-sdk ≥10.13, googlemaps/ios-places-sdk ≥10.13 (GooglePlaces, GooglePlacesSwift), Kingfisher ≥8.8.1, supabase-swift ≥2.5.1.
- Architecture: `App/Composition.swift` (a lazy DI root), `Core/DataCore` (Domain/Data repositories), `Core/UICore` (Emira design system), and `Features/<Name>/{Domain,Data,UI}`.
- `Lamha Ads/Core/DataCore/Data/Networking/LamhaSupabaseClient.swift`, `Features/Media/MediaShared/MediaRepository.swift` and `Features/PostAd/UI/Components/LocationSearchService.swift` reference `AppConfig.*`. The `AppConfig.swift` file is git-ignored (`**/AppConfig.swift`) and not in the repo, so **the repo does not build from a clean clone**.
- `supabase/schema.sql` is a pasted snapshot ("for context only and is not meant to be run"). It contains **no RLS policies**. Only 2 migrations are tracked. Edge-function sources were downloaded from the live project, and `mark-uploaded/index.ts` is an empty placeholder (its own comment says the download kept returning an empty file).
- Tests: `Lamha AdsTests/Lamha_AdsTests.swift` is the 36-line Xcode template. No real tests.

---

## 2. Tap Payments end-to-end

### 2.1 What is charged

A one-off fee for **posting an ad** (`ad_requests.total_price`). The fee comes from the `ad_pricing` plan (base price + `duration_days`), an optional "featured" surcharge (`app_settings.featured_surcharge` / `featured_surcharge_enabled`, see `Core/DataCore/Domain/Models/AppSettings.swift`) and optional influencer add-ons (`ad_request_influencers.price`).
There is **no recurring billing, no saved card and no subscription** anywhere in Lamha (`save_card: false`, `customer_initiated: true`).

### 2.2 Flow

```
iOS PostAdViewModel.submit()
  └─ creates ad_requests row (client-side insert) → runPayment(adRequestID)
       ├─ TapAdPaymentService.createCharge → POST functions/v1/create-ad-charge {ad_request_id}
       │     server: auth user → load ad_requests (service role) → ownership check
       │             → amount = ad.total_price (server-side, never from client)
       │             → POST {TAP_API_BASE}/v2/charges  (source src_all, 3DS, metadata.ad_request_id,
       │                 post.url = …/tap-webhook, redirect.url = PAYMENT_RETURN_URL)
       │             → insert ad_payments {status:'initiated', tap_charge_id, raw}
       │             ← { paymentUrl, chargeId, paymentId } | { alreadyPaid:true }
       ├─ AdPaymentPresenter.present(url)  (ASWebAuthenticationSession, callbackURLScheme "lamha")
       │     Tap hosted page → browser redirect → functions/v1/payment-return?tap_id=…
       │        server: re-fetch charge from Tap → settle DB → HTML page → JS redirect lamha://pay-return?tap_id=…
       │     ← true if the callback fired, false if the user cancelled (NOT proof of payment)
       └─ confirmPayment(attempts: returned ? 6 : 2) → polls get-ad-payment-status
             server: latest ad_payments row for (ad, user); if 'initiated' re-fetch from Tap & settle;
                     falls back to ad_requests.payment_status as tie-breaker
             ← { paymentStatus: paid|failed|initiated|none, adStatus, amount, currency }
Tap → POST functions/v1/tap-webhook (server-to-server, Verify JWT OFF)
      body is NOT trusted: takes id → GET /v2/charges/{id} with secret → CAPTURED ⇒ paid/active,
      FAILED|DECLINED|CANCELLED|VOID|RESTRICTED ⇒ failed; always 200
```

Files:
- `supabase/functions/create-ad-charge/index.ts` (138 lines). It includes `parsePhone()`, which normalises SA/GCC/EG numbers into Tap's `{country_code, number}` and omits the phone rather than guessing. This is reusable as-is.
- `supabase/functions/tap-webhook/index.ts` (66 lines)
- `supabase/functions/payment-return/index.ts` (84 lines). It renders an RTL Arabic success/fail HTML page with `Content-Type: text/html; charset=utf-8` and auto-redirects to `APP_DEEPLINK`.
- `supabase/functions/get-ad-payment-status/index.ts` (82 lines)
- iOS: `Lamha Ads/Features/PostAd/Data/TapAdPaymentService.swift` (protocol `AdPaymentService` + `TapAdPaymentService` calling `client.functions.invoke`), `Features/PostAd/UI/AdPaymentPresenter.swift` (`ASWebAuthenticationSession`, `prefersEphemeralWebBrowserSession = false` to keep the Apple Pay/bank session), `Features/PostAd/UI/ViewModels/PostAdViewModel.swift` (`runPayment` lines ~325–360, `confirmPayment` ~364, `retryPayment` 312), and `Features/Account/UI/MyPayments/*`, where the user's own payments are read directly from `ad_payments` filtered by `user_id`.
- Dashboard: the `admin-content` actions `list_ad_payments` (read-only, joins `ad_requests(store_name, order_number)`), `list_ad_requests`, `set_ad_request_status` (manual override for offline payments/disputes: `active|pending_payment|rejected`) and `delete_ad_request`. `delete_ad_request` refuses when a payment row exists, to keep the audit trail. `DASHBOARD_HANDOFF.md §4` describes the payments table UI to build.

Tables (from `supabase/schema.sql`):
```sql
ad_payments(id uuid, ad_request_id uuid not null → ad_requests, user_id uuid, amount numeric,
            currency text default 'SAR', provider text default 'tap', tap_charge_id text UNIQUE,
            status text default 'initiated', raw jsonb, created_at, paid_at)
ad_requests(... total_price numeric, status text default 'pending', payment_status text default 'unpaid', paid_at ...)
```

### 2.3 Secrets and config

| Env | Used by | Notes |
|---|---|---|
| `TAP_SECRET_KEY` | create-ad-charge, tap-webhook, payment-return, get-ad-payment-status | `sk_test_…` / `sk_live_…` |
| `TAP_API_BASE` | all four | default `https://api.tap.company` |
| `PAYMENT_RETURN_URL` | create-ad-charge | defaults to `${SUPABASE_URL}/functions/v1/payment-return` |
| `AD_CURRENCY` | create-ad-charge | default `SAR` |
| `APP_DEEPLINK` | payment-return | default `lamha://pay-return` |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY` | all | auto-injected (note: some other Lamha functions read `ANON_KEY` instead; this is inconsistent) |

Verify-JWT settings: ON for `create-ad-charge` and `get-ad-payment-status`; OFF for `tap-webhook` and `payment-return`.
No Tap publishable key is on the client and no card data touches the app, so there is no PCI scope in the app.

### 2.4 What is good (keep)
- The amount is computed server-side, and the charge is created only for a row the caller owns.
- The webhook ignores the body and **re-fetches the charge** with the secret key. This substitutes for signature verification; Tap's `hashstring` header is not checked.
- Settlement is triple-redundant (webhook, return page, status poll), so a late webhook never strands a paid user.
- `UNIQUE(tap_charge_id)`, plus `raw jsonb` for reconciliation.
- The client-side result of the hosted page is treated as "returned", not "paid".

### 2.5 Gaps and bugs to fix before reuse
1. **No amount/currency verification on CAPTURED.** Neither the webhook nor the return page compares `charge.amount`/`charge.currency` to `ad_payments.amount`. It is low risk because the server created the charge, but add the check.
2. **Settlement is idempotent only because it writes constant values.** For subscriptions, "paid" must *extend* `current_period_end`. If the webhook, the return page and the poll all run, a naive port would extend the period 3 times. Move settlement into one SQL RPC, e.g. `settle_subscription_payment(p_charge_id, p_charge jsonb)`, that does `UPDATE … SET status='paid' WHERE tap_charge_id = $1 AND status <> 'paid' RETURNING …` and extends the period only when a row was returned.
3. **`payment-return` is unauthenticated and settles DB state** from a `tap_id` query param. This is safe only because it re-fetches from Tap. Keep it that way, and never accept a status from the query string.
4. **Duplicated settle logic in 3 functions.** Extract it to a shared `_shared/tap.ts` module.
5. **Orphan handling is client-side.** `PostAdViewModel` deletes the request if payment fails, and the request is inserted by the client. For Munyati, create the subscription order server-side.
6. **Webhook URL is built from `SUPABASE_URL`.** That is fine, but for Munyati consider routing through `api.munyati.co` so the domain can be moved later.
7. **The dev placeholder email is `noreply@lamha.app`.** Replace it with `noreply@munyati.co` or `contact@munyati.co`.

### 2.6 Can it power Munyati provider subscription billing?

**Yes, for "pay monthly, manually renewed" billing. Not for automatic recurring as-is.**
Lamha has no saved-card or merchant-initiated charge code. Tap's card-saving and recurring features (customer + saved card + merchant-initiated charges) were **not used and not verified** here; confirm them with Tap and the account's enabled features before promising auto-renew.

Proposed adaptation:
- **Tables:**
  - `subscription_plans` (`code` normal|plus|diamond, `name_ar/en`, `price_monthly`, `max_services`, `features jsonb`, `is_active`, `sort_order`), editable from the dashboard (requirement 8). Add a nullable `price_yearly` for requirement 11's "yearly later".
  - `provider_subscriptions` (`provider_id`, `plan_code`, `status` trialing|active|past_due|expired|cancelled, `trial_ends_at` = signup + 2 months (requirement 23), `current_period_end`).
  - `subscription_payments`, cloned from `ad_payments`, with `subscription_id`, `plan_code`, `period_start`, `period_end`, `tap_charge_id UNIQUE`, `raw`.
- **Edge functions:**
  - `create-subscription-charge {plan_code}`: reads the price from `subscription_plans` server-side; `metadata: {kind:'subscription', subscription_id, plan_code}`.
  - `tap-webhook`: dispatch on `metadata.kind`, so one webhook serves future charge kinds.
  - `payment-return`: set `APP_DEEPLINK=munyati://pay-return`.
  - `get-subscription-status`.
- **Service-count enforcement** (requirement 2): use a DB trigger or RLS check on `services` insert, `count(*) < plan.max_services` while the subscription is `trialing|active`. Do not enforce it only in the app.
- **Renewal nudges:** use the `send-auto-reminder` pattern (§9) plus OurSMS: T-7/T-3/T-0 before `current_period_end` or `trial_ends_at`.
- **iOS:** clone `TapAdPaymentService` into `SubscriptionPaymentService`, and reuse `AdPaymentPresenter` almost verbatim (change `callbackScheme` to `munyati`). On iOS 17.4+, `ASWebAuthenticationSession` can also use an https callback on `munyati.co`; this is optional.
- **App Store risk:** Lamha charges for ad posting through Tap. Charging providers for the in-app ability to list services may be read by App Review as unlocking app functionality (guideline 3.1.1). Whether Lamha passed review with this flow is **not verifiable from the repo**. Flag it for the owner and decide early: web-only checkout on `munyati.co`, or a reader-style approach.
- **Bride payments are not affected.** The bride-to-provider payment is manual transfer plus a receipt screenshot (requirement 5), not Tap. Tap is only for provider subscriptions.

---

## 3. Universal links and deep-link routing

### 3.1 What exists
- `.well-known/apple-app-site-association`:
  ```json
  {"applinks":{"details":[{"appIDs":["7X8S9DG2DC.com.trndsky.lamha"],
    "components":[{"/":"/ad/*"},{"/":"/gallery/*"}]}]}}
  ```
  It sits at the repo root and nothing in this repo serves it. Where it is actually hosted is **not verifiable from here**.
- `Lamha Ads/Lamha Ads.entitlements`: `applinks:lamha.trndsky.com`, `aps-environment = development`.
- `Lamha-Ads-Info.plist`: URL scheme `lamha`, `LSApplicationQueriesSchemes = [comgooglemaps]`, `UIBackgroundModes = [audio, remote-notification]`.
- Share links: `Core/DataCore/Domain/Models/AdShareText.swift`, with `universalLinkBase = "https://lamha.trndsky.com"` and `/ad/{id}`, `/gallery/{id}`. Its doc comment explains AASA hosting and a Smart App Banner fallback (`<meta name="apple-itunes-app">`). That is useful as a checklist for the munyati.co landing site (requirement 29).
- `App/RootView.swift`: `.onOpenURL { deepLinkState.handle($0) }` and `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { … webpageURL … }`.
- `Navigation/AppRouter.swift` → `DeepLinkState` (`@MainActor ObservableObject`):
  - `handle(_ url:)` splits custom scheme `lamha://ad/{id}` from https universal links.
  - `handleNotification(userInfo:)` checks keys in this order: `deep_link` (a URL string), `ad_id` (Int or String), `podcast_id`, `url` (external, opened in Safari).
  - It publishes `pendingAdID`, `pendingGalleryAdID`, `pendingPodcastID` and `pendingExternalURL`.
- `Navigation/NotificationHandler.swift` is the `UNUserNotificationCenterDelegate`. It forwards taps to `DeepLinkState` and shows foreground banners.
- `App/MainTabView.swift` consumes the pending values with `.onChange(of:)`: it switches tab, pushes a typed route onto that tab's `NavigationStack`, and nils the value. For the gallery it also checks on appear (comment at ~line 318), which covers cold start.
- Each tab has its own route enum: `App/Routers/HomeRoute.swift` (manual `Hashable` keyed by id, documented as the fix for a "white-screen race"), `CategoriesRoute`, `GalleryRoute`, `AccountRoute`, `SupportRoute`, `AccountSupportRoute`.

### 3.2 Problems (do not copy)
- `Navigation/Route.swift` (`login/home/profile`), `AppState.swift`, `NavigationState.swift` (empty) and `AppRouter.appState` are **dead code**.
- `handleUniversalLink` **does not check the host**. Any https URL handed to the app is parsed by path, and unknown paths become `pendingExternalURL`, which then opens in Safari.
- Doc comments say `links.lamha.app`, but the entitlement and share base use `lamha.trndsky.com`. The domains have drifted.
- The router handles `/podcast/*`, but the AASA does not include it.
- All ids are parsed as `Int`. Munyati will use UUIDs.

### 3.3 Munyati adaptation
- **AASA** at `https://munyati.co/.well-known/apple-app-site-association`, team-id + Munyati bundle. Suggested components: `/p/*` (provider), `/s/*` (service), `/store/*`, `/c/*` (category), `/b/*` (booking; it must still require auth and a party check in-app), `/invite/*`. Exclude `/privacy`, `/terms`, `/support` and `/` so the website pages open in Safari (`"exclude": true` components).
- **Entitlement:** `applinks:munyati.co` (and `www.` if used).
- **Router:** keep the "pending target published, then consumed by the tab shell" design and Kolna's cold-start tap cache (`pendingTap` in Kolna's `AppDelegate`). Replace the per-entity `@Published` vars with a single `@Published var pending: DeepLink?` enum (`.provider(UUID)`, `.service(UUID)`, `.booking(UUID)`, `.bookingProposal(UUID)`, `.receipt(bookingID)`, `.subscription`, `.external(URL)`). Add a host allow-list (`munyati.co`, `www.munyati.co`).
- **Push payload:** make the server always send one `deep_link` string (e.g. `munyati://booking/<uuid>`). FCM data values are strings, which is why Lamha has to try both `as? Int` and `as? String`.

---

## 4. FCM token registration and push segmentation

Files: `App/AppDelegate.swift` (APNs token → `Messaging.apnsToken`), `App/FCMTokenHandler.swift`, `App/NotificationTopics.swift`, `supabase/functions/register-fcm-token/index.ts`, `supabase/migrations/20260705000000_device_tokens_segments.sql`, and `supabase/functions/send-push-notification/{index.ts,README.md}`.

- `FCMTokenHandler` (a `MessagingDelegate`) uploads `{fcm_token, platform, language, topics[], region_id, city_id}` to `register-fcm-token`. It runs on every token refresh, **on every login** (`sessionStore.$currentUser`), and **on every city change** (`citySelection.$scope`).
- `NotificationTopics` computes the desired topic set: `all`, `ios`, `lang_ar|lang_en`, `region_<id>`, `city_<id>`. It diffs against `syncedTopics` and subscribes or unsubscribes only the deltas, and sanitises ids to FCM's allowed charset. **This is the piece Kolna lacks.** For Munyati's multi-city filter (requirement 16), subscribe to `city_<id>` for every selected city. "All" maps to just `all`. Add role topics (`role_bride`, `role_provider`) and plan topics (`plan_diamond`) for dashboard campaigns.
- `register-fcm-token` upserts `device_tokens` on `fcm_token`, using the service role, and links `user_id` only when a valid JWT is present.
  Caveat (documented in the README): an unauthenticated re-registration **nulls `user_id`**, so targeted pushes silently stop. For Munyati, do not overwrite a non-null `user_id` with null; clear it only on explicit logout.
- `send-push-notification` handles FCM HTTP v1 through a service-account JWT, targets `user_id` (fan-out to all devices) or a `topic`, and deletes `UNREGISTERED`/`NOT_FOUND` tokens. Kolna has its own `send-push`, so compare the two and keep one. Lamha's topic support is the differentiator.

---

## 5. Maps: Google Maps vs MapKit

Lamha uses Google:
- `App/GoogleMapsBootstrap.swift` calls `GMSServices.provideAPIKey` and `GMSPlacesClient.provideAPIKey` with keys from Info.plist (`GMSApiKey`, optional `GMSPlacesApiKey`). Its comment correctly notes that the key must be restricted by bundle id in the Cloud Console.
- `Core/UICore/Components/AdDetailMapSection.swift` shows a non-interactive `GMSMapView` preview with a marker, plus an "open in Google Maps" hand-off via `comgooglemaps://` with a web fallback.
- `Features/PostAd/UI/Components/LocationPickerView.swift` is a center-pin picker on `GMSMapView` (`idleAt` → reverse-geocode) plus `PlacesSearchService`, which uses the Places SDK autocomplete with a `GMSAutocompleteSessionToken` (session billing) and a rectangular location bias.
- `Features/PostAd/UI/Components/LocationSearchService.swift` is a second implementation that calls the **Places REST** (`place/autocomplete`, `place/details`) and **Geocoding REST** APIs directly with the API key in the URL, falling back to `MKLocalSearch`/`CLGeocoder`. **It is never instantiated (dead code).**

Cost-relevant facts:
- The Maps SDK key is committed in plain text in `Lamha-Ads-Info.plist`. Whether it is restricted is not verifiable.
- Places Autocomplete, Place Details and Geocoding are billed per request or session. Map loads in the mobile SDK have historically been no-charge. **Verify current Google pricing**; it changed in 2025.
- Two extra SDKs (~tens of MB of binary) and a Google Cloud billing account are required.

**Recommendation for Munyati Explore (the map tab, requirement 7): use MapKit**, as Kolna already does (`Packages/Features/Explore/.../ExploreView.swift`, `Places/.../PlaceMapView.swift`, `LocationPickerSheet.swift`). It has no key or billing, works with SwiftUI `Map` on iOS 17 with annotations and clustering via `MKMapView` if needed, and `MKLocalSearchCompleter` covers address search.
From Lamha, port only the **UX ideas**: a non-interactive preview card with an "open in Maps" action, and the center-pin picker that reverse-geocodes on camera idle (in MapKit: `onMapCameraChange(frequency: .onEnd)`).
Apple Maps POI quality in Dammam, Khaibar and Taif is **not verified**. Because providers enter their own pin, POI coverage matters less.
Note that the owner wrote "Tafeef"; this is probably Taif (الطائف). Confirm before seeding cities.

---

## 6. QR scan

- The customer side is `Features/AdDetail/UI/Views/CustomerQRView.swift`. It calls `get-customer-qr`, which mints a 15-minute single-use token per (customer, ad) and requires an approved `qr_code_requests` row with capacity. Table: `customer_qr_tokens`.
- The merchant side is `Features/Account/UI/QRScanner/QRScannerView.swift`. It uses `AVCaptureSession` + `AVCaptureMetadataOutput` (`.qr`) and calls `verify-qr-scan`, which checks that the scanner owns the ad and that the token is unused and unexpired, then marks it used.
- Dead duplicates: `Features/QRScanner/UI/CustomerQRView1.swift`, `QRCodeRequestView1.swift` and `Features/AdDetail/UI/Components/AdDetailQROffer1.swift` are fully commented out.
- **Munyati use (optional, high value):** an "appointment check-in" or "mark completed" proof. The provider scans the bride's booking QR at the appointment, which moves the booking to `in_progress`/`completed`. That transition gates reviews (requirement 15), releases the same-category lock (requirement 20), and gives admins evidence in disputes (requirement 5). Reuse the token table pattern (`booking_checkin_tokens`) and the scanner controller. On iOS 16+ you could use `DataScannerViewController`, but the AVFoundation one is fine.

---

## 7. Media upload and signing, for receipt screenshots

- `supabase/functions/create-upload/index.ts` is **admin-only** (`user_roles.role = 'admin'`) and only accepts `kind` of `audio|video`. It inserts a `media_assets` row, `createSignedUploadUrl` on the `media` bucket at `video|audio/{assetId}/source.{ext}`, and marks the asset ready up front. A Cloudflare Stream branch is behind `VIDEO_PROVIDER=cloudflare`.
- `supabase/functions/sign-media-url/index.ts` returns a 1-hour `createSignedUrl` for a `playbackId`. It requires a logged-in user but **performs no ownership or audience check**: any logged-in user can sign any asset. That is acceptable for public episodes, but **unacceptable for bank-transfer receipts**.
- `admin-content` → `sign_cover_upload` signs uploads into a **public** `covers` bucket.
- In iOS, ad images are uploaded straight from the client to the public bucket `ad-request-images` (`Features/PostAd/Data/Repositories/SupabaseAdRequestRepository.swift`, `uploadMedia`, `image/jpeg`). Kolna does the same with `place-images` (`App/Sources/Backend/SupabaseImageUploader.swift`).

**Munyati receipt upload design (adapted from this pattern):**
- Use a private bucket `payment-receipts` with path `{booking_id}/{uuid}.jpg`.
- `create-receipt-upload {booking_id}`: verify the caller is the booking's bride and the booking status is `awaiting_payment`; insert a `payment_receipts` row (`booking_id`, `uploaded_by`, `path`, `status` pending|confirmed|rejected, `amount_claimed`, `transfer_method_id`); return `createSignedUploadUrl`.
- `sign-receipt-url {receipt_id}`: allow only the bride, the booking's provider, or an admin. Use a short TTL (5–15 minutes) and **log every view** to `audit_log` for dispute evidence.
- The provider confirms or rejects through an RPC with a status transition guard. The admin can see everything via an `admin-content`-style action or admin RLS.
- Strip EXIF and compress on device before upload.

---

## 8. OTP (OurSMS)

Lamha `supabase/functions/send-otp/index.ts` and `verify-otp/index.ts` use **OurSMS**: `POST https://api.oursms.com/msgs/sms`, `Authorization: Bearer ${OURSMS_API_KEY}`, body `{src, dests[], body, priority, delay, validity, maxParts, transliteration}`. It maps OurSMS error codes to Arabic messages (6307 unapproved sender, 1001 bad credentials, 1008 insufficient balance). Sessions are minted with a synthetic email `{phone}@lamha.app` and an HMAC-derived password (`PASSWORD_SECRET`).

**Kolna's version is strictly better. Use Kolna's**:
- Kolna hashes codes with `OTP_HASH_SECRET`; Lamha stores OTPs in **plaintext** in `phone_otp.code`.
- Kolna has `MAX_VERIFY_ATTEMPTS`; Lamha has **no verify-attempt limit**, so a 6-digit code is brute-forceable within its 10-minute window.
- Kolna reads the sender from `OURSMS_SENDER`; Lamha hardcodes `"LamhaAds"` with a TODO comment.

Lamha also has these problems:
- `Math.random` is used for the code.
- **Hardcoded dev-bypass phone numbers** with code `000000` ship in production code.
- Raw OurSMS response text is returned to the client.
- `listUsers({perPage:1000})` is used for recovery, which breaks above 1,000 users.

Worth taking from Lamha:
- `supabase/functions/change-phone/index.ts`: a 2-step `send`/`verify` that sends the OTP to the **new** number, then updates the auth email and `user_profiles.phone`. Port it onto Kolna's hashed-OTP tables.
- The OurSMS error-code mapping, for the **marketing SMS** dashboard feature (requirement 10). Build `send-sms-campaign` as an admin-only function that reuses the same OurSMS call with a batched `dests[]`, records `sms_campaigns`/`sms_campaign_recipients`, and respects opt-out. Lamha has no marketing-SMS code; only the OTP call exists.

---

## 9. `admin-content` action pattern and scheduled notifications

`supabase/functions/admin-content/index.ts` (467 lines) is one POST endpoint, `{action, ...}`:
1. Verify the JWT with the anon client and `getUser()`.
2. Gate on `user_roles.role === 'admin'` with the service role.
3. A `switch(action)` covers ~28 actions: `get_options`, `list_/upsert_/delete_` for people, episodes, events, clips and coverage categories, `get_/set_coverage_settings` with clamping, `sign_cover_upload`, `reconcile_uploads`, `list_ad_requests`, `set_ad_request_status`, `list_ad_payments` and `delete_ad_request`.
4. Errors return Arabic messages with 400 status (e.g. publishing without a cover).

`DASHBOARD_HANDOFF.md` documents the contract per action (payload and return), which is a good handoff format.

For Munyati, Kolna's RLS-first approach (`is_admin()` policies) should remain the default. Use an `admin-content`-style function **only** where the service role is required or a multi-table transaction-like orchestration is needed:
- listing all payments, receipts and disputes;
- dispute resolution (`resolve_dispute`, `ban_provider`, `refund_note`);
- SMS campaigns;
- plan edits that must propagate to `provider_subscriptions`.

Add an `admin_audit_log` insert for every action. Lamha does not log admin actions.

`supabase/functions/send-auto-reminder/index.ts` and `send-manual-notification/index.ts` both use FCM v1 with a service-account JWT. The reminder function reads `notification_settings` (`hours_before`, `target_mode`, templates), finds items ending within that window, dedups through `sent_notifications(ad_id, notification_type)`, and targets tokens by city or region.
This is directly reusable as the shape for **booking reminders** (24h / 2h before the appointment), **trial-ending** and **subscription-expiring** nudges, and **"proposal pending"** reminders. Trigger it via `pg_cron`. How Lamha schedules it is not visible in the repo.

`send-acceptance-notification` and `send-ad-notification` send email through Resend (`RESEND_API_KEY`). This could be useful for `contact@munyati.co` transactional mail, but it is not reviewed in depth here.

---

## 10. Analytics and logging

- `Core/Utilities/Analytics.swift` defines `enum Track`, a typed wrapper over `FirebaseAnalytics.Analytics.logEvent`.
  - Events: `ad_post_started`, `ad_plan_selected`, `ad_payment_started|succeeded|failed`, `ad_published`, `ad_viewed`, `ad_contact_tapped`, `ad_shared`, `search_performed`, `category_browsed`, `city_changed`.
  - `compact()` drops nil params. There are 14 call sites.
  - `search_performed` sends the raw query string to GA4. Avoid this in Munyati, since queries can contain names or phone numbers.
  - `GoogleService-Info.plist` has `IS_ANALYTICS_ENABLED = false`, while the FirebaseAnalytics product is linked. Whether events actually reach GA4 in production is **not verifiable**.
- `Core/Utilities/AppLogger.swift` provides OSLog `Logger`s under subsystem `com.lamha.ads`, categories Session/Home/PostAd/Media/Maps/Stats/Nav. It logs locally only, with no remote error logging.
- Neither Lamha nor Kolna integrates **Crashlytics** (grep found none).

For Munyati requirement 9 (analytics for everything, including error logs):
- Combine Kolna's server-side `analytics_events` + `record_analytics_event` RPC + insight RPCs (the dashboard source of truth for providers vs brides, services and categories) with Lamha-style `Track` for the GA4 funnels: signup role choice → budget set → service viewed → booking requested → approved/proposal → receipt uploaded → confirmed → completed → reviewed; and for providers, trial → plan viewed → subscribed.
- Add Crashlytics (or Sentry) for crash and error logs.
- Add a small `client_error_logs` table for non-fatal errors you want visible in the dashboard.
- Put an `AnalyticsSink` protocol behind `Track` so one call fans out to both GA4 and Supabase.

---

## 11. DiskCache

`Core/Utilities/DiskCache.swift` is a `DiskCache<T: Codable>` JSON-file cache in `Caches/com.lamha.ads.<namespace>/`, using a wrapper `{savedAt, value}` with `isFresh(key:ttl:)` (default 30 minutes). It is used only by `Features/Home/Domain/UseCases/GetHomeFeedUseCase.swift` (`namespace: "home_feed"`).
It has an odd `@_optimize(none) deinit {}`. Do not copy that. It is not `Sendable` and has no size cap.
Kolna already has `Packages/Shared/Sources/Shared/Persistence/CacheStore.swift`, so this is **not needed**.

---

## 12. Emira UI kit and theme

Theme (`Lamha Ads/Core/UICore/Theme/`):
- `EmiraColors.swift`: semantic tokens backed by asset-catalog named colors (shadcn-style `background/foreground/card/primary/primarySoft/primaryDark/secondary/muted/accent/destructive/border/divider/gold/goldLight/goldBorder/info/accent{Green,Purple,Orange}{,Tint}`). It also has `Color(hsl:)` and `Color(hex:)` initializers.
- `EmiraTypography.swift`: `titleLarge 28` / `titleMedium 22` / `titleSmall 18` / `body 16` / `bodyMedium` / `bodySmall 14` / `labelMedium 13` / `caption 12`, with a Cairo font toggle that is `useCairo = false`.
- `EmiraSpacing.swift`: spacing 4/8/12/16/20/24/32/48, plus `EmiraRadius` 8/12/16/24/pill.
- `EmiraImages.swift`: only `mapPin`.

Components (`Core/UICore/Components/`):

| Component | Purpose |
|---|---|
| `EmiraActionCard` | Tappable card: hero icon + title/subtitle + chevron (support/contact rows) |
| `EmiraFAQItem` | Expand/collapse Q&A row with rotating chevron |
| `EmiraHeroHeader` | Screen hero: large tinted icon + title + optional subtitle |
| `EmiraHeroIcon` | Circular tinted SF Symbol container |
| `EmiraRemoteImage` | Kingfisher-backed remote image with size/radius/contentMode |
| `EmiraScreenHeader` | Back arrow + centered title, RTL-aware |
| `EmiraSearchField` | Search capsule with clear button |
| `EmiraSectionHeader` | In-screen section title with leading icon |
| `EmiraStatsRow` | Views + likes counters with like toggle, compact/large sizes (ad-specific) |
| `ProfileMenuRow` | Full-width tappable profile menu row |
| `ShimmerPlaceholders` | `ShimmerBox`, `ShimmerListPlaceholder`, `ShimmerGridPlaceholder` |
| `AdDetailMapSection` | Google Maps preview + open-in-maps (ad-specific) |
| `TextFields/OTPInputField` | 6-digit UIKit-backed OTP field with `.oneTimeCode` autofill and `onComplete` |
| `TextFields/PhoneInputField` | Flag + `+966` + UIKit field, `.telephoneNumber` |
| `TextFields/ForcedEnglishTextField` (`EnglishPhoneField`) | `UITextField` subclass forcing a Latin keyboard and Western digits, fixing the SwiftUI RTL invisible-text bug; includes Arabic→Western digit `String` extension |

Modifiers: `.shimmer()`, `.blinkEffect()`, `.corner(radius:corners:)` (per-corner rounding), in `View+EmiraModifiers.swift`.
Extensions: `Image.chevronForward` (RTL-aware) and `Locale.isArabic`.

**Verdict:** Kolna's `DesignSystem` package already covers buttons, cards, chips, shimmer/skeleton, empty/error states, headers and `UIKitNumberField`. The Emira kit is redundant except possibly the **phone/OTP field trio**: compare it with Kolna's `UIKitNumberField` and `Authentication/.../OTPView.swift` before porting. Lamha's green/gold palette does not apply. Munyati's tokens must be rebuilt from burgundy `#8A0D3A`, gold `#DFC389`, cream `#F2E5D2` and ivory `#FAFAEC`.

---

## 13. Features list (Lamha) and relevance

`Lamha Ads/Features/`:

| Feature | What it is | Munyati relevance |
|---|---|---|
| Account | Auth (OTP), profile edit, phone change, My Ads, My Payments, My Likes, QR scanner and QR request | Pattern only; My Payments maps to a "subscription invoices" screen for providers |
| AdDetail | Ad detail, image carousel, contact actions, QR offer, Google map | Pattern for the provider/service detail page |
| Categories | Category grid and detail feed | Kolna has its own equivalent |
| CityPicker | Single city **or** region picker (`LocationScope.city/.region/.none`, persisted in `UserDefaults`; filters by city *name* strings) | Munyati needs **multi-select + All** keyed by city id. Rewrite it |
| Featured | Featured ads grid | Could become featured or Diamond-plan providers |
| Gallery | Vertical video pager with a player pool | No |
| Home | Banner slider, featured slider, categories row, giveaways, countdown, "coming soon" | Banner `internal_path` parsing (`Core/Utilities/BannerLinkParser.swift`) is replaced by the unified deep-link enum |
| Media | Episodes, coverage, AV/YouTube players | No |
| Partners | "Success partners" logos | No |
| PostAd | Multi-step post-ad form, pricing plan cards, PHPicker, location picker, influencer picker, **Tap payment** | Payment pieces (§2); `PricingPlanCard` maps to subscription plan cards |
| PrivacyPolicy | Remote `terms_policies` content with a local fallback | Kolna has CMS |
| QRScanner | Commented-out duplicates | No |
| Search | Ad search | Kolna has search |
| Support | FAQ (local repo) + support contacts | Requirement 28 needs report/flag tables. Lamha has none (`support_contacts` is just WhatsApp-style contact rows) |

The tab bar has 5 tabs: home, categories, postAd (login-gated), gallery and account. Munyati needs 4: Home, Explore (map), My Bookings, Profile.

---

## 14. Other small but useful bits
- **Force-update gate** in `App/RootView.swift` (`app_settings.min_required_version`, `force_update`, `store_url`, `update_message`). Kolna already has force update, so skip it.
- `HomeRoute` uses manual `Hashable` keyed by id, and routes carry full objects to avoid the "white page on first push" race documented in `Lamha Ads/LAMHA_CUSTOMER_AND_ADMIN.md` (P0). That is a useful lesson for NavigationStack routes.
- `ViewedAdsTracker` dedups view counting per session; `record-media-view` is an atomic RPC counter. Kolna already has analytics RPCs.
- `DASHBOARD_HANDOFF.md` is a good format for iOS-repo-to-dashboard contract handoffs: action table, payload, returns, UI notes and server-enforced constraints.

---

## 15. Quality issues: do NOT copy
1. **Committed `.claude/worktrees/cranky-newton-dc6d1f/`**: 268 tracked files, a full stale copy of the app including `.claude/settings.local.json`. Add `.claude/` to `.gitignore` in Munyati from day one.
2. **`GoogleService-Info.plist` is committed twice** (repo root and `Lamha Ads/`), even though `.gitignore` lists it; it was added before the ignore rule or force-added. It contains the Firebase iOS API key.
3. **The Google Maps API key is committed in plain text** in `Lamha-Ads-Info.plist` (`GMSApiKey`). Use xcconfig plus CI secrets, and restrict keys by bundle id.
4. **`supabase/.temp/` is committed** (project ref, pooler URL, versions).
5. **The live project ref is embedded in docs and comments** (`schema.sql`, the `send-push-notification` README, the `mark-uploaded` placeholder).
6. **Unresolved git merge-conflict markers** (`<<<<<<< HEAD` … `>>>>>>>`) are committed in `supabase/migrations/20260705000000_device_tokens_segments.sql`. This migration would fail if run.
7. **`AppConfig.swift` is git-ignored but required to compile**, with no `AppConfig.example.swift` template. Munyati should use `.xcconfig` per environment plus a checked-in template.
8. **The backend is not reproducible from the repo**: no RLS policies, `schema.sql` is "not meant to be run", only 2 migrations, and one edge function source is missing. Munyati should follow Kolna's full migrations-in-repo discipline.
9. **The OTP is insecure** (plaintext codes, no attempt limit, `Math.random`, hardcoded dev bypass numbers, raw provider errors returned to the client). See §8.
10. **`sign-media-url` has no authorization beyond "logged in".** See §7.
11. **Inconsistent env names**: `SUPABASE_ANON_KEY` vs `ANON_KEY` across functions.
12. **Dead or duplicate code**: `Navigation/Route.swift`, `AppState.swift`, empty `NavigationState.swift`, `AppRouter.appState`, unused `LocationSearchService`, commented-out `*1.swift` QR files.
13. **Domain drift** (`links.lamha.app` in docs vs `lamha.trndsky.com` in config), and the AASA is missing a path the router handles.
14. **`aps-environment = development`** is in the committed entitlements. Release builds should use production (Xcode normally manages this at export; just verify).
15. **Swift 5 mode, iOS 16 target, no real tests.** Kolna's Swift 6 / iOS 17 / SPM-modular setup is the better base.
16. Comments in the code reference "Capacitor" and an admin app path that is not in this repo. Keep documentation accurate.

---

## 16. "Take from Lamha" list

| # | Take | Source path(s) | Adaptation for Munyati |
|---|---|---|---|
| 1 | Tap charge creation | `lamha_backup_ios/supabase/functions/create-ad-charge/index.ts` | Rename it `create-subscription-charge`. Take `{plan_code}` and read the price from `subscription_plans`. Set `metadata.kind='subscription'` plus `subscription_id`. Use a Munyati description and email, `APP_DEEPLINK=munyati://pay-return`. Move `parsePhone`/`json`/`cors` into `_shared/` |
| 2 | Tap webhook (re-fetch, don't trust body) | `.../tap-webhook/index.ts` | Dispatch on `metadata.kind`. Verify amount and currency. Call one SQL RPC `settle_tap_charge(charge_id, charge jsonb)` that is idempotent and extends `current_period_end` exactly once. Optionally also verify Tap's `hashstring` |
| 3 | Payment return HTML page | `.../payment-return/index.ts` | Apply Munyati branding (burgundy/gold, Arabic copy, logo) and the `munyati://pay-return` deep link; call the same settle RPC |
| 4 | Status poll endpoint | `.../get-ad-payment-status/index.ts` | `get-subscription-status` returning `{paymentStatus, subscriptionStatus, planCode, currentPeriodEnd}` |
| 5 | Payment ledger table shape | `lamha_backup_ios/supabase/schema.sql` (`ad_payments`) | `subscription_payments` with `period_start/end`, `plan_code`, `UNIQUE(tap_charge_id)`, `raw jsonb`; RLS so the owner can read and the admin can read all |
| 6 | iOS payment service + hosted-page presenter | `Lamha Ads/Features/PostAd/Data/TapAdPaymentService.swift`, `Features/PostAd/UI/AdPaymentPresenter.swift` | Move them into a Kolna-style `Features/Subscription` SPM package. Set `callbackScheme = "munyati"`. Keep "returned ≠ paid" and the polling logic from `PostAdViewModel.runPayment`/`confirmPayment` |
| 7 | Admin payments listing + manual override | `.../admin-content/index.ts` (`list_ad_payments`, `set_ad_request_status`), `DASHBOARD_HANDOFF.md §4` | Dashboard: subscription payments table, a manual "mark active" for offline payment with a reason and an audit-log entry, and a parallel **receipts and disputes** view for bride-to-provider transfers |
| 8 | AASA + entitlements + share-URL builder | `lamha_backup_ios/.well-known/apple-app-site-association`, `Lamha Ads/Lamha Ads.entitlements`, `Core/DataCore/Domain/Models/AdShareText.swift` | Host the AASA on `munyati.co` with `/p/*`, `/s/*`, `/store/*`, `/c/*`, `/b/*`, `/invite/*` and exclusions for website pages. Add `applinks:munyati.co`. Add a Smart App Banner on the landing pages. Create a `ShareLink` builder |
| 9 | Deep-link state + notification delegate + `onOpenURL`/`onContinueUserActivity` | `Navigation/AppRouter.swift` (`DeepLinkState`), `Navigation/NotificationHandler.swift`, `App/RootView.swift`, `App/MainTabView.swift` | A single `DeepLink` enum with UUID ids, a host allow-list, one `deep_link` push key, and the cold-start cache (from Kolna). Map to 4 tabs. Drop the dead `Route`/`AppState` |
| 10 | FCM topic manager + token uploader | `App/NotificationTopics.swift`, `App/FCMTokenHandler.swift`, `supabase/functions/register-fcm-token/index.ts`, `migrations/20260705000000_device_tokens_segments.sql` (resolve the conflict markers!) | Multi-city topics (`city_<id>` per selected city; "All" means no city topics), plus `role_bride|role_provider` and `plan_<code>`. Never null an existing `user_id` on unauthenticated re-registration. Rewrite the migration cleanly |
| 11 | Scheduled reminder function shape | `supabase/functions/send-auto-reminder/index.ts` | Booking reminders (24h/2h), pending-proposal reminders, trial/subscription-expiry nudges via push and OurSMS. Dedup table `sent_notifications(entity_id, type)`. Run from `pg_cron` |
| 12 | Phone change via OTP to the new number | `supabase/functions/change-phone/index.ts` | Rebuild on Kolna's hashed OTP plus attempt limits; update `profiles.phone` and the auth identity |
| 13 | OurSMS error-code mapping | `supabase/functions/send-otp/index.ts` (error branch) | Reuse it in a new admin `send-sms-campaign` function (requirement 10). Keep Kolna's `send-otp`/`verify-otp` for OTP itself |
| 14 | Signed-upload / signed-read edge-function pattern | `supabase/functions/create-upload/index.ts`, `sign-media-url/index.ts` | `create-receipt-upload` (bride + booking status check, private `payment-receipts` bucket) and `sign-receipt-url` (bride, provider or admin only, short TTL, view audit log) |
| 15 | Single-use QR token (show + scan) | `Features/AdDetail/UI/Views/CustomerQRView.swift`, `Features/Account/UI/QRScanner/QRScannerView.swift` (`QRScannerController`), `supabase/functions/get-customer-qr`, `verify-qr-scan` | Optional booking check-in or completion proof that gates reviews and releases the same-category lock |
| 16 | `admin-content` action-router pattern | `supabase/functions/admin-content/index.ts` | Use it only for service-role operations (payments, receipts, disputes, bans, SMS campaigns). Add `admin_audit_log`. Document the contracts in a `DASHBOARD_HANDOFF.md`-style file |
| 17 | Typed analytics vocabulary | `Core/Utilities/Analytics.swift` (`Track`) | Use the Munyati funnel event names. Fan out via an `AnalyticsSink` protocol to GA4 and Kolna's `record_analytics_event`. Never log raw search text or PII |
| 18 | Phone/OTP UIKit-backed fields (only if Kolna lacks them) | `Core/UICore/Components/TextFields/{OTPInputField,PhoneInputField,ForcedEnglishTextField}.swift` | Restyle with Munyati tokens. Put them in Kolna-style `DesignSystem` |
| 19 | Center-pin location picker UX | `Features/PostAd/UI/Components/LocationPickerView.swift` | Port to **MapKit** (`Map` + `onMapCameraChange(.onEnd)` + `CLGeocoder`/`MKLocalSearchCompleter`). Drop the Google SDKs entirely |

**Do not take:** Google Maps/Places SDKs and keys; Lamha's OTP functions; `DiskCache`, `AppLogger` and Emira theme/components (Kolna has equivalents); media/gallery/episodes/coverage; the single-city `LocationScope`; dead navigation files; committed secrets and `.claude/worktrees`.

---

## 17. Could not verify
- Whether Lamha's AASA is actually served at `lamha.trndsky.com`, and whether universal links work in production.
- Whether the Google Maps key is restricted, and current Google Maps Platform pricing.
- Whether Firebase Analytics events reach GA4 (`IS_ANALYTICS_ENABLED=false` in the plist).
- Lamha's RLS policies, storage bucket policies and cron schedules (none are in the repo).
- Tap account capabilities for saved cards and recurring/merchant-initiated charges (not used in Lamha).
- App Store review outcome for Lamha's Tap-paid ad posting, which bears on Munyati's provider subscriptions (guideline 3.1.1 risk).
- The `mark-uploaded` function source (empty in the repo).
