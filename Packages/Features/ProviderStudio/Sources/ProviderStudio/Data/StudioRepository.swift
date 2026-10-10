import Foundation
import Core
import Networking
import Catalog

public protocol StudioRepository: Sendable {
    func business() async throws -> MyBusiness
    func updateBusiness(_ draft: BusinessDraft) async throws
    func saveService(_ draft: ServiceDraft) async throws -> SaveResult
    func deleteService(id: String) async throws
    func saveStore(_ draft: StoreDraft) async throws -> SaveResult
    func deleteStore(id: String) async throws
    func categories() async throws -> [CatalogCategory]
    func cities() async throws -> [City]
    // Phase 4: plans and insights
    func subscription() async throws -> SubscriptionOverview
    func insights(days: Int) async throws -> Insights
}

/// Supabase RPCs from `supabase/migrations/20261011000000_catalog.sql`.
public struct RemoteStudioRepository: StudioRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func business() async throws -> MyBusiness {
        try await client.send(.rpc("get_my_business"), body: NoArgs())
    }

    public func updateBusiness(_ d: BusinessDraft) async throws {
        let _: OkResult = try await client.send(.rpc("update_my_business"), body: BusinessArgs(
            pBusinessName: d.businessName, pBio: d.bio.nilIfBlank, pCategoryIds: Array(d.categoryIds),
            pCityIds: Array(d.cityIds), pAddress: d.address.nilIfBlank, pCityId: d.cityId, pLat: d.lat, pLng: d.lng,
            pInstagram: d.instagram.nilIfBlank, pLogoUrl: d.logoUrl?.absoluteString, pCoverUrl: d.coverUrl?.absoluteString,
            pCrNumber: d.crNumber.nilIfBlank, pFreelanceDocNumber: d.freelanceDocNumber.nilIfBlank,
            pFemaleStaffOnly: d.femaleStaffOnly
        ))
    }

    public func saveService(_ d: ServiceDraft) async throws -> SaveResult {
        let result: SaveDTO = try await client.send(.rpc("upsert_my_service"), body: ServiceArgs(
            pId: d.id, pTitle: d.title, pCategoryId: d.categoryId ?? "", pPrice: d.price ?? 0,
            pDescription: d.description.nilIfBlank, pDurationMinutes: d.durationMinutes,
            pFemaleStaffOnly: d.femaleStaffOnly, pAtCustomerLocation: d.atCustomerLocation, pStoreId: d.storeId,
            pImageUrls: d.imageUrls.map(\.absoluteString), pStatus: d.isActive ? "active" : "paused"
        ))
        return result.toDomain(maxKey: result.maxServices)
    }

    public func deleteService(id: String) async throws {
        let _: OkResult = try await client.send(.rpc("delete_my_service"), body: IdArgs(pId: id))
    }

    public func saveStore(_ d: StoreDraft) async throws -> SaveResult {
        let result: SaveDTO = try await client.send(.rpc("upsert_my_store"), body: StoreArgs(
            pId: d.id, pName: d.name, pDescription: d.description.nilIfBlank, pAddress: d.address.nilIfBlank,
            pCityId: d.cityId, pLat: d.lat, pLng: d.lng, pInstagram: d.instagram.nilIfBlank,
            pLogoUrl: d.logoUrl?.absoluteString, pIsActive: d.isActive
        ))
        return result.toDomain(maxKey: result.maxStores)
    }

    public func deleteStore(id: String) async throws {
        let _: OkResult = try await client.send(.rpc("delete_my_store"), body: IdArgs(pId: id))
    }

    public func categories() async throws -> [CatalogCategory] {
        try await client.send(.catalog.categories, body: NoArgs())
    }

    public func cities() async throws -> [City] {
        try await client.send(.catalog.cities, body: NoArgs())
    }

    public func subscription() async throws -> SubscriptionOverview {
        try await client.send(.rpc("get_my_subscription"), body: NoArgs())
    }

    public func insights(days: Int) async throws -> Insights {
        try await client.send(.rpc("get_my_insights"), body: DaysArgs(pDays: days))
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct NoArgs: Encodable, Sendable {}
private struct IdArgs: Encodable, Sendable { let pId: String }
private struct DaysArgs: Encodable, Sendable { let pDays: Int }
private struct OkResult: Decodable, Sendable { let ok: Bool? }

private struct SaveDTO: Decodable, Sendable {
    let ok: Bool
    let id: String?
    let error: String?
    let maxServices: Int?
    let maxStores: Int?

    func toDomain(maxKey: Int?) -> SaveResult {
        if ok, let id { return .saved(id: id) }
        return .limitReached(max: maxKey ?? 0)
    }
}

private struct BusinessArgs: Encodable, Sendable {
    let pBusinessName: String
    let pBio: String?
    let pCategoryIds: [String]
    let pCityIds: [String]
    let pAddress: String?
    let pCityId: String?
    let pLat: Double?
    let pLng: Double?
    let pInstagram: String?
    let pLogoUrl: String?
    let pCoverUrl: String?
    let pCrNumber: String?
    let pFreelanceDocNumber: String?
    let pFemaleStaffOnly: Bool
}

private struct ServiceArgs: Encodable, Sendable {
    let pId: String?
    let pTitle: String
    let pCategoryId: String
    let pPrice: Decimal
    let pDescription: String?
    let pDurationMinutes: Int?
    let pFemaleStaffOnly: Bool
    let pAtCustomerLocation: Bool
    let pStoreId: String?
    let pImageUrls: [String]
    let pStatus: String

    // p_id must be sent even when nil (it has no default in SQL), so encode it explicitly.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pId, forKey: .pId)
        try c.encode(pTitle, forKey: .pTitle)
        try c.encode(pCategoryId, forKey: .pCategoryId)
        try c.encode(pPrice, forKey: .pPrice)
        try c.encodeIfPresent(pDescription, forKey: .pDescription)
        try c.encodeIfPresent(pDurationMinutes, forKey: .pDurationMinutes)
        try c.encode(pFemaleStaffOnly, forKey: .pFemaleStaffOnly)
        try c.encode(pAtCustomerLocation, forKey: .pAtCustomerLocation)
        try c.encodeIfPresent(pStoreId, forKey: .pStoreId)
        try c.encode(pImageUrls, forKey: .pImageUrls)
        try c.encode(pStatus, forKey: .pStatus)
    }

    private enum CodingKeys: String, CodingKey {
        case pId, pTitle, pCategoryId, pPrice, pDescription, pDurationMinutes, pFemaleStaffOnly,
             pAtCustomerLocation, pStoreId, pImageUrls, pStatus
    }
}

private struct StoreArgs: Encodable, Sendable {
    let pId: String?
    let pName: String
    let pDescription: String?
    let pAddress: String?
    let pCityId: String?
    let pLat: Double?
    let pLng: Double?
    let pInstagram: String?
    let pLogoUrl: String?
    let pIsActive: Bool

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pId, forKey: .pId)
        try c.encode(pName, forKey: .pName)
        try c.encodeIfPresent(pDescription, forKey: .pDescription)
        try c.encodeIfPresent(pAddress, forKey: .pAddress)
        try c.encodeIfPresent(pCityId, forKey: .pCityId)
        try c.encodeIfPresent(pLat, forKey: .pLat)
        try c.encodeIfPresent(pLng, forKey: .pLng)
        try c.encodeIfPresent(pInstagram, forKey: .pInstagram)
        try c.encodeIfPresent(pLogoUrl, forKey: .pLogoUrl)
        try c.encode(pIsActive, forKey: .pIsActive)
    }

    private enum CodingKeys: String, CodingKey {
        case pId, pName, pDescription, pAddress, pCityId, pLat, pLng, pInstagram, pLogoUrl, pIsActive
    }
}
