import Foundation

// Wire models decode straight from the RPC JSON (the API client converts snake_case keys), so
// there is no separate DTO layer for these read-only shapes.

/// Picks the Arabic or English variant for the current language.
func localized(ar: String, en: String, locale: Locale = .current) -> String {
    locale.language.languageCode?.identifier == "en" ? en : ar
}

/// A city the app serves (dashboard-managed).
public struct City: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let nameAr: String
    public let nameEn: String
    public let lat: Double?
    public let lng: Double?

    public init(id: String, nameAr: String, nameEn: String, lat: Double? = nil, lng: Double? = nil) {
        self.id = id
        self.nameAr = nameAr
        self.nameEn = nameEn
        self.lat = lat
        self.lng = lng
    }

    public func name(locale: Locale = .current) -> String { localized(ar: nameAr, en: nameEn, locale: locale) }
}

/// A service category (dashboard-managed; icons can change without an app release).
public struct CatalogCategory: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let nameAr: String
    public let nameEn: String
    public let iconUrl: URL?
    public let iconSymbol: String?
    public let priceHintAr: String?
    public let priceHintEn: String?
    public let serviceCount: Int?

    public var name: String { localized(ar: nameAr, en: nameEn) }
    public var priceHint: String? {
        localized(ar: priceHintAr ?? "", en: priceHintEn ?? "").nilIfEmpty
    }
}

/// The card shown in every list.
public struct ServiceCard: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let title: String
    public let price: Decimal
    public let imageUrl: URL?
    public let categoryId: String
    public let providerId: String
    public let providerName: String?
    public let providerLogoUrl: URL?
    public let isVerified: Bool
    /// Diamond plan: "featured" badge (Phase 4; absent from older responses).
    public let isFeatured: Bool?
    public let femaleStaffOnly: Bool
    public let isFavorite: Bool
}

public struct ProviderSummary: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let name: String?
    public let logoUrl: URL?
    public let isVerified: Bool
    public let femaleStaffOnly: Bool
    public let cityIds: [String]
}

public struct StoreSummary: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let name: String
    public let logoUrl: URL?
    public let address: String?
    public let cityId: String?
    public let lat: Double?
    public let lng: Double?
}

public struct ServiceDetail: Sendable, Decodable {
    public let card: ServiceCard
    public let description: String?
    public let durationMinutes: Int?
    public let atCustomerLocation: Bool
    public let imageUrls: [URL]
    public let provider: ProviderSummary
    public let store: StoreSummary?
    public let moreFromProvider: [ServiceCard]

    private enum CodingKeys: String, CodingKey {
        case description, durationMinutes, atCustomerLocation, imageUrls, provider, store, moreFromProvider
    }

    public init(from decoder: Decoder) throws {
        card = try ServiceCard(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
        atCustomerLocation = try c.decodeIfPresent(Bool.self, forKey: .atCustomerLocation) ?? false
        imageUrls = try c.decodeIfPresent([URL].self, forKey: .imageUrls) ?? []
        provider = try c.decode(ProviderSummary.self, forKey: .provider)
        store = try c.decodeIfPresent(StoreSummary.self, forKey: .store)
        moreFromProvider = try c.decodeIfPresent([ServiceCard].self, forKey: .moreFromProvider) ?? []
    }
}

public struct ProviderProfile: Sendable, Decodable {
    public let summary: ProviderSummary
    public let bio: String?
    public let coverUrl: URL?
    public let address: String?
    public let instagram: String?
    public let services: [ServiceCard]
    public let stores: [StoreSummary]

    private enum CodingKeys: String, CodingKey { case bio, coverUrl, address, instagram, services, stores }

    public init(from decoder: Decoder) throws {
        summary = try ProviderSummary(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bio = try c.decodeIfPresent(String.self, forKey: .bio)
        coverUrl = try c.decodeIfPresent(URL.self, forKey: .coverUrl)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        instagram = try c.decodeIfPresent(String.self, forKey: .instagram)
        services = try c.decodeIfPresent([ServiceCard].self, forKey: .services) ?? []
        stores = try c.decodeIfPresent([StoreSummary].self, forKey: .stores) ?? []
    }
}

public struct StoreDetail: Sendable, Decodable {
    public let summary: StoreSummary
    public let description: String?
    public let instagram: String?
    public let provider: ProviderSummary
    public let services: [ServiceCard]

    private enum CodingKeys: String, CodingKey { case description, instagram, provider, services }

    public init(from decoder: Decoder) throws {
        summary = try StoreSummary(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        instagram = try c.decodeIfPresent(String.self, forKey: .instagram)
        provider = try c.decode(ProviderSummary.self, forKey: .provider)
        services = try c.decodeIfPresent([ServiceCard].self, forKey: .services) ?? []
    }
}

public struct HomeContent: Sendable, Decodable {
    public let categories: [CatalogCategory]
    public let featured: [ServiceCard]
    public let newest: [ServiceCard]
}

public struct MapPin: Identifiable, Hashable, Sendable, Decodable {
    public let kind: String          // "provider" | "store"
    public let id: String
    public let name: String?
    public let lat: Double
    public let lng: Double
    public let logoUrl: URL?
}

/// The bride's wedding budget (requirement 13). `reserved` is the sum of approved bookings.
public struct Budget: Equatable, Sendable, Decodable {
    public let total: Decimal
    public let reserved: Decimal
    public let remaining: Decimal
    public let weddingDate: String?

    public init(total: Decimal, reserved: Decimal, remaining: Decimal, weddingDate: String?) {
        self.total = total
        self.reserved = reserved
        self.remaining = remaining
        self.weddingDate = weddingDate
    }

    /// 0…1, how much of the budget is reserved.
    public var usedFraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, NSDecimalNumber(decimal: reserved / total).doubleValue))
    }
}

/// What a services list shows: a category, a free-text search, or both.
public struct ServiceFilter: Hashable, Sendable {
    public var categoryId: String?
    public var title: String?
    public var query: String
    public var withinBudget: Bool
    public var femaleOnly: Bool
    public var sort: Sort

    public enum Sort: String, Hashable, Sendable, CaseIterable {
        case recommended, priceAsc = "price_asc", priceDesc = "price_desc", newest
    }

    public init(categoryId: String? = nil, title: String? = nil, query: String = "",
                withinBudget: Bool = false, femaleOnly: Bool = false, sort: Sort = .recommended) {
        self.categoryId = categoryId
        self.title = title
        self.query = query
        self.withinBudget = withinBudget
        self.femaleOnly = femaleOnly
        self.sort = sort
    }
}

/// Destinations inside the catalog. The App registers `CatalogFeature.destination(for:)` for
/// this type on each tab's NavigationStack and appends routes for deep links.
public enum CatalogRoute: Hashable, Sendable {
    case services(ServiceFilter)
    case service(id: String)
    case provider(id: String)
    case store(id: String)
    case favorites
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// "٢٬٨٠٠ ر.س" / "SAR 2,800".
public func formatSAR(_ amount: Decimal, locale: Locale = .current) -> String {
    let number = amount.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    return String(format: CatalogL10n.string("price.sar"), number)
}
