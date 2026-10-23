import Foundation

/// Mirrors the Postgres `booking_status` enum (supabase/migrations/20261012000000_booking.sql).
public enum BookingStatus: String, Sendable, Decodable, Hashable, CaseIterable {
    case requested
    case rescheduleProposed = "reschedule_proposed"
    case awaitingPayment = "awaiting_payment"
    case paymentSubmitted = "payment_submitted"
    case paymentConfirmed = "payment_confirmed"
    case completed
    case declined
    case cancelledByBride = "cancelled_by_bride"
    case cancelledByProvider = "cancelled_by_provider"
    case expired
    case disputed

    /// Holds a slot (and counts for the one-per-category rule).
    public var isActive: Bool {
        switch self {
        case .requested, .rescheduleProposed, .awaitingPayment, .paymentSubmitted, .paymentConfirmed, .disputed: true
        default: false
        }
    }

    /// Position on the 5-step progress bar (request → approval → payment → confirmation → done).
    var step: Int {
        switch self {
        case .requested, .rescheduleProposed: 1
        case .awaitingPayment: 2
        case .paymentSubmitted: 3
        case .paymentConfirmed, .disputed: 4
        case .completed: 5
        case .declined, .cancelledByBride, .cancelledByProvider, .expired: 0
        }
    }
}

/// Which side of the booking the viewer is on.
public enum BookingRole: String, Sendable {
    case bride, provider
}

public struct BookingProvider: Hashable, Sendable, Decodable {
    public let id: String
    public let name: String?
    public let logoUrl: URL?
    public let isVerified: Bool
}

public struct BookingSummary: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let referenceCode: String
    public let status: BookingStatus
    public let isDemo: Bool
    public let serviceId: String?
    public let serviceTitle: String
    public let categoryId: String?
    public let price: Decimal
    public let startsAt: Date
    public let endsAt: Date
    public let note: String?
    public let paymentDueAt: Date?
    public let statusChangedAt: Date
    public let provider: BookingProvider
    /// Masked for providers until payment is confirmed.
    public let brideName: String?
}

public struct PaymentMethodSnapshot: Hashable, Sendable, Decodable {
    public let kind: String          // iban | sarie_alias | wallet
    public let label: String
    public let accountName: String
    public let value: String
}

public struct BookingProposal: Hashable, Sendable, Decodable {
    public let id: String
    public let startsAt: Date
    public let endsAt: Date
    public let note: String?
    public let expiresAt: Date
}

public struct BookingReceipt: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let storagePath: String?  // nil for the demo booking's sample receipt
    public let amount: Decimal
    public let transferredAt: Date?
    public let senderBank: String?
    public let status: String        // pending | accepted | rejected
    public let rejectReason: String?
    public let createdAt: Date
}

public struct BookingEvent: Hashable, Sendable, Decodable {
    public let toStatus: BookingStatus
    public let actorRole: String
    public let note: String?
    public let createdAt: Date
}

public struct BookingDispute: Hashable, Sendable, Decodable {
    public let reason: String
    public let createdAt: Date
}

public struct BookingDetail: Sendable, Decodable {
    public let summary: BookingSummary
    public let paymentMethods: [PaymentMethodSnapshot]
    public let proposal: BookingProposal?
    public let receipts: [BookingReceipt]
    public let events: [BookingEvent]
    public let openDispute: BookingDispute?

    private enum CodingKeys: String, CodingKey { case paymentMethods, proposal, receipts, events, openDispute }

    public init(from decoder: Decoder) throws {
        summary = try BookingSummary(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        paymentMethods = try c.decodeIfPresent([PaymentMethodSnapshot].self, forKey: .paymentMethods) ?? []
        proposal = try c.decodeIfPresent(BookingProposal.self, forKey: .proposal)
        receipts = try c.decodeIfPresent([BookingReceipt].self, forKey: .receipts) ?? []
        events = try c.decodeIfPresent([BookingEvent].self, forKey: .events) ?? []
        openDispute = try c.decodeIfPresent(BookingDispute.self, forKey: .openDispute)
    }
}

/// A provider's own payment method (managed in the studio).
public struct PaymentMethod: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let kind: String
    public let label: String
    public let accountName: String
    public let value: String
    public let isActive: Bool
}

public struct PaymentMethodDraft: Sendable, Equatable, Identifiable {
    public var id: String?
    public var kind = "iban"
    public var label = ""
    public var accountName = ""
    public var value = ""
    public var isActive = true

    public init() {}

    init(_ method: PaymentMethod) {
        id = method.id
        kind = method.kind
        label = method.label
        accountName = method.accountName
        value = method.value
        isActive = method.isActive
    }

    var isValid: Bool {
        label.trimmingCharacters(in: .whitespaces).count >= 2
            && accountName.trimmingCharacters(in: .whitespaces).count >= 2
            && value.trimmingCharacters(in: .whitespaces).count >= 5
    }
}

/// Weekly working hours and days off.
public struct Availability: Sendable, Decodable, Equatable {
    public struct Rule: Sendable, Codable, Equatable, Hashable {
        public var weekday: Int          // 0 = Sunday
        public var startTime: String     // "HH:mm"
        public var endTime: String
    }

    public var rules: [Rule]
    public var daysOff: [String]         // "yyyy-MM-dd"
}

/// The result of an action that the server can refuse with a reason code.
public enum ActionResult: Sendable, Equatable {
    case ok(id: String?)
    case refused(String)                 // error code, e.g. "slot_unavailable", "category_active"
}

/// Reasons offered when opening a dispute (must match the SQL check constraint).
public enum DisputeReason: String, CaseIterable, Sendable {
    case paymentNotReceived = "payment_not_received"
    case receiptFake = "receipt_fake"
    case noShow = "no_show"
    case serviceIssue = "service_issue"
    case refund
    case other
}
