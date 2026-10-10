import Foundation

/// The provider's own business as returned by `get_my_business` (all statuses, incl. paused).
public struct MyBusiness: Sendable, Decodable {
    public enum Status: String, Sendable, Decodable {
        case pending, approved, rejected, suspended
    }

    public struct Limits: Sendable, Decodable, Equatable {
        public let maxServices: Int
        public let maxStores: Int
        /// Photos per service on the current plan (Phase 4).
        public let maxPhotos: Int?
    }

    public let id: String
    public let status: Status
    public let businessName: String?
    public let bio: String?
    public let logoUrl: URL?
    public let coverUrl: URL?
    public let address: String?
    public let cityId: String?
    public let lat: Double?
    public let lng: Double?
    public let instagram: String?
    public let crNumber: String?
    public let freelanceDocNumber: String?
    public let isVerified: Bool
    public let femaleStaffOnly: Bool
    public let trialEndsAt: String?
    public let reviewNote: String?
    public let categoryIds: [String]
    public let cityIds: [String]
    public let limits: Limits
    public let services: [MyService]
    public let stores: [MyStore]

    var activeServiceCount: Int { services.filter { $0.status == .active }.count }

    /// Profile essentials an admin needs before approving (and brides need to find them).
    var setupSteps: [SetupStep] {
        [SetupStep(key: "studio.step.profile", done: !(businessName ?? "").isEmpty && logoUrl != nil),
         SetupStep(key: "studio.step.coverage", done: !categoryIds.isEmpty && !cityIds.isEmpty),
         SetupStep(key: "studio.step.location", done: lat != nil && lng != nil),
         SetupStep(key: "studio.step.service", done: !services.isEmpty)]
    }
}

struct SetupStep: Hashable, Sendable {
    let key: String
    let done: Bool
}

public struct MyService: Identifiable, Hashable, Sendable, Decodable {
    public enum Status: String, Sendable, Codable, Hashable {
        case active, paused
    }

    public let id: String
    public let title: String
    public let description: String?
    public let categoryId: String
    public let price: Decimal
    public let durationMinutes: Int?
    public let femaleStaffOnly: Bool
    public let atCustomerLocation: Bool
    public let storeId: String?
    public let imageUrls: [URL]
    public let status: Status
}

public struct MyStore: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let name: String
    public let description: String?
    public let logoUrl: URL?
    public let address: String?
    public let cityId: String?
    public let lat: Double?
    public let lng: Double?
    public let instagram: String?
    public let isActive: Bool
}

/// Editable copies used by the forms.
public struct BusinessDraft: Sendable, Equatable {
    public var businessName = ""
    public var bio = ""
    public var categoryIds: Set<String> = []
    public var cityIds: Set<String> = []
    public var address = ""
    public var cityId: String?
    public var lat: Double?
    public var lng: Double?
    public var instagram = ""
    public var logoUrl: URL?
    public var coverUrl: URL?
    public var crNumber = ""
    public var freelanceDocNumber = ""
    public var femaleStaffOnly = false

    public init() {}

    init(_ business: MyBusiness) {
        businessName = business.businessName ?? ""
        bio = business.bio ?? ""
        categoryIds = Set(business.categoryIds)
        cityIds = Set(business.cityIds)
        address = business.address ?? ""
        cityId = business.cityId
        lat = business.lat
        lng = business.lng
        instagram = business.instagram ?? ""
        logoUrl = business.logoUrl
        coverUrl = business.coverUrl
        crNumber = business.crNumber ?? ""
        freelanceDocNumber = business.freelanceDocNumber ?? ""
        femaleStaffOnly = business.femaleStaffOnly
    }

    var isValid: Bool { businessName.trimmingCharacters(in: .whitespaces).count >= 2 }
}

public struct ServiceDraft: Sendable, Equatable {
    public var id: String?
    public var title = ""
    public var description = ""
    public var categoryId: String?
    public var priceText = ""
    public var durationMinutes: Int?
    public var femaleStaffOnly = false
    public var atCustomerLocation = false
    public var storeId: String?
    public var imageUrls: [URL] = []
    public var isActive = true

    public init() {}

    init(_ service: MyService) {
        id = service.id
        title = service.title
        description = service.description ?? ""
        categoryId = service.categoryId
        priceText = "\(service.price)"
        durationMinutes = service.durationMinutes
        femaleStaffOnly = service.femaleStaffOnly
        atCustomerLocation = service.atCustomerLocation
        storeId = service.storeId
        imageUrls = service.imageUrls
        isActive = service.status == .active
    }

    /// The price typed in Arabic or Latin digits.
    var price: Decimal? {
        let ascii = String(priceText.map { ch in ch.wholeNumberValue.map { Character(String($0)) } ?? ch })
            .replacingOccurrences(of: "٫", with: ".")
            .filter { $0.isNumber || $0 == "." }
        return ascii.isEmpty ? nil : Decimal(string: ascii)
    }

    var isValid: Bool {
        title.trimmingCharacters(in: .whitespaces).count >= 2 && categoryId != nil && price != nil
    }
}

public struct StoreDraft: Sendable, Equatable {
    public var id: String?
    public var name = ""
    public var description = ""
    public var address = ""
    public var cityId: String?
    public var lat: Double?
    public var lng: Double?
    public var instagram = ""
    public var logoUrl: URL?
    public var isActive = true

    public init() {}

    init(_ store: MyStore) {
        id = store.id
        name = store.name
        description = store.description ?? ""
        address = store.address ?? ""
        cityId = store.cityId
        lat = store.lat
        lng = store.lng
        instagram = store.instagram ?? ""
        logoUrl = store.logoUrl
        isActive = store.isActive
    }

    var isValid: Bool { name.trimmingCharacters(in: .whitespaces).count >= 2 }
}

/// Result of saving a service or store: the plan limit can refuse it (requirement 2).
public enum SaveResult: Sendable, Equatable {
    case saved(id: String)
    case limitReached(max: Int)
}
