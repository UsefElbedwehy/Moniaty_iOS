import Foundation
import Core

/// In-memory `ConfigurationRepository` used when no backend is configured, and in UI tests
/// (`UITEST_MOCK_BACKEND`).
public final class MockConfigurationRepository: ConfigurationRepository {
    private let config: RemoteConfig

    public init() {
        self.config = RemoteConfig(
            branding: RemoteConfig.Branding(
                appName: "Munyati",
                logoURL: nil,
                primaryColorHex: "#8A0D3A",
                accentColorHex: "#DFC389"
            ),
            featureFlags: ["guestBrowsing": true, "maintenanceMode": false],
            enabledModules: [],
            supportedLanguages: ["en", "ar"],
            supportedCurrencies: ["SAR"],
            regions: [],
            cities: ["Dammam", "Khobar", "Qatif"],
            socialLinks: [:],
            support: RemoteConfig.SupportInfo(
                helpCenterURL: nil,
                termsURL: URL(string: "https://munyati.co/terms"),
                privacyPolicyURL: URL(string: "https://munyati.co/privacy"),
                contactMethods: [RemoteConfig.ContactMethod(id: "mock-whatsapp", type: "email", value: "contact@munyati.co")]
            ),
            update: RemoteConfig.UpdateInfo(minRequiredVersion: nil, updateMessage: nil, forceUpdate: false, storeURL: nil)
        )
    }

    public func fetchConfiguration() async throws -> RemoteConfig { config }
    public func cachedConfiguration() async -> RemoteConfig? { config }
}
