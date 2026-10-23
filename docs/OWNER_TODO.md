# What the owner must do (phases 0–9)

Everything below is outside the code: accounts, keys, uploads and decisions. Do them roughly in
this order; items marked ⏳ take weeks, so start them first.

**Status (2026-10-23):** both apps are feature-complete, build and pass their tests; the
dashboard is live on Vercel; the iOS app talks to the live Supabase project. What's left is
mostly here: accounts and approvals, keys, the last two migrations (§9, §10) and the store
listings (§11, ready-to-paste text in `docs/STORE_LISTING.md`).

## 1. Accounts and legal (start today)
- [ ] ⏳ **Commercial registration (CR)** + register on **business.sa** (needed for Apple, Tap, OurSMS).
- [ ] ⏳ **Apple Developer account** as an organization (needs a D-U-N-S number) — 99 USD/year.
- [ ] ⏳ **OurSMS**: open an account and request sender names **`Munyati`** (transactional) and
      **`Munyati-AD`** (marketing). Approval takes 2–3 weeks.
- [ ] ⏳ **Tap Payments** merchant account (needs the CR). You get `sk_test_…` now and `sk_live_…` after approval.
- [ ] **Domain munyati.co**: make sure you own it and can edit DNS. Create **contact@munyati.co** email.
- [ ] Repos: optionally create `munyati_dashboard` and `munyati_web` and give Claude access
      (today the dashboard is in `dashboard/` and the website in `website/` of this repo; both can stay).
- [ ] 🔒 **Security (old project):** rotate the Supabase **service-role key** of the Lamha project
      (it's committed in `lamha_dahsboard/.env.example`) and upgrade that dashboard's Next.js.

## 2. Supabase (backend) — see `supabase/README.md`
- [ ] Create the project (Pro plan, region Frankfurt).
- [ ] Authentication: enable **anonymous sign-ins** (guest browsing) and the **email** provider (admins).
- [ ] Extensions: enable **pg_cron** and **btree_gist**.
- [ ] Push the database: `supabase link --project-ref <ref>` then `supabase db push`. The live
      project (`kjibwspziclotvynrjub`) already has the earlier migrations; §9 and §10 add the last two.
- [ ] Secrets (`supabase secrets set NAME=value`): `OTP_HASH_SECRET`, `PASSWORD_SECRET`,
      `OURSMS_API_KEY`, `OURSMS_SENDER`, `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON`,
      `PUSH_WEBHOOK_SECRET`, `SMS_WEBHOOK_SECRET`, `TAP_SECRET_KEY` (and optionally
      `DEV_PHONES` + `DEV_OTP_CODE` for App Review test accounts).
- [ ] Deploy functions: `supabase functions deploy send-otp verify-otp send-push send-sms delete-account tap-checkout tap-webhook`.
- [ ] Database webhooks: `notifications` insert → `send-push`, `sms_outbox` insert → `send-sms`
      (each with its `x-webhook-secret` header).
- [ ] First admin: invite your email (Authentication → Invite), then the SQL line in `dashboard/README.md`.

## 3. Firebase
- [x] Create a Firebase project, add the iOS app `co.munyati.app`, download **GoogleService-Info.plist**
      into `App/Resources/` (present in the repo checkout).
- [ ] Upload your **APNs key** (from Apple Developer → Keys) to Firebase Cloud Messaging.
- [ ] Create a service account with *Firebase Cloud Messaging API Admin* → its JSON goes into the
      `FIREBASE_SERVICE_ACCOUNT_JSON` secret.

## 4. The iOS app
- [x] Builds with Xcode (`xcodegen generate`, open `Munyati.xcodeproj`); unit and UI tests pass.
- [x] `App/Resources/BackendConfig.plist` points at the live Supabase project (anon key only).
- [x] App icon in the asset catalog.
- [ ] Set your Apple **Team** (`DEVELOPMENT_TEAM` in `project.yml`) once the Apple Developer account exists, then Product → Archive → upload to TestFlight.

## 5. Content and business decisions (in the dashboard)
- [ ] **Plan prices**: seeded 99 / 249 / 499 SAR are placeholders — set the real ones (Plans page).
- [ ] **Terms, privacy, provider terms, FAQ**: write/review the real texts (Pages & strings). Get a
      lawyer's review for the terms (manual payments between users, refunds, disputes).
- [ ] Category icons and cover images; check the 14 active categories and 3 cities.
- [ ] Banned words list for reviews; SMS events on/off; support WhatsApp number.
- [ ] Decide on Apple in-app purchase vs Tap (App Store rejection risk, PLAN §16 #2).

## 6. Website (Phase 7) — see `website/README.md`
- [ ] Put your **Apple Team ID** in `website/.well-known/apple-app-site-association`.
- [ ] Put the Supabase URL + anon key in `website/config.js`.
- [ ] Deploy `website/` (Vercel or Cloudflare Pages, free) and point **munyati.co** DNS to it.
- [ ] After the App Store listing exists, put the App Store link in `website/config.js`.
- [x] Deploy the dashboard (`dashboard/`, Vercel): live at https://munyati-admin.vercel.app
      (add `admin.munyati.co` with `vercel domains add admin.munyati.co` + the CNAME it shows).
- [ ] After the first Play upload, put the **Play app signing SHA-256** in
      `website/.well-known/assetlinks.json` (Play Console → Test and release → App integrity), so
      munyati.co links open the Android app.

## 7. Before App Store submission (PLAN §11)
- [ ] 3 demo accounts with fixed OTP (bride, subscribed provider, new provider) via `DEV_PHONES`.
- [ ] Seed bookings in each state for the reviewer; write review notes explaining manual payment,
      Tap plans and the demo booking.
- [ ] Privacy labels in App Store Connect, screenshots, name «منيتي - Munyati», subtitle.
- [ ] Optional but recommended: book a free App Review consultation with Apple about Tap.
- [ ] TestFlight with real providers in Dammam / Khobar / Qatif.

## 8. Android (Phase 9) — see `android/README.md`
- [ ] **Google Play developer account** for the company (25 USD once; needs the CR / D-U-N-S).
- [ ] **Firebase:** in the same Firebase project as iOS, add an Android app with package
      `co.munyati.app`, download **google-services.json** and put it in `android/app/`. That turns
      on push, Firebase Analytics and Crashlytics; nothing else changes.
- [ ] **Redeploy `send-push`** (it now names the Android notification channel):
      `supabase functions deploy send-push`.
- [ ] **Google Maps key** (Explore map + location pickers): Google Cloud → enable "Maps SDK for
      Android" → create a key restricted to `co.munyati.app` + your signing SHA-1 → put it in
      `android/backend.properties` as `MAPS_API_KEY`.
- [ ] **Upload key** (keep it safe; it signs every Play upload):
      `keytool -genkeypair -v -keystore munyati-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`,
      then create `android/keystore.properties` (storeFile, storePassword, keyAlias, keyPassword).
      Both stay out of git. Turn on **Play App Signing** when you create the app.
- [ ] Build the bundle: `cd android && ./gradlew :app:bundleRelease` → upload
      `app/build/outputs/bundle/release/app-release.aab` to an internal testing track.
- [ ] Play listing: name «منيتي - Munyati», short description, screenshots, **Data safety** form
      (phone number, name, photos, payment receipts, approximate location; account deletion is
      in the app and on munyati.co/delete-account), content rating, target audience.
- [ ] Decide on Play Billing vs Tap for provider plans (PLAN §16 #12) before production.

## 9. Home v2 and Profile v2 (carousel banners)
- [ ] Apply `supabase/migrations/20261018000000_home_banners.sql` to the live project (SQL editor or `supabase db push`). Until then the apps show only the built-in brand slides.
- [ ] Redeploy the dashboard (Vercel) so **بنرات الرئيسية / Home banners** appears; add banners there (image 2:1, up to 1 MB; link such as `https://munyati.co/c/makeup`).
- [ ] Make sure `https://munyati.co/providers` explains how providers join: Home's "تقدّمين خدمات للعرائس؟" card opens it.
- [ ] Optional: add `social_links` (instagram, tiktok, snapchat, x, whatsapp) in Settings → remote config to show the "تابعينا" icons in Profile.

## 10. Service videos and the photo viewer
- [ ] Apply `supabase/migrations/20261019000000_service_videos.sql` to the live project (after §9's migration). Until then the apps keep working with photos only, and the video upload fails to save.
- [ ] Redeploy the dashboard: each service on a provider's page now opens **الصور والفيديوهات / Photos and videos**, where admins watch, add (MP4 up to 60 s and 50 MB) and remove media. Reported services open there too.
- [ ] Keep an eye on Supabase **egress**: videos are far heavier than photos (a 60-second 720p clip is roughly 5–15 MB, streamed each time a bride watches it). The free plan includes 5 GB of egress a month and Pro 250 GB. If it grows, move videos to a video CDN (e.g. Cloudflare Stream or Bunny); only the upload path changes.
- [ ] Supabase's per-file upload limit must stay at least 50 MB (Storage settings), the size the apps allow.

## 11. Store listings
- [ ] App Store Connect: paste the name, subtitle, keywords, descriptions, review notes and privacy
      answers from `docs/STORE_LISTING.md`; upload the screenshots in `design/store/ios/`
      (6.9" iPhone, Arabic and English). Retake them with real providers' photos when you have
      some: run `StoreScreenshotsTests` on the iPhone 16 Pro Max simulator.
- [ ] Google Play Console: the same document has the short description, content-rating answers
      and the Data safety form.
- [ ] Fill the demo numbers in the review notes after setting `DEV_PHONES` / `DEV_OTP_CODE`.
