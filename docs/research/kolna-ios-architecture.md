# Kolna Al-Khafji iOS: architecture analysis as the base for Munyati (منيتي)

Source analysed: `/home/user/kolna-al-khafji-ios` at HEAD `5c3a378` ("Repaint Account's rows when the appearance changes"). `.claude/worktrees` copies were ignored. Paths below are repo-relative and start with `kolna-al-khafji-ios/`.

> **Verdict.** Kolna is a strong base for Munyati. The parts that carry over almost unchanged are the module skeleton, the composition root, `ViewState`/`AppError`, Networking (plain HTTPS to Supabase with no SDK), the Keychain session with refresh single-flighting, OurSMS phone OTP, FCM push with a rich-push extension, force-update, CMS pages, account deletion, the image cache and the native `TabView` shell.
> The domain layer is the opposite. It is built around "places/ads" and has nothing for bookings, calendars, payments-by-receipt, subscriptions, roles, budget, multiple cities or universal links. Expect to keep about 40–50% of the code (infrastructure plus DesignSystem) and to rewrite or replace about 50–60% (features).

---

## 1. Snapshot

| Item | Value | Where |
|---|---|---|
| UI | SwiftUI, iPhone only (`TARGETED_DEVICE_FAMILY: "1"`), portrait only | `project.yml`, `App/Resources/Info.plist` |
| Language / concurrency | Swift 6 (`SWIFT_VERSION: "6.0"`, `SWIFT_STRICT_CONCURRENCY: complete`); every package uses `.swiftLanguageMode(.v6)` | `project.yml`, each `Package.swift` |
| Min OS | iOS 17.0 (packages also declare `.macOS(.v14)` so `swift test` runs on the Mac host) | `project.yml`, `Package.swift` |
| Project generation | XcodeGen (`project.yml` is the source of truth; `MaalimAlKhafji.xcodeproj` is generated) | `project.yml`, `README.md` |
| Package manager | Local SPM packages only. The single remote dependency is `firebase-ios-sdk` `from: 11.0.0`, linked as `FirebaseMessaging` to the App target only | `project.yml` |
| Backend | Supabase (PostgREST RPC + GoTrue + Storage + Edge Functions) over **plain HTTPS. The Supabase SDK is not used.** 78 SQL migrations | `App/Sources/Composition/BackendConfiguration.swift`, `supabase/migrations/` |
| Toolchain | README says Xcode 16+. However, `DesignSystem/Components/GlassBackground.swift` calls `glassEffect(...)` (iOS 26 Liquid Glass) behind `#available(iOS 26.0, *)`, which needs the iOS 26 SDK to compile. In practice it builds with **Xcode 26**. I inferred this from the code and have not verified it by building. | |
| Size (Swift source lines, approx.) | Core 358 · DesignSystem 1,625 · Networking 457 · Shared 1,235 · Authentication 1,668 · Places 7,970 · Home 1,723 · Explore 1,668 · Account 1,093 · Saved 340 · App target 2,687 · package tests ~1,640 · UI tests ~490 | |

---

## 2. Module graph and dependency rules

### 2.1 Documented (`Docs/ARCHITECTURE.md`)
`Core` has no dependencies. `DesignSystem`, `Networking` and `Shared` depend only on `Core`. Features depend on all four, plus any features they navigate into. `App` is the only composition root.

### 2.2 Actual (from each `Package.swift`)

```
                                   App (Xcode target + NotificationService extension)
                                    │  imports every package + FirebaseMessaging
   ┌──────────────┬────────────┬────┴─────┬───────────┬──────────┬──────────┐
Authentication  Places        Home      Explore     Saved     Account
   │              │             │  └──────┴───────────┴─▶ Places (Home/Explore/Saved import Places)
   │              │             │
   ├─ Core, DesignSystem, Networking, Shared        (Authentication, Places, Home)
   │                                                (Explore, Saved, Account: Core, DesignSystem, Shared — no Networking)
   ▼
Shared ──▶ Core, DesignSystem        ← doc says "Core only": drift
Networking ──▶ Core
DesignSystem ──▶ Core
Core ──▶ (nothing)
```

Drift between the docs and the code:
- `Shared` depends on `DesignSystem`, which the doc does not mention (`Packages/Shared/Package.swift`). `NotificationsView` and the National-Day theme in Shared use DS tokens.
- The doc says Places depends on Authentication. It does not. In fact Home, Explore and Saved depend on Places and reuse its entities, repositories and screens (`PlaceDetailScreen`, `FavoritesState`, `PlaceRepository`).
- `Docs/ADR/0001-vertical-slice-scope.md` says Home/Explore/Account are "Coming soon" placeholders and the backend is mocked. That is out of date: all of them are fully implemented and `AppEnvironment.useRemoteBackend` is `true` unless `UITEST_MOCK_BACKEND=1`.

**Rule that matters for Munyati:** vendor SDKs (Firebase, and Supabase-as-HTTP) are confined to the **App target**. Feature packages see only protocols such as `PushNotifying`, `PlaceImageUploader`, `ProfileRepository` and `CMSPageRepository`. The concrete Supabase implementations live in `App/Sources/Backend/*`. This is why switching backend is a Data-layer change only, which is relevant to the owner's question 12.

### 2.3 Layering inside a feature (documented)
`View → ViewModel → UseCase → Repository (protocol) → Remote*/Mock* → Networking.APIClient → APIEndpoint`. Folder layout: `Presentation/{Views,ViewModels}`, `Domain/{Entities,UseCases,Repositories}`, `Data/{DTOs,RepositoryImpl,Mock}`, `DI/`, `Navigation/`.

Places and Authentication follow it strictly (`PlacesUseCases`, `AuthUseCases` bundles). Home and Explore view models call `PlaceRepository` directly in places, for example `HomeViewModel.init(fetchCategories:repository:homeSections:)` and `ExploreViewModel.init(repository:)`. Munyati should pick one convention and enforce it.

---

## 3. DI / composition root

- **`App/Sources/Composition/AppEnvironment.swift`** (`@MainActor final class AppEnvironment`) is the real DI mechanism. It does plain constructor injection.
  - `init()` reads `BackendConfig.plist`, builds two `URLSessionAPIClient`s (one for auth; one for data, with `authTokenProvider: { await auth.currentAccessToken() }`), then creates every `Remote*`/`Supabase*` repository or the matching `Mock*` set.
  - Feature factories: `makePlacesFeature`, `makeHomeFeature`, `makeExploreFeature`, `makeSavedFeature`, `makeAccountFeature`, `makeAuthFeature`, `makeDetailScreen`, `makeBusinessProfileScreen`, `makeExploreSearchScreen`, `makeInfoSheet`, `makeBusinessEditScreen`.
  - Session-driven state: `restoreSession()`, `loadRemoteConfig()`, `syncAccountProfile()`, `signOut()`, `deleteAccount()`.
  - Push: `bindPush(_:)`, `registerPushTokenIfPossible()`.
  - Shared observable objects it owns: `AppSession`, `AccountProfile`, `RemoteConfigStore`, `NationalDayTheme`, `AppRouter`, `DeepLinkStore`, `FavoritesState`, `AnalyticsRecorder`.
- **`Core/DI/DIContainer.swift`** (`protocol DIContainer`, `AppDIContainer` service locator) is **defined but never used**. A grep finds no call sites outside its own file. Munyati can delete it or adopt it on purpose.
- Each feature exposes a public `XFeature` struct (`PlacesFeature`, `HomeFeature`, `ExploreFeature`, `SavedFeature`, `AccountFeature`, `AuthenticationFeature`). Its `init` takes repositories and callbacks, and `rootView()` mounts it. Cross-feature navigation and side effects are passed in as closures (`onOpenSearch`, `onAuthRequired`, `onOpenBusiness`, `AccountActions`, and so on), so features never import the App.
- Cross-cutting values are injected once at the root with `EnvironmentValues`: `\.authGate` (`Shared/Auth/AuthGate.swift`), `\.analytics` (`Shared/Analytics/AnalyticsRecorder.swift`), `\.requiresSignInToViewAds` (`Shared/Auth/AdAccessPolicy.swift`), and the seasonal-skin overrides (`DesignSystem/Foundations/DSSurfaceOverride.swift`).
- One subtle lesson is documented in code. `AppRouter` must be owned by `AppEnvironment` and not created in `RootTabView.init`, because that initializer re-runs when the `App` body re-evaluates (for example when appearance changes) and the callbacks would capture a dead instance. Keep this.

---

## 4. Navigation: Coordinator pattern and tab shell

- **`Core/Navigation/Coordinator.swift`** defines `@MainActor protocol Coordinator: AnyObject, Observable` with `path: NavigationPath`, `presentedSheet`, `presentedFullScreenCover`, and default `push/pop/popToRoot/present(sheet:)/present(fullScreenCover:)/dismissPresented`. It also defines `protocol ViewFactory { func makeView(for route:) }`.
- Only **two** features use it:
  - `Authentication/Navigation/AuthCoordinator.swift` with `AuthRoute`: `.phoneEntry`, `.otp(challengeId:)`, `.name(challengeId:code:)`, and `AuthFactory`.
  - `Places/Navigation/PlacesCoordinator.swift` with `PlacesRoute`: `.categoryPicker`, `.form`, `.review`, `.pending`, `.placeDetail(id:)`, plus `PlacesFactory` and `PlaceComposer` (draft state held by the coordinator, not passed in routes).
  - Both bind `NavigationStack(path: $coordinator.path)` with `.navigationDestination(for: Route.self)` in a private `*RootView`.
- Home, Explore, Saved and Account do **not** use a coordinator. They own a `NavigationStack` and push with local `@State` and `.navigationDestination(item:)` or `isPresented:` (21 `navigationDestination` call sites across packages). Account uses a private `enum Route` (`AccountView.swift:39`).
- **Tab shell: `App/Sources/RootTab/RootTabView.swift` uses the native SwiftUI `TabView(selection:)` with `.tabItem { Label(...) }` and `.tag(AppTab.x)`.** On iOS 26 this automatically gets the system Liquid Glass tab bar, which meets Munyati requirement 7 ("native component").
  - `AppTab` (`RootTab/AppTab.swift`) has 5 cases: `home, explore, post, saved, account`, with SF Symbols and localized `tab.*` keys.
  - Selection goes through a custom `Binding` (`tabSelection`) so the auth-gated Post tab opens sign-in instead of switching.
  - Feature roots are created once in `RootTabView.init` so each tab keeps its stack.
  - The shell switches between `OnboardingCarouselView`, then `SessionCheckView` while `session.state == .checking`, then `tabShell`. `ForceUpdateView` is overlaid at `zIndex(11)`.
  - Global modals are hung off the shell: `fullScreenCover` for auth, search, deep-linked place and business, and UI-test hooks; `sheet` for business edit.
- `App/Sources/RootTab/SwipeBackGesture.swift` re-enables edge-swipe-back when the nav bar is hidden. It does this by making `UINavigationController` its own gesture delegate (`@retroactive`) and reading the private KVC key `"_isTransitioning"`. It works, but it relies on a private key, so treat it as a known risk.
- Many screens hide the system nav bar and use the custom `LargeHeaderBar`, not native large titles.

**For Munyati:** keep the native `TabView` with 4 tabs: `home, explore (map), bookings, profile`. Move every tab onto the `Coordinator` pattern, because deep links have to push onto a specific tab's stack, which a local `@State` cannot do from the outside. Decide whether providers get a different tab set or different content in the same 4 slots. It is easiest when `RootTabView` switches on `session.role`.

---

## 5. ViewState and AppError

- **`Core/State/ViewState.swift`** is `enum ViewState<Value: Sendable>` with `.loading`, `.refreshing(Value)`, `.loaded(Value)`, `.empty`, `.error(AppError)`, `.offline`, plus `value`, `isLoading`, `error`, `map(_:)`, and `Equatable` when `Value: Equatable`. The rule is one `ViewState` per screen or section, never boolean flags. Tests: `Core/Tests/CoreTests/ViewStateTests.swift`. Reusable as-is.
- **`Core/Error/AppError.swift`** is `enum AppError: Error, Equatable, Sendable`.
  - Cases: `.network(NetworkFailureReason)` (`timedOut`, `noConnection`, `cancelled`, `decodingFailed`, `invalidResponse`), `.validation(field:message:)`, `.authentication(AuthFailureReason)` (`invalidCredentials`, `sessionExpired`, `otpExpired`, `otpIncorrect`, `notAuthenticated`), `.server(statusCode:message:)`, `.offline`, `.unknown(message:)`.
  - `LocalizedError` with `String(localized:defaultValue:)` English fallbacks. `Core` has no bundle-specific strings, so localization of these keys depends on the app bundle.
  - `URLSessionAPIClient.mapHTTPError` maps 401 to `.authentication(.sessionExpired)`, 400/422 with a `message` body to `.validation`, and everything else to `.server`. The `APIClient` uses typed throws: `async throws(AppError)`.
  - Reusable as-is. Munyati will want domain-specific cases or codes, for example `bookingConflictSameCategory`, `planLimitReached`, `slotUnavailable` and `receiptRejected`. These can be `.validation` with server `message` text, or a new `.business(code:)` case.

---

## 6. RemoteConfig and force update

- **Model: `Core/Configuration/RemoteConfig.swift`**
  - `branding {appName, logoURL, primaryColorHex, accentColorHex}`
  - `featureFlags: [String: Bool]` (`isFeatureEnabled(_:)`), `enabledModules`, `supportedLanguages`, `supportedCurrencies`, `regions: [String]`, `cities: [String]`, `socialLinks: [String: URL]`
  - `support {helpCenterURL, termsURL, privacyPolicyURL, contactMethods[{id,type,value}]}`
  - `update {minRequiredVersion, updateMessage, forceUpdate, storeURL}`
  - `protocol ConfigurationRepository { fetchConfiguration(); cachedConfiguration() }`.
- **Implementation: `App/Sources/Backend/SupabaseConfigurationRepository.swift`.** It calls RPC `get_config` (`APIEndpoint.configuration.get`), maps a private `RemoteConfigDTO`, and caches to disk through `FileCacheStore(key: "remote_config")`. `MockConfigurationRepository.swift` is the offline variant.
- **Store: `App/Sources/Composition/RemoteConfigStore.swift`** (`@Observable`) exposes typed flags with explicit fail-open or fail-closed semantics:
  - `isPostAdEnabled` (fail-open)
  - `forceUpdateRequired` (fail-closed; `CFBundleShortVersionString.compare(min, options: .numeric) == .orderedAscending`)
  - `isNationalDayThemeEnabled` (fail-closed)
  - `isSignInRequiredForAds` (fail-open)
- **Load sequence:** `RootTabView.task` runs `async let configLoad = environment.loadRemoteConfig()` in parallel with `restoreSession()`. It fetches first and falls back to the cache on failure.
- **Force update UI:** `App/Sources/Support/Presentation/UI/ForceUpdateView.swift` is a full-screen, undismissable overlay with an "Update" button that opens `storeURL`. Reusable as-is.
- **Gap:** `branding.*`, `enabledModules`, `regions`, `cities` and `supportedCurrencies` are decoded but **never read by any view** (grep confirms). `cities` is a flat `[String]` with no ids, no bilingual names and no coordinates.

---

## 7. White-labeling

How the brand is actually configured today:

| Brand aspect | Mechanism | Runtime-changeable? |
|---|---|---|
| Colors | 21 semantic color sets in `Packages/DesignSystem/Sources/DesignSystem/Resources/Colors.xcassets` (light and dark each), exposed as `Color.dsX` in `Colors/DSColor.swift`. Also `App/Resources/Assets.xcassets/AccentColor` (light `#0B7A5B`) | No. Build-time. `branding.primaryColorHex` is not wired to anything |
| Gradients | **Hard-coded RGB literals** in `DesignSystem/Foundations/DSGradient.swift` (`primary` green, `gold`, `error`) | No. Must be re-toned by hand |
| Typography | `DesignSystem/Typography/DSFont.swift`: `Font.system(<TextStyle>, design: .rounded)` at fixed weights (SF Rounded / SF Arabic Rounded). Dynamic Type works. No custom font files | No |
| Imagery | Khafji photos in `DesignSystem/Resources/Media.xcassets` (`HeroArch`, `HeroArch2`, `HeroWatertower`) via `DSHeroImage`; `Home/Resources/HeroBannerPhotos/*.jpg`; `App/Resources/Assets.xcassets/AppLogo`, `AppIcon`, `NationalDayAppIcon` | Hero banners on Home are remote (`get_home_sections`); the rest are bundled |
| Names / strings | `APP_DISPLAY_NAME` in `project.yml`; per-module `Localizable.strings`; hard-coded "Kolna Al-Khafji" in `AppEnvironment.appVersionString` | No |
| Seasonal skin | `Shared/Theme/NationalDay*` plus `DSSurfaceOverride` environment keys (`dsRaisedSurface`, `dsScreenGround`, `dsPaintedGround`), toggled by remote flag `nationalDayThemeEnabled` | Yes (flag). The override mechanism is generic and worth keeping |

**Re-skin for Munyati.** The palette is `#8A0D3A` burgundy, `#DFC389` gold, `#F2E5D2` cream and `#FAFAEC` ivory. Re-skin by editing the color sets and `DSGradient`; no call sites need to change. A suggested starting mapping, which needs design sign-off and dark-mode values:

| Token | Kolna light | Munyati proposal (light) |
|---|---|---|
| `Primary` | `#495D39` | `#8A0D3A` (white text on it is about 9.5:1, which passes AA) |
| `PrimaryPress` | `#38452C` | about `#6E0A2E` (darker burgundy) |
| `PrimaryMuted` | `#EDF0E6` | `#F2E5D2` cream, or a burgundy tint |
| `PremiumGold` | `#C79A3E` | `#DFC389`. Use for fills and badges only: gold text on ivory is about 1.6:1 and fails. Burgundy text on gold is about 5.6:1 |
| `Background` | `#F7F0E3` | `#FAFAEC` ivory |
| `Surface` | `#FBF7EE` | `#F2E5D2` cream, or a lighter ivory |
| `Elevated` | `#FFFFFF` | `#FFFFFF` |
| `TextPrimary` / `TextSecondary` | `#241F16` / `#6B6154` | warm near-black and warm grey (to be designed) |
| `Success`/`Error`/`Warning`/`Info` and the badge pairs | various | keep the semantics and re-tone to fit the palette |

For a premium bridal feel, consider swapping `.rounded` in `DSFont.swift` for `.default` or `.serif` headlines, or bundling a licensed Arabic display font. It is a one-file change, but custom fonts in an SPM package need registration through `CTFontManagerRegisterFontsForURL` or `UIAppFonts` in the App.

---

## 8. DesignSystem package: complete inventory

Base path: `kolna-al-khafji-ios/Packages/DesignSystem/Sources/DesignSystem/`. Resources: `Resources/Colors.xcassets`, `Resources/Media.xcassets`, `Resources/{en,ar}.lproj/Localizable.strings` (5 keys: `common.retry`, `common.loading`, `common.error.offline.title`, `common.error.generic.title`, `common.tryAgain`).

### 8.1 Foundations

| Token set | File | Values |
|---|---|---|
| Colors (21) | `Colors/DSColor.swift` + `Colors.xcassets` | Brand: `dsPrimary`, `dsPrimaryPress`, `dsPrimaryMuted`, `dsPremiumGold`. Status: `dsSuccess`, `dsWarning`, `dsError`, `dsInfo`. Surfaces: `dsBackground`, `dsSurface`, `dsElevated`. Text: `dsTextPrimary`, `dsTextSecondary`, `dsDisabled`. `dsBorder`. Badge pairs: `dsPending{Background,Foreground}`, `dsLive{…}`, `dsRejected{…}`. Helpers: `Color.dsBrightened(_:to:)`, `Color.dsAdaptive(light:dark:)` |
| Typography (8) | `Typography/DSFont.swift` | `dsLargeTitle` (.title, heavy), `dsTitle1` (.title2, bold), `dsTitle2` (.title3, bold), `dsHeadline` (bold), `dsBody`, `dsSubhead` (medium), `dsFootnote` (medium), `dsCaption` (semibold). All `.rounded` |
| Spacing (4pt base) | `Foundations/DSSpacing.swift` | `xxs 4`, `xs 8`, `sm 12`, `md 16`, `lg 20`, `xl 24`, `xxl 32` |
| Radii | `Foundations/DSRadius.swift` | `control 8`, `button 14`, `card 20`, `sheet 26`, `pill 999` |
| Shadows | `Foundations/DSShadow.swift` | `level1` (0.08, r3, y1), `level2` (0.10, r14, y4), `level3` (0.14, r30, y12); `View.dsShadow(_:)` |
| Gradients | `Foundations/DSGradient.swift` | `primary`, `gold`, `error` (literal RGB) |
| Surface overrides | `Foundations/DSSurfaceOverride.swift` | `@Entry dsRaisedSurface`, `dsScreenGround`, `dsPaintedGround`; `View.dsScreenBackground(_:)` |

### 8.2 Components and modifiers

| Component | File | Purpose |
|---|---|---|
| `PrimaryButton` | `Components/PrimaryButton.swift` | Filled CTA, 50pt, `DSGradient.primary` fill (or `dsDisabled`), loading spinner, optional SF Symbol |
| `SecondaryButton` | `Components/SecondaryButton.swift` | Pale tinted fill with `dsPrimary` text, for secondary prominent actions |
| `TertiaryButton` | `Components/TertiaryButton.swift` | Outline button with a 1.5pt `dsBorder` stroke |
| `DestructiveButton` | `Components/DestructiveButton.swift` | `dsError` filled destructive button, 44pt |
| `DSButtonLabel` (internal) | `Components/DSButtonLabel.swift` | Shared label for buttons: swaps in a `ProgressView` while loading and respects Reduce Motion |
| `AppTextField` | `Components/AppTextField.swift` | Text field with default, focused (2pt primary border plus glow) and error states, and an inline error message. Includes a macOS `UIKeyboardType` shim |
| `AppMultilineTextField` | `Components/AppMultilineTextField.swift` | Growing multi-line counterpart (Return inserts a newline) |
| `UIKitNumberField` | `Components/UIKitNumberField.swift` | `UIViewRepresentable` digits-only field. Forces ASCII numerals and LTR in Arabic RTL; used for phone and OTP (`.oneTimeCode`) |
| `Chip` | `Components/Chip.swift` | Selectable filter pill with optional `matchedGeometryEffect` sliding selection |
| `PillSwitcher<T>` | `Components/PillSwitcher.swift` | Custom 2–3-way segmented control with a sliding pill |
| `DSCard<Content>` | `Components/DSCard.swift` | Elevated container (`dsElevated`, `DSRadius.card`, level-1 shadow); follows `dsRaisedSurface` |
| `SectionHeader` | `Components/SectionHeader.swift` | Section title with an optional trailing "See all" action |
| `LargeHeaderBar<Trailing>` | `Components/LargeHeaderBar.swift` | Fixed custom screen header (bold title plus trailing accessory) that replaces the native nav title |
| `HeaderIconButton` | `Components/LargeHeaderBar.swift` | Circular icon button for header accessories (for example the bell) |
| `EmptyStateView` | `Components/EmptyStateView.swift` | Centered icon, title, message and optional primary action |
| `ErrorStateView` | `Components/ErrorStateView.swift` | Centered error view driven by `AppError`, with optional retry |
| `SkeletonView` / `SkeletonShape` | `Components/SkeletonView.swift` | Shimmering loading placeholder (rect or circle); static when Reduce Motion is on |
| `StatusBadge` / `StatusBadgeKind` | `Components/StatusBadge.swift` | Pill badge: `pending`, `live`, `rejected`, `featured` (gold shine), `verified` (primary shine) |
| `CarouselPageIndicator` | `Components/CarouselPageIndicator.swift` | Pill and dot page indicator |
| `InfiniteCarousel<Item,Content>` | `Components/InfiniteCarousel.swift` | Auto-advancing, seamlessly looping paged carousel (used by Home hero banners) |
| `View.glassBackground` / `glassPill` | `Components/GlassBackground.swift` | Hand-rolled frosted material with stroke and shadow, for map overlays and floating bars |
| `View.liquidGlass` / `liquidGlassPill` | `Components/GlassBackground.swift` | Real iOS 26 `glassEffect` (optionally `.interactive()`), falling back to the above |
| `View.shimmering()` | `Components/Shimmer.swift` | Looping diagonal highlight sweep (premium badges and CTAs) |
| `DSHeroImage` | `HeroImage.swift` | Enum of the bundled Khafji photos (`khafjiArch`, `khafjiArch2`, `khafjiWatertower`). **Replace** |
| `DSFadingHeroImage` | `DSFadingHeroImage.swift` | Photo that fades into the screen ground (onboarding, auth landing) |
| `InfoPageHeroHeader` | `InfoPageHeroHeader.swift` | Rounded photo accent plus title and subtitle for About, Terms, Privacy and Help pages |

### 8.3 Reusable UI outside DesignSystem that should be promoted
These are `internal` to `Packages/Features/Places/Sources/Places/Presentation/Views/` today:
- `ReviewsUI.swift`: `StarRatingView`, `StarInput`, `ReviewRow` (likes and dislikes), `RateReviewSheet`
- `FlexibleWrap.swift`: a wrapping `Layout`
- `ExpandableText.swift`
- `FullscreenMediaPager.swift`: zoom, drag-to-dismiss, video and save/share
- `ImageCompressor.swift`, `VideoCompressor.swift`
- `BusinessHoursView.swift`: weekly hours timeline
- `LocationPickerSheet.swift`, `CurrentLocationProvider.swift` (public, iOS only), `PlaceMapView.swift`
- `ContactSheet.swift`
- `FormFieldView.swift` / `DynamicPlaceFormView.swift`: a backend-schema-driven form engine with field kinds `text`, `multilineText`, `number`, `toggle`, `segmented`, `singleSelect`, `multiSelect` and `time`

There is also duplicated code to consolidate:
- `AvailabilityPill.swift` (Home, Explore, Saved)
- `CrossPlatform.swift` (Home, Explore, Places, Saved)
- `PlaceCardComponents.swift` (Home, Explore)
- `PlatformImage.swift` (Account, Places)

Tests: `DesignSystem/Tests/DesignSystemTests/DSColorTests.swift` checks that all 21 tokens resolve; `FoundationsTests.swift` covers spacing, radius and shadow scales.

---

## 9. Localization (Arabic/English, RTL, ADR 0002) and backend-driven strings

- **Per-module `.strings`.** Every package with UI ships `Resources/{en,ar}.lproj/Localizable.strings` with `defaultLocalization: "en"`. The App target has `App/Localization/{en,ar}.lproj/Localizable.strings` (tabs, onboarding, force update, and the notifications screen keys used by `Shared/Notifications/NotificationsView.swift`, which resolves against the **main** bundle). Approximate key counts: App 49, Places 146, Account 47, Explore 30, Authentication 29, Home 26, Shared 14, Saved 11, DS 5. The project uses legacy `.strings`, not `.xcstrings` catalogs. `knownRegions = (Base, ar, en)`.
- **ADR 0002 (`Docs/ADR/0002-localization-bundle-pattern.md`).** A bare `LocalizedStringKey` resolves against the main bundle, and a DS component resolves keys against **DesignSystem's** bundle. So every feature has an `XL10n` helper:
  - `text(_:)` returns `Text(key, bundle: .module)`.
  - `string(_:)` returns `String(localized:bundle: .module)`.
  - `dsKey(_:)` returns `LocalizedStringKey("\(string(key))")`, which resolves in the caller's bundle and passes verbatim text into DS components.
  - Examples: `Authentication/.../Views/AuthL10n.swift`, `PlacesL10n`, `HomeL10n`, `AccountL10n`, `SavedL10n`, `Explore/Localization/ExploreL10n.swift`, `Shared/Localization/SharedStrings.swift`.
- **Language selection.** `AppLanguageStore` (bottom of `AppEnvironment.swift`) defaults a fresh install to **Arabic** by writing `UserDefaults["AppleLanguages"] = ["ar"]` on first read. In Account, the Language row opens iOS Settings (per-app language), and iOS relaunches the app. There is no in-session language flip.
- **RTL.** It is fully system-driven: layout follows the `AppleLanguages` locale, with no `.environment(\.layoutDirection)` overrides except deliberate LTR pins for numerals (`OTPView.swift:106`, and `UIKitNumberField` with `semanticContentAttribute = .forceLeftToRight` plus `.asciiCapableNumberPad`). `DSFont` uses `Font.system`, so SF Arabic Rounded is picked up automatically.
- **Bilingual data.** Backend content is bilingual by convention:
  - `PlaceCategory.name` (Arabic) plus `nameEn`, with `displayName` picking by `Locale.preferredLanguages`.
  - `PlaceFormField.optionsEn`.
  - CMS pages via `get_cms_page(p_slug, p_locale)` with English fallback.
- **Can strings be backend-driven?** Not today for UI copy. Only CMS pages, category names, form labels, hero banner titles, notification bodies and the force-update message come from the server. ADR 0002 helps here: every lookup already goes through one `XL10n.string()` per module. Munyati can add a `RemoteStrings` overlay in `Shared` (a `[locale: [key: value]]` dictionary fetched with config, cached with `FileCacheStore`, and checked first inside each `L10n.string`/`dsKey`/`text`). For that to work, `text(_:)` must become `Text(string(key))` so the override applies. See §20, gap G19.

---

## 10. Image caching

`Packages/Shared/Sources/Shared/Images/RemoteImageView.swift`:
- `RemoteImageLoading.session` is a dedicated `URLSession` with `URLCache` (50 MB memory, 400 MB disk, `diskPath: "MaalimAlKhafjiRemoteImageCache"`) and `.returnCacheDataElseLoad`.
- `RemoteImageDecodeCache.shared` is an `NSCache<NSURL, UIImage>` that holds decoded images. Decoding happens off the main actor (`nonisolated static func decode`).
- `RemoteImageLoader` (`@Observable @MainActor`) drives `ImagePhase` (`loading`, `loaded`, `failed`) with cancellation. `RemoteImageView(url:contentMode:)` shows a placeholder, a tap-to-retry button on failure, and a fade-in that respects Reduce Motion.
- The upload side sets `Cache-Control: public, max-age=31536000, immutable` (`SupabaseImageUploader.swift`, `SupabaseProfileRepository.uploadAvatar`) because every object path contains a new UUID.

Reuse as-is (rename the disk path). For **payment receipts**, which go in a private bucket with signed URLs, bypass the long-lived cache: signed URLs change, and the files are sensitive.

---

## 11. Persistence

| What | Mechanism | Where |
|---|---|---|
| Auth session (access and refresh token, user id, phone, expiry) | Keychain generic password, `kSecAttrAccessibleAfterFirstUnlock`, service `com.maalimalkhafji.app.session`. Survives reinstall on purpose, so guest identity is reused | `App/Sources/Backend/KeychainSessionStore.swift` |
| Offline caches | `protocol CacheStore<Value>` plus `FileCacheStore<Value>`: JSON in `Caches/MaalimAlKhafji/<key>.json` behind a private actor | `Shared/Persistence/CacheStore.swift`. Used for `remote_config`, `places.mine`, `places.detail` (`RemotePlaceRepository.swift:24-25`) |
| Small preferences | `UserDefaults`/`@AppStorage`: `appearance`, `app_language` and `AppleLanguages`, `has_seen_onboarding`, recent searches (`Explore/.../RecentSearchesStore.swift`) | |
| Local database | None (no SwiftData or Core Data). Server is the source of truth: "always re-fetch so admin edits show" (ADR 0001) | |

This is reusable. Munyati will add a cached bride budget and city filter (UserDefaults for guests, server for signed-in users), plus possibly an offline queue for analytics events.

---

## 12. Network monitor

`Shared/Network/NetworkMonitor.swift` is an `@Observable @MainActor` wrapper over `NWPathMonitor` that exposes `isConnected`, and it is unit-tested (`SharedTests/NetworkMonitorTests.swift`). **It is never instantiated in app code.** The `.offline` state only comes from `AppError.offline` mappings in view models (`PlaceDetailViewModel.swift:82`, `CategoryPickerViewModel.swift:29`). Munyati should wire one instance into the environment and show an offline banner, especially around receipt upload.

---

## 13. Networking (worth keeping)

- `Networking/APIClient.swift`: `protocol APIClient: Sendable` with `send(_:)` and `send(_:body:)` and **typed throws `throws(AppError)`**.
- `Networking/URLSessionAPIClient.swift`:
  - snake_case encode and decode, ISO-8601 dates
  - `authTokenProvider` closure, so the module does not know about auth
  - pure, tested `makeURLRequest`, `mapTransportError` and `mapHTTPError`
- `Networking/APIEndpoint.swift` is the only file that knows paths. Helpers: `.rpc(name)` maps to `POST /rest/v1/rpc/<name>`, and `.function(name)` maps to `POST /functions/v1/<name>`. Namespaces: `authentication`, `configuration`, `categories`, `home`, `places`, `analytics`, `search`, `favorites`, `reviews`, `promotion`, `profile`, `business`, `notifications`, `cms`, `storage`.
- `PageDTO<Element>` (cursor pagination), `EmptyResponse` (void RPCs), `RecordAnalyticsEventArgs`.
- Tests: `NetworkingTests/URLSessionAPIClientTests.swift` (15), `APIEndpointTests.swift` (5), `PageDTOTests.swift` (2).

Reuse as-is. Munyati adds namespaces: `bookings`, `availability`, `services`, `providers`, `stores`, `subscriptions`, `payments`, `receipts`, `disputes`, `reports`, `cities`, `budget`, `strings`.

---

## 14. Authentication package

Path: `Packages/Authentication/Sources/Authentication/`

- **Flow:** `AuthLandingView` (root) has **Continue with phone** and **Browse as guest**. Phone leads to `PhoneEntryView` (country picker: `PhoneCountry.saudiArabia`, `.kuwait`, plus `.egypt` in DEBUG only). That leads to `OTPView` (6-digit, `.oneTimeCode` autofill, resend countdown from `OTPChallenge.resendInterval` = 60s). If the server says the number is new, `NameEntryView` follows (first and last name), then `onFinished(.authenticated(user))`.
- **Domain:**
  - `AuthRepository` (`sendOTP`, `verifyOTP`, `registerWithName`, `signInWithApple`, `continueAsGuest`, `currentState`)
  - `OTPFlowError.requiresRegistration`
  - `AuthState {.guest, .authenticated(User)}`
  - `User {id, phoneNumber, displayName}`, with **no role**
  - Use cases in `Domain/UseCases/AuthUseCases.swift` with `PhoneNumberValidator` and `OTPCodeValidator`
- **Live implementation: `App/Sources/Backend/SupabaseAuthRepository.swift`** (an `actor`):
  - `sendOTP` and `verifyOTP` go to Edge Functions `send-otp` / `verify-otp`. **OurSMS is already integrated**: `supabase/functions/send-otp/index.ts` uses the `OURSMS_API_KEY` and `OURSMS_SENDER` secrets, HMACs the code with `OTP_HASH_SECRET`, and has a `DEV_PHONES` bypass. `verify-otp` mints a GoTrue session.
  - Guest is anonymous GoTrue sign-up (`/auth/v1/signup`), which reuses a Keychain session so reinstalls do not spawn new guests.
  - `currentUserIsAnonymous` decodes the JWT `is_anonymous` claim.
  - `refreshIfNeeded()` single-flights token refresh. GoTrue rotates refresh tokens, and any 4xx on refresh discards the session.
  - Apple Sign-In has a use case, a nonce helper (`AppleSignInSupport.swift`) and the entitlement, **but no button**: it is not called from any view.
- **Guest gating:** `AppSession.isAnonymous` plus `Shared.AuthGate` (`isGuest`, `requireSignIn`) in the environment. Features call `authGate.requireSignIn()` before identity actions.
- **Onboarding carousel** (pre-auth marketing pages) is in the App target, not this package: `App/Sources/Support/Presentation/UI/OnboardingCarouselView.swift` (3 hard-coded pages, `OnboardingStore.hasSeenOnboarding`).

### Adding "choose account type" (bride vs service provider)
1. **Domain.** Add `public enum AccountRole: String, Sendable { case customer, provider }` and `User.role: AccountRole?`. `AppSession.State.authenticated(userId:)` becomes `authenticated(userId:role:)`, or keep role on `AccountProfile`.
2. **Route.** Add `AuthRoute.roleSelection`, or make role selection the landing screen itself: two large cards ("عروس" / "مقدم خدمة"). Store `selectedRole` on `AuthCoordinator`, next to `activeChallenge`.
3. **Registration.** Pass the role through `registerWithName(challengeId:code:firstName:lastName:role:)`. That means adding `account_type` to `VerifyOTPBody` in `SupabaseAuthRepository` and to `verify-otp/index.ts`, which writes `profiles.role`. Returning users get their role from `get_profile`, so it is never trusted from the client after creation. Role changes should be admin-only.
4. **Guests.** Browsing as a guest is allowed only for brides. The provider path skips "Browse as guest" and goes straight to phone, then name, then business onboarding (subscription trial and demo booking).
5. **Shell.** `RootTabView` switches the tab content set on the role.
6. **Phone countries.** Restrict `PhoneCountry.selectable` to Saudi Arabia, since the launch cities are Saudi (owner decision).

---

## 15. Explore map

- **Apple MapKit (SwiftUI `Map`), not Google.** `Packages/Features/Explore/Sources/Explore/Presentation/Views/ExploreView.swift`:
  - `Map(position: $cameraPosition)` with `UserAnnotation()` and custom `Annotation` pins (price bubbles)
  - initial `MKCoordinateRegion` hard-coded to Khafji (`28.4392, 48.4915`)
  - "locate me" through `Places.CurrentLocationProvider` (CoreLocation async bridge)
  - **hand-rolled de-overlap**: pins within `clusterThresholdMeters = 60` are fanned onto a 15 m ring, which is not true clustering
  - floating `liquidGlassPill` search bar and category chip rail, a bottom preview card on pin tap, and `.navigationDestination(item:)` to `PlaceDetailScreen`
- It loads **all** live places client-side (`viewModel.allPlaces`). There is no viewport or bounding-box query.
- Other MapKit uses: `Places/.../PlaceMapView.swift` (detail mini-map plus Directions, tracked as `place_directions`) and `LocationPickerSheet.swift` (owner pin picker).
- (Lamha uses Google Maps. Kolna does not, and needs no API key.)

**For Munyati:** keep MapKit, which is free, native and RTL-aware. Centre on the selected city or cities from the `cities` table (lat/lng/zoom), pin providers or stores rather than services, and query by city ids plus bounding box. Add real clustering if provider density grows (MapKit in SwiftUI has no built-in clustering; use `MKMapView` with `clusteringIdentifier` through `UIViewRepresentable`, or server-side grid clustering).

---

## 16. Push notifications, NotificationService extension, deep links from notifications

- **SDK confinement.** FirebaseMessaging is imported only in `App/Sources/Push/AppDelegate.swift`. `AppDelegate` runs `FirebaseApp.configure()` and bridges the APNs token to `Messaging.messaging().apnsToken`.
- `FirebasePushNotificationService` (`@MainActor`):
  - implements `PushNotifying` (`App/Sources/Push/PushNotificationService.swift`): `requestAuthorizationAndRegister()`, `fcmToken`, `onTokenChange`, `onNotificationTap`
  - shows foreground banners (`[.banner, .badge, .sound]`)
  - **buffers cold-start taps** in `pendingTap` until the SwiftUI layer wires the handler
- **Token lifecycle.** `AppEnvironment.bindPush` caches `lastPushToken`. `registerPushTokenIfPossible()` calls RPC `register_device_token(p_token, p_platform: "ios")` once authenticated. `unregister_device_token` runs on sign-out and account deletion.
- **Server side.** `supabase/functions/send-push/index.ts` is triggered by a database webhook on `public.notifications` insert. It uses FCM HTTP v1 with a service-account JWT and sends `data: {notification_id, place_id?, business_id?, image?}` with `apns.payload.aps["mutable-content"] = 1`.
- **Rich push.** `App/NotificationService/NotificationService.swift` is a `UNNotificationServiceExtension` that downloads `userInfo["image"]` and attaches it; it also honours a `subtitle` data key. The target is pinned to **Swift 5** language mode (`project.yml`), on purpose, because of the completion-handler template.
- **Deep-link routing from a tap.** `PushTap {placeId, businessId, notificationId}` goes to `bindPush` and then to `DeepLinkStore.pendingPlaceId` or `.pendingBusinessId` (`App/Sources/Composition/DeepLinkStore.swift`). `RootTabView` presents a `fullScreenCover` wrapping its **own** `NavigationStack` with `makeDetailScreen` or `makeBusinessProfileScreen`. It also calls `mark_notification_opened`. Routing does **not** switch tabs or push onto a tab stack.
- **In-app inbox.** `Shared/Notifications/NotificationsView.swift` plus `NotificationsRepository`: list, mark read, mark opened, mark all read, delete, delete all. `AppNotification.Kind` is a **closed enum** (`place_approved`, `review_received`, `admin_message`, …) and unknown kinds are dropped by the DTO mapper.
- **Entitlements.** `App/Resources/App.entitlements` has `aps-environment = development` and `com.apple.developer.applesignin`. `Info.plist` has `UIBackgroundModes: remote-notification`.

**For Munyati:** reuse all the plumbing. Replace the ad-hoc `place_id`/`business_id` keys with a single `deep_link` (a URL string such as `https://munyati.co/booking/<id>`). Push taps, universal links and in-app links then go through one parser into a `DeepLink` enum, and the router switches tab and pushes onto that tab's coordinator path instead of a detached full-screen cover. Add booking `Kind`s and consider notification categories with actions (approve or decline from the lock screen, which needs `UNNotificationCategory` registration).

---

## 17. Universal links

**Missing in Kolna.** There is no `com.apple.developer.associated-domains` entitlement, no `onOpenURL` or `onContinueUserActivity`, no `CFBundleURLTypes` custom scheme, and no `ShareLink` for listings (grep-verified). The only "share" is image share in `FullscreenMediaPager`.

A pattern exists in the sibling repo `lamha_backup_ios`: `Lamha Ads/Lamha Ads.entitlements` has `applinks:lamha.trndsky.com`, and the AASA file is at `lamha_backup_ios/.well-known/apple-app-site-association`.

For Munyati:
1. Add `applinks:munyati.co` (and `www.` if used) to `App.entitlements`.
2. Host the AASA at `https://munyati.co/.well-known/apple-app-site-association` from the landing site, with paths such as `/p/*` (provider), `/s/*` (service), `/store/*`, `/booking/*` and `/invite/*`.
3. Add `.onOpenURL { router.handle(DeepLink(url:)) }` in `RootTabView`.
4. Use `ShareLink(item: URL)` on provider, service and store screens.
5. Have the website render a web fallback page with an App Store badge for each path.

---

## 18. Analytics and logging

- **`Shared/Analytics/AnalyticsRecorder.swift`** is a `Sendable` struct wrapping a closure. It is injected through `\.analytics`, defaults to `.disabled` (previews and tests), and is called as `analytics(.event, entityId, context:)`.
  - `AnalyticsEvent` is a **closed enum of 6**: `app_open`, `place_directions`, `place_whatsapp`, `delivery_link_click`, `banner_impression`, `banner_click`. These map 1:1 to the Postgres enum `analytics_event_type` (`supabase/migrations/20260906150000_engagement_analytics.sql`, extended by `20260912100000_analytics_event_context.sql`).
  - It is wired in `AppEnvironment` to fire-and-forget RPC `record_analytics_event(p_event_type, p_entity_id, p_context_id)`.
- **Call sites:**
  - `RootTabView.swift:150,171`: `appOpen` on launch and on return from background
  - `PlaceMapView.swift:47,51`: directions
  - `ContactSheet.swift:26`: WhatsApp
  - `PlaceDetailView.swift:299`: delivery link
  - `DiscoverHeroCarousel.swift:47,53`: banner click and impression
- **Server-side implicit events:** `record_place_view` (fired inside `RemotePlaceRepository.fetchPlaceDetail`) and `log_search` (inside `fetchPlaces` when a search term or filter is set), with `popular_searches` for the dashboard.
- **Logging:**
  - `Core/Logging/Logger.swift` defines `protocol AppLogging` and `OSAppLogger` (os.Logger), **but it is unused**.
  - The App uses `AppLog.push` and `AppLog.composition` (`App/Sources/Composition/AppLog.swift`).
  - Shared uses private `os.Logger`s (cache, RemoteImage).
  - **There is no crash reporting** (no Crashlytics or Sentry; Package.resolved has only the Firebase core and messaging dependency graph) and **no client error telemetry**.

**For Munyati requirement 9 ("analytics for everything") this is the largest infrastructure gap:**
- **Events.** Replace the closed enum with `track(_ name: String, properties: [String: AnalyticsValue])` plus typed helpers. Store rows as `analytics_events(id, user_id, anon_id, session_id, role, city_id, event_name text, screen, properties jsonb, app_version, os_version, device, locale, created_at)`.
- **Delivery.** Batch on the client (a queue persisted with `FileCacheStore`, flushed every N events or seconds and on background) to one `record_events_batch` RPC or Edge Function.
- **Screen views.** Add a `.trackScreen("name")` view modifier.
- **Errors.** Add an `AppError` hook: every `ViewState.error` and every `mapHTTPError` posts to `client_errors`.
- **Crashes.** Add **FirebaseCrashlytics** (Firebase is already in the stack and confined to the App target) for crash and non-fatal reporting.
- **Dashboard aggregates.** Providers vs customers, services per category, bookings funnel, and so on can be computed by SQL views and RPCs.

---

## 19. Tests, UI tests and build settings

- **Unit tests use Swift Testing** (`import Testing`, `@Test`, `#expect`), one test target per package. Run with `cd Packages/<Name> && swift test` (macOS host, hence `.macOS(.v14)` and the `#if canImport(UIKit)` shims). About 93 `@Test` functions:

  | Package | Tests |
  |---|---|
  | Networking | 22 |
  | Explore | 13 (`ExploreViewModelTests` with `FakePlaceRepository`) |
  | Shared | 11 |
  | Places | 11 (including `AdminEditReflectionTests`) |
  | Authentication | 11 |
  | Home | 7 |
  | Core | 6 |
  | DesignSystem | 6 |
  | Account | 4 |
  | Saved | 2 |
- **UI tests use XCTest** in `AppUITests/`: `HomeUITests` (6), `AccountUITests` (7), `ExploreMapUITests` (4), `PlaceDetailUITests` (6), `SavedUITests` (2), about 25 tests. They are driven by launch environment hooks:
  - `UITEST_MOCK_BACKEND=1` (mock repositories, no onboarding, analytics disabled)
  - `UITEST_START_TAB`, `UITEST_START_AUTHENTICATED`, `UITEST_PRESENT_AUTH`, `UITEST_OPEN_DETAIL`, `UITEST_OPEN_BUSINESS`
  - `UITEST_NO_PUSH`
  - launch arguments `-AppleLanguages (en)`
- The `App` scheme's test action runs **only** `AppUITests`. Package tests are not in the Xcode scheme.
- **Missing:** no CI (`.github/` absent), no SwiftLint or SwiftFormat config, no snapshot tests (ADR 0001 lists them as future work).
- **Build settings** (`project.yml`):
  - `SWIFT_VERSION 6.0` and `SWIFT_STRICT_CONCURRENCY: complete` at project level; the NotificationService target overrides to `SWIFT_VERSION 5.0`
  - `ENABLE_USER_SCRIPT_SANDBOXING: YES`
  - `DEVELOPMENT_TEAM: T36353GWKH`, `CODE_SIGN_STYLE: Automatic`
  - `MARKETING_VERSION 1.0.5`, `CURRENT_PROJECT_VERSION 1`
  - `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
  - `ExportOptions.plist` uses `method app-store-connect`

---

## 20. Reuse table (per package and area)

| Package / area | Decision | Notes |
|---|---|---|
| `Core/State/ViewState` | **Copy as-is** | |
| `Core/Error/AppError` | **Copy, then extend** | Add business-rule cases or codes (plan limit, same-category conflict, slot taken, receipt rejected) |
| `Core/Navigation/Coordinator` + `ViewFactory` | **Copy as-is** | Then actually use it in every tab |
| `Core/Configuration/RemoteConfig` | **Adapt** | `cities` becomes `[City]`; add `trialDays`, booking rules, support WhatsApp, `stringsVersion`; drop or wire `branding` |
| `Core/DI/DIContainer` | **Drop** (unused) | Or adopt deliberately |
| `Core/Logging/Logger` | **Adapt** | Make it the real logger and route `.error` to client-error telemetry |
| `DesignSystem` foundations and components | **Copy, then re-skin** | New colors, gradients and font; replace `DSHeroImage` assets; add `StatusBadgeKind` cases for booking states; promote the Places helpers from §8.3 |
| `Networking` | **Copy as-is** | Add new `APIEndpoint` namespaces |
| `Shared/Images` (`RemoteImageView`) | **Copy as-is** | Rename cache path |
| `Shared/Persistence` (`CacheStore`) | **Copy as-is** | Rename folder |
| `Shared/Network/NetworkMonitor` | **Copy, then wire it in** | |
| `Shared/Auth` (`AuthGate`, `AdAccessPolicy`) | **Copy `AuthGate`; drop `AdAccessPolicy`** | Add a `RoleGate` / `PlanGate` analogue |
| `Shared/Analytics` | **Rewrite** | Generic event stream (§18) |
| `Shared/Notifications` | **Adapt** | New `Kind`s, `deepLink` field; keep the view and repository shape |
| `Shared/Icons/CategoryIcon` | **Adapt** | Keep bundled fallback; add a remote `iconURL` path |
| `Shared/Icons/SocialIcon` | **Copy as-is** | |
| `Shared/Theme/NationalDay*` | **Drop** (keep the generic `DSSurfaceOverride` mechanism) | Could become a remote-flagged seasonal theme later |
| `Shared/Localization/SharedStrings` | **Copy, then extend** | Add the `RemoteStrings` overlay |
| `Authentication` | **Adapt** | Add role selection, role in `User`/registration; providers have no guest path; SA-only phone; optional Apple button |
| `Features/Places` | **Mine, don't copy** | Keep patterns: dynamic form engine, reviews UI with masking (`Review.displayAuthorName`), media pager, image compressor, location picker, Business→Places relation, pending/approved moderation, `PlaceComposer` draft pattern. Replace domain: `Place` becomes `Service`, `Business` becomes `Provider`/`Store` |
| `Features/Home` | **Adapt** | Keep hero carousel (`DiscoverHeroCarousel`, `HomeSectionsRepository`), category rail, featured rails. Drop `WeatherStore`, Khafji header, `AllPlaces`; add budget card, city filter header, recommended services ≤ budget |
| `Features/Explore` | **Adapt** | Keep MapKit map, glass search bar, chip rail, preview card; replace Khafji region; multi-city; provider pins |
| `Features/Saved` | **Optional** | Not one of the 4 tabs; could live under Profile as "Favorites" |
| `Features/Account` | **Adapt** | Keep profile edit, avatar upload, language and appearance rows, notifications, Help/About/Terms/Privacy (CMS), social links, rate app, sign out, **delete account**. Remove My Places, List business and the hard-coded WhatsApp. Add provider sections (subscription, payout accounts, stores, services) and bride sections (budget, cities) |
| App `Composition/*` | **Copy, then adapt** | `AppEnvironment` (new repos), `AppSession` (+role), `RemoteConfigStore` (new flags), `DeepLinkStore` becomes a `DeepLink` router, `BackendConfiguration` as-is |
| App `Backend/*` | **Copy, then adapt** | `SupabaseAuthRepository` (+role), `KeychainSessionStore`, `SupabaseConfigurationRepository`, `SupabaseCMSPageRepository`, `SupabaseNotificationsRepository`, `SupabaseProfileRepository` as-is or lightly changed; `SupabaseImageUploader` becomes a generic uploader with public/private bucket support; drop `SupabaseVideoUploader` unless services have video |
| App `Push/*` + `NotificationService` | **Copy as-is** | Change payload keys to `deep_link` |
| App `Support/UI` | `ForceUpdateView`, `SessionCheckView`, `InfoSheet`, `CMSMarkdownView`: **copy**. `OnboardingCarouselView`: **adapt** (new pages, budget step). `PostDisabledView`: **drop** |
| App `RootTab/*` | **Adapt** | 4 tabs, role-based content, `onOpenURL`; keep `SwipeBackGesture` (with its known risk) |
| `supabase/functions/send-otp`, `verify-otp`, `send-push`, `delete-account` | **Copy, then adapt** | OurSMS OTP is already done; `verify-otp` gains `account_type` |
| `AppUITests` + `UITEST_*` hooks | **Copy pattern** | Rewrite the tests |

---

## 21. Renames and config changes to start Munyati from this code

1. **Project and targets** (`project.yml`):
   - `name: MaalimAlKhafji` becomes `Munyati`; `bundleIdPrefix: com.maalimalkhafji` becomes something like `co.munyati`
   - `PRODUCT_BUNDLE_IDENTIFIER` for `App`, `NotificationService` (`….app.notificationservice`) and `AppUITests`
   - `APP_DISPLAY_NAME: Kolna Al-Khafji` becomes `منيتي` (Arabic display name via `InfoPlist.strings` for ar/en if desired)
   - `MARKETING_VERSION 1.0.5` becomes `1.0.0`
   - Confirm `DEVELOPMENT_TEAM T36353GWKH` is the right Apple team
   - Regenerate with `xcodegen generate`; the `.xcodeproj` becomes `Munyati.xcodeproj`
2. **Entry point:** rename `App/Sources/MaalimAlKhafjiApp.swift` (`struct MaalimAlKhafjiApp`).
3. **Identifier strings:**
   - `AppLog` subsystem `com.maalimalkhafji.app` (`AppLog.swift`)
   - Keychain service `com.maalimalkhafji.app.session` (`KeychainSessionStore.swift`)
   - `OSAppLogger` default `"MaalimAlKhafji"` (`Core/Logging/Logger.swift`)
   - `NetworkMonitor` queue label
   - `FileCacheStore` folder `"MaalimAlKhafji"` plus logger subsystem (`CacheStore.swift`)
   - `RemoteImageLoading` `diskPath` plus logger (`RemoteImageView.swift`)
   - `AppEnvironment.appVersionString` (`"Kolna Al-Khafji …"`)
4. **Backend config:**
   - New `App/Resources/BackendConfig.plist` (new Supabase project URL and anon key)
   - New `App/Resources/GoogleService-Info.plist` (new Firebase project with an APNs `.p8` key uploaded)
   - `supabase/config.toml` project ref
   - Edge-function secrets: `OURSMS_API_KEY`, `OURSMS_SENDER` (an **approved Munyati sender name** in the OurSMS portal), `OTP_HASH_SECRET`, `DEV_PHONES`, `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `PUSH_WEBHOOK_SECRET`, plus Tap keys
5. **Entitlements** (`App/Resources/App.entitlements`): add `com.apple.developer.associated-domains = [applinks:munyati.co]`; keep `aps-environment`; drop `applesignin` if Apple Sign-In is not offered.
6. **Info.plist:** rewrite the usage strings (`NSPhotoLibraryUsageDescription` mentions "your place"; add camera if receipts can be photographed; location wording for brides and providers).
7. **Brand assets:**
   - `AppIcon`, `AppLogo`, `AccentColor` (App `Assets.xcassets`); delete `NationalDayAppIcon`
   - DS `Colors.xcassets` (21 sets) and `DSGradient.swift` literals
   - `DSHeroImage` cases and assets (`HeroArch`, `HeroArch2`, `HeroWatertower`)
   - `Home/Resources/HeroBannerPhotos/*`, `Places/Resources/MockPhotos/*`
   - `Shared/Resources/Media.xcassets/NationalDay*`
   - Category icon set (Hugeicons, licence in `Shared/THIRD_PARTY_NOTICES.txt`): choose wedding-relevant keys
8. **Hard-coded Khafji values:**
   - `ExploreView.khafjiRegion` (28.4392, 48.4915)
   - `WeatherStore` coordinates (drop the file)
   - `home.location.city` string in the Home header
   - `RootTabView` `listBusiness` WhatsApp URL `https://wa.me/966505772798`
   - `MockConfigurationRepository` (app name, `#4A5D3A`/`#C79A3E`, `cities: ["Khafji"]`)
   - all `Mock*` seed data
   - onboarding copy and SF Symbols
   - `CMSPageRepository` mock "About Kolna Al-Khafji"
9. **Strings:** search every `Localizable.strings` for Khafji, الخفجي, كلنا and معالم (about 20 files listed by grep). Rename `places.*` and `tab.post` keys to the new domain.
10. **Enums tied to the old domain:** `AppTab` (5 becomes 4), `AnalyticsEvent`, `AppNotification.Kind`, `StatusBadgeKind`, `PlacesRoute`, `PlaceStatus`, `PhoneCountry.selectable`.
11. **Remote-config flags:** drop `postAdEnabled` (Post tab), `requireSignInForAds` and `nationalDayThemeEnabled`; add Munyati flags.
12. **Docs:** fix the module-graph drift (§2.2) and ADR 0001 staleness when copying `Docs/`. Write new ADRs (roles, booking state machine, payments by receipt, deep links).
13. **UI tests:** replace assertions on `"Kolna Al-Khafji"` and Arabic category names (`HomeUITests`, `AccountUITests`, `PlaceDetailUITests`).

---

## 22. Gaps: what Munyati needs that Kolna lacks

Rough client-side effort: **S** about 1–3 days, **M** about 1–2 weeks, **L** more than 2 weeks. Every item also needs schema, RPC and RLS work.

| # | Gap (owner req.) | Status in Kolna | What to build on iOS |
|---|---|---|---|
| G1 | **Roles** (1) | None; `User` has no role | Role picker in auth, `User.role`, role-based shell, provider onboarding. **M** |
| G2 | **Provider subscriptions and plan gating** (2, 8, 11, 23, 24) | None. `PromoteSheet` only records a promotion request handled off-app; `payments` table is an admin-only manual log | Plans screen (Normal/Plus/Diamond loaded from server, monthly), 2-month trial state, paywall when adding service N+1 beyond the plan limit, renewal and expiry banners. Tap checkout via an Edge Function charge plus `SFSafariViewController`/`ASWebAuthenticationSession`, with the result from a webhook (pattern: `lamha_backup_ios/supabase` `create-ad-charge`, `tap-webhook`, `payment-return`). Open question for the owner: check App Store guideline 3.1 for selling provider subscriptions through Tap instead of IAP. **L** |
| G3 | **Services catalogue** (2, 3, 18) | `Place` plus a dynamic form engine; categories are dynamic (`get_categories`, bilingual) | `Service` entity (price, duration, category, provider, store, images), provider CRUD reusing `DynamicPlaceFormView` and the image pipeline. **M** |
| G4 | **Booking request flow** (4) | None | Booking entity and state machine: `requested` → `approved` / `declined` / `reschedule_proposed` → (bride accepts or rejects the proposal) → `awaiting_payment` → `receipt_submitted` → `payment_confirmed` / `payment_rejected` → `completed` / `cancelled` / `disputed`. Bride and provider booking lists (the "My Bookings" tab), detail with a timeline, actions, push for every transition. **L** |
| G5 | **Calendar and availability slots** (4) | Only display of weekly hours (`BusinessHoursView`) and a time `DatePicker` in forms | Provider working hours and blackout dates, slot generation (server-side), date and time picker for brides showing free slots, provider agenda or calendar view. **L** |
| G6 | **Manual payment and receipt upload** (5, 22) | Uploads go to **public** buckets only (`SupabaseImageUploader` returns `/object/public/...`) | Provider payout methods (IBAN, STC Pay, …) CRUD; bride sees them after approval; `PhotosPicker` or camera, then `ImageCompressor`, then upload to a **private** `payment-receipts` bucket (signed URLs, RLS limited to the booking's bride, its provider and admins; Lamha's `supabase/functions/sign-media-url` and `create-upload` are a reference for signed access); provider confirms or rejects. **M** |
| G7 | **Disputes, reports, flags, support** (5, 28) | Review moderation exists server-side (approval, bans, hidden or soft-deleted); **no user-facing report or flag**; support is CMS pages plus contact methods | "Report" sheet for provider, service, review or booking; "Open dispute" on a booking with evidence; support ticket screen or WhatsApp deep link from config. **M** |
| G8 | **Budget** (13) | None | Budget capture (onboarding step or first-booking prompt; editable in Profile), remaining = budget − sum of active bookings (one per category, computed server-side), "within budget" filter on Home and Explore, budget progress card. **M** |
| G9 | **Same-category booking rule** (20) | None | Enforced server-side (unique partial index or RPC check on bride + category where status is not final); client disables "Book" and explains which booking blocks it. **S** |
| G10 | **Stores linked to provider** (14) | `Business` → places (one business per user via `get_my_business`) is the closest analogue; `BusinessProfileScreen` exists | `Store` entity (one-to-many under provider), store profile screen, store pins on the map. **M** |
| G11 | **Demo booking for new providers** (24) | None | Server creates one `is_demo` booking on provider registration; client renders a "تجريبي" badge, lets the provider approve, reschedule or complete it with no real customer notified, and shows a guided tooltip overlay. **S–M** |
| G12 | **Two-way reviews after completion, masked names** (15) | Bride→place reviews only, admin approval, reactions, client-side masking (`Review.displayAuthorName`: "Ah**** Al****"); **the backend returns the full name** (`20260756100000_reviews_full_name_backend.sql`) | Review is unlocked by a `completed` booking (one per side per booking); provider→bride review; **move masking server-side** for brides' privacy (only admins see full names). Reuse `ReviewsUI`. **M** |
| G13 | **Multi-city filter with "All"** (16, 17) | `RemoteConfig.cities: [String]` never read; `PlaceQuery.city` takes one string; Home header city hard-coded | `City {id, nameAr, nameEn, lat, lng, isActive}` from the server, a `CityFilterStore` (`Set<CityID>` or `.all`) persisted per user, a city-picker sheet with multi-select, `p_city_ids uuid[]` on every list RPC. **M** |
| G14 | **Remote content without a build** (19) | Partly: categories (names), hero banners, CMS pages, notifications, flags, force-update message. Category **icons are bundled assets** keyed by name | Add `categories.icon_url` rendered by `RemoteImageView` with the bundled `iconKey` as fallback; `RemoteStrings` overlay (§9); remote onboarding pages and empty-state images. **M** |
| G15 | **Universal links and sharing** (26, 27) | Missing (§17) | AASA, entitlement, `onOpenURL`, `DeepLink` parser plus tab router, `ShareLink`. **S–M** |
| G16 | **Unified deep-link router** (26) | Push only (`place_id`/`business_id` opens a detached full-screen cover) | `DeepLink` enum used by push, universal links and in-app links; coordinator-per-tab routing. **S** |
| G17 | **Strong analytics and error logs** (9) | 6 fixed events plus view and search logs; no screen views, errors or crashes | §18: generic batched events, screen tracking, client error log, Crashlytics. **M** |
| G18 | **OurSMS marketing from dashboard** (10) | OTP only (`send-otp`) | Server and dashboard only; the app needs an SMS marketing opt-in toggle in Profile (consent). **S** |
| G19 | **Provider-facing tools** | None (Kolna's owner side is "My Places" plus status) | Provider dashboard: requests inbox, today's agenda, earnings and receipts, subscription status, services, stores. **L** |
| G20 | **Landing and legal web pages** (29) | Out of scope for the iOS repo; app links to CMS pages | Host privacy, terms and support on munyati.co (also serves the AASA); app `support.*URL` points there. **S** (client) |
| G21 | **Bride-centric onboarding** (6, 13) | Generic 3-page carousel in the App target | Role-aware onboarding (bride: wedding date, cities, budget; provider: plan trial explanation, then demo booking). **S–M** |
| G22 | **Offline and network UX** | `NetworkMonitor` unused | Offline banner; disable submit buttons while offline. **S** |
| G23 | **CI and quality** | No CI, lint or snapshot tests | GitHub Actions: `xcodegen` plus `swift test` per package plus `xcodebuild build`; SwiftLint. **S** |

### Suggested Munyati package layout (derived from Kolna)
```
Packages/
  Core/ DesignSystem/ Networking/ Shared/        ← copied and re-skinned/extended
  Authentication/                                ← + role selection
  Features/
    Home/            (bride: budget card, categories, featured providers; provider: requests summary)
    Explore/         (MapKit, multi-city, providers/stores)
    Catalog/         (categories → providers → services → store profile; replaces Places browsing)
    Booking/         (request, reschedule proposals, payment and receipt, timeline, disputes)
    Availability/    (provider hours, slots, calendar)
    ProviderStudio/  (services CRUD, stores, payout methods, subscription and plans, demo booking)
    Reviews/         (two-way, post-completion, masked names)
    Profile/         (from Account: settings, cities, budget, support, report, delete account)
```
