# What the owner must do (phases 0–7)

Everything below is outside the code: accounts, keys, uploads and decisions. Nothing here is done
yet. Do them roughly in this order; items marked ⏳ take weeks, so start them first.

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
- [ ] Push the database: `supabase link --project-ref <ref>` then `supabase db push` (applies all
      7 migrations in `supabase/migrations`).
- [ ] Secrets (`supabase secrets set NAME=value`): `OTP_HASH_SECRET`, `PASSWORD_SECRET`,
      `OURSMS_API_KEY`, `OURSMS_SENDER`, `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON`,
      `PUSH_WEBHOOK_SECRET`, `SMS_WEBHOOK_SECRET`, `TAP_SECRET_KEY` (and optionally
      `DEV_PHONES` + `DEV_OTP_CODE` for App Review test accounts).
- [ ] Deploy functions: `supabase functions deploy send-otp verify-otp send-push send-sms delete-account tap-checkout tap-webhook`.
- [ ] Database webhooks: `notifications` insert → `send-push`, `sms_outbox` insert → `send-sms`
      (each with its `x-webhook-secret` header).
- [ ] First admin: invite your email (Authentication → Invite), then the SQL line in `dashboard/README.md`.

## 3. Firebase
- [ ] Create a Firebase project, add the iOS app `co.munyati.app`, download **GoogleService-Info.plist**
      into `App/Resources/`.
- [ ] Upload your **APNs key** (from Apple Developer → Keys) to Firebase Cloud Messaging.
- [ ] Create a service account with *Firebase Cloud Messaging API Admin* → its JSON goes into the
      `FIREBASE_SERVICE_ACCOUNT_JSON` secret.

## 4. The iOS app — build it (nothing was compiled yet!)
- [ ] On the Mac: `brew install xcodegen`, then in the repo `xcodegen generate`, open `Munyati.xcodeproj`.
- [ ] Set your Apple **Team** (`DEVELOPMENT_TEAM` in `project.yml`).
- [ ] Fill `App/Resources/BackendConfig.plist` with the Supabase URL + **anon** key (never the service key).
- [ ] Build. Expect compile errors (the code was written without a compiler): fix them with Claude
      in your local session, one batch at a time. The app also runs with **no backend** on sample
      data, which is the fastest way to start.
- [ ] Run the tests in Xcode (Product → Test).
- [ ] App icon: export the ring-meem icon (`design/logo/`) at 1024×1024 into the asset catalog.

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
- [ ] Deploy the dashboard (`dashboard/`, Vercel) on e.g. `admin.munyati.co`.

## 7. Before App Store submission (PLAN §11)
- [ ] 3 demo accounts with fixed OTP (bride, subscribed provider, new provider) via `DEV_PHONES`.
- [ ] Seed bookings in each state for the reviewer; write review notes explaining manual payment,
      Tap plans and the demo booking.
- [ ] Privacy labels in App Store Connect, screenshots, name «منيتي - Munyati», subtitle.
- [ ] Optional but recommended: book a free App Review consultation with Apple about Tap.
- [ ] TestFlight with real providers in Dammam / Khobar / Qatif.
