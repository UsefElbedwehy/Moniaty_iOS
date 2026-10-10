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
5. Run the **App** scheme on an iOS 17+ simulator.

Without step 4 the app runs on built-in sample data with Firebase switched off, so you can
try the flows straight away. Test sign-in on sample data: any Saudi mobile (5XXXXXXXX) and the
code `123456`.

Package tests: `cd Packages/<Name> && swift test`, or the App scheme's test action.

## Status

- **Phase 1 (foundation):** design system and logo, sign-in with role choice, the two
  four-tab shells, cities with "All", remote config and strings, analytics, push, deep links.
- **Phase 2 (discovery):** brides browse categories, search with filters (within budget,
  female staff only, sort), open service / provider / store pages, save favorites, set a
  budget, share links and explore the map. Providers fill in their join form, services (with
  photos) and stores in "My studio"; nothing is public until an admin approves them.
- Next: Phase 3 (booking, payment receipts, demo booking), then subscriptions (`docs/PLAN.md` §12).
