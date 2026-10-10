import Testing
import Foundation
@testable import Catalog

@Suite("Catalog models and mock repository")
struct CatalogTests {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    @Test("ServiceDetail decodes the flat card fields plus its extras, as get_service returns them")
    func decodesServiceDetail() throws {
        let json = """
        {"id":"s1","title":"مكياج العروس","price":2800.00,"image_url":null,"category_id":"makeup",
         "provider_id":"p1","provider_name":"لمسة جمال","provider_logo_url":null,"is_verified":true,
         "female_staff_only":true,"is_favorite":false,"description":"شامل الرموش","duration_minutes":180,
         "at_customer_location":true,"image_urls":["https://x.co/1.jpg"],
         "provider":{"id":"p1","name":"لمسة جمال","logo_url":null,"is_verified":true,"female_staff_only":true,"city_ids":["khobar"]},
         "store":null,"more_from_provider":[]}
        """
        let detail = try decoder.decode(ServiceDetail.self, from: Data(json.utf8))
        #expect(detail.card.price == 2800)
        #expect(detail.durationMinutes == 180)
        #expect(detail.provider.cityIds == ["khobar"])
        #expect(detail.store == nil)
    }

    @Test("get_service returning null decodes to nil")
    func decodesNull() throws {
        let detail = try decoder.decode(ServiceDetail?.self, from: Data("null".utf8))
        #expect(detail == nil)
    }

    @Test("budget used fraction is clamped to 0…1")
    func budgetFraction() {
        #expect(Budget(total: 1000, reserved: 250, remaining: 750, weddingDate: nil).usedFraction == 0.25)
        #expect(Budget(total: 0, reserved: 0, remaining: 0, weddingDate: nil).usedFraction == 0)
        #expect(Budget(total: 100, reserved: 300, remaining: -200, weddingDate: nil).usedFraction == 1)
    }

    @Test("mock search honours category, budget and city filters")
    func mockSearch() async throws {
        let repo = MockCatalogRepository()
        let makeup = try await repo.search(ServiceFilter(categoryId: "makeup"), cityIds: nil, maxPrice: nil, offset: 0)
        #expect(makeup.allSatisfy { $0.categoryId == "makeup" })
        let cheap = try await repo.search(ServiceFilter(withinBudget: true), cityIds: nil, maxPrice: 1000, offset: 0)
        #expect(cheap.allSatisfy { $0.price <= 1000 })
        let qatif = try await repo.search(ServiceFilter(), cityIds: ["qatif"], maxPrice: nil, offset: 0)
        #expect(qatif.map(\.providerId) == ["p-henna"])
    }

    @Test("favorites toggle on and off")
    func favorites() async throws {
        let repo = MockCatalogRepository()
        #expect(try await repo.toggleFavorite(serviceId: "s1"))
        #expect(try await repo.favorites().map(\.id) == ["s1"])
        #expect(try await repo.toggleFavorite(serviceId: "s1") == false)
    }
}
