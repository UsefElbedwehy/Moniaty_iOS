import Foundation

/// White-label, backend-driven app configuration. Nothing in this struct is ever
/// hardcoded in a View — Presentation reads it through `ConfigurationRepository`.
public struct RemoteConfig: Codable, Equatable, Sendable {
    public struct Branding: Codable, Equatable, Sendable {
        public let appName: String
        public let logoURL: URL?
        public let primaryColorHex: String
        public let accentColorHex: String

        public init(appName: String, logoURL: URL?, primaryColorHex: String, accentColorHex: String) {
            self.appName = appName
            self.logoURL = logoURL
            self.primaryColorHex = primaryColorHex
            self.accentColorHex = accentColorHex
        }
    }

    public struct ContactMethod: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let type: String // "phone" | "whatsapp" | "email"
        public let value: String

        public init(id: String, type: String, value: String) {
            self.id = id
            self.type = type
            self.value = value
        }
    }

    public struct SupportInfo: Codable, Equatable, Sendable {
        public let helpCenterURL: URL?
        public let termsURL: URL?
        public let privacyPolicyURL: URL?
        public let contactMethods: [ContactMethod]

        public init(helpCenterURL: URL?, termsURL: URL?, privacyPolicyURL: URL?, contactMethods: [ContactMethod]) {
            self.helpCenterURL = helpCenterURL
            self.termsURL = termsURL
            self.privacyPolicyURL = privacyPolicyURL
            self.contactMethods = contactMethods
        }
    }

    /// Admin-settable minimum app version — when `forceUpdate` is on and the running build is
    /// older than `minRequiredVersion`, `RemoteConfigStore.forceUpdateRequired` blocks the whole
    /// app behind an update screen. Same mechanism previously shipped in the Lamha Ads iOS app.
    public struct UpdateInfo: Codable, Equatable, Sendable {
        public let minRequiredVersion: String?
        public let updateMessage: String?
        public let forceUpdate: Bool
        public let storeURL: URL?

        public init(minRequiredVersion: String?, updateMessage: String?, forceUpdate: Bool, storeURL: URL?) {
            self.minRequiredVersion = minRequiredVersion
            self.updateMessage = updateMessage
            self.forceUpdate = forceUpdate
            self.storeURL = storeURL
        }
    }

    public let branding: Branding
    public let featureFlags: [String: Bool]
    public let enabledModules: [String]
    public let supportedLanguages: [String]
    public let supportedCurrencies: [String]
    public let regions: [String]
    public let cities: [String]
    public let socialLinks: [String: URL]
    public let support: SupportInfo
    public let update: UpdateInfo

    public init(
        branding: Branding,
        featureFlags: [String: Bool],
        enabledModules: [String],
        supportedLanguages: [String],
        supportedCurrencies: [String],
        regions: [String],
        cities: [String],
        socialLinks: [String: URL],
        support: SupportInfo,
        update: UpdateInfo
    ) {
        self.branding = branding
        self.featureFlags = featureFlags
        self.enabledModules = enabledModules
        self.supportedLanguages = supportedLanguages
        self.supportedCurrencies = supportedCurrencies
        self.regions = regions
        self.cities = cities
        self.socialLinks = socialLinks
        self.support = support
        self.update = update
    }

    public func isFeatureEnabled(_ key: String) -> Bool {
        featureFlags[key] ?? false
    }
}

/// Boundary between Presentation and the backend-driven config. Implementations are
/// expected to cache the last successful fetch (via `Shared`'s `CacheStore`) so the app
/// remains usable offline with the last-known configuration.
public protocol ConfigurationRepository: Sendable {
    func fetchConfiguration() async throws -> RemoteConfig
    func cachedConfiguration() async -> RemoteConfig?
}
