# Munyati: App Store (and Google Play) policy review

Research date: 2026-10-09. The primary source is Apple's **App Review Guidelines**, which the page itself marks *"Last Updated: June 8, 2026"*: <https://developer.apple.com/app-store/review/guidelines/>. All guideline quotes below were taken from that page on the research date. Some third-party sites (apps.apple.com, support.google.com, calendly.com, appfollow) were blocked by this environment's proxy. Where a fact rests only on search-engine snippets of those pages, it is marked **(secondary / not fetched)**.

---

## TL;DR: Recommendations

| # | Topic | Recommendation | Risk if ignored |
|---|---|---|---|
| 1 | Provider subscriptions (Normal/Plus/Diamond) | **Use auto-renewable IAP (StoreKit 2) inside the iOS app**, with a 2-month free-trial introductory offer. You may *also* sell the same plans on `munyati.co` through Tap (3.1.3(b) multiplatform), as long as the app has **no link, button, price or wording that points to the web** (Saudi storefront anti-steering). Book an App Review consultation before building billing. | **High.** Tap-only or web-only provider plans that unlock in-app listing are a classic 3.1.1 rejection. |
| 2 | Bride → provider bank transfer + receipt screenshot | **Allowed. In fact required to be non-IAP** (3.1.3(e)). Word it as "pay the provider directly". Never imply that Munyati processes, holds or guarantees the money. | Low |
| 3 | UGC (services, photos, reviews) | Implement all four 1.2 items: filter/pre-moderation, report, block, published contact. Add a Terms/EULA acceptance with a zero-tolerance clause, and act on reports within 24h. | Medium (common rejection) |
| 4 | Account deletion / SIWA / privacy / ATT | In-app deletion is **required**. SIWA is **not required** for phone-OTP-only login. Fill in privacy labels and the privacy manifest. **No ATT prompt** if Firebase Analytics runs without IDFA and data isn't used for ads. | Medium |
| 5 | Demo booking for new providers | OK if it is **clearly labelled as a demo**, isn't counted as real activity or reviews, and isn't used for misleading upsell. Describe it in Review Notes. | Low |
| 6 | Remote content (strings, icons, images, CMS) | Allowed: it is data, not code. Do **not** use remote flags to hide or enable reviewed functionality, especially the paywall. | Low (high if flags hide IAP) |
| 7 | Review notes | Provide 3 accounts (bride, subscribed provider, new provider) with fixed OTP numbers. Seed bookings in every state and explain the manual-payment flow and the IAP products. | Medium (2.1 rejections) |

---

## 1. Provider subscriptions: IAP or Tap/web?

### 1.1 The rules (verbatim, current page)

- **3.1.1 In-App Purchase:** *"If you want to unlock features or functionality within your app, (by way of example: subscriptions, in-game currencies, game levels, access to premium content, or unlocking a full version), you must use in-app purchase. Apps may not use their own mechanisms to unlock content or functionality, such as license keys …"*
- **3.1.1(a) Link to Other Purchase Methods:** entitlements exist only *"in specific storefronts. In all other storefronts, except for the United States storefront, where this prohibition does not apply, apps and their metadata may not include buttons, external links, or other calls to action that direct customers to purchasing mechanisms other than in-app purchase."*
- **3.1.3 (preamble):** *"Apps in this section cannot, within the app, encourage users to use a purchasing method other than in-app purchase, except for apps on the United States storefront and as set forth in 3.1.1(a) and 3.1.3(a). Developers can send communications outside of the app to their user base about purchasing methods other than in-app purchase."*
- **3.1.3(b) Multiplatform Services:** *"Apps that operate across multiple platforms may allow users to access content, subscriptions, or features they have acquired in your app on other platforms or your web site … **provided those items are also available as in-app purchases within the app**."*
- **3.1.3(c) Enterprise Services:** applies only to apps sold *"directly by you to organizations or groups for their employees or students … Consumer, single user, or family sales must use in-app purchase."*
- **3.1.3(e) Goods and Services Outside of the App:** *"If your app enables people to purchase physical goods or services that will be consumed outside of the app, you must use purchase methods other than in-app purchase to collect those payments, such as Apple Pay or traditional credit card entry."*
- **3.1.3(f) Free Stand-alone Apps:** *"Free apps acting as a stand-alone companion to a paid web based tool (i.e. VoIP, Cloud Storage, Email Services, Web Hosting) do not need to use in-app purchase, provided there is no purchasing inside the app, or calls to action for purchase outside of the app."*
- **3.1.3(g) Advertising Management Apps:** *"Digital purchases for content that is experienced or consumed in an app, including buying advertisements to display in the same app (such as sales of "boosts" for posts in a social media app) must use in-app purchase."*
- **3.1.5:** in the current guidelines this is **Cryptocurrencies** (wallets, mining, exchanges, ICOs). It has **no bearing on Munyati**, because no crypto is involved. (The task brief assumed 3.1.5 covered physical goods; in older versions the physical-goods text lived elsewhere and is now 3.1.3(e).)
- **DPLA §3.3.1(C):** *"Without Apple's prior written approval or as permitted under Section 3.3.9(A) (In-App Purchase API), an Application may not provide, unlock or enable additional features or functionality through distribution mechanisms other than the App Store …"*. Source: <https://developer.apple.com/support/terms/apple-developer-program-license-agreement/>.

### 1.2 How this applies to Munyati

What a provider pays for is **in-app functionality**: the right to publish service listings inside the Munyati app, receive bookings in the app, and get more listings at higher tiers. That is exactly what 3.1.1 describes ("subscriptions … unlocking"). It is also the close cousin of 3.1.3(g): paying to have your content displayed to other users of the same app requires IAP.

The usual counter-arguments are weak:

- **"The provider's business is real-world, so 3.1.3(e)."** 3.1.3(e) covers goods and services *the buyer* consumes outside the app (a ride, a stay, a makeup session). A provider buying a listing slot is buying a digital service that is delivered inside the app. Brides paying providers is 3.1.3(e). Providers paying Munyati is not.
- **"B2B, so 3.1.3(c)."** Only for sales to organizations *for their employees or students*. Explicitly: *"Consumer, single user … sales must use in-app purchase."* Most Munyati providers are sole traders and small salons.
- **"Companion app, so 3.1.3(f)."** 3.1.3(f) is limited to free companions of a paid web tool, with examples like VoIP, storage, email and hosting, and **no purchasing inside the app**. Munyati's bride app is the marketplace itself, not a companion. Recent forum threads show App Review rejecting login-only B2B companion apps under 3.1.1 (see 1.3).

### 1.3 Precedents and reported rejections

| App / thread | What it shows | Source |
|---|---|---|
| **Booksy Biz** (salon/barber provider app) | The App Store listing states *"Booksy Biz offers auto-renewable monthly subscriptions based on the number of Staff Members associated with your account"*. Tiers run from about $29.99 (owner only) up to multi-staff tiers. This is the **closest analogue to Munyati: a provider-side subscription sold through IAP, tiered by capacity.** | <https://apps.apple.com/app/id725335996> (secondary / not fetched), <https://koalendar.com/blog/booksy-pricing> |
| **Calendly** | The iOS app sells only the single-seat *Standard* plan through Apple IAP. Teams are bought on the web, which fits the 3.1.3(b) and 3.1.3(c) pattern. Apple-billed subscriptions must be managed through Apple. | <https://calendly.com/help/how-to-upgrade-your-subscription-from-the-mobile-app> (secondary / not fetched) |
| **Fresha** | Charges per-team-member SaaS fees plus a 20% new-client commission and card processing fees. Whether its iOS partner app offers IAP **could not be verified**. | <https://www.fresha.com/pricing>, <https://pabau.com/blog/fresha-pricing/> (secondary) |
| **Vagaro Pro** | The listing shows the app as free. Whether it offers IAP **could not be verified**. | <https://apps.apple.com/app/id346778559> (secondary / not fetched) |
| **Uber Driver / Airbnb host** | Monetise through **commission on real-world transactions** (3.1.3(e)), not a listing subscription, so they are not precedents for subscription-to-list. | (no verified source for their in-app billing; general knowledge) |
| Apple forum 811018: B2B SaaS coaching app, existing accounts only, no purchase UI | Rejected under 3.1.1: *"Your app accesses digital content purchased outside the app, and that content is not available through in-app purchase."* Reviewers rejected the 3.1.3(b) argument. | <https://developer.apple.com/forums/thread/811018> |
| Apple forum 828238 (May 2026): freemium SaaS, web-only Stripe checkout, all prices and plan names stripped from the app | Rejected several times under 3.1.1 because the reviewer's account had a web-activated paid plan. | <https://developer.apple.com/forums/thread/828238> |
| Apple forum 698537 | Standard 3.1.1 template: content bought outside must also be available through IAP (3.1.3(b)). | <https://developer.apple.com/forums/thread/698537> |
| Apple forum 814676 (Feb 2026): **"Do Vendor Listing Plans With Feature Limits Require In-App Purchase?"** (marketplace vendor app for offline services, Free/Silver/Gold plans) | This is Munyati's exact question. Apple staff gave **no ruling** and told the developer to book a one-on-one App Review consultation through Meet with Apple. | <https://developer.apple.com/forums/thread/814676> |
| Owner's **Lamha** app (`lamha_backup_ios/supabase/functions/create-ad-charge`, `tap-webhook`) | Charges businesses for ad posting through Tap. Whether it passed App Review with this flow is **not verifiable from the repo**. If those ads are displayed inside Lamha, the model falls under 3.1.3(g) ("buying advertisements to display in the same app … must use in-app purchase"). Do not treat Lamha as proof that Tap-for-in-app-features is accepted. | repo |

Neither of the owner's iOS repos uses StoreKit. A grep for `StoreKit|SKProduct|Product.products` in `kolna-al-khafji-ios` and `lamha_backup_ios` returns nothing. **The IAP layer is net-new work.**

### 1.4 Saudi Arabia storefront specifics

- No external-purchase entitlement covers Saudi Arabia. The **StoreKit External Purchase Link** page currently lists only the **Netherlands, for dating apps** (<https://developer.apple.com/support/storekit-external-entitlement/>).
- Japan has its own MSCA regime, effective with iOS 26.2 per Apple's Dec 17, 2025 announcement: <https://www.apple.com/newsroom/2025/12/apple-announces-changes-to-ios-in-japan/> (secondary).
- The EU has the DMA terms.
- The **US storefront exemption from anti-steering** (3.1.1(a) and 3.1.3) explicitly applies only to the United States.
- A search found **no Saudi (GAC/CST) ruling** that changes Apple's rules in KSA. So in the Saudi storefront:
  - The app and its App Store metadata **may not** contain buttons, links, prices, or calls to action pointing to munyati.co checkout. This includes copy like "subscribe on our website" or "cheaper on the web".
  - **Outside the app** (SMS via OurSMS, email, WhatsApp, the website), Munyati may tell its providers about web subscription (3.1.3 preamble).

### 1.5 Options with risk levels

**(a) Auto-renewable IAP via StoreKit 2 + 2-month free-trial introductory offer. Risk: LOW (recommended)**
- One subscription group, e.g. `munyati.provider`, with three products: `provider.normal.monthly`, `provider.plus.monthly`, `provider.diamond.monthly`. Rank them Diamond = level 1, Plus = 2, Normal = 3, so upgrades and downgrades are automatic (3.1.2(b) *"should not be able to inadvertently subscribe to multiple variations of the same thing"*).
- Introductory offer: a **2-month free trial** is a supported duration (*"3 Days. 1 or 2 Weeks. 1, 2, 3, or 6 Months. 1 Year."*). Each person can redeem **one introductory offer per subscription group**. Source: <https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions>.
- Optionally **also** sell the same plans on munyati.co through Tap, as allowed by 3.1.3(b) because the items are also available as IAP. Both sources grant the same server-side entitlement. Apple does not require price parity, but the app must never mention the web price.
- Cost: Apple's commission is 15% under the **Small Business Program**. New developers qualify, and it applies to developers with ≤ $1M in proceeds in the prior calendar year (<https://developer.apple.com/app-store/small-business-program/>). Outside SBP, subscriptions are 70% in year 1 and 85% after a subscriber has a year of paid service. *"Free trials … are excluded from days of paid service"* and *"Upgrades, downgrades, or crossgrades … in the same subscription group don't affect the one year of paid service."* Source: <https://developer.apple.com/app-store/subscriptions/>.

**(b) Web-only purchase on munyati.co (Tap), no IAP and no CTA in the app. Risk: HIGH**
- This depends on 3.1.3(f) or a reviewer overlooking it. 3.1.3(b) does not apply because the plans would not be available as IAP. The rejections in forum threads 811018 and 828238 show App Review rejecting exactly this pattern, even with every price string removed. The reviewer's demo provider account must have an active plan to test provider features, and that alone triggers the "accesses content purchased outside the app" finding.
- It is also hard to sustain operationally. Providers who discover the app first cannot subscribe in it, and support staff cannot tell them inside the app where to pay.

**(c) Separate provider app ("Munyati Business"). Risk: neutral on payments; LOW–MEDIUM overall**
- A second app **does not change the 3.1.1 analysis**: provider plans still unlock in-app functionality, so pair it with (a). It also adds a second review, second listing, second set of screenshots and possible 4.3 spam scrutiny.
- Two apps for the two sides of a marketplace is a common, accepted pattern (Booksy / Booksy Biz, Uber / Uber Driver).
- The benefit is UX and product separation (bride-centric app vs business tool), not payments. **Recommendation:** start with **one app with role selection**, which matches requirement #1. Revisit a separate business app only if provider tooling grows large.

**Other model (for completeness):** a **commission per completed booking** (Airbnb/Uber model) on a real-world service could legitimately be collected outside IAP (3.1.3(e)). It conflicts with the owner's manual bank-transfer design (Munyati never touches the money) and with requirement #2, so it is not recommended now.

**Action:** book a **one-on-one App Review consultation** (Meet with Apple → "Request a one-on-one App Review consultation"), which Apple staff recommended in thread 814676, before building billing. Bring the plan matrix and screenshots.

### 1.6 Admin-editable plans vs App Store Connect

| Thing the admin wants to edit | Can the dashboard change it alone? | How |
|---|---|---|
| Plan display name and description in the app, features list, **max services per plan**, sort order, active flag | **Yes** | Store in `subscription_plans` (`code`, `name_ar`, `name_en`, `max_services`, `features jsonb`, `apple_product_id`, `web_price_sar`, `is_active`). The app shows this copy beside the StoreKit price. |
| **iOS price** | **No** (it lives in App Store Connect) | Change it in App Store Connect, or automate through the App Store Connect API (subscription price endpoints; needs an ASC API key). In the app, **always display `Product.displayPrice` from StoreKit**, never a DB price, so the shown price always matches the charge (3.1.2(c), Schedule 2). |
| Price **increase** for existing subscribers | No | Apple notifies subscribers. *"Some price increases require subscribers to opt in"*; non-consenting subscribers *"expire at the end of their current billing cycle"*. Apple supports keeping existing subscribers at the old price (<https://developer.apple.com/app-store/subscriptions/>). |
| **New tier** (e.g. "Diamond+") | No | Create a new product in App Store Connect and submit it for review. Map it in `subscription_plans.apple_product_id`. Until it is approved, hide it on iOS (filter plans by the products StoreKit actually returns). |
| Web (Tap) price | Yes | `web_price_sar` is used only by the munyati.co checkout. It is never shown in the app. |
| Free-trial length | No (on iOS) | Set the introductory offer per product in App Store Connect. It cannot be edited; you delete it and create a new one. One current and one future offer per storefront. |

Apple price points are fixed per currency (SAR is supported). Pick the nearest point to the admin's intended price. **Not verified here:** the exact SAR price-point list, and whether Saudi VAT (15%) is included in the displayed price. Check App Store Connect → Pricing for the Saudi storefront and *Agreements, Tax, and Banking*.

### 1.7 Server-side entitlement (one source of truth)

- **Table:** `provider_subscriptions` with columns `provider_id`, `plan_code`, `source` ('app_store' | 'tap_web' | 'admin_comp'), `status`, `current_period_end`, `trial_used bool`, `apple_original_transaction_id UNIQUE`, `tap_charge_id`, `raw jsonb`. The admin dashboard edits plans but reads entitlements.
- **Purchase:** call `Product.purchase(options: [.appAccountToken(providerUUID)])` so every Apple transaction carries the Supabase user id. After purchase, the app sends `Transaction.jwsRepresentation` to an edge function, e.g. `verify-apple-transaction`, which verifies the JWS chain against Apple Root CA G3 and upserts the entitlement.
- **Renewals and changes:** use **App Store Server Notifications V2** (<https://developer.apple.com/documentation/appstoreservernotifications>) to a new edge function, e.g. `apple-asn-v2`. Like Lamha's `tap-webhook`, run it with *Verify JWT OFF*, but it **must verify the `signedPayload` JWS** before use. Handle `SUBSCRIBED`, `DID_RENEW`, `DID_CHANGE_RENEWAL_PREF` (scheduled downgrade), `DID_CHANGE_RENEWAL_STATUS`, `DID_FAIL_TO_RENEW` / `GRACE_PERIOD_EXPIRED`, `EXPIRED`, `REFUND`, `REVOKE` and `OFFER_REDEEMED`. Reconcile with the **App Store Server API** "Get All Subscription Statuses".
  - Apple publishes an official App Store Server Library (Node/Java/Python/Swift). Whether the Node version runs unchanged under Supabase's Deno runtime was **not verified**.
- **Reuse:** the Lamha Tap code (`lamha_backup_ios/supabase/functions/create-ad-charge`, `tap-webhook`, `payment-return`) adapts to the **web** checkout. The fixes noted in `docs/research/lamha-ios-and-backend.md` §2 still apply: an idempotent `settle_subscription_payment` RPC and an amount/currency check.
- **Upgrade/downgrade behaviour** (Apple, <https://developer.apple.com/app-store/subscriptions/>):
  - Upgrade: *"immediately upgraded and receive a refund of the prorated amount"*.
  - Downgrade: *"continues until the next renewal date"*.
  - On downgrade the backend must **deactivate** (not delete) listings above the new `max_services` and let the provider choose which ones stay live.
- **Trial abuse:** Apple's intro-offer eligibility is per **Apple ID**, but Munyati's "first 2 months free" is per **provider account**. Check `trial_used` server-side. If a provider already used a web or Apple trial, the app should not advertise a free trial (`isEligibleForIntroOffer` covers only the Apple side).
- **Restore:** provide a "Restore purchases" button (3.1.1: *"make sure you have a restore mechanism"*), using `AppStore.sync()`.
- **Paywall disclosure:** before purchase, show what each tier gives (number of services etc.), the price per month, the auto-renewal terms, the trial length and post-trial price, and links to Terms (EULA) and Privacy. Apple requires these per 3.1.2(c) and DPLA Schedule 2.

### 1.8 Account deletion interaction

If a provider has an active Apple subscription, the deletion flow must *"notify them that billing will continue through Apple and ask them to cancel their subscription before continuing"*. Use `showManageSubscriptions`. Source: <https://developer.apple.com/support/offering-account-deletion-in-your-app/>.

---

## 2. Bride pays provider by bank transfer + receipt screenshot

- **Allowed, and IAP must not be used.** 3.1.3(e) says that for services *"consumed outside of the app, you **must** use purchase methods other than in-app purchase"*. Makeup, photography, venues and similar services are real-world services. This covers deposits and full payments alike.
- **The receipt upload is UGC and sensitive data.** Use the system **PHPicker** or `PhotosPicker`, an out-of-process picker that needs no Photos permission (5.1.1(iii): *"Where possible, use the out-of-process picker"*). Store receipts in a **private** Supabase bucket with signed URLs, visible only to the bride, that provider and admins (1.6 Data Security). Disclose them in the privacy policy and in the privacy label (see §4.3).
- **Provider IBAN/wallet details** are shown to the bride after approval. Treat them as financial info: same access rules, plus an audit log.
- **Wording to avoid:** anything implying Munyati processes, holds, escrows, guarantees or refunds the money. Examples: "الدفع الآمن عبر منيتي", "محفظة منيتي", "ضمان استرداد", "Pay in app".
- **Preferred wording:** "حوّلي المبلغ مباشرة لمزوّدة الخدمة" ("transfer the amount directly to the service provider"), "إرفاق إيصال التحويل" ("attach the transfer receipt"), "منيتي لا تستلم أو تحتفظ بأي مبالغ" ("Munyati does not receive or hold any money"). The dispute/report path should be phrased as **"report a problem"**, not "request refund".
  - This keeps the app honest under 5.6 and 2.3, and away from 5.1.1(ix)'s "highly regulated fields (such as banking and financial services …)".
- **Never sell anything digital through this channel.** Examples: "featured listing" for the provider, or a "premium budget planner" for the bride. Those would be 3.1.1 IAP items.
- **Non-Apple risk to flag:** whether facilitating payment instructions and receipt verification triggers **SAMA** payment-services regulation is a legal question outside App Store policy. It was not researched here; confirm with Saudi counsel.

---

## 3. User-generated content (guideline 1.2)

**Guideline 1.2 (verbatim):** apps with UGC *"must include:*
- *a method for filtering objectionable material from being posted to the app;*
- *a mechanism to report offensive content and timely responses to concerns;*
- *the ability to block abusive users from the service;*
- *published contact information so users can easily reach you."*

It continues: *"It is your responsibility to remove content that violates this guideline, your terms of service, or your community standards. If we find such content, we will ask you to remove it, and provide a plan to improve your compliance …"*

App Review's standard 1.2 rejection checklist, as reproduced in forum threads (<https://developer.apple.com/forums/thread/807358>, <https://developer.apple.com/forums/thread/116703>), also asks for:
- **users agree to terms (EULA)** that make clear there is **no tolerance for objectionable content or abusive users**;
- a developer who **acts on reports within 24 hours** by removing the content and ejecting the user.

Munyati UGC surfaces: service listings (text, prices, photos), provider/store profiles, portfolio images, reviews (both directions), receipt screenshots, booking notes, and any chat added later.

| Requirement | Munyati implementation | Reuse from repos |
|---|---|---|
| Filter | Pre-moderate **new providers and new listings** (status `pending → approved`). Pre-moderate **reviews** with an Arabic + English banned-word list and admin approval. Run image checks on uploads, with a manual queue at minimum. | Kolna `kolna-al-khafji-ios/supabase/migrations/20260765100000_review_approval_workflow.sql` (`reviews.status` pending/approved/declined) — reuse it. Kolna has no word filter (grep found none), so that is new. |
| Report / flag | "Report" on every provider, listing, store, review and user profile, and "Report a problem" on bookings (payment dispute). Back it with a `content_reports` table and an admin queue with SLA timestamps. | Kolna has admin-side flags (`20260723100000_post_flag_and_admin_create.sql`) but **no user-facing report table**. That is new work. |
| Block | A bride can block a provider and vice versa. Blocking hides the blocked party's content and listings, prevents new bookings between the two, and hides reviews from the blocker. Admins can **ban** a user. | Kolna `profiles.is_banned` + `admin_set_user_banned()` in `20260753100000_review_bans_reactions_masking.sql` covers the admin ban. User-to-user block is new. |
| Contact info | Support screen in Profile & Settings with `contact@munyati.co`, plus a support URL `https://munyati.co/support` in App Store Connect metadata. | Kolna CMS pages (`20260730100000_cms_pages_bilingual.sql`) can host terms and support text. |
| Terms acceptance | A checkbox or explicit acceptance at sign-up for both roles. The Terms must contain the zero-tolerance clause. | — |
| 24h response | Admin dashboard queue sorted by age, with push and email alerts to admins on new reports. | Dashboard pattern from `lamha_dahsboard`. |
| Masked reviewer names ("private mode") | Show only the masked name publicly; admins see the real name. | Kolna `get_reviews()` masks names to *"first 2 letters + first 2 letters of last name"* (`20260753100000_review_bans_reactions_masking.sql`), and admin RPCs keep full names. Reuse as-is. |

Also:
- **Age rating:** Apple's age-rating questionnaire was updated (new 13+/16+/18+ tiers). Answer "User-Generated Content: Yes" (<https://www.pocketgamer.biz/apple-overhauls-app-store-age-ratings-with-new-categories>, secondary). Reviews and photos warrant at least 13+. Choose the final rating in App Store Connect.
- **Fake reviews:** reviews only after completed bookings (requirement #15) helps with 5.6 and 5.6.3.

---

## 4. Account deletion, Sign in with Apple, privacy labels, ATT

### 4.1 Account deletion (5.1.1(v))

*"If your app supports account creation, you must also offer account deletion within the app."* Apple's guidance (<https://developer.apple.com/support/offering-account-deletion-in-your-app/>) says:
- It must be easy to find (account settings).
- It must delete the whole account record and associated data; deactivation alone is insufficient.
- No phone, email or chat-support flows unless the app is in a highly regulated industry.
- UGC must be deleted: *"photos, videos, text posts, and reviews"*.
- If deletion is not instant, tell the user how long it takes.
- If you must retain data by law, say what is kept.
- Handle Apple subscriptions as described in §1.8.

**Reuse:** Kolna `kolna-al-khafji-ios/supabase/functions/delete-account/index.ts` deletes the account in two steps: the `delete_my_account()` RPC as the user, cascading owned content, then `auth.admin.deleteUser` as the service role. It is wired in `Packages/Features/Account/.../AccountView.swift`. Adapt it for Munyati:
- **Bookings and receipts in dispute:** decide on retention (anonymise the bride or provider, keep the receipt for N days for admin dispute resolution) and **disclose it**.
- **Active provider subscription:** warn the provider first.
- **Upcoming confirmed bookings:** cancel them and notify the counterparty.

### 4.2 Sign in with Apple (4.8)

SIWA, or an equivalent privacy-preserving login, is required **only** when the app uses a *third-party or social login* (Google, Facebook, X …) for the primary account. Exemption: *"Your app exclusively uses your company's own account setup and sign-in systems."*

Phone number + OTP through OurSMS is Munyati's own account system, so **SIWA is not required**. If Google Sign-In is ever added, add SIWA at the same time.

**Guest browsing (5.1.1(v)):** *"If your app doesn't include significant account-based features, let people use it without a login."* Booking is account-based, but **browsing categories, providers and the map should work as a guest**, with the login wall only on book, save, review or report. Kolna already does this: `App/Sources/Composition/AppSession.swift` has a `guest` state and "posting is the only thing gated behind auth". The **budget question must be skippable** (5.1.1(iii) data minimisation; 5.1.1(v): *"Apps may not require users to enter personal information to function, except when directly relevant"*).

### 4.3 Privacy policy, nutrition labels, privacy manifest

- **Privacy policy:** 5.1.1(i) requires a policy link in App Store Connect and inside the app. It must list collected data, third parties (Supabase, Firebase/Google, OurSMS, Tap, Google Maps if used), retention and deletion, and how to revoke consent. Host it at `https://munyati.co/privacy`.
- **Expected App Privacy label entries.** All are *linked to the user* and used for *App Functionality* unless noted. **Tracking: No.**

| Category | Data |
|---|---|
| Contact Info | Phone number, Name |
| User Content | Photos (portfolio, receipts), Other user content (reviews, booking notes, budget) |
| Financial Info | "Other financial info": provider IBAN/wallet, transfer receipts |
| Purchases | Purchase history (provider subscription) |
| Location | Precise or coarse, if Explore uses device location. Ask with a clear purpose string and offer manual city selection (5.1.1(iv)). |
| Identifiers | User ID; Device ID if any SDK uses IDFV or the FCM token |
| Usage Data | Product interaction (taps, clicks, screen views), also for **Analytics** |
| Diagnostics | Crash data, performance data, other diagnostic data (error logs), also for **Analytics** |

- **Privacy manifest** (`PrivacyInfo.xcprivacy`): required-reason API declarations for the app, and signed manifests from third-party SDKs (Firebase ships its own). See <https://developer.apple.com/documentation/bundleresources/privacy-manifest-files>. Neither repo was found to contain a `PrivacyInfo.xcprivacy` (grep for `PrivacyInfo` returned nothing), so add one.
- **Push marketing:** 4.5.4 requires explicit opt-in consent text in the app plus an in-app opt-out before any promotional push. **SMS marketing through OurSMS** is outside Apple's rules but subject to Saudi CST rules (sender-ID registration, opt-out); not researched here.

### 4.4 App Tracking Transparency

Apple defines tracking as *"linking user or device data collected from your app with user or device data collected from other companies' apps, websites, or offline properties for targeted advertising or advertising measurement purposes … [or] sharing … with data brokers."* The IDFV may be used for analytics without ATT. Source: <https://developer.apple.com/app-store/user-privacy-and-data-use/>.

**Recommendation:** first-party analytics (Supabase event tables) plus Firebase Analytics **without IDFA**, with no ad SDKs and no Google Ads linking or ad personalisation, means **no ATT prompt is needed** and the privacy label says "Tracking: No".
- **Without-IDFA variant:** the CocoaPods route is `$FirebaseAnalyticsWithoutAdIdSupport = true` (<https://firebase.google.com/docs/ios/supporting-ios-14>). The SPM product name changed across Firebase major versions, so **verify the current SPM product** for v11+.
- **Repo status:** Lamha links the plain `FirebaseAnalytics` product (`lamha_backup_ios/Lamha Ads.xcodeproj/project.pbxproj`). Kolna links only `FirebaseMessaging` (Firebase 11.15.0 per `Package.resolved`).
- **If ads or attribution are added later** (e.g. Meta/Snap install campaigns for brides), ATT and the label must be revisited.
- **Fingerprinting is prohibited regardless of ATT.**

---

## 5. Demo booking for new providers

No guideline prohibits it, and it is good onboarding. The relevant guardrails:

- **2.3.1 Hidden features:** *"All new features … must be described with specificity in the Notes for Review."* Describe the demo booking in Review Notes.
- **5.6 Code of Conduct / 1.1.6 false information:** the app must not *"trick"* users. Concretely:
  - Label the booking **clearly** as "طلب تجريبي / Demo booking" on the card, the detail screen and the notification. Use a fictional bride name such as "عروس تجريبية" ("demo bride") and no real person's data.
  - Send it **once per provider account** (requirement #24), flagged `is_demo = true`.
  - **Exclude** it from analytics KPIs, provider ratings and reviews, the bride-side app, admin dispute queues, revenue stats and the "one service per category" rule (requirement #20).
  - Let the provider walk the full flow (approve, reschedule proposal, mark payment received using a sample receipt image bundled with the app or served from CMS, then complete), and let them dismiss or delete it.
  - **No fake urgency or bait-and-switch** tied to the paywall. Avoid copy like "a real bride wants to book you — subscribe now". 3.1.2(a) says apps that *"trick users into purchasing a subscription under false pretenses or engage in bait-and-switch"* are removed.
  - If it triggers a push notification, the text must say it is a demo.

---

## 6. Remote content updates without a release

- **2.5.2:** apps *"may not … download, install, or execute code which introduces or changes features or functionality of the app"*.
- **DPLA §3.3.1(B) Executable Code** (verbatim, fetched from the DPLA): *"an Application may not download or install executable code. Interpreted code may be downloaded to an Application but only so long as such code: (a) does not change the primary purpose of the Application by providing features or functionality that are inconsistent with the intended and advertised purpose of the Application (b) does not bypass signing, sandbox, or other security features of the OS; and (c) … does not create a store or storefront for other Applications."*
- **2.3.1:** no *"hidden, dormant, or undocumented features"*.

**Allowed (data, not code):**
- Localized strings and copy overrides
- Category names and icons (PNG/SVG/PDF fetched from Supabase Storage or a CDN)
- Banners and home sections, onboarding images
- City lists, plan copy and limits
- CMS pages (terms, privacy, FAQ)
- Remote-config values (thresholds, sort orders)
- Force-update gates

**Reuse:**
- Kolna `20260716090000_admin_config_cms.sql`, `20260730100000_cms_pages_bilingual.sql`, `20260763100000_force_update.sql`
- Lamha `supabase/functions/admin-content`

**Not allowed or risky:**
- Downloading Swift or JS that adds new screens or flows
- Remote flags that hide functionality from App Review and switch it on after approval. Most dangerous: hiding the provider paywall or IAP during review, or switching iOS to a Tap checkout remotely. That is a 2.3.1 / 3.1.1 violation and can lead to removal.
- Feature flags are fine for gradual rollout of **reviewed** features. Any feature reachable in production must have been present and reviewable in the submitted build.

**Practical rules:**
- Bundle default strings and icons in the binary so the app works offline and on first launch.
- Cache remote assets.
- If a first-launch download is large, *"disclose the size … and prompt users"* (4.2.3(ii)). This is unlikely to matter for icons.

---

## 7. App Review notes and demo accounts (OTP, two-sided marketplace)

**2.1(a)** requires a demo account (*"include demo account info (and turn on your back-end service!)"*) or a pre-approved built-in demo mode. **2.1(b)** requires IAP items to be *"complete, up-to-date, visible to the reviewer and functional"*. Reviewers cannot receive Saudi SMS, so use fixed OTP test numbers.

**Reuse the existing bypass.** Kolna's `supabase/functions/send-otp/index.ts` and `verify-otp/index.ts` read a `DEV_PHONES` env list (default `+966500000000`), skip the real SMS, and accept `000000` for those numbers. The bypass is server-side and env-driven: no code in the binary and no hidden feature.
- Do **not** copy Lamha's version: it hard-codes `+201069300055` in `lamha_backup_ios/supabase/functions/send-otp/index.ts`.
- Exempt the review numbers from the OTP rate limit.

**Accounts to provide** (App Store Connect → App Review Information → Sign-in + Notes):

| Account | Phone / OTP | Pre-seeded state |
|---|---|---|
| Bride (customer) | `+9665000000x1` / `000000` | City set to "All". Budget set. Bookings in every state: pending, provider proposed reschedule, approved awaiting transfer, receipt uploaded, completed and reviewable. |
| Provider, subscribed | `+9665000000x2` / `000000` | Active plan (granted via the `admin_comp` source so the reviewer doesn't have to pay). 2+ services, a linked store, incoming pending booking, a receipt to confirm, bank details filled in. |
| Provider, new | `+9665000000x3` / `000000` | Fresh registration: shows the role choice, the **demo booking**, the **paywall with the 2-month free trial (sandbox)**, and upgrade/downgrade. Explain how to reset it, or give two spare numbers. |

**Notes text should explain:**
1. The two roles and how to switch.
2. That bride→provider payment is an **off-app bank transfer for a real-world service (3.1.3(e))**, and that Munyati never handles money.
3. That provider plans are **auto-renewable IAP** in group *X* with product IDs, and where the paywall is.
4. The demo booking.
5. The UGC controls (report, block, terms, moderation, contact) and where each is.
6. Account deletion location.
7. That the content is Saudi-city-filtered and "All" shows everything.
8. That the app uses no ATT because it does no tracking.

Keep the reviewer accounts permanently valid and the backend in production mode during review.

---

## 8. Google Play equivalents (if Android follows)

| Topic | Google Play rule | Munyati impact |
|---|---|---|
| Provider subscriptions | Google Play's billing system is required for *digital items, subscription services, app functionality or content, and cloud software and services* ("data storage, business productivity software, financial management software"). Apps may not lead users to other payment methods for in-scope items except under specific programs. User-choice and alternative-billing programs currently cover the EEA, UK, US, Japan, Korea, India and a few others. **Saudi Arabia was not found in any program list.** Policy: <https://support.google.com/googleplay/android-developer/answer/9858738> and <https://support.google.com/googleplay/android-developer/answer/10281818> (secondary / not fetched); programs: <https://support.google.com/googleplay/android-developer/answer/13821247>, <https://android-developers.googleblog.com/2026/06/play-expanded-billing.html> (secondary). | Use **Play Billing subscriptions** (base plans + free-trial offer) for the same three tiers, with server verification through Real-time Developer Notifications and the Play Developer API. Store these in the same `provider_subscriptions` table with `source = 'play'`. |
| Fees | Outside the EEA/UK/US, the 15% rate for auto-renewing subscriptions still applies. A new regional structure applies in the EEA/UK/US from June 30, 2026 (<https://support.google.com/googleplay/android-developer/answer/112622>, secondary). | ~15% in KSA |
| Bride bank transfer | Physical goods and services (examples include transportation, gym memberships, food delivery, cleaning, live-event tickets) are **excluded** from Play Billing. | Same as iOS: fine. |
| UGC | The UGC policy requires terms acceptance, robust ongoing moderation, **in-app reporting**, and **user blocking** (<https://support.google.com/googleplay/android-developer/answer/9876937>, secondary). | Same implementation as §3 |
| Account deletion | Requires an **in-app** deletion path **and a web link** where users can request deletion without reinstalling. The link goes in the Data safety form (<https://support.google.com/googleplay/android-developer/answer/13327111>). | Add `https://munyati.co/account/delete`. Build it now; it also helps on iOS. |
| Data safety | A Data safety form, the Play counterpart of Apple's privacy label. | Mirror §4.3 |
| Reviewer access | "App access" must contain **reusable credentials that bypass OTP/2FA**, valid from any location, with instructions in English (<https://support.google.com/googleplay/android-developer/answer/15748846>, secondary). | Same `DEV_PHONES` numbers |
| Photo access | Play's Photo and Video Permissions policy expects the system **photo picker** for one-off uploads such as receipts. Not fetched; verify. | Use the Android Photo Picker |
| Tracking | No ATT equivalent. Declare advertising ID use in Play Console; don't request `AD_ID` if unused. | — |

---

## 9. What is reusable, what to adapt, what is missing

- **Reusable as-is:**
  - Kolna review approval workflow and name masking (`20260765100000_*`, `20260753100000_*`)
  - Admin ban (`admin_set_user_banned`)
  - CMS, remote config and force-update migrations
  - Guest-first `AppSession`
  - OTP `DEV_PHONES` review bypass (Kolna version)
- **Adapt:**
  - Kolna `delete-account` (booking, receipt and subscription retention rules)
  - Lamha Tap functions, **for web checkout only**, with an idempotent settlement RPC and amount check
  - Lamha `admin-content` for remote assets
- **Missing (new work):**
  - StoreKit 2 paywall and restore
  - `verify-apple-transaction` and `apple-asn-v2` edge functions
  - `provider_subscriptions` with multi-source entitlement
  - App Store Connect product setup and Small Business Program enrolment
  - User-facing `content_reports`
  - User-to-user block
  - Banned-word filter
  - Terms/EULA acceptance
  - `PrivacyInfo.xcprivacy`
  - Demo-booking generator with `is_demo` exclusions
  - Web account-deletion page
  - Review-notes document

## Sources

- Apple App Review Guidelines (Last Updated June 8, 2026): <https://developer.apple.com/app-store/review/guidelines/>
- Apple Developer Program License Agreement §3.3.1(B)/(C): <https://developer.apple.com/support/terms/apple-developer-program-license-agreement/>
- StoreKit External Purchase entitlement (Netherlands only): <https://developer.apple.com/support/storekit-external-entitlement/>
- Apple Japan MSCA changes: <https://www.apple.com/newsroom/2025/12/apple-announces-changes-to-ios-in-japan/> (secondary)
- Auto-renewable subscriptions (groups, levels, upgrades, price changes, 85%): <https://developer.apple.com/app-store/subscriptions/>
- Introductory offers: <https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions>
- Small Business Program: <https://developer.apple.com/app-store/small-business-program/>
- App Store Server Notifications: <https://developer.apple.com/documentation/appstoreservernotifications>
- Account deletion: <https://developer.apple.com/support/offering-account-deletion-in-your-app/>
- User privacy and data use (tracking/ATT): <https://developer.apple.com/app-store/user-privacy-and-data-use/>
- Privacy manifests: <https://developer.apple.com/documentation/bundleresources/privacy-manifest-files>
- Firebase iOS 14 / IDFA: <https://firebase.google.com/docs/ios/supporting-ios-14>
- Apple forums:
  - <https://developer.apple.com/forums/thread/814676>
  - <https://developer.apple.com/forums/thread/811018>
  - <https://developer.apple.com/forums/thread/828238>
  - <https://developer.apple.com/forums/thread/698537>
  - <https://developer.apple.com/forums/thread/807358>
  - <https://developer.apple.com/forums/thread/116703>
- Booksy Biz listing: <https://apps.apple.com/app/id725335996> (secondary)
- Booksy pricing: <https://koalendar.com/blog/booksy-pricing>
- Calendly in-app upgrade: <https://calendly.com/help/how-to-upgrade-your-subscription-from-the-mobile-app> (secondary)
- Fresha pricing: <https://www.fresha.com/pricing>, <https://pabau.com/blog/fresha-pricing/> (secondary)
- Age ratings update: <https://www.pocketgamer.biz/apple-overhauls-app-store-age-ratings-with-new-categories> (secondary)
- Google Play:
  - Payments: <https://support.google.com/googleplay/android-developer/answer/9858738>
  - Payments FAQ: <https://support.google.com/googleplay/android-developer/answer/10281818>
  - User choice billing: <https://support.google.com/googleplay/android-developer/answer/13821247>
  - Expanded billing blog: <https://android-developers.googleblog.com/2026/06/play-expanded-billing.html>
  - Service fees: <https://support.google.com/googleplay/android-developer/answer/112622>
  - UGC: <https://support.google.com/googleplay/android-developer/answer/9876937>
  - Account deletion: <https://support.google.com/googleplay/android-developer/answer/13327111>
  - App access: <https://support.google.com/googleplay/android-developer/answer/15748846>
  - (all secondary / not fetched)
