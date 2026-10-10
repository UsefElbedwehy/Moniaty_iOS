import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import Core
import Networking
import Authentication
import Shared
import Catalog
import ProviderStudio
import Booking

/// The composition root: builds every repository once, owns the app-wide stores, and is the
/// only place that knows about Supabase and Firebase. Features get plain values and closures.
///
/// Phase 1 scope (`docs/PLAN.md` §12): session restore, sign-in with role, profile + role,
/// remote config and strings, cities, analytics, push registration and deep links.
@MainActor
final class AppEnvironment {
    let session = AppSession()
    let remoteConfig = RemoteConfigStore()
    let deepLink = DeepLinkStore()
    let cities = CityFilterStore()
    let analytics: AnalyticsRecorder
    /// Bride discovery (Phase 2). Its context mirrors the session and city filter.
    private(set) var catalog: CatalogFeature!
    /// Provider studio (Phase 2).
    let studio: StudioFeature
    /// Requests, the booking lifecycle and receipts for both roles (Phase 3).
    private(set) var booking: BookingFeature!

    private static var useRemoteBackend: Bool {
        ProcessInfo.processInfo.environment["UITEST_MOCK_BACKEND"] != "1"
    }

    private let supabaseAuth: SupabaseAuthRepository?
    private let configurationRepository: ConfigurationRepository
    private let profileRepository: ProfileRepository
    private let contentRepository: ContentRepository
    let cmsPageRepository: CMSPageRepository
    private let catalogRepository: CatalogRepository
    private let performDeleteAccount: (@Sendable () async throws -> Void)?

    init() {
        let bookingRepository: BookingRepository
        let receiptStorage: ReceiptStorage
        if Self.useRemoteBackend, let values = BackendConfiguration.load(),
           let config = BackendConfiguration.makeNetworkConfiguration() {
            let auth = SupabaseAuthRepository(client: URLSessionAPIClient(configuration: config))
            let dataClient = URLSessionAPIClient(
                configuration: config,
                authTokenProvider: { await auth.currentAccessToken() }
            )
            supabaseAuth = auth
            configurationRepository = SupabaseConfigurationRepository(client: dataClient)
            profileRepository = SupabaseProfileRepository(client: dataClient)
            contentRepository = SupabaseContentRepository(client: dataClient)
            cmsPageRepository = SupabaseCMSPageRepository(client: dataClient)
            catalogRepository = RemoteCatalogRepository(client: dataClient)
            studio = StudioFeature(
                repository: RemoteStudioRepository(client: dataClient),
                uploader: SupabaseMediaUploader(
                    baseURL: values.baseURL,
                    anonKey: values.anonKey,
                    accessToken: { await auth.currentAccessToken() },
                    currentUserId: { await auth.currentUserId }
                )
            )
            bookingRepository = RemoteBookingRepository(client: dataClient)
            receiptStorage = SupabaseReceiptStorage(
                baseURL: values.baseURL,
                anonKey: values.anonKey,
                accessToken: { await auth.currentAccessToken() }
            )
            analytics = Self.makeAnalytics(client: dataClient)

            let baseURL = values.baseURL
            let anonKey = values.anonKey
            performDeleteAccount = {
                guard let token = await auth.currentAccessToken() else { throw AccountDeletionError.notSignedIn }
                var request = URLRequest(url: baseURL.appendingPathComponent("functions/v1/delete-account"))
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue(anonKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw AccountDeletionError.requestFailed
                }
            }
        } else {
            // No BackendConfig.plist values (or a UI-test run): everything runs on in-memory mocks.
            supabaseAuth = nil
            configurationRepository = MockConfigurationRepository()
            profileRepository = MockProfileRepository()
            contentRepository = MockContentRepository()
            cmsPageRepository = MockCMSPageRepository()
            catalogRepository = MockCatalogRepository()
            studio = StudioFeature(repository: MockStudioRepository(), uploader: MockMediaUploader())
            // One mock for both shells: a request sent as a bride shows up in the provider inbox.
            bookingRepository = MockBookingRepository()
            receiptStorage = MockReceiptStorage()
            analytics = .disabled
            performDeleteAccount = nil
        }
        catalog = CatalogFeature(
            repository: catalogRepository,
            context: CatalogContext(citySummary: L10n.string("cities.all")),
            openCityPicker: { [weak self] in self?.session.isPickingCities = true },
            requireSignIn: { [weak self] in self?.session.isPresentingAuth = true }
        )
        booking = BookingFeature(
            repository: bookingRepository,
            receipts: receiptStorage,
            remainingBudget: { [weak self] in self?.catalog.remainingBudget },
            onBookingsChanged: { [weak self] in self?.catalog.refreshBudget() }
        )
        catalog.setBookingHandler { [weak self] card in self?.requestBooking(card) }
        let bookingFeature = self.booking!
        studio.setSettingsDestination { link in
            switch link {
            case .availability: AnyView(bookingFeature.destination(for: .availability, role: .provider))
            case .paymentMethods: AnyView(bookingFeature.destination(for: .paymentMethods, role: .provider))
            }
        }
    }

    /// "Book" on a service: guests sign in first, providers can't book, brides get the request sheet.
    private func requestBooking(_ card: ServiceCard) {
        guard session.hasAccount else {
            session.isPresentingAuth = true
            return
        }
        guard session.user?.role != .provider else { return }
        session.bookingRequest = BookableService(id: card.id, title: card.title, price: card.price,
                                                 providerName: card.providerName)
    }

    /// Mirrors who is signed in and which cities are chosen into the catalog, which reloads
    /// its screens when these change.
    func refreshCatalogContext() {
        let context = catalog.context
        let wasGuest = context.isGuest
        context.isGuest = !session.hasAccount
        context.displayName = session.user?.displayName
        context.cityIds = cities.queryCityIds
        context.citySummary = cities.summary(allLabel: L10n.string("cities.all"))
        if wasGuest != context.isGuest { catalog.accountChanged() }
    }

    // MARK: - Analytics

    /// Curated events → Postgres + Firebase; screens → Firebase; errors → Crashlytics + Postgres.
    private static func makeAnalytics(client: APIClient) -> AnalyticsRecorder {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let osVersion = UIDevice.current.systemVersion
        return AnalyticsRecorder(
            onEvent: { event, entityId, context, props in
                var parameters: [String: Any] = props
                if let entityId { parameters["entity_id"] = entityId }
                if let context { parameters["context"] = context }
                if FirebaseApp.app() != nil { Analytics.logEvent(event.rawValue, parameters: parameters) }
                Task {
                    let _: EmptyResponse? = try? await client.send(
                        .analytics.record,
                        body: RecordAnalyticsEventArgs(pEventType: event.rawValue, pEntityId: entityId, pContextId: context, pProps: props.isEmpty ? nil : props)
                    )
                }
            },
            onScreen: { name in
                guard FirebaseApp.app() != nil else { return }
                Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: name])
            },
            onError: { code, message, screen in
                if FirebaseApp.app() != nil {
                    Crashlytics.crashlytics().record(error: NSError(
                        domain: "co.munyati.app", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "\(code): \(message)", "screen": screen ?? "-"]
                    ))
                }
                Task {
                    let _: EmptyResponse? = try? await client.send(
                        .analytics.logError,
                        body: LogClientErrorArgs(pCode: code, pMessage: message, pScreen: screen, pAppVersion: appVersion, pOsVersion: osVersion)
                    )
                }
            }
        )
    }

    // MARK: - Auth

    func makeAuthFeature(onFinished: @escaping (AuthState) -> Void) -> AuthenticationFeature {
        if let supabaseAuth {
            return AuthenticationFeature(repository: supabaseAuth, onFinished: onFinished)
        }
        return AuthenticationFeature.makeDefault(onFinished: onFinished)
    }

    /// Launch: restore the Keychain session, then load the profile (which carries the role).
    func restoreSession() async {
        guard session.state == .checking else { return }
        guard let supabaseAuth else {
            session.state = .signedOut
            return
        }
        switch await supabaseAuth.restoreSession() {
        case .guest:
            session.state = .signedOut
        case .authenticated(let user):
            await signedIn(user)
        }
    }

    /// Called when the auth flow finishes (new sign-in, registration, or "browse as guest").
    func authFinished(_ state: AuthState) async {
        switch state {
        case .guest:
            // "Browse as guest" without a server session (mock backend, or anonymous sign-in
            // unavailable): browse as a bride; anything that needs an account asks to sign in.
            session.state = .signedIn(.init(id: "guest", role: .bride, isAnonymous: true, displayName: nil))
        case .authenticated(let user):
            await signedIn(user)
        }
        session.isPresentingAuth = false
        refreshCatalogContext()
    }

    private func signedIn(_ user: User) async {
        let isAnonymous = await supabaseAuth?.currentUserIsAnonymous ?? false
        session.state = .signedIn(.init(id: user.id, role: user.role, isAnonymous: isAnonymous, displayName: user.displayName))
        await syncProfile()
        refreshCatalogContext()
    }

    /// Refreshes the role, name and saved cities from the server profile.
    func syncProfile() async {
        // A local guest (no server session) has no profile to load.
        guard var current = session.user, current.id != "guest" else { return }
        guard let profile = try? await profileRepository.fetchMyProfile() else {
            // Offline: keep what we have. A guest browses as a bride.
            if current.role == nil, current.isAnonymous { current.role = .bride }
            session.state = .signedIn(current)
            return
        }
        current.role = profile.role ?? (profile.isAnonymous ? .bride : current.role)
        current.isAnonymous = profile.isAnonymous
        current.displayName = profile.displayName
        session.state = .signedIn(current)
        cities.restore(profile.cityIds)
        refreshCatalogContext()
        if FirebaseApp.app() != nil {
            Analytics.setUserProperty(current.role?.rawValue, forName: "role")
            Crashlytics.crashlytics().setUserID(profile.id)
        }
    }

    func signOut() async {
        await supabaseAuth?.signOut()
        session.state = .signedOut
        cities.restore([])
        refreshCatalogContext()
    }

    func deleteAccount() async throws {
        guard let performDeleteAccount else { throw AccountDeletionError.notSignedIn }
        try await performDeleteAccount()
        await signOut()
    }

    // MARK: - Remote config, strings, cities

    func loadRemoteConfig() async {
        if let config = try? await configurationRepository.fetchConfiguration() {
            remoteConfig.update(config)
        } else if let cached = await configurationRepository.cachedConfiguration() {
            remoteConfig.update(cached)
        }
    }

    /// Installs dashboard-edited text for the current language (falls back to the bundle).
    func loadRemoteStrings() async {
        let language = Locale.current.language.languageCode?.identifier == "ar" ? "ar" : "en"
        if let strings = try? await contentRepository.fetchStrings(language: language) {
            RemoteStrings.shared.install(strings)
        }
    }

    func loadCities() async {
        if let list = try? await contentRepository.fetchCities() {
            cities.available = list
            refreshCatalogContext()
        }
    }

    /// Saves the bride's city choice ("All" = empty list) to her profile.
    func saveCities() async {
        let ids = cities.isAll ? [] : Array(cities.selected).sorted()
        refreshCatalogContext()
        analytics(.cityFilterChanged, nil, props: ["cities": cities.isAll ? "all" : ids.joined(separator: ",")])
        guard session.hasAccount else { return }
        try? await profileRepository.setMyCities(ids)
    }

    // MARK: - Push and links

    func bindPush(_ service: PushNotifying) {
        service.onTokenChange = { [weak self] token in
            guard let self else { return }
            Task { try? await self.profileRepository.registerDeviceToken(token) }
        }
        service.onNotificationTap = { [weak self] tap in
            self?.open(DeepLink(string: tap.deepLink))
        }
        // A token that arrived before sign-in is registered again once a user exists.
        if let token = service.fcmToken {
            Task { try? await profileRepository.registerDeviceToken(token) }
        }
    }

    func open(_ link: DeepLink?) {
        guard let link else { return }
        deepLink.pending = link
    }

    func open(url: URL) {
        open(DeepLink(url: url))
    }

    static var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }
}

enum AccountDeletionError: Error {
    case notSignedIn
    case requestFailed
}
