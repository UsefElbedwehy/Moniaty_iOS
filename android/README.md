# Munyati Android

The Android twin of the iOS app: identical screens, flows, text and backend, built natively with
**Kotlin + Jetpack Compose** (`docs/PLAN.md` §12 Phase 9, decision #12).

## Run
```sh
cd android
./gradlew :app:assembleDebug          # build
./gradlew testDebugUnitTest           # unit tests
./gradlew :app:installDebug           # install on a running emulator/device
```
Or open `android/` in Android Studio. Needs JDK 17+ and the Android SDK (`local.properties` with
`sdk.dir=...`, which Android Studio writes for you).

`backend.properties` holds the Supabase URL and the **public anon key** (the same values as
`App/Resources/BackendConfig.plist`), plus an optional `MAPS_API_KEY` (Google Maps SDK for Android,
restricted to `co.munyati.app`) for the Explore map. Add `-Pmock` to any Gradle command to build on
in-memory mocks instead (sample catalog, OTP code `123456`).

## Layout (mirrors the iOS Swift packages)
| Module | iOS counterpart | What |
|---|---|---|
| `core` | `Packages/Core` | `ViewState`, `AppError`, `RemoteConfig` |
| `networking` | `Packages/Networking` | `ApiEndpoint` (the only place with URLs), `OkHttpApiClient` |
| `shared` | `Packages/Shared` | `RemoteStrings`, `CacheStore`, `AnalyticsRecorder` |
| `designsystem` | `Packages/DesignSystem` | `DS.colors` / `DS.type` / `DSSpacing` / `DSRadius`, components, brand marks, Amiri |
| `authentication` | `Packages/Authentication` | role → phone → OTP → name |
| `features/catalog` | `Packages/Features/Catalog` | bride discovery: Home, search, category lists, service/provider/store pages, favorites, budget, Explore map |
| `features/providerstudio` | `Packages/Features/ProviderStudio` | provider Home: status, setup checklist, business profile (join form), services, stores, photo upload, plans with Tap checkout (Custom Tabs), insights |
| `features/booking` | `Packages/Features/Booking` | requests with free slots, the booking lifecycle for both roles, receipts (private storage, SHA-256), disputes, working hours, payout methods |
| `app` | `App/` | composition root (`AppEnvironment`), Supabase repositories, session, deep links, shells |

Feature module still to port: `trust` (one per iOS package).

## Rules
- **iOS is the source of truth for text.** Edit the iOS `.strings`, then run
  `python3 tools/sync_strings.py`; it regenerates every `strings_ios.xml` (Arabic in `values/`,
  English in `values-en/`). Don't edit the generated files. Modules that build keys at run time
  (Booking, App) also get a generated key map (`bookingKeys`, `l10nKeys`).
- Brand vectors come from the iOS SVGs via `tools/svg_to_vector.py`.
- Same conventions as iOS: DS tokens only, no literals; one `ViewState` per screen; the app module
  is the only place that knows the backend is Supabase; plain HTTPS, no Supabase SDK.
- Each tab has its own NavHost; features push their `@Serializable` routes through `LocalNavigator`
  (the App provides it per tab), like iOS pushing routes onto a tab's NavigationStack.
- Not wired yet: Firebase (needs an Android app `co.munyati.app` in the Firebase project and its
  `google-services.json`), push (FCM), App Links verification (`website/.well-known/assetlinks.json`).
