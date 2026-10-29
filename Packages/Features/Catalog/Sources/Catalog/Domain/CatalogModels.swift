import Foundation
import Shared

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
    /// Listed by the admin (the dresses for rent), not by providers: opens `CatalogRoute.dresses`.
    public let adminListings: Bool?

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
    /// Approved bride reviews (Phase 5; absent from older responses).
    public let ratingAvg: Decimal?
    public let ratingCount: Int?
    public let femaleStaffOnly: Bool
    public let isFavorite: Bool
    /// "weekly", "dates" or "request" (the bride picks any time; the provider accepts or declines).
    public let bookingMode: String?

    /// The provider takes requests for any date and time («حسب الطلب»).
    public var isOnRequest: Bool { bookingMode == "request" }
}

public struct ProviderSummary: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let name: String?
    public let logoUrl: URL?
    public let isVerified: Bool
    public let femaleStaffOnly: Bool
    public let cityIds: [String]
    public let ratingAvg: Decimal?
    public let ratingCount: Int?
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
    public let videos: [VideoAsset]
    public let provider: ProviderSummary
    public let store: StoreSummary?
    public let moreFromProvider: [ServiceCard]
    /// The viewer's own service: she is its provider, or her bride account shares the provider's
    /// phone number. It can't be booked (the server refuses it too).
    public let isOwn: Bool

    private enum CodingKeys: String, CodingKey {
        case description, durationMinutes, atCustomerLocation, imageUrls, videos, provider, store, moreFromProvider, isOwn
    }

    public init(from decoder: Decoder) throws {
        card = try ServiceCard(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
        atCustomerLocation = try c.decodeIfPresent(Bool.self, forKey: .atCustomerLocation) ?? false
        imageUrls = try c.decodeIfPresent([URL].self, forKey: .imageUrls) ?? []
        videos = try c.decodeIfPresent([VideoAsset].self, forKey: .videos) ?? []
        provider = try c.decode(ProviderSummary.self, forKey: .provider)
        store = try c.decodeIfPresent(StoreSummary.self, forKey: .store)
        moreFromProvider = try c.decodeIfPresent([ServiceCard].self, forKey: .moreFromProvider) ?? []
        isOwn = try c.decodeIfPresent(Bool.self, forKey: .isOwn) ?? false
    }

    /// The page's gallery: photos (or the card photo when there are none), then videos.
    public var galleryItems: [GalleryItem] {
        GalleryItem.items(images: imageUrls.isEmpty ? [card.imageUrl].compactMap { $0 } : imageUrls, videos: videos)
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
    /// Dashboard-managed carousel slides (absent from older responses).
    public let banners: [HomeBanner]
    public let categories: [CatalogCategory]
    public let featured: [ServiceCard]
    public let newest: [ServiceCard]

    private enum CodingKeys: String, CodingKey { case banners, categories, featured, newest }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        banners = try c.decodeIfPresent([HomeBanner].self, forKey: .banners) ?? []
        categories = try c.decode([CatalogCategory].self, forKey: .categories)
        featured = try c.decode([ServiceCard].self, forKey: .featured)
        newest = try c.decode([ServiceCard].self, forKey: .newest)
    }
}

/// A Home carousel slide from the dashboard (`home_banners`). `linkUrl` is an app link
/// (https://munyati.co/<p|s|store|c>/<id>) or an outside page.
public struct HomeBanner: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    /// Optional: a banner without a title is a designed image shown on its own.
    public let titleAr: String?
    public let titleEn: String?
    public let subtitleAr: String?
    public let subtitleEn: String?
    public let ctaAr: String?
    public let ctaEn: String?
    public let imageUrl: URL?
    public let linkUrl: URL?

    public var title: String? { localized(ar: titleAr ?? "", en: titleEn ?? "").nilIfEmpty }
    public var subtitle: String? { localized(ar: subtitleAr ?? "", en: subtitleEn ?? "").nilIfEmpty }
    public var cta: String? { localized(ar: ctaAr ?? "", en: ctaEn ?? "").nilIfEmpty }
    /// No title but an image: the slide is the image alone, with no fade or text over it.
    public var isImageOnly: Bool { title == nil && imageUrl != nil }
}

public struct MapPin: Identifiable, Hashable, Sendable, Decodable {
    public let kind: String          // "provider" | "store"
    public let id: String
    public let name: String?
    public let lat: Double
    public let lng: Double
    public let logoUrl: URL?
}

/// A dress for rent in «فساتين», listed by the admin: a photo, the price and the owner's number.
public struct DressListing: Identifiable, Hashable, Sendable, Decodable {
    public enum Kind: String, CaseIterable, Sendable, Decodable { case wedding, jalwa, evening }

    public let id: String
    public let kind: Kind
    public let imageUrl: URL
    public let price: Decimal
    /// +9665XXXXXXXX.
    public let contactPhone: String
    /// The last day it is listed, "yyyy-MM-dd".
    public let endsOn: String?

    /// wa.me wants the number without "+".
    public var whatsAppURL: URL? { URL(string: "https://wa.me/\(contactPhone.filter(\.isNumber))") }
    public var callURL: URL? { URL(string: "tel:\(contactPhone)") }
}

/// The notice for dress owners: list a dress for `price` riyals for `days` days by contacting `phone`.
public struct DressNotice: Hashable, Sendable, Decodable {
    public let price: Decimal?
    public let days: Int?
    public let phone: String?

    public var whatsAppURL: URL? { phone.flatMap { URL(string: "https://wa.me/\($0.filter(\.isNumber))") } }
    public var callURL: URL? { phone.flatMap { URL(string: "tel:\($0)") } }
}

/// One of the three dress lists, with the notice.
public struct DressListingsPage: Sendable, Decodable {
    public let listings: [DressListing]
    public let notice: DressNotice?
}

/// The bride's details (تفاصيل العروس): about her, then the wedding. Every field is optional. Filled
/// once in Profile and shown to the provider of each of her bookings (name and phone only once
/// the payment is confirmed). `weddingDate` ("yyyy-MM-dd") is the same date the budget stores.
public struct BrideDetails: Equatable, Sendable, Decodable {
    public var fullName: String?
    public var age: Int?
    public var nationality: String?
    /// The number she signed in with (+9665XXXXXXXX), from the server; she can't change it.
    public var phone: String?
    /// One more number she may add (+9665XXXXXXXX).
    public var extraPhone: String?
    /// One of `BrideDetails.skinTypes` (and likewise for the other choice fields).
    public var skinType: String?
    public var skinTone: String?
    public var hairType: String?
    public var hairLength: String?
    public var allergies: String?
    public var weddingDate: String?
    public var cityId: String?
    public var cityNameAr: String?
    public var cityNameEn: String?
    public var venue: String?
    public var guestCount: Int?
    public var notes: String?

    /// The values the server accepts for each choice field (labels are localized by the apps).
    public static let skinTypes = ["normal", "dry", "oily", "combination", "sensitive"]
    public static let skinTones = ["light", "medium", "tan", "deep"]
    public static let hairTypes = ["straight", "wavy", "curly"]
    public static let hairLengths = ["short", "medium", "long"]

    public init(fullName: String? = nil, age: Int? = nil, nationality: String? = nil, phone: String? = nil,
                extraPhone: String? = nil, skinType: String? = nil, skinTone: String? = nil, hairType: String? = nil, hairLength: String? = nil,
                allergies: String? = nil, weddingDate: String? = nil, cityId: String? = nil, cityNameAr: String? = nil,
                cityNameEn: String? = nil, venue: String? = nil, guestCount: Int? = nil, notes: String? = nil) {
        self.fullName = fullName
        self.age = age
        self.nationality = nationality
        self.phone = phone
        self.extraPhone = extraPhone
        self.skinType = skinType
        self.skinTone = skinTone
        self.hairType = hairType
        self.hairLength = hairLength
        self.allergies = allergies
        self.weddingDate = weddingDate
        self.cityId = cityId
        self.cityNameAr = cityNameAr
        self.cityNameEn = cityNameEn
        self.venue = venue
        self.guestCount = guestCount
        self.notes = notes
    }

    /// True when she has filled anything besides the date.
    public var hasEventDetails: Bool {
        cityId != nil || venue?.isEmpty == false || guestCount != nil || notes?.isEmpty == false
    }
}

/// One item on the bride's "My preparations" checklist (تجهيزاتي), with an optional note.
public struct Preparation: Identifiable, Equatable, Sendable, Decodable {
    public let id: String
    public var title: String
    public var note: String?
    public var isDone: Bool

    public init(id: String, title: String, note: String? = nil, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.note = note
        self.isDone = isDone
    }
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

    /// Whole days from today to the wedding date (0 on the day), nil without a date or after it.
    public func daysUntilWedding(now: Date = .now) -> Int? {
        Self.daysUntil(weddingDate, now: now)
    }

    /// Whole days from today to a "yyyy-MM-dd" day (0 on the day), nil without one or after it.
    public static func daysUntil(_ weddingDate: String?, now: Date = .now) -> Int? {
        guard let weddingDate else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let day = formatter.date(from: weddingDate) else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: day).day ?? -1
        return days >= 0 ? days : nil
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
    /// Only services with a free time that day.
    public var date: Date?

    public enum Sort: String, Hashable, Sendable, CaseIterable {
        case recommended, priceAsc = "price_asc", priceDesc = "price_desc", newest
    }

    public init(categoryId: String? = nil, title: String? = nil, query: String = "",
                withinBudget: Bool = false, femaleOnly: Bool = false, sort: Sort = .recommended, date: Date? = nil) {
        self.categoryId = categoryId
        self.title = title
        self.query = query
        self.withinBudget = withinBudget
        self.femaleOnly = femaleOnly
        self.sort = sort
        self.date = date
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
    case preparations
    case brideDetails
    case dresses
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// "٢٬٨٠٠ ر.س" / "SAR 2,800".
public func formatSAR(_ amount: Decimal, locale: Locale = .current) -> String {
    let number = amount.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    return String(format: CatalogL10n.string("price.sar"), number)
}
