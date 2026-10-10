import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import Core
import Networking
import Authentication
import Shared

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

    private static var useRemoteBackend: Bool {
        ProcessInfo.processInfo.environment["UITEST_MOCK_BACKEND"] != "1"
    }

    private let supabaseAuth: SupabaseAuthRepository?
    private let configurationRepository: ConfigurationRepository
    private let profileRepository: ProfileRepository
    private let contentRepository: ContentRepository
    let cmsPageRepository: CMSPageRepository
    private let performDeleteAccount: (@Sendable () async throws -> Void)?

    init() {
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
            analytics = .disabled
            performDeleteAccount = nil
        }
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
            session.state = .signedOut
        case .authenticated(let user):
            await signedIn(user)
        }
        session.isPresentingAuth = false
    }

    private func signedIn(_ user: User) async {
        let isAnonymous = await supabaseAuth?.currentUserIsAnonymous ?? false
        session.state = .signedIn(.init(id: user.id, role: user.role, isAnonymous: isAnonymous, displayName: user.displayName))
        await syncProfile()
    }

    /// Refreshes the role, name and saved cities from the server profile.
    func syncProfile() async {
        guard var current = session.user else { return }
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
        if FirebaseApp.app() != nil {
            Analytics.setUserProperty(current.role?.rawValue, forName: "role")
            Crashlytics.crashlytics().setUserID(profile.id)
        }
    }

    func signOut() async {
        await supabaseAuth?.signOut()
        session.state = .signedOut
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
        }
    }

    /// Saves the bride's city choice ("All" = empty list) to her profile.
    func saveCities() async {
        let ids = cities.isAll ? [] : Array(cities.selected).sorted()
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
