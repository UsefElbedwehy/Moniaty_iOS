import Foundation
import Core
import Networking
import Shared

/// Production `ConfigurationRepository` over the Supabase `get_config` RPC. Caches the last
/// successful fetch to disk so the app has a usable config immediately on a cold, offline
/// launch (falling back only to the fetch's own error on a truly first-ever offline launch).
public final class SupabaseConfigurationRepository: ConfigurationRepository {
    private let client: APIClient
    private let cache: any CacheStore<RemoteConfig>

    public convenience init(client: APIClient) {
        self.init(client: client, cache: FileCacheStore(key: "remote_config"))
    }

    init(client: APIClient, cache: any CacheStore<RemoteConfig>) {
        self.client = client
        self.cache = cache
    }

    public func fetchConfiguration() async throws -> RemoteConfig {
        let dto: RemoteConfigDTO = try await client.send(.configuration.get)
        let config = dto.toDomain()
        try? await cache.save(config)
        return config
    }

    public func cachedConfiguration() async -> RemoteConfig? {
        await cache.load()
    }
}

// MARK: - Supabase wire shape (snake_case → decoded via the client's .convertFromSnakeCase)

private struct RemoteConfigDTO: Decodable, Sendable {
    struct BrandingDTO: Decodable, Sendable {
        let appName: String
        let logoUrl: URL?
        let primaryColorHex: String
        let accentColorHex: String
    }

    struct ContactMethodDTO: Decodable, Sendable {
        let id: String
        let kind: String
        let value: String
    }

    struct SupportDTO: Decodable, Sendable {
        let helpCenterUrl: URL?
        let termsUrl: URL?
        let privacyPolicyUrl: URL?
        let contactMethods: [ContactMethodDTO]
    }

    struct UpdateInfoDTO: Decodable, Sendable {
        let minRequiredVersion: String?
        let updateMessage: String?
        let forceUpdate: Bool?
        let storeUrl: URL?
    }

    let branding: BrandingDTO
    let featureFlags: [String: Bool]
    let enabledModules: [String]
    let supportedLanguages: [String]
    let supportedCurrencies: [String]
    let regions: [String]
    let cities: [String]
    let socialLinks: [String: URL]
    let support: SupportDTO
    let update: UpdateInfoDTO?

    func toDomain() -> RemoteConfig {
        RemoteConfig(
            branding: RemoteConfig.Branding(
                appName: branding.appName,
                logoURL: branding.logoUrl,
                primaryColorHex: branding.primaryColorHex,
                accentColorHex: branding.accentColorHex
            ),
            featureFlags: featureFlags,
            enabledModules: enabledModules,
            supportedLanguages: supportedLanguages,
            supportedCurrencies: supportedCurrencies,
            regions: regions,
            cities: cities,
            socialLinks: socialLinks,
            support: RemoteConfig.SupportInfo(
                helpCenterURL: support.helpCenterUrl,
                termsURL: support.termsUrl,
                privacyPolicyURL: support.privacyPolicyUrl,
                contactMethods: support.contactMethods.map {
                    RemoteConfig.ContactMethod(id: $0.id, type: $0.kind, value: $0.value)
                }
            ),
            update: RemoteConfig.UpdateInfo(
                minRequiredVersion: update?.minRequiredVersion,
                updateMessage: update?.updateMessage,
                forceUpdate: update?.forceUpdate ?? false,
                storeURL: update?.storeUrl
            )
        )
    }
}
