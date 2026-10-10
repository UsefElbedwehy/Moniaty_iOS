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
   `xcodebuild -scheme Munyati -destination 'platform=iOS Simulator,name=iPhone 16' build`).
   Expect a few rounds: fix by module (Core → DesignSystem → Shared → features → App).
2. "Run the unit tests and fix failures."
3. "Walk me through `docs/OWNER_TODO.md` step by step" (Supabase project, secrets, deploys).
4. When the app runs on mock data, try both roles end to end (book → approve → pay → confirm →
   complete → review), then switch `BackendConfig.plist` to the real project.
5. Open a pull request into `main` when it builds.

## Effort
Keep effort high for compile-error rounds touching many files; lower it for single fixes and
text changes.
