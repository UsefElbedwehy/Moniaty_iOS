import Foundation

/// In-memory reviews, reports, blocks and tickets for running without a backend.
/// Reviews are published at once (no moderation queue offline).
public actor MockTrustRepository: TrustRepository {
    private var reviews: [String: [Review]] = [:]          // by provider id
    private var reviewedBookings: Set<String> = []
    private var blocks: [BlockedUser] = []
    private var ticketList: [SupportTicket] = []

    public init() {
        reviews["p-lamsa"] = [
            Review(id: "r1", rating: 5, body: "مكياج ناعم وثابت طول الليل، والتعامل راقي جداً.", photoUrls: [],
                   authorName: "نو**** مح****", isMine: false, serviceTitle: "مكياج العروس",
                   providerReply: "شكراً لكِ يا عروستنا الجميلة!", status: "approved", createdAt: .now.addingTimeInterval(-86400 * 9)),
            Review(id: "r2", rating: 4, body: "التزام بالموعد وشغل نظيف.", photoUrls: [],
                   authorName: "سا**** عل****", isMine: false, serviceTitle: "مكياج سهرة",
                   providerReply: nil, status: "approved", createdAt: .now.addingTimeInterval(-86400 * 30))
        ]
    }

    public func providerReviews(providerId: String, limit: Int, offset: Int) async throws -> ReviewsPage {
        let items = reviews[providerId] ?? []
        let count = items.count
        let avg = count == 0 ? nil : Decimal(items.map(\.rating).reduce(0, +)) / Decimal(count)
        var distribution: [String: Int] = [:]
        for star in 1...5 { distribution[String(star)] = items.filter { $0.rating == star }.count }
        return ReviewsPage(ratingAvg: avg, ratingCount: count, distribution: distribution,
                           items: Array(items.dropFirst(offset).prefix(limit)))
    }

    public func myReview(bookingId: String) async throws -> MyReviewState? {
        let mine = reviews.values.joined().first { $0.isMine && $0.id == "mine-\(bookingId)" }
        return MyReviewState(review: mine, canReview: !reviewedBookings.contains(bookingId))
    }

    public func submitReview(bookingId: String, rating: Int, body: String?, photoUrls: [URL]) async throws -> TrustResult {
        guard !reviewedBookings.contains(bookingId) else { return .refused("already_reviewed") }
        reviewedBookings.insert(bookingId)
        let review = Review(id: "mine-\(bookingId)", rating: rating, body: body, photoUrls: photoUrls, authorName: "أنا",
                            isMine: true, serviceTitle: nil, providerReply: nil, status: "approved", createdAt: .now)
        reviews["p-lamsa", default: []].insert(review, at: 0)
        return .ok
    }

    public func reply(reviewId: String, text: String) async throws {}

    public func report(_ target: ReportTarget, reason: ReportReason, details: String?) async throws -> TrustResult { .ok }

    public func block(userId: String) async throws {
        guard !blocks.contains(where: { $0.userId == userId }) else { return }
        blocks.insert(BlockedUser(userId: userId, name: userId, createdAt: .now), at: 0)
    }

    public func blockBookingParty(bookingId: String) async throws {
        try await block(userId: "booking-\(bookingId)")
    }

    public func unblock(userId: String) async throws {
        blocks.removeAll { $0.userId == userId }
    }

    public func blockedUsers() async throws -> [BlockedUser] { blocks }

    public func createTicket(subject: String, message: String, bookingId: String?) async throws -> TrustResult {
        ticketList.insert(SupportTicket(id: UUID().uuidString, subject: subject, message: message, status: "open",
                                        adminReply: nil, repliedAt: nil, createdAt: .now, bookingReference: nil), at: 0)
        return .ok
    }

    public func tickets() async throws -> [SupportTicket] { ticketList }
}
