import Foundation

/// A public review. `authorName` is already masked by the server («نو**** مح****») unless it's
/// the viewer's own review.
public struct Review: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let rating: Int
    public let body: String?
    public let photoUrls: [URL]
    public let authorName: String
    public let isMine: Bool
    public let serviceTitle: String?
    public let providerReply: String?
    public let status: String          // pending | approved | rejected | hidden
    public let createdAt: Date
}

/// `get_provider_reviews`: summary plus a page of reviews.
public struct ReviewsPage: Sendable, Decodable {
    public let ratingAvg: Decimal?
    public let ratingCount: Int
    public let distribution: [String: Int]
    public let items: [Review]

    private enum CodingKeys: String, CodingKey { case ratingAvg, ratingCount, distribution, items }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ratingAvg = try c.decodeIfPresent(Decimal.self, forKey: .ratingAvg)
        ratingCount = try c.decodeIfPresent(Int.self, forKey: .ratingCount) ?? 0
        distribution = try c.decodeIfPresent([String: Int].self, forKey: .distribution) ?? [:]
        items = try c.decodeIfPresent([Review].self, forKey: .items) ?? []
    }

    public init(ratingAvg: Decimal?, ratingCount: Int, distribution: [String: Int], items: [Review]) {
        self.ratingAvg = ratingAvg
        self.ratingCount = ratingCount
        self.distribution = distribution
        self.items = items
    }
}

/// `get_my_review`: the caller's review of a booking, and whether they can still write one.
public struct MyReviewState: Sendable, Decodable {
    public let review: Review?
    public let canReview: Bool
}

/// Which side is writing: the bride's review is public, the provider's note is private.
public enum ReviewRole: String, Sendable {
    case bride, provider
}

/// Anything that can be reported (must match the SQL `report_target` enum).
public enum ReportTarget: Hashable, Sendable {
    case provider(String), service(String), store(String), review(String), booking(String), user(String)

    var type: String {
        switch self {
        case .provider: "provider"
        case .service: "service"
        case .store: "store"
        case .review: "review"
        case .booking: "booking"
        case .user: "user"
        }
    }

    var id: String {
        switch self {
        case .provider(let id), .service(let id), .store(let id), .review(let id), .booking(let id), .user(let id): id
        }
    }
}

public enum ReportReason: String, CaseIterable, Sendable {
    case spam, inappropriate, fake, harassment, fraud, other
}

public struct BlockedUser: Identifiable, Hashable, Sendable, Decodable {
    public let userId: String
    public let name: String
    public let createdAt: Date
    public var id: String { userId }
}

public struct SupportTicket: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let subject: String
    public let message: String
    public let status: String          // open | answered | closed
    public let adminReply: String?
    public let repliedAt: Date?
    public let createdAt: Date
    public let bookingReference: String?
}

/// Result of a write the server may refuse with a code.
public enum TrustResult: Sendable, Equatable {
    case ok
    case refused(String)
}
