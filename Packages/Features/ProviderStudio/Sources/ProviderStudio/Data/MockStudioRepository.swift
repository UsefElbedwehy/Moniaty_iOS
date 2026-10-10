import Foundation
import Catalog

/// In-memory studio for running without a backend. Starts as a fresh, pending provider.
public actor MockStudioRepository: StudioRepository {
    private var draft = BusinessDraft()
    private var services: [String: ServiceDraft] = [:]
    private var stores: [String: StoreDraft] = [:]
    private let maxServices = 10
    private let maxStores = 3

    public init() {}

    nonisolated(unsafe) private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    public func business() async throws -> MyBusiness {
        var object: [String: Any] = [
            "id": "mock-provider",
            "status": "pending",
            "business_name": draft.businessName,
            "bio": draft.bio,
            "address": draft.address,
            "instagram": draft.instagram,
            "cr_number": draft.crNumber,
            "is_verified": false,
            "female_staff_only": draft.femaleStaffOnly,
            "category_ids": Array(draft.categoryIds),
            "city_ids": Array(draft.cityIds),
            "limits": ["max_services": maxServices, "max_stores": maxStores]
        ]
        if let url = draft.logoUrl { object["logo_url"] = url.absoluteString }
        if let cityId = draft.cityId { object["city_id"] = cityId }
        if let lat = draft.lat, let lng = draft.lng { object["lat"] = lat; object["lng"] = lng }

        object["services"] = services.values.map { s -> [String: Any] in
            var row: [String: Any] = [
                "id": s.id ?? "", "title": s.title, "description": s.description, "category_id": s.categoryId ?? "",
                "price": NSDecimalNumber(decimal: s.price ?? 0), "female_staff_only": s.femaleStaffOnly,
                "at_customer_location": s.atCustomerLocation, "image_urls": s.imageUrls.map(\.absoluteString),
                "status": s.isActive ? "active" : "paused"
            ]
            if let minutes = s.durationMinutes { row["duration_minutes"] = minutes }
            if let storeId = s.storeId { row["store_id"] = storeId }
            return row
        }
        object["stores"] = stores.values.map { st -> [String: Any] in
            var row: [String: Any] = [
                "id": st.id ?? "", "name": st.name, "description": st.description, "address": st.address,
                "instagram": st.instagram, "is_active": st.isActive
            ]
            if let cityId = st.cityId { row["city_id"] = cityId }
            if let lat = st.lat, let lng = st.lng { row["lat"] = lat; row["lng"] = lng }
            if let url = st.logoUrl { row["logo_url"] = url.absoluteString }
            return row
        }
        let data = try JSONSerialization.data(withJSONObject: object)
        return try Self.decoder.decode(MyBusiness.self, from: data)
    }

    public func updateBusiness(_ draft: BusinessDraft) async throws {
        self.draft = draft
    }

    public func saveService(_ draft: ServiceDraft) async throws -> SaveResult {
        var d = draft
        let id = d.id ?? UUID().uuidString
        d.id = id
        let active = services.values.filter { $0.isActive && $0.id != id }.count
        if d.isActive, active >= maxServices { return .limitReached(max: maxServices) }
        services[id] = d
        return .saved(id: id)
    }

    public func deleteService(id: String) async throws {
        services[id] = nil
    }

    public func saveStore(_ draft: StoreDraft) async throws -> SaveResult {
        var d = draft
        if d.id == nil, stores.count >= maxStores { return .limitReached(max: maxStores) }
        let id = d.id ?? UUID().uuidString
        d.id = id
        stores[id] = d
        return .saved(id: id)
    }

    public func deleteStore(id: String) async throws {
        stores[id] = nil
    }

    public func categories() async throws -> [CatalogCategory] {
        try await MockCatalogRepository().home(cityIds: nil, maxPrice: nil).categories
    }

    public func cities() async throws -> [City] {
        [City(id: "dammam", nameAr: "الدمام", nameEn: "Dammam"),
         City(id: "khobar", nameAr: "الخبر", nameEn: "Khobar"),
         City(id: "qatif", nameAr: "القطيف", nameEn: "Qatif")]
    }
}
