import Foundation

/// A plan from `subscription_plans` (Normal / Plus / Diamond, dashboard-editable).
public struct SubscriptionPlan: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let nameAr: String
    public let nameEn: String
    public let descriptionAr: String?
    public let descriptionEn: String?
    public let featuresAr: [String]
    public let featuresEn: [String]
    public let priceSar: Decimal
    public let periodMonths: Int
    public let maxServices: Int
    public let maxStores: Int
    public let maxPhotos: Int
    public let isFeatured: Bool
    public let insightsLevel: String
    public let rank: Int
    public let isRecommended: Bool

    public var name: String { studioLocalized(ar: nameAr, en: nameEn) }
    public var details: String? { studioLocalized(ar: descriptionAr ?? "", en: descriptionEn ?? "").nilIfBlank }
    public var features: [String] { isEnglish ? featuresEn : featuresAr }
}

/// What the provider is entitled to now. The app reads this, never how it was paid (decision #2).
public struct Entitlement: Sendable, Decodable, Equatable {
    public enum State: String, Sendable, Decodable {
        case pending, trial, subscribed, expired
    }

    public let state: State
    public let planId: String?
    public let source: String?
    public let trialEndsAt: Date?
    public let periodEndsAt: Date?
    /// End of everything already paid for, including a plan queued after the current one.
    public let paidUntil: Date?
    public let nextPlanId: String?
    public let nextStartsAt: Date?
    public let isListed: Bool

    /// When the listing stops unless the provider pays: the trial end, or the paid time's end.
    public var listedUntil: Date? {
        switch state {
        case .trial: paidUntil ?? trialEndsAt
        case .subscribed: paidUntil ?? periodEndsAt
        case .pending, .expired: nil
        }
    }

    public func daysLeft(now: Date = .now) -> Int? {
        guard let end = listedUntil else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: now, to: end).day ?? 0)
    }
}

public struct PlanLimits: Sendable, Decodable, Equatable {
    public let planId: String?
    public let maxServices: Int
    public let maxStores: Int
    public let maxPhotos: Int?
}

public struct PlanPayment: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let planId: String
    public let amount: Decimal
    public let currency: String
    public let status: PlanPaymentStatus
    public let createdAt: Date
    public let capturedAt: Date?
}

public enum PlanPaymentStatus: String, Sendable, Decodable {
    case initiated, captured, failed, review
}

/// `get_my_subscription`: state, limits, usage, the plans to choose from and recent payments.
public struct SubscriptionOverview: Sendable, Decodable {
    public struct Usage: Sendable, Decodable, Equatable {
        public let activeServices: Int
        public let activeStores: Int
    }

    public let entitlement: Entitlement
    public let limits: PlanLimits
    public let usage: Usage
    public let plans: [SubscriptionPlan]
    public let payments: [PlanPayment]

    public var currentPlan: SubscriptionPlan? { plans.first { $0.id == entitlement.planId } }
    public var nextPlan: SubscriptionPlan? { plans.first { $0.id == entitlement.nextPlanId } }
    public func plan(_ id: String) -> SubscriptionPlan? { plans.first { $0.id == id } }
}

/// `get_my_insights`. Basic plans get the first four numbers; the rest are nil.
public struct Insights: Sendable, Decodable {
    public struct ServiceRow: Identifiable, Hashable, Sendable, Decodable {
        public let id: String
        public let title: String
        public let views: Int
        public let requests: Int
    }

    public let level: String
    public let days: Int
    public let profileViews: Int
    public let serviceViews: Int
    public let requests: Int
    public let contactTaps: Int?
    public let favorites: Int?
    public let approved: Int?
    public let completed: Int?
    public let revenue: Decimal?
    public let services: [ServiceRow]?

    public var isFull: Bool { level != "basic" }
}

/// Starting a plan payment.
public enum CheckoutStart: Sendable, Equatable {
    /// Open Tap's hosted page; it returns to `munyati://pay-return`.
    case open(paymentId: String, url: URL)
    /// Nothing to open (offline mock): check the status right away.
    case completed(paymentId: String)
    /// Refused by the server, e.g. "not_approved", "too_many_attempts".
    case refused(String)
}

/// Plan payments, implemented by the App (Tap edge functions, or a mock).
public protocol PlanCheckout: Sendable {
    func start(planId: String) async throws -> CheckoutStart
    func status(paymentId: String) async throws -> PlanPaymentStatus
}

var isEnglish: Bool { Locale.current.language.languageCode?.identifier == "en" }

func studioLocalized(ar: String, en: String) -> String {
    isEnglish ? (en.isEmpty ? ar : en) : (ar.isEmpty ? en : ar)
}
