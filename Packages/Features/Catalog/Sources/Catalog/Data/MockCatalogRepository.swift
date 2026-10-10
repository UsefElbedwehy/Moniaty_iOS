import Foundation
import Core

/// Sample catalog for running the app without a backend (and for previews/UI tests).
/// Content is built as JSON and decoded exactly like real RPC responses.
public actor MockCatalogRepository: CatalogRepository {
    private var favoriteIds: Set<String> = []
    private var storedBudget: Budget?

    public init() {}

    nonisolated(unsafe) private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    nonisolated(unsafe) private static let categories: [[String: Any]] = [
        ["id": "makeup", "name_ar": "خبيرة مكياج", "name_en": "Makeup artist", "icon_symbol": "paintbrush.pointed", "price_hint_ar": "٣٥٠ – ٣٬٠٠٠ ر.س", "price_hint_en": "SAR 350 – 3,000"],
        ["id": "photography", "name_ar": "مصوّرات", "name_en": "Female photographers", "icon_symbol": "camera"],
        ["id": "venues", "name_ar": "قصور وقاعات الأفراح", "name_en": "Wedding halls & venues", "icon_symbol": "building.columns"],
        ["id": "henna", "name_ar": "نقش الحناء", "name_en": "Henna artist", "icon_symbol": "hand.raised"],
        ["id": "kosha_decor", "name_ar": "الكوش والتنسيق", "name_en": "Kosha & décor", "icon_symbol": "sparkles.rectangle.stack"],
        ["id": "dresses", "name_ar": "فساتين الزفاف", "name_en": "Wedding dresses", "icon_symbol": "tshirt"],
        ["id": "coffee_servers", "name_ar": "القهوجيات", "name_en": "Coffee servers", "icon_symbol": "cup.and.saucer"],
        ["id": "cakes_sweets", "name_ar": "الكيك والحلويات", "name_en": "Cakes & sweets", "icon_symbol": "birthday.cake"]
    ]

    nonisolated(unsafe) private static let providers: [[String: Any]] = [
        ["id": "p-lamsa", "name": "لمسة جمال", "is_verified": true, "female_staff_only": true, "city_ids": ["dammam", "khobar"], "lat": 26.285, "lng": 50.208],
        ["id": "p-reem", "name": "عدسة ريم", "is_verified": true, "female_staff_only": true, "city_ids": ["khobar"], "lat": 26.30, "lng": 50.19],
        ["id": "p-lulu", "name": "قصر اللؤلؤة", "is_verified": false, "female_staff_only": false, "city_ids": ["dammam"], "lat": 26.43, "lng": 50.10],
        ["id": "p-henna", "name": "حناء نجد", "is_verified": false, "female_staff_only": true, "city_ids": ["qatif"], "lat": 26.52, "lng": 50.01]
    ]

    nonisolated(unsafe) private static let services: [[String: Any]] = [
        ["id": "s1", "title": "مكياج العروس", "price": 2800, "category_id": "makeup", "provider_id": "p-lamsa", "duration_minutes": 180, "at_customer_location": true, "description": "مكياج ناعم يدوم طوال الليلة، شامل الرموش وتثبيت التسريحة."],
        ["id": "s2", "title": "مكياج ليلة الحناء", "price": 1500, "category_id": "makeup", "provider_id": "p-lamsa", "duration_minutes": 120],
        ["id": "s3", "title": "تصوير الزفاف كاملاً", "price": 6500, "category_id": "photography", "provider_id": "p-reem", "duration_minutes": 360],
        ["id": "s4", "title": "جلسة تصوير العروس", "price": 3500, "category_id": "photography", "provider_id": "p-reem", "duration_minutes": 120],
        ["id": "s5", "title": "قاعة كبرى حتى ٤٠٠ ضيفة", "price": 28000, "category_id": "venues", "provider_id": "p-lulu"],
        ["id": "s6", "title": "نقش حناء العروس", "price": 600, "category_id": "henna", "provider_id": "p-henna", "duration_minutes": 90]
    ]

    private func card(_ service: [String: Any]) -> [String: Any] {
        let provider = Self.providers.first { $0["id"] as? String == service["provider_id"] as? String } ?? [:]
        var card = service
        card["provider_name"] = provider["name"]
        card["is_verified"] = provider["is_verified"] ?? false
        card["female_staff_only"] = provider["female_staff_only"] ?? false
        card["is_favorite"] = favoriteIds.contains(service["id"] as? String ?? "")
        card["image_url"] = "https://picsum.photos/seed/\(service["id"] as? String ?? "x")/800/600"
        return card
    }

    private func decode<T: Decodable>(_ object: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try Self.decoder.decode(T.self, from: data)
    }

    private func providerSummary(_ id: String) -> [String: Any] {
        Self.providers.first { $0["id"] as? String == id } ?? ["id": id, "is_verified": false, "female_staff_only": false, "city_ids": []]
    }

    private func matches(_ service: [String: Any], cityIds: [String]?) -> Bool {
        guard let cityIds, !cityIds.isEmpty else { return true }
        let cities = providerSummary(service["provider_id"] as? String ?? "")["city_ids"] as? [String] ?? []
        return !Set(cities).isDisjoint(with: cityIds)
    }

    private func price(_ service: [String: Any]) -> Decimal { Decimal(service["price"] as? Int ?? 0) }

    public func home(cityIds: [String]?, maxPrice: Decimal?) async throws -> HomeContent {
        let visible = Self.services.filter { matches($0, cityIds: cityIds) }
        let categories = Self.categories.map { category -> [String: Any] in
            var c = category
            c["service_count"] = visible.filter { $0["category_id"] as? String == category["id"] as? String }.count
            return c
        }
        let featured = visible.filter { maxPrice == nil || price($0) <= maxPrice! }.map(card)
        return try decode(["categories": categories, "featured": featured, "newest": visible.reversed().map(card)])
    }

    public func search(_ filter: ServiceFilter, cityIds: [String]?, maxPrice: Decimal?, offset: Int) async throws -> [ServiceCard] {
        guard offset == 0 else { return [] }
        var list = Self.services.filter { s in
            matches(s, cityIds: cityIds)
                && (filter.categoryId == nil || s["category_id"] as? String == filter.categoryId)
                && (filter.query.isEmpty || (s["title"] as? String ?? "").contains(filter.query))
                && (!filter.withinBudget || maxPrice == nil || price(s) <= maxPrice!)
        }
        switch filter.sort {
        case .priceAsc: list.sort { price($0) < price($1) }
        case .priceDesc: list.sort { price($0) > price($1) }
        case .newest: list.reverse()
        case .recommended: break
        }
        let cards: [ServiceCard] = try decode(list.map(card))
        return filter.femaleOnly ? cards.filter(\.femaleStaffOnly) : cards
    }

    public func service(id: String) async throws -> ServiceDetail? {
        guard let service = Self.services.first(where: { $0["id"] as? String == id }) else { return nil }
        var detail = card(service)
        let providerId = service["provider_id"] as? String ?? ""
        detail["provider"] = providerSummary(providerId)
        detail["image_urls"] = (1...3).map { "https://picsum.photos/seed/\(id)-\($0)/1200/900" }
        detail["more_from_provider"] = Self.services
            .filter { $0["provider_id"] as? String == providerId && $0["id"] as? String != id }
            .map(card)
        return try decode(detail)
    }

    public func provider(id: String) async throws -> ProviderProfile? {
        var profile = providerSummary(id)
        profile["bio"] = "نسعد بخدمتك في أجمل أيامك."
        profile["services"] = Self.services.filter { $0["provider_id"] as? String == id }.map(card)
        profile["stores"] = [[String: Any]]()
        return try decode(profile)
    }

    public func store(id: String) async throws -> StoreDetail? { nil }

    public func mapPins(minLat: Double, minLng: Double, maxLat: Double, maxLng: Double,
                        cityIds: [String]?, categoryId: String?) async throws -> [MapPin] {
        let pins = Self.providers.map { p -> [String: Any] in
            ["kind": "provider", "id": p["id"]!, "name": p["name"]!, "lat": p["lat"]!, "lng": p["lng"]!]
        }
        return try decode(pins)
    }

    public func toggleFavorite(serviceId: String) async throws -> Bool {
        if favoriteIds.remove(serviceId) == nil { favoriteIds.insert(serviceId) }
        return favoriteIds.contains(serviceId)
    }

    public func favorites() async throws -> [ServiceCard] {
        try decode(Self.services.filter { favoriteIds.contains($0["id"] as? String ?? "") }.map(card))
    }

    public func budget() async throws -> Budget? { storedBudget }

    public func setBudget(total: Decimal, weddingDate: String?) async throws -> Budget? {
        storedBudget = Budget(total: total, reserved: 0, remaining: total, weddingDate: weddingDate)
        return storedBudget
    }
}
