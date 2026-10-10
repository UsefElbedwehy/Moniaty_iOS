import Foundation
import Core
import Networking
import Authentication

/// The signed-in person's profile as the app needs it in Phase 1: who they are, which side of
/// the marketplace they're on, and which cities they browse.
struct MyProfile: Equatable, Sendable {
    let id: String
    let displayName: String?
    let phone: String?
    let role: UserRole?
    let cityIds: [String]
    let isAnonymous: Bool
    /// Provider accounts only: "pending" until an admin approves the join request.
    let providerStatus: String?
}

/// A city the app serves. Managed from the dashboard (`cities` table).
struct City: Identifiable, Equatable, Sendable, Decodable {
    let id: String
    let nameAr: String
    let nameEn: String

    func name(locale: Locale = .current) -> String {
        locale.language.languageCode?.identifier == "ar" ? nameAr : nameEn
    }
}

protocol ProfileRepository: Sendable {
    func fetchMyProfile() async throws -> MyProfile
    func setMyCities(_ cityIds: [String]) async throws
    func registerDeviceToken(_ token: String) async throws
}

protocol ContentRepository: Sendable {
    func fetchCities() async throws -> [City]
    /// Remote string overrides for one language (key → text).
    func fetchStrings(language: String) async throws -> [String: String]
}

struct SupabaseProfileRepository: ProfileRepository {
    let client: APIClient

    func fetchMyProfile() async throws -> MyProfile {
        let dto: ProfileDTO = try await client.send(.profile.get, body: EmptyArgs())
        return MyProfile(
            id: dto.id,
            displayName: dto.displayName,
            phone: dto.phone,
            role: dto.role.flatMap(UserRole.init(rawValue:)),
            cityIds: dto.cityIds ?? [],
            isAnonymous: dto.isAnonymous ?? false,
            providerStatus: dto.providerStatus
        )
    }

    func setMyCities(_ cityIds: [String]) async throws {
        let _: EmptyResponse = try await client.send(.profile.setCities, body: SetCitiesArgs(pCityIds: cityIds))
    }

    func registerDeviceToken(_ token: String) async throws {
        let _: EmptyResponse = try await client.send(
            .notifications.registerDeviceToken,
            body: RegisterTokenArgs(pToken: token, pPlatform: "ios")
        )
    }
}

struct SupabaseContentRepository: ContentRepository {
    let client: APIClient

    func fetchCities() async throws -> [City] {
        try await client.send(.catalog.cities, body: EmptyArgs())
    }

    func fetchStrings(language: String) async throws -> [String: String] {
        let rows: [StringRowDTO] = try await client.send(.configuration.strings, body: StringsArgs(pLang: language))
        return Dictionary(rows.map { ($0.key, $0.value) }, uniquingKeysWith: { _, last in last })
    }
}

// MARK: - Offline / UI-test stand-ins

struct MockProfileRepository: ProfileRepository {
    func fetchMyProfile() async throws -> MyProfile {
        MyProfile(id: "mock-user", displayName: "نورة", phone: "+966500000000", role: .bride,
                  cityIds: ["dammam"], isAnonymous: false, providerStatus: nil)
    }
    func setMyCities(_ cityIds: [String]) async throws {}
    func registerDeviceToken(_ token: String) async throws {}
}

struct MockContentRepository: ContentRepository {
    func fetchCities() async throws -> [City] {
        [City(id: "dammam", nameAr: "الدمام", nameEn: "Dammam"),
         City(id: "khobar", nameAr: "الخبر", nameEn: "Khobar"),
         City(id: "qatif", nameAr: "القطيف", nameEn: "Qatif")]
    }
    func fetchStrings(language: String) async throws -> [String: String] { [:] }
}

// MARK: - Wire shapes (snake_case decoded by the client)

private struct EmptyArgs: Encodable, Sendable {}

private struct ProfileDTO: Decodable, Sendable {
    let id: String
    let displayName: String?
    let phone: String?
    let role: String?
    let cityIds: [String]?
    let isAnonymous: Bool?
    let providerStatus: String?
}

private struct SetCitiesArgs: Encodable, Sendable {
    let pCityIds: [String]
}

private struct RegisterTokenArgs: Encodable, Sendable {
    let pToken: String
    let pPlatform: String
}

private struct StringsArgs: Encodable, Sendable {
    let pLang: String
}

private struct StringRowDTO: Decodable, Sendable {
    let key: String
    let value: String
}
