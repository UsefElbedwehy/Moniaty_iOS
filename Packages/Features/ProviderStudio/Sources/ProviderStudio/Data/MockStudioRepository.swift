import Foundation
import Catalog

/// In-memory studio for running without a backend. Starts as a fresh, pending provider; saving
/// the business profile counts as the admin's approval, which starts the 60-day trial.
public actor MockStudioRepository: StudioRepository {
    private var draft = BusinessDraft()
    private var services: [String: ServiceDraft] = [:]
    private var stores: [String: StoreDraft] = [:]
    private var trialEndsAt: Date?
    private var paidPlanId: String?
    private var paidUntil: Date?
    private var payments: [[String: Any]] = []

    private var currentPlan: [String: Any] {
        Self.plans.first { $0["id"] as? String == (paidPlanId ?? "diamond") } ?? Self.plans[2]
    }
    private var maxServices: Int { currentPlan["max_services"] as? Int ?? 10 }
    private var maxStores: Int { currentPlan["max_stores"] as? Int ?? 3 }

    public init() {}

    private static let decoder: JSONDecoder = {
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
            "limits": ["max_services": maxServices, "max_stores": maxStores,
                       "max_photos": currentPlan["max_photos"] as? Int ?? 30] as [String: Any]
        ]
        object["status"] = trialEndsAt == nil ? "pending" : "approved"
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
        if trialEndsAt == nil { trialEndsAt = .now.addingTimeInterval(60 * 86400) }
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

    // MARK: Plans (Phase 4)

    nonisolated(unsafe) private static let iso = ISO8601DateFormatter()

    nonisolated(unsafe) private static let plans: [[String: Any]] = [
        ["id": "normal", "name_ar": "العادية", "name_en": "Normal", "price_sar": 99, "period_months": 1,
         "features_ar": ["خدمة واحدة", "٦ صور لكل خدمة", "ظهور عادي", "إحصائيات أساسية"],
         "features_en": ["1 service", "6 photos per service", "Standard placement", "Basic insights"],
         "max_services": 1, "max_stores": 0, "max_photos": 6, "is_featured": false, "insights_level": "basic",
         "rank": 1, "is_recommended": false],
        ["id": "plus", "name_ar": "بلس", "name_en": "Plus", "price_sar": 249, "period_months": 1,
         "features_ar": ["٣ خدمات", "متجر واحد", "١٥ صورة لكل خدمة", "ظهور مُعزَّز", "إحصائيات كاملة"],
         "features_en": ["3 services", "1 store", "15 photos per service", "Boosted placement", "Full insights"],
         "max_services": 3, "max_stores": 1, "max_photos": 15, "is_featured": false, "insights_level": "full",
         "rank": 2, "is_recommended": true],
        ["id": "diamond", "name_ar": "دايموند", "name_en": "Diamond", "price_sar": 499, "period_months": 1,
         "features_ar": ["١٠ خدمات", "٣ متاجر", "٣٠ صورة لكل خدمة", "أعلى الظهور وشارة مميّزة", "بنر شهري في الرئيسية"],
         "features_en": ["10 services", "3 stores", "30 photos per service", "Top placement and a featured badge", "A monthly Home banner"],
         "max_services": 10, "max_stores": 3, "max_photos": 30, "is_featured": true, "insights_level": "export",
         "rank": 3, "is_recommended": false]
    ]

    private func decodeDated<T: Decodable>(_ object: Any) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }

    public func subscription() async throws -> SubscriptionOverview {
        let now = Date.now
        let subscribed = paidUntil.map { $0 > now } ?? false
        let onTrial = (trialEndsAt ?? .distantPast) > now
        let state = subscribed ? "subscribed" : trialEndsAt == nil ? "pending" : onTrial ? "trial" : "expired"
        var entitlement: [String: Any] = ["state": state, "plan_id": currentPlan["id"] ?? "diamond",
                                          "is_listed": subscribed || onTrial]
        if let trialEndsAt { entitlement["trial_ends_at"] = Self.iso.string(from: trialEndsAt) }
        if subscribed, let paidUntil {
            entitlement["period_ends_at"] = Self.iso.string(from: paidUntil)
            entitlement["paid_until"] = Self.iso.string(from: paidUntil)
            entitlement["source"] = "tap"
        }
        return try decodeDated([
            "entitlement": entitlement,
            "limits": ["plan_id": currentPlan["id"] ?? "diamond", "max_services": maxServices,
                       "max_stores": maxStores, "max_photos": currentPlan["max_photos"] ?? 30] as [String: Any],
            "usage": ["active_services": services.values.filter(\.isActive).count,
                      "active_stores": stores.values.filter(\.isActive).count],
            "plans": Self.plans,
            "payments": payments
        ] as [String: Any])
    }

    public func insights(days: Int) async throws -> Insights {
        let full = (currentPlan["insights_level"] as? String) != "basic"
        var object: [String: Any] = ["level": currentPlan["insights_level"] ?? "basic", "days": days,
                                     "profile_views": 230, "service_views": 412, "requests": 4]
        if full {
            object.merge(["contact_taps": 37, "favorites": 18, "approved": 3, "completed": 2, "revenue": 5600,
                          "services": services.values.map { s -> [String: Any] in
                              ["id": s.id ?? "", "title": s.title, "views": Int.random(in: 20...200), "requests": Int.random(in: 0...3)]
                          }] as [String: Any]) { a, _ in a }
        }
        return try decodeDated(object)
    }

    /// What a captured Tap payment does on the server, simplified: one month of the plan.
    func activate(planId: String) -> String {
        let id = UUID().uuidString
        let start = max(.now, paidUntil ?? .now)
        paidPlanId = planId
        paidUntil = Calendar.current.date(byAdding: .month, value: 1, to: start)
        let price = Self.plans.first { $0["id"] as? String == planId }?["price_sar"] ?? 0
        payments.insert(["id": id, "plan_id": planId, "amount": price, "currency": "SAR", "status": "captured",
                         "created_at": Self.iso.string(from: .now), "captured_at": Self.iso.string(from: .now)] as [String: Any], at: 0)
        // Above the new plan's limit: pause the extra services.
        for key in services.filter({ $0.value.isActive }).keys.sorted().dropFirst(maxServices) {
            services[key]?.isActive = false
        }
        return id
    }
}

/// Offline stand-in for Tap: every payment succeeds immediately.
public struct MockPlanCheckout: PlanCheckout {
    private let repository: MockStudioRepository

    public init(repository: MockStudioRepository) {
        self.repository = repository
    }

    public func start(planId: String) async throws -> CheckoutStart {
        .completed(paymentId: await repository.activate(planId: planId))
    }

    public func status(paymentId: String) async throws -> PlanPaymentStatus { .captured }
}
