# Munyati (منيتي): backend stack, region, cost and PDPL

> Research date: 2026-10-09. Answers owner requirement #12: "I usually use Firebase for notifications and Supabase as the backend. What is best for performance and cost?" Also covers #9 (analytics), #19 (remote content), #26 (push), #7 (Explore map) and the image CDN.
>
> **How the figures were gathered.** The sandbox's egress proxy blocked direct fetches of supabase.com, cloud.google.com and firebase.google.com. Every price below comes from web-search extracts of the official pricing pages plus 2026 third-party pricing guides; all are cited in the Sources section. Anything marked **(verify)** came only from secondary sources or from memory. Re-check these on the vendor pages before signing up. Prices are USD unless marked SAR.

---

## 1. TL;DR recommendation

| Decision | Recommendation | Why |
|---|---|---|
| Core backend | **Supabase Pro, hosted in `eu-central-1` (Frankfurt)** | The data is relational (bookings ↔ services ↔ providers ↔ categories ↔ cities ↔ plans ↔ payment proofs ↔ reviews). Several hard rules (#2, #13, #20) are easy to enforce in Postgres and hard in Firestore. The owner already has about 80 migrations, edge functions and a Next.js dashboard on this stack to reuse. Pricing is flat and predictable. |
| Middle East region? | **Supabase has none.** Its 17 regions are all in NA, EU, APAC and South America. Do not wait for one. | AWS `me-central-1` (UAE) and `me-south-1` (Bahrain) took physical damage from drone strikes in March 2026, and a September 2026 report says recovery is still incomplete. AWS's Saudi region is only *targeted* for December 2026. |
| Push | **Keep FCM**, sent from a Supabase edge function. Reuse `kolna-al-khafji-ios/supabase/functions/send-push`. | Free. The code exists, and FCM topics are useful for per-city broadcasts (Lamha already uses `region_<id>` topics). Direct APNs is also free and possible, but it means new code and no Android path. |
| Analytics (#9) | **Hybrid of 3 layers:** (A) curated business events, audit logs and error logs in **Postgres**, which feed the admin dashboard and the provider "insights" screen; (B) **Firebase Analytics (GA4)** for every tap and screen, free with no volume cap; (C) **Firebase Crashlytics** for crashes and non-fatal errors. Add **PostHog EU** later only if funnels or session replay are worth paying for. | Costs $0 up to 200k MAU, except Postgres storage. PostHog and Mixpanel bill per event above 1M/month, and "track everything" at growth scale would cost hundreds of USD a month. |
| Remote content (#19) | **DB-driven**: `app_config`, `app_strings`, `categories.icon_url`, `cms_pages` in Postgres, plus a public Storage bucket behind the Smart CDN. **Not** Firebase Remote Config. | Already built in Maalim (`app_config`, `cms_pages`, `home_sections`, `force_update`). One admin dashboard edits everything. Firebase Remote Config would mean a second console. |
| Explore map (#7) | **MapKit**: free, no key, already used in Maalim's `ExploreView`. Location queries via **PostGIS** in Supabase. | The Google Maps iOS SDK map is also free, but Places/Autocomplete is billed after 10k free calls a month. Use Google only if a field test in Khaibar or Taif shows Apple's POI data is poor. |
| Images | Resize **on device** before upload (thumbnail plus full size), serve from Supabase Storage through the Smart CDN, cache with Kingfisher on the client. **Avoid Supabase on-the-fly image transformations** at scale. | Transformations cost $5 per 1,000 origin images after 100 a month. That alone would be about $300/month at 60k images. |
| Data residency | Hosting in Frankfurt is **acceptable for a startup** under the amended PDPL transfer regulation, if the transfer basis is documented, data is minimised and the privacy policy discloses it. See §7. | No data-localisation mandate applies to a private consumer marketplace that holds no government or regulated-sector data. Get a local legal review before launch. |
| Dashboard and landing | Next.js dashboard (reuse `lamha_dahsboard` patterns) on **Vercel Pro** ($20/seat; Hobby is non-commercial only) or Cloudflare. Landing, privacy and terms pages as static pages. | Low cost. Universal-link file `.well-known/apple-app-site-association` served from `munyati.co` (Lamha pattern). |

**Estimated monthly cost** (details in §9): **about $35–55 at launch, $100–150 at 20k MAU, $650–900 at 200k MAU**, excluding SMS. OurSMS OTP traffic adds roughly **$70, $215 and $1,100** at the same three scales. **SMS, not the database, becomes the biggest line item.**

---

## 2. What the owner's existing repos already give us

| Asset | Where | Reuse for Munyati |
|---|---|---|
| OurSMS OTP (custom `phone_otp` table, HMAC-hashed codes, CSPRNG) | `kolna-al-khafji-ios/supabase/functions/send-otp`, `verify-otp`; `lamha_backup_ios/supabase/functions/send-otp` (`fetch("https://api.oursms.com/msgs/sms")`) | **Adapt.** `verify-otp` creates sessions with a synthetic email and an HMAC-derived password (`signInWithPassword`). Its fallback path calls `supabase.auth.admin.listUsers({ perPage: 1000 })`, so the lookup **breaks beyond 1,000 users**. For Munyati, prefer Supabase's native phone auth with a **Send SMS Hook** pointing at an edge function that calls OurSMS. Supabase Auth then owns OTP generation, expiry and rate limits. See `docs/research/oursms.md`. |
| FCM push from Postgres | `kolna-al-khafji-ios/supabase/functions/send-push/index.ts` (FCM HTTP v1, hand-rolled RS256 JWT for the service account, fired by a Database Webhook on `notifications` insert); migrations `20260725100000_notifications.sql`, `20260727100000_device_tokens.sql`, `20260737100000_notification_settings.sql` | **Reuse as-is**, then extend the payload with a `deeplink` field (#26). |
| FCM topics per region/city | `lamha_backup_ios/Lamha Ads/App/NotificationTopics.swift` (`region_<id>` topics, dynamic on city switch) | **Reuse** for city-targeted marketing pushes (#16, #17). |
| Engagement analytics in Postgres | `kolna-al-khafji-ios/supabase/migrations/20260906150000_engagement_analytics.sql` (`analytics_events`, enum `analytics_event_type`, `record_analytics_event()`, admin RPCs `get_active_users_stats()`, `get_engagement_insights()`), `20260912100000_analytics_event_context.sql` | **Adapt.** A good base, but it needs a wider event enum, a `role` column (provider or customer), `city_id`, monthly partitioning and daily roll-ups. |
| Typed analytics wrapper over GA4 | `lamha_backup_ios/Lamha Ads/Core/Utilities/Analytics.swift` (`enum Track` wrapping `FirebaseAnalytics`; comment: "If we ever swap GA4 for PostHog/Amplitude, only this file changes") | **Reuse the pattern.** Make it fan out to GA4 and to the Postgres curated events. |
| Remote config / CMS | `kolna-al-khafji-ios/supabase/migrations/20260716090000_admin_config_cms.sql` (`app_config` singleton with `feature_flags`, `cities`, `logo_url`, colors; `home_sections`, `home_banner_slides`, `cms_pages`), `20260763100000_force_update.sql` (`get_config()`), `20260730100000_cms_pages_bilingual.sql` | **Adapt.** Cities and categories must become real tables (#17, #18), not `text[]`. |
| Review masking and moderation | `20260753100000_review_bans_reactions_masking.sql`, `20260756100000_reviews_full_name_backend.sql`, `20260765100000_review_approval_workflow.sql` | **Adapt** for two-way reviews after completion (#15). |
| Tap payments | `lamha_backup_ios/supabase/functions/create-ad-charge`, `tap-webhook`, `payment-return`, `get-ad-payment-status` | **Adapt** for provider subscriptions (#2, #8, #11). |
| Universal links | Lamha `.well-known/apple-app-site-association` | **Reuse** on `munyati.co` (#27). |
| Map | Maalim uses MapKit (`Packages/Features/Explore/.../ExploreView.swift`, `PlaceMapView.swift`, `LocationPickerSheet.swift`). Lamha uses the Google Maps and Places SDKs (`GoogleMapsBootstrap.swift`). | **Reuse the MapKit approach.** |
| Admin dashboard | `lamha_dahsboard` (Next.js 14.2.5, `@supabase/ssr` 0.5.2) | **Adapt.** |
| Firebase products in use | Maalim: `FirebaseCore` and `FirebaseMessaging` only (no Crashlytics or Analytics). Lamha: Messaging plus Analytics. | Add Crashlytics. |

**Not verifiable from the repos:** which Supabase region the existing projects run in (Maalim's `supabase/config.toml` holds only the project ref `tdwbchuupsqkdbmfwzec`). Check this in the Supabase dashboard. If those projects already run in Frankfurt with acceptable latency, that is real-world evidence for §4.

**Missing for Munyati:** pg_cron jobs and partitioning (no `cron.schedule` in any Maalim migration), an `error_logs` table, an `audit_log` table for disputes, PostGIS location queries, plan-limit enforcement, and storage policies for private payment receipts.

---

## 3. Supabase: pricing (2026)

| Item | Free | Pro ($25/mo per org) | Team ($599/mo) |
|---|---|---|---|
| Use for Munyati | Dev/sandbox only. Projects **pause after 7 days idle**; 2 active projects. | **Production** | Only if SOC 2 reports, SSO or 14-day backups are needed later |
| Monthly active users (Auth) | 50k (verify) | 100k, then **$0.00325/MAU** | same as Pro |
| Database disk | 500 MB | 8 GB, then $0.125/GB | same |
| File storage | 1 GB | 100 GB, then ~$0.021/GB-month | same |
| Egress (uncached) | 5 GB | 250 GB, then **$0.09/GB** | same |
| Cached egress (CDN) | 5 GB | 250 GB, then **$0.03/GB** | same |
| Edge Function invocations | 500k | **2M, then $2 per 1M** | same |
| Realtime messages | 2M | **5M, then $2.50 per 1M** | same |
| Realtime peak connections | 200 (verify) | **500, then $10 per 1,000** | same |
| Image transformations | not available | **100 origin images, then $5 per 1,000** | same |
| Compute credit | n/a | **$10/month** (covers one Micro instance) | same |
| Spend cap | n/a | **On by default** on Pro | n/a |

**Compute add-ons** (billed hourly, a partial hour counts as a full hour):

| Size | ~$/month | Note |
|---|---|---|
| Micro (1 GB RAM) | ~$10 (covered by the credit) | Launch |
| Small (2 GB) | ~$15 | Launch to early growth |
| Medium (4 GB) | ~$60 | Growth |
| Large (8 GB, dedicated CPU) | ~$110 | Scale |
| XL and above | not verified | Scale+ / read replicas |

Smart CDN: Storage assets are CDN-cached, and with Smart CDN updates and deletes propagate in about 60 s. Manual purge needs Pro or above. This matters for #19: swapping a category logo at the same path shows up within about a minute. Putting a version in the filename is still the safer cache-buster.

Other notes:
- Postgres, Auth and Storage objects stay in the chosen region. Backups, logs and edge-function execution are **not** covered by that residency guarantee (erfi.dev analysis). Disclose this in the privacy policy (§7).
- **Point-in-time recovery** is a paid add-on. Its price was not verified in this run. Budget for it once real payments and disputes exist (verify).

## 4. Region and latency to Dammam, Riyadh and Taif

| Option | Status (Oct 2026) | Verdict |
|---|---|---|
| Supabase in a Middle East region | **Does not exist.** The live catalogue has 17 regions: us-west-1/2, us-east-1/2, ca-central-1, eu-west-1/2/3, eu-central-1/2, eu-north-1, ap-south-1, ap-southeast-1/2, ap-northeast-1/2, sa-east-1. | n/a |
| AWS `me-central-1` (UAE) or `me-south-1` (Bahrain), for example self-hosted | Drone strikes physically damaged both regions in March 2026. AWS told Middle East customers to migrate to other regions, and a September 2026 report says Bahrain is still not fully restored (secondary source). | **Avoid** for now |
| AWS Saudi region | Announced; **targeted for December 2026**, 3 AZs. | Revisit in 2027 if Supabase adds it or a customer requires KSA residency |
| Azure "Saudi Arabia East" | Targeted Q4 2026 | Not relevant to Supabase |
| Google Cloud Dammam `me-central2` | Live. Firestore has supported Dammam since 2024-01-02, and Cloud Functions **2nd gen only** runs there. **Billing restriction:** a customer with a **KSA billing address must buy Google Cloud (any region) through CNTXT**; non-KSA customers need invoiced billing to use Dammam. | The only "in-Kingdom" option for a Firebase stack, but with billing friction for a Saudi company |
| **Supabase `eu-central-1` (Frankfurt)** | Live | **Recommended** |
| Supabase `ap-south-1` (Mumbai) | Live | Alternative; test it |

**Latency.** No authoritative Riyadh→AWS measurements were found. A gaming-network blog estimates **70–95 ms Riyadh→Frankfurt**. Mumbai is closer as the crow flies (~2,700 km vs ~4,000 km), but routes from KSA carriers often transit Europe, so Mumbai is not guaranteed to be faster.

**Action before creating the project** (the region cannot easily change later): ping `ec2.eu-central-1.amazonaws.com` and `ec2.ap-south-1.amazonaws.com`, for example from cloudping.info, over STC, Mobily and Zain 4G/5G in Dammam and Riyadh at peak hours. Pick Frankfurt unless Mumbai is clearly faster (more than 25 ms). Frankfurt also puts the data under GDPR jurisdiction, which helps the PDPL transfer case (§7), and sits next to PostHog EU (Frankfurt) if PostHog is added.

**Why ~80 ms does not matter much:** a booking app makes few round-trips per screen. Mitigations: use RPCs (one round-trip per screen instead of several REST calls); serve images and icons from the CDN, which has edge locations near the Gulf; cache config, strings and categories on device; use optimistic UI for booking actions.

## 5. Firebase as the backend (Firestore + Cloud Functions)

**Pricing (Standard edition, us-central1 default table):** reads **$0.03 per 100k**, writes **$0.09 per 100k**, deletes **$0.01 per 100k**. Free tier: 50k reads, 20k writes and 20k deletes per day, 1 GiB stored, 10 GiB egress a month. Storage is about $0.15/GiB-month. Dammam has its own regional price row that could not be extracted (verify; Middle East regions are usually priced higher). Cloud Functions 2nd gen is billed as Cloud Run. Analytics, FCM, Crashlytics and Remote Config cost nothing on both the Spark and Blaze plans.

**Why Firestore is a worse fit for Munyati than the raw per-read price suggests:**

1. **Hard rules need relational constraints.**
   - #20, one active booking per category per bride, is a single partial unique index in Postgres:
     ```sql
     create unique index one_active_booking_per_category
       on bookings (customer_id, category_id)
       where status in ('requested','reschedule_proposed','approved','awaiting_payment','payment_submitted','confirmed');
     ```
     In Firestore this needs a sentinel document per (bride, category) plus a transaction in every write path. Any path that forgets it breaks the rule.
   - #2, plan service limits (Normal 1, Plus N, Diamond M), is a `before insert` trigger on `services` that compares against `subscription_plans.max_services`, which admins can edit.
   - #13, remaining budget, is one SQL view: `budget - sum(price) of active bookings`.
2. **Read amplification is unpredictable.** Every listener re-read, map-pin load and dashboard table scan is billed per document.
   - Example: an admin page that counts disputes or summarises 50k payment proofs reads 50k documents on every load, unless counters are kept denormalised with Cloud Functions.
   - Aggregation queries help, but joins (booking + service + provider + city + proof) do not exist. Data must be duplicated and kept in sync.
3. **Analytics (#9) wants SQL.** Admin metrics such as "services per category per city" or "providers vs customers by city over time" are `group by` queries in Postgres. Firestore needs a BigQuery export or pre-computed counters.
4. **Raw cost is not the deciding factor at these scales.** Rough estimate: 20k MAU × 10 sessions × ~300 reads = 60M reads ≈ **$18/month** at the us-central1 rate; 200k MAU is about $180. Both are comparable to Supabase. The real cost of Firestore is engineering time and the risk of a runaway bill from a buggy listener.
5. **No reuse.** About 80 migrations, the RPC patterns and the Next.js `@supabase/ssr` dashboard would all be rewritten.

**Verdict:** keep Firebase for what is free and good (FCM, Crashlytics, Analytics). Keep the data in Supabase.

## 6. Self-hosted options (brief)

| Option | Cost | Fit |
|---|---|---|
| Self-hosted Supabase (Docker) or plain Postgres on a VPS | Server only (≈ $10–60/mo; Hetzner prices not verified) | Saves money only beyond about 200k MAU. You own backups, upgrades, security patches and uptime. Worth considering later **only** if KSA residency is demanded: run it on an in-Kingdom cloud (Google Dammam through CNTXT, Azure or AWS Saudi once live, or a local provider). |
| Appwrite Cloud | Pro reportedly $25/project/month since Sept 2025 (verify) | Historically MariaDB-based. Weaker SQL analytics. No reuse. |
| PocketBase | Free (MIT) plus a ~$5 VPS | SQLite on a single server, no horizontal scaling, no managed backups. Fine for prototypes, wrong for a two-sided marketplace with admin auditing. |

## 7. Saudi PDPL: residency, cross-border transfer, privacy policy

> Not legal advice. Sources are law-firm and consultancy summaries plus the SDAIA SCC document. Have a Saudi lawyer review before launch.

**Status of the law**
- The PDPL (amended 2023) and its Implementing Regulations became enforceable in **September 2024**.
- The **Regulation on Personal Data Transfer Outside the Kingdom** (amended September 2024) implements Article 29.
- SDAIA published **Standard Contractual Clauses**, and in February 2025 a non-binding **transfer risk-assessment guideline**.
- A third consultation on amendments ran from 27 April to 27 May 2025. Whether it was finalised is **not verified**.

**Is hosting in Frankfurt allowed?** Yes. There is no blanket localisation requirement for a private-sector consumer app, but the transfer needs a basis:
1. **Adequacy:** transfers to countries SDAIA deems adequate are free, subject to minimisation. **The adequacy list had not been published** in the sources reviewed.
2. **Appropriate safeguards:** SDAIA SCCs, Binding Common Rules, or a certification.
3. **Exceptions:** for example, a transfer needed to perform a contract the data subject is party to. Commentary says these exceptions are narrower than teams assume, and that **sensitive data generally cannot use them**.
4. **Transfer risk assessment:** required at least when relying on safeguards or exceptions, or for continuous or large-scale transfers of sensitive data. Sources differ on whether it is needed for every transfer. **Write one anyway**: 2–3 pages listing data categories, recipients, countries and protections.

**Practical checklist for a startup**
- Sign the **Supabase DPA**, and check Firebase/Google's and PostHog's DPAs if used. Record which transfer basis applies to each vendor: Supabase (Germany), Google/Firebase (US and global), Vercel, OurSMS (KSA), Tap.
- **Minimise data.** No national ID numbers. Payment receipts (#5) are needed for dispute resolution, but:
  - store them in a **private** Storage bucket;
  - give access only through short-lived signed URLs for the bride, the provider and admins;
  - delete them after a stated retention period (for example 12 months after booking completion or dispute closure);
  - log every admin view in `audit_log`.
- PDPL lists **credit data** among its sensitive categories. Receipts showing IBANs and bank names are probably "financial" rather than credit data, but **ask counsel**. If treated as sensitive, the "exception" transfer route is closed and SCCs plus a risk assessment become mandatory.
- **Registration on SDAIA's National Data Governance Platform** is required when, among other triggers, processing personal data is the controller's *main activity* or it processes *sensitive data*. A marketplace may fall in scope, so plan to register. A **DPO** is required when core activities involve sensitive data or regular large-scale monitoring. Product analytics on every tap (#9) could arguably count as monitoring, which is another question for counsel.
- **Breach notification** to SDAIA within 72 hours, as commonly summarised from the Implementing Regulations (verify).

**What the privacy policy (munyati.co/privacy, Arabic and English) must contain**

The PDPL requires a privacy policy made available *before* collection that states: purpose, data collected, method of collection, storage, processing, destruction, and data-subject rights and how to exercise them. This summary is from secondary sources; verify the exact Article 12 text. For Munyati, list:
1. The controller's identity, Commercial Registration and contact: contact@munyati.co.
2. The data categories:
   - phone number (OTP), name, city, budget (#13);
   - booking history;
   - provider bank, wallet and IBAN details (#5);
   - payment receipt images;
   - reviews, shown with masked names (#15);
   - device and push tokens;
   - analytics and crash data;
   - approximate location for the Explore map.
3. The purpose for each category, and its legal basis (contract, consent for marketing SMS and push (#10), legitimate interest for fraud prevention).
4. **Cross-border transfer disclosure:** "Your data is stored with Supabase in Frankfurt, Germany (AWS), with push and crash services by Google Firebase and SMS by OurSMS in KSA…", plus the safeguards relied on.
5. Retention periods per category, especially receipts and analytics.
6. Rights: access, correction, destruction, a copy, withdrawing consent. Also in-app **account deletion**, which Apple requires as well. Maalim's `supabase/functions/delete-account` is reusable.
7. Marketing opt-in and opt-out for OurSMS campaigns (#10) and push topics.
8. The complaint route to SDAIA.
9. The date of the last update, and how changes are notified.

## 8. Component recommendations

### 8.1 Push notifications (#4, #26)

| | FCM (via Supabase edge function) | Direct APNs (p8 + ES256 JWT from an edge function) |
|---|---|---|
| Cost | $0 | $0 |
| Existing code | **Yes**: `send-push` (FCM HTTP v1, Database Webhook on `notifications` insert) | None. A developer report shows APNs can return 200 OK with no delivery when headers or topic are wrong, so it needs careful testing. |
| Topics / broadcast | **Yes**: per-city topics (Lamha pattern) for marketing | You fan out yourself, one HTTP/2 request per token |
| Android later | Works | Must add FCM anyway |
| App dependency | FirebaseMessaging SDK (already in both apps) | None |

**Recommendation: FCM.** Every booking event (request, approve, decline, reschedule proposal, payment uploaded, payment confirmed, reminder, review request, demo booking (#24)) inserts a row into `notifications`, and the webhook sends the push.
- Add `deeplink text` to the payload, for example `munyati://booking/<id>` or `https://munyati.co/b/<id>`, so a tap routes to the screen (#26).
- Keep the in-app notification inbox in Postgres.

### 8.2 Analytics for "everything" (#9): hybrid design

| Layer | Tool | What goes there | Cost |
|---|---|---|---|
| **A. Business truth** | **Postgres** (Supabase) | Counts and trends: users by role and city; services per category and city; bookings funnel by status; payment proofs (submitted, confirmed, disputed); reviews; subscriptions by plan (MRR); SMS sent and cost (see `oursms.md`). | Included |
| **A2. Curated interaction events** | Postgres `analytics_events`. Extend Maalim's table with `role`, `city_id`, `provider_id`, `service_id`, `props jsonb`, `session_id`, `app_version`. **Partition monthly**, roll up nightly with **pg_cron** into `analytics_daily`, drop raw partitions after 90–180 days. | About 20–30 typed events that matter to admins **and providers**: `service_view`, `provider_profile_view`, `whatsapp_tap`, `call_tap`, `share_tap`, `booking_started`, `booking_submitted`, `search`, `category_open`, `city_filter_changed`, `budget_set`, `banner_click`. These feed a **provider "Insights" screen** ("your profile got 230 views this month"), a natural **Plus/Diamond selling point** (#24 conversion). | Included. ~2.4M rows/month at 20k MAU is fine. |
| **A3. Audit and errors** | Postgres `audit_log` (admin actions, payment-proof approve/reject, bans, dispute resolutions, plan changes) and `error_logs` (client API failures plus edge-function errors with code, endpoint, app version, user id) | Dispute handling (#5, #28) and the "error logs" part of #9. Supabase's own logs have limited retention, so keep app-level errors in the database. | Included |
| **B. Every tap and screen** | **Firebase Analytics (GA4)** behind the Lamha `Track` wrapper. One call site fans out to GA4 and, for curated events, to A2. | Screen views, every button tap, funnels, retention, audiences. Optional free BigQuery sandbox export. | **$0** |
| **C. Crashes and non-fatal errors** | **Firebase Crashlytics** | Crashes; non-fatal decode or network errors via `recordError`. | **$0** |
| Optional later | **PostHog Cloud EU (Frankfurt)** | Funnels and retention UI, session replay (mobile: 2,500 recordings free, then ~$0.01 each), feature flags, HogQL API the dashboard can query | 1M events/month free, then ~$0.00005/event (secondary sources; identified events can cost more). "Track everything" at 20k MAU (~10M events) is roughly **$300–450/month (verify)**. |
| Not recommended | Mixpanel | Similar to PostHog: 1M free, then ~$0.28 per 1k events on Growth | ~$2,500/month at 10M events |
| Optional | Sentry | Better server and edge-function error tracing | Free for 5k errors; Team $26/mo |

Why not "every tap in Postgres": 200k MAU × 10 sessions × 100 taps is about **200M rows/month**. That would force a large compute tier and partition management for data nobody queries row by row. Send raw taps to GA4, which is free, and keep Postgres for events with business meaning.

### 8.3 Remote content without a new build (#19)

| | Supabase DB + Storage/CDN (recommended) | Firebase Remote Config |
|---|---|---|
| Strings | `app_strings(key, ar, en, updated_at)`. App fetches `get_config()` plus a strings delta on launch, using an `updated_at` or version check, caches to disk, and **falls back to the bundled `Localizable.xcstrings`**. | Key/value; 3,000 parameters per template; 2,000 conditions |
| Images and category logos | Public `content` bucket behind the Smart CDN; `categories.icon_url` holds a **versioned path** (`icons/makeup_v3.png`); upload through the dashboard | Not suited to images (URLs only) |
| Cities, categories, plans | Real tables (#16, #17, #18) | Not suited |
| Admin UX | **One dashboard** (Next.js) | Firebase console or REST API, i.e. a second admin tool |
| Flags, A/B tests, force update | `app_config.feature_flags` plus `force_update` (Maalim) | A/B testing is built in (free) |
| Cost | Included | Free |

Use Remote Config only if A/B experiments are wanted later. App Store guideline 2.5.2 allows content updates but not downloaded executable code; strings, images and config are fine.

### 8.4 Explore map (#7)
- **MapKit**: free, no API key, native SwiftUI `Map`, clustering via `MKClusterAnnotation`. Reuse Maalim's `ExploreView` and `LocationPickerSheet`.
- **Google Maps SDK for iOS**: the map itself is free and unlimited per 2026 guides. **Places** (autocomplete, details) gets 10k free Essentials calls a month, then about $2.83 per 1k autocomplete calls (secondary source). It also adds a heavy SDK and an API-key setup (Lamha `GoogleMapsBootstrap.swift`).
- **Backend:** enable **PostGIS** and store `geography(Point)` on providers and stores (#14). Add a GiST index. Use an RPC `providers_in_bounds(min_lat, min_lng, max_lat, max_lng, city_ids[], category_id, max_price)` that returns lightweight pins only. This keeps Explore to one round-trip per viewport.
- **Field test** Apple Maps POI and address quality in **Khaibar** and **Taif** before final sign-off.

### 8.5 Images and CDN
- **Upload:** resize on device into two variants, a ~400 px thumbnail and a ~1600 px full image, encoded as JPEG or HEIC around 80% quality. Upload both. This avoids Supabase's paid transformations ($5 per 1k origin images after 100).
- **Public portfolio images:** public bucket with Smart CDN; cached egress is $0.03/GB beyond 250 GB.
- **Receipts (#5):** private bucket with RLS-protected signed URLs (60–300 s). Never serve them through the public CDN.
- **Client:** Kingfisher (already in Lamha) with a disk cache.
- **At 200k+ MAU,** if image egress dominates, consider Cloudflare R2, which has zero egress fees (from memory; verify).

### 8.6 OTP and SMS (#10)
Use Supabase phone auth with a **Send SMS Hook** pointing at an edge function that calls OurSMS (see `docs/research/oursms.md`). Make sessions long-lived; refresh tokens avoid repeat OTPs. Rate-limit per phone and IP. **SMS is the largest variable cost:** about SAR 0.069–0.13 per SMS according to OurSMS's 2026 blog, a figure to confirm with OurSMS sales.

## 9. Cost model

### Assumptions

| | Launch | Growth | Scale |
|---|---|---|---|
| Registered / MAU | 1k users (~800 brides, ~200 providers) | 20k MAU (~2k providers) | 200k MAU (~15k providers) |
| Sessions per MAU per month | 8 | 8 | 10 |
| DB size | < 1 GB | ~3–5 GB | ~30–60 GB (analytics raw rolled up) |
| Storage (portfolio ~30 imgs × 2 variants + receipts) | ~2 GB | ~30 GB | ~300 GB |
| Egress | < 20 GB | ~40 GB API + ~150 GB images (cached) | ~400 GB API + ~1.4 TB cached |
| Realtime peak connections (booking screens only; everything else via push) | < 50 | ~400–800 | ~3–5k |
| Edge Function calls (OTP, push, Tap, receipts) | < 100k | ~1M | ~5M |
| OTP SMS per month | ~2k | ~8k | ~60k |

### Monthly cost estimate (USD)

| Line item | Launch | Growth | Scale |
|---|---|---|---|
| Supabase Pro base | 25 | 25 | 25 |
| Compute (net of $10 credit) | 0 (Micro) | 5–50 (Small to Medium) | 100 (Large) to 200 (XL, verify) |
| Auth MAU overage (above 100k × $0.00325) | 0 | 0 | 325 |
| Egress overage | 0 | 0 | ~35 cached + ~15 uncached |
| Storage / DB disk overage | 0 | 0 | ~5–10 |
| Realtime connections overage | 0 | 0–5 | ~25–45 |
| Edge Function overage | 0 | 0 | ~6 |
| Staging project (Micro) | ~10 | ~10 | ~10 |
| PITR / backups add-on | – | optional (verify) | recommended (verify) |
| **Supabase subtotal** | **≈ 35** | **≈ 40–90** | **≈ 550–650** |
| Firebase (FCM, Analytics, Crashlytics) | 0 | 0 | 0 |
| MapKit | 0 | 0 | 0 |
| Dashboard and landing hosting (Vercel Pro 1 seat, or Cloudflare) | 0–20 | 20 | 20–40 |
| Sentry (optional) | 0 | 0–26 | 26–80 |
| Apple Developer ($99/yr) | 8 | 8 | 8 |
| **Total excl. SMS** | **≈ 45–65** | **≈ 70–145** | **≈ 610–820** |
| OurSMS OTP (SAR 0.13 / 0.10 / 0.069 per SMS) | ~70 | ~215 | ~1,100 |
| Optional PostHog "track everything" | 0 | ~300–450 (verify) | ~1,500+ (verify) |
| Tap fees (per subscription charge) | % of revenue, not modelled | | |

Rounded headline: **launch ≈ $35–55, growth ≈ $100–150, scale ≈ $650–900 per month, excluding SMS and Tap fees.**

**Firebase-centric alternative, for comparison only:**
- Launch: ~$0–10.
- Growth: ~$30–80 (Firestore ~$18 reads + ~$5 writes + Functions + Storage).
- Scale: ~$300–700 (Firestore ~$180+ plus Functions). If Firebase Auth / Identity Platform MAU billing applies above 50k MAU, add roughly $0.0055 per MAU, which is **from memory; verify**.
- It is similar or slightly cheaper in raw spend, but needs a full rewrite, denormalised counters and BigQuery for admin analytics. Saudi billing addresses also face CNTXT billing.

## 10. Final recommended stack

| Layer | Choice | Launch | Growth (20k MAU) | Scale (200k MAU) |
|---|---|---|---|---|
| DB / Auth / Storage / RPC / Edge Functions | Supabase Pro, `eu-central-1` (latency-test against `ap-south-1` first) | $35 | $40–90 | $550–650 |
| OTP and marketing SMS | OurSMS via Supabase Send SMS Hook + edge function | ~$70 | ~$215 | ~$1,100 |
| Push | FCM HTTP v1 from the `send-push` edge function (Database Webhook), with deeplink payload | $0 | $0 | $0 |
| Product analytics (taps, screens) | Firebase Analytics (GA4) behind the `Track` wrapper | $0 | $0 | $0 |
| Business metrics, provider insights, audit and error logs | Postgres tables, RPCs and pg_cron roll-ups shown in the admin dashboard | incl. | incl. | incl. |
| Crashes and non-fatal errors | Firebase Crashlytics (+ Sentry optional) | $0 | $0–26 | $0–80 |
| Remote content | `app_config`, `app_strings`, `categories`, `cities`, `cms_pages` + Storage Smart CDN | incl. | incl. | incl. |
| Map | MapKit + PostGIS bounds RPC | $0 | $0 | $0 |
| Images | On-device resize, public CDN bucket; receipts in a private bucket with signed URLs | incl. | incl. | +R2 if needed |
| Subscriptions billing | Tap (adapt Lamha `create-ad-charge`, `tap-webhook`) | fees only | fees only | fees only |
| Admin dashboard, landing, privacy, terms, support, AASA | Next.js on Vercel Pro (or Cloudflare) on `munyati.co` | $0–20 | $20 | $20–40 |
| **Total excl. SMS** | | **≈ $35–55** | **≈ $100–150** | **≈ $650–900** |
| **Total incl. SMS** | | **≈ $105–125** | **≈ $315–365** | **≈ $1,750–2,000** |

### Open items to verify
1. Run latency tests to Frankfurt and Mumbai from KSA mobile carriers before creating the project.
2. Re-check prices on supabase.com/pricing. This run could not fetch it directly; MAU overage, PITR and XL compute need confirming.
3. Get legal review of the PDPL transfer basis, the SDAIA registration and DPO triggers, and the receipt retention period.
4. Confirm OurSMS per-SMS price and sender-name approval.
5. **Out of scope, but flagged:** App Store guideline 3.1.1 (in-app purchase) may apply to provider subscriptions paid with Tap inside the iOS app. This needs its own review; it was not researched here.

---

## Sources

**Supabase**
- [Supabase pricing (official)](https://supabase.com/pricing)
- [Billing on Supabase (official)](https://supabase.com/docs/guides/platform/billing-on-supabase)
- [Compute add-ons (official)](https://supabase.com/docs/guides/platform/compute-add-ons)
- [Available regions (official)](https://supabase.com/docs/guides/platform/regions)
- [regions.ts in supabase/supabase](https://github.com/supabase/supabase/blob/master/packages/shared-data/regions.ts)
- [Supabase data residency analysis (erfi.dev)](https://erfi.dev/reference/supabase-data-residency/)
- [Storage CDN / Smart CDN (official)](https://supabase.com/docs/guides/storage/cdn/fundamentals)
- [Purge CDN cache (official)](https://supabase.com/docs/guides/storage/cdn/purge-cdn-cache)
- [Send SMS Hook (official)](https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook)
- [Push notifications example (official)](https://supabase.com/docs/guides/functions/examples/push-notifications)
- [Makerkit: Supabase pricing 2026](https://makerkit.dev/blog/saas/supabase-pricing)
- [Toolradar: Supabase pricing 2026](https://toolradar.com/blog/supabase-pricing-2026)
- [Jetadmin: Supabase pricing 2026](https://www.jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs/)

**Firebase / Google Cloud**
- [Firestore pricing (official)](https://cloud.google.com/firestore/pricing)
- [Cloud Firestore locations (official)](https://firebase.google.com/docs/firestore/locations)
- [Firestore release notes (Dammam support)](https://docs.cloud.google.com/firestore/docs/release-notes)
- [Cloud Functions locations (official)](https://firebase.google.com/docs/functions/locations)
- [Dammam region access (official)](https://cloud.google.com/docs/dammam-region-access)
- [KSA Data Boundary by CNTXT](https://docs.cloud.google.com/sovereign-controls-by-partners/docs/data-boundaries/ksa-data-boundary-cntxt-foundation)
- [KSA migration FAQ](https://support.google.com/cloud/answer/13567838?hl=en)
- [Firebase pricing (official)](https://firebase.google.com/pricing)
- [Remote Config quotas and limits (official)](https://firebase.google.com/docs/remote-config/quotas-limits)
- [Crashlytics BigQuery export](https://firebase.google.com/docs/crashlytics/bigquery-export)
- [Cloud Run functions pricing guide (nOps)](https://www.nops.io/blog/cloud-run-functions-pricing/)

**AWS and Saudi cloud regions**
- [AWS UAE region launch](https://aws.amazon.com/blogs/aws/now-open-aws-region-in-the-united-arab-emirates-uae/)
- [AWS Bahrain/UAE outage after strikes](https://cryptobriefing.com/aws-bahrain-uae-outage-iran-strikes/)
- [AWS Middle East disruption, Sept 2026](https://cybersecuritynews.com/aws-middle-east-services-disrupted/)
- [AWS Saudi region December 2026 (About Amazon)](https://www.aboutamazon.com/news/aws/aws-cloud-region-saudi-arabia)
- [AWS Saudi region December 2026 (W.Media)](https://w.media/aws-saudi-arabia-cloud-region-set-for-december-2026-launch/)
- [Microsoft Saudi region Q4 2026](https://meatechwatch.com/2026/02/11/microsoft-confirms-saudi-arabia-datacenter-region-to-go-live-in-q4-2026/)
- [Saudi cloud providers 2026 guide](https://momentumx.cloud/saudi-cloud-providers-2026/)
- [Riyadh latency estimates (gaming blog)](https://noping.com/blog/fortnite-servers-saudi-arabia-mumbai-migration-fix-2026)

**PDPL**
- [SDAIA Standard Contractual Clauses](https://sdaia.gov.sa/Documents/StandardContractualClausesForPersonalDataTransferEN.pdf)
- [Dentons: KSA cross-border framework](https://www.dentons.com/en/insights/alerts/2025/may/15/saudi-arabias-framework-for-cross-border-data-transfers)
- [Clyde & Co: risk assessment guidelines](https://www.clydeco.com/en/insights/2025/03/update-on-saudi-arabia-risk-assessment-guidelines)
- [Clyde & Co: 10 legal updates](https://clydeco.com/en/insights/2025/02/10-legal-updates-ksa-tech-and-data-laws)
- [Clyde & Co: PDPL enforceable](https://www.clydeco.com/en/insights/2024/09/saudi-arabia-s-personal-data-protection-law-become)
- [DLA Piper: PDPL in force](https://www.dlapiper.com/en/insights/publications/2024/02/saudi-arabias-new-personal-data-protection-law-in-force)
- [Securiti: transfer regulation overview](https://securiti.ai/regulation-on-personal-data-transfer-outside-the-kingdom/)
- [Baker McKenzie: DPOs and registration](https://resourcehub.bakermckenzie.com/en/resources/global-data-and-cyber-handbook/emea/saudi-arabia/topics/dpos-and-notification-requirements)
- [Bird & Bird: controller registration](https://twobirds.com/en/insights/2024/saudi-arabia-qualified-obligation-on-data-controllers-to-register-with-data-protection-authority)
- [Middle East Briefing: PDPL framework](https://www.middleeastbriefing.com/news/navigating-saudi-arabias-personal-data-protection-law-and-regulatory-framework)
- [Recording Law: PDPL 2026 guide](https://www.recordinglaw.com/world-laws/world-data-privacy-laws/saudi-arabia-data-privacy-laws/)
- [Tsaaro: cross-border transfers](https://tsaaro.com/newsletter/navigating-saudi-arabia%E2%80%99s-cross-border-data-transfer-regulations)

**Analytics, errors, maps, hosting, SMS**
- [PostHog EU cloud](https://posthog.com/eu)
- [PostHog pricing breakdown (Schematic)](https://schematichq.com/blog/posthog-pricing)
- [PostHog pricing (CubeAPM)](https://cubeapm.com/blog/posthog-pricing-and-review/)
- [Toolradar: PostHog](https://toolradar.com/tools/posthog)
- [Mixpanel pricing 2026 (Usercall)](https://usercall.co/post/mixpanel-pricing)
- [Mixpanel pricing (SaaS Price Pulse)](https://www.saaspricepulse.com/tools/mixpanel)
- [Sentry pricing (Toolradar)](https://toolradar.com/tools/sentry/pricing)
- [Sentry pricing (Capterra)](https://capterra.com/p/165426/sentry/pricing)
- [Google Maps API pricing 2026 (Woosmap)](https://www.woosmap.com/blog/google-maps-api-pricing-breakdown)
- [Google Maps API pricing 2026 (MapAtlas)](https://mapatlas.eu/blog/google-maps-api-pricing-2026)
- [Vercel pricing 2026 (Modelence)](https://modelence.com/compare/vercel-pricing)
- [Appwrite vs PocketBase (Toolradar)](https://toolradar.com/compare/pocketbase-vs-appwrite)
- [Direct APNs from backend issue (Apple forums)](https://developer.apple.com/forums/thread/760928)
- [CST bulk SMS price ceiling](https://www.cst.gov.sa/en/regulations-and-licenses/decisions/Regulation-456)
- OurSMS pricing: see `moniaty_ios/docs/research/oursms.md` ([pricing page](https://oursms.com/en/pricing/), [2026 blog](https://oursms.com/en/whatsapp-vs-sms-cost-in-saudi-arabia-2026-oursms/))
