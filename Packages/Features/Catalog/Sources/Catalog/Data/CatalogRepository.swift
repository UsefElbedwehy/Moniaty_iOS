import Foundation
import Core
import Networking

public protocol CatalogRepository: Sendable {
    func home(cityIds: [String]?, maxPrice: Decimal?) async throws -> HomeContent
    func search(_ filter: ServiceFilter, cityIds: [String]?, maxPrice: Decimal?, offset: Int) async throws -> [ServiceCard]
    func service(id: String) async throws -> ServiceDetail?
    func provider(id: String) async throws -> ProviderProfile?
    func store(id: String) async throws -> StoreDetail?
    func mapPins(minLat: Double, minLng: Double, maxLat: Double, maxLng: Double,
                 cityIds: [String]?, categoryId: String?) async throws -> [MapPin]
    func toggleFavorite(serviceId: String) async throws -> Bool
    func favorites() async throws -> [ServiceCard]
    func budget() async throws -> Budget?
    func setBudget(total: Decimal, weddingDate: String?) async throws -> Budget?
}

/// Supabase RPCs from `supabase/migrations/20261011000000_catalog.sql`.
public struct RemoteCatalogRepository: CatalogRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func home(cityIds: [String]?, maxPrice: Decimal?) async throws -> HomeContent {
        try await client.send(.rpc("get_home"), body: HomeArgs(pCityIds: cityIds, pMaxPrice: maxPrice))
    }

    public func search(_ filter: ServiceFilter, cityIds: [String]?, maxPrice: Decimal?, offset: Int) async throws -> [ServiceCard] {
        try await client.send(.rpc("search_services"), body: SearchArgs(
            pQuery: filter.query.isEmpty ? nil : filter.query,
            pCategoryId: filter.categoryId,
            pCityIds: cityIds,
            pMaxPrice: filter.withinBudget ? maxPrice : nil,
            pFemaleOnly: filter.femaleOnly,
            pSort: filter.sort.rawValue,
            pLimit: 30,
            pOffset: offset
        ))
    }

    public func service(id: String) async throws -> ServiceDetail? {
        try await client.send(.rpc("get_service"), body: IdArgs(pId: id))
    }

    public func provider(id: String) async throws -> ProviderProfile? {
        try await client.send(.rpc("get_provider"), body: IdArgs(pId: id))
    }

    public func store(id: String) async throws -> StoreDetail? {
        try await client.send(.rpc("get_store"), body: IdArgs(pId: id))
    }

    public func mapPins(minLat: Double, minLng: Double, maxLat: Double, maxLng: Double,
                        cityIds: [String]?, categoryId: String?) async throws -> [MapPin] {
        try await client.send(.rpc("get_map_pins"), body: MapArgs(
            pMinLat: minLat, pMinLng: minLng, pMaxLat: maxLat, pMaxLng: maxLng,
            pCityIds: cityIds, pCategoryId: categoryId
        ))
    }

    public func toggleFavorite(serviceId: String) async throws -> Bool {
        let result: FavoriteResult = try await client.send(.rpc("toggle_favorite"), body: FavoriteArgs(pServiceId: serviceId))
        return result.isFavorite
    }

    public func favorites() async throws -> [ServiceCard] {
        try await client.send(.rpc("get_my_favorites"), body: NoArgs())
    }

    public func budget() async throws -> Budget? {
        try await client.send(.rpc("get_my_budget"), body: NoArgs())
    }

    public func setBudget(total: Decimal, weddingDate: String?) async throws -> Budget? {
        try await client.send(.rpc("set_my_budget"), body: BudgetArgs(pTotal: total, pWeddingDate: weddingDate))
    }
}

private struct NoArgs: Encodable, Sendable {}
private struct IdArgs: Encodable, Sendable { let pId: String }
private struct HomeArgs: Encodable, Sendable { let pCityIds: [String]?; let pMaxPrice: Decimal? }
private struct SearchArgs: Encodable, Sendable {
    let pQuery: String?
    let pCategoryId: String?
    let pCityIds: [String]?
    let pMaxPrice: Decimal?
    let pFemaleOnly: Bool
    let pSort: String
    let pLimit: Int
    let pOffset: Int
}
private struct MapArgs: Encodable, Sendable {
    let pMinLat: Double, pMinLng: Double, pMaxLat: Double, pMaxLng: Double
    let pCityIds: [String]?
    let pCategoryId: String?
}
private struct FavoriteArgs: Encodable, Sendable { let pServiceId: String }
private struct FavoriteResult: Decodable, Sendable { let isFavorite: Bool }
private struct BudgetArgs: Encodable, Sendable { let pTotal: Decimal; let pWeddingDate: String? }
