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

    @Test("a banner without a title is image-only; with a title it is a card")
    func bannerTitleIsOptional() throws {
        let json = """
        [{"id":"b1","title_ar":"","title_en":"","subtitle_ar":null,"subtitle_en":null,"cta_ar":null,"cta_en":null,
          "image_url":"https://x.co/b.jpg","link_url":"https://munyati.co/c/makeup"},
         {"id":"b2","title_ar":null,"title_en":null,"image_url":"https://x.co/c.jpg"},
         {"id":"b3","title_ar":"عرض","title_en":"Offer","image_url":"https://x.co/d.jpg"}]
        """
        let banners = try decoder.decode([HomeBanner].self, from: Data(json.utf8))
        #expect(banners.map(\.isImageOnly) == [true, true, false])
        #expect(banners[0].title == nil)
        #expect(banners[2].title != nil)
    }

    @Test("get_service returning null decodes to nil")
    func decodesNull() throws {
        let detail = try decoder.decode(ServiceDetail?.self, from: Data("null".utf8))
        #expect(detail == nil)
    }

    @Test("a preparation decodes as get_my_preparations returns it")
    func decodesPreparation() throws {
        let json = #"[{"id":"a1","title":"قياس الفستان","note":null,"is_done":true,"created_at":"2026-10-28T10:00:00+03:00"}]"#
        let items = try decoder.decode([Preparation].self, from: Data(json.utf8))
        #expect(items == [Preparation(id: "a1", title: "قياس الفستان", note: nil, isDone: true)])
    }

    @Test("preparations: add, tick (done ones move below), edit the note and delete")
    @MainActor
    func preparationsFlow() async throws {
        let store = PreparationsStore(repository: MockCatalogRepository())
        await store.load(isGuest: false)
        #expect(store.hasLoaded && store.items.isEmpty)
        try await store.save(id: nil, title: "الفستان", note: nil)
        try await store.save(id: nil, title: "الدعوات", note: "  ")
        #expect(store.items.map(\.title) == ["الفستان", "الدعوات"])
        #expect(store.items[1].note == nil)

        try await store.toggle(store.items[0])
        #expect(store.open.map(\.title) == ["الدعوات"])
        #expect(store.done.map(\.title) == ["الفستان"])

        let invitations = store.open[0]
        try await store.save(id: invitations.id, title: "الدعوات", note: "٢٠٠ دعوة")
        #expect(store.open[0].note == "٢٠٠ دعوة")

        try await store.delete(store.done[0])
        #expect(store.items.count == 1)

        await store.load(isGuest: true)
        #expect(!store.hasLoaded && store.items.isEmpty)
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
