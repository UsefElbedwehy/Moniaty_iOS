# Handoff: continuing in a local Claude Code session

State on branch `claude/gallant-meitner-edx231` (not merged to `main`): phases 1–7 are written.
- iOS app (`App/`, `Packages/`): **never compiled** (no Swift on the cloud machine).
- Backend (`supabase/`): 7 migrations tested on Postgres 16; edge functions type-checked with Deno.
- Dashboard (`dashboard/`): builds with `npm run build`; not yet run against a real Supabase.
- Website (`website/`): static, not deployed.

## Start locally
```sh
git clone https://github.com/UsefElbedwehy/Moniaty_iOS.git && cd Moniaty_iOS
git checkout claude/gallant-meitner-edx231
brew install xcodegen && xcodegen generate && open Munyati.xcodeproj
claude
```
`CLAUDE.md` loads automatically, so the new session knows the architecture.

## Suggested first prompts
1. "Build the app in Xcode and fix the compile errors" — paste the errors (or let Claude run
   `xcodebuild -project Munyati.xcodeproj -scheme Munyati -destination 'platform=iOS Simulator,name=iPhone 16' build`).
   Expect a few rounds: fix by module (Core → DesignSystem → Shared → features → App).
2. "Run the unit tests and fix failures."
3. "Walk me through `docs/OWNER_TODO.md` step by step" (Supabase project, secrets, deploys).
4. When the app runs on mock data, try both roles end to end (book → approve → pay → confirm →
   complete → review), then switch `BackendConfig.plist` to the real project.
5. Open a pull request into `main` when it builds.

## Effort
Keep effort high for compile-error rounds touching many files; lower it for single fixes and
text changes.

## Known platform pitfalls
- **Keep the development language English** (`project.yml`: `developmentLanguage` and
  `DEVELOPMENT_LANGUAGE`). With Arabic there, iOS 17 and 18 draw Arabic reversed and unjoined
  inside `List`, `Form`, `Picker` and segmented controls (SwiftUI text hosted in UIKit); iOS 26
  is fine. Arabic phones still get Arabic. Found 2026-10-23 on the iOS 18.0 simulator; matches
  https://developer.apple.com/forums/thread/782459.
- **Times are shown in the phone's time zone** on both apps (booking slots are computed in Riyadh
  time on the server). Correct for phones in Saudi Arabia; a phone set to another zone sees
  booking times shifted (e.g. Cairo in winter shows 9:00 for a 10:00 Riyadh slot). Pinning the
  display to Asia/Riyadh means changing `Calendar.display` (iOS), `DisplayDates` (Android) and
  every date-only formatter and date picker together, or wedding dates shift by a day.
