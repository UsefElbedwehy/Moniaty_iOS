import Foundation
import Core
import Networking

public protocol TrustRepository: Sendable {
    func providerReviews(providerId: String, limit: Int, offset: Int) async throws -> ReviewsPage
    func myReview(bookingId: String) async throws -> MyReviewState?
    func submitReview(bookingId: String, rating: Int, body: String?, photoUrls: [URL]) async throws -> TrustResult
    func reply(reviewId: String, text: String) async throws
    func report(_ target: ReportTarget, reason: ReportReason, details: String?) async throws -> TrustResult
    func block(userId: String) async throws
    func blockBookingParty(bookingId: String) async throws
    func unblock(userId: String) async throws
    func blockedUsers() async throws -> [BlockedUser]
    func createTicket(subject: String, message: String, bookingId: String?) async throws -> TrustResult
    func tickets() async throws -> [SupportTicket]
}

/// Supabase RPCs from `supabase/migrations/20261014000000_trust.sql`.
public struct RemoteTrustRepository: TrustRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func providerReviews(providerId: String, limit: Int, offset: Int) async throws -> ReviewsPage {
        try await client.send(.rpc("get_provider_reviews"), body: ReviewsArgs(pProvider: providerId, pLimit: limit, pOffset: offset))
    }

    public func myReview(bookingId: String) async throws -> MyReviewState? {
        try await client.send(.rpc("get_my_review"), body: BookingArgs(pBooking: bookingId))
    }

    public func submitReview(bookingId: String, rating: Int, body: String?, photoUrls: [URL]) async throws -> TrustResult {
        let result: ResultDTO = try await client.send(.rpc("submit_review"), body: SubmitArgs(
            pBooking: bookingId, pRating: rating, pBody: body, pPhotoUrls: photoUrls.map(\.absoluteString)))
        return result.domain
    }

    public func reply(reviewId: String, text: String) async throws {
        let _: ResultDTO = try await client.send(.rpc("reply_to_review"), body: ReplyArgs(pReview: reviewId, pReply: text))
    }

    public func report(_ target: ReportTarget, reason: ReportReason, details: String?) async throws -> TrustResult {
        let result: ResultDTO = try await client.send(.rpc("report_content"), body: ReportArgs(
            pTargetType: target.type, pTargetId: target.id, pReason: reason.rawValue, pDetails: details))
        return result.domain
    }

    public func block(userId: String) async throws {
        let _: ResultDTO = try await client.send(.rpc("block_user"), body: UserArgs(pUser: userId))
    }

    public func blockBookingParty(bookingId: String) async throws {
        let _: ResultDTO = try await client.send(.rpc("block_booking_party"), body: BookingArgs(pBooking: bookingId))
    }

    public func unblock(userId: String) async throws {
        let _: ResultDTO = try await client.send(.rpc("unblock_user"), body: UserArgs(pUser: userId))
    }

    public func blockedUsers() async throws -> [BlockedUser] {
        try await client.send(.rpc("get_my_blocks"), body: NoArgs())
    }

    public func createTicket(subject: String, message: String, bookingId: String?) async throws -> TrustResult {
        let result: ResultDTO = try await client.send(.rpc("create_support_ticket"), body: TicketArgs(
            pSubject: subject, pMessage: message, pBooking: bookingId))
        return result.domain
    }

    public func tickets() async throws -> [SupportTicket] {
        try await client.send(.rpc("get_my_support_tickets"), body: NoArgs())
    }
}

private struct ResultDTO: Decodable, Sendable {
    let ok: Bool
    let error: String?
    var domain: TrustResult { ok ? .ok : .refused(error ?? "unknown") }
}

private struct NoArgs: Encodable, Sendable {}
private struct UserArgs: Encodable, Sendable { let pUser: String }
private struct BookingArgs: Encodable, Sendable { let pBooking: String }
private struct ReviewsArgs: Encodable, Sendable { let pProvider: String; let pLimit: Int; let pOffset: Int }
private struct SubmitArgs: Encodable, Sendable { let pBooking: String; let pRating: Int; let pBody: String?; let pPhotoUrls: [String] }
private struct ReplyArgs: Encodable, Sendable { let pReview: String; let pReply: String }
private struct ReportArgs: Encodable, Sendable { let pTargetType: String; let pTargetId: String; let pReason: String; let pDetails: String? }
private struct TicketArgs: Encodable, Sendable { let pSubject: String; let pMessage: String; let pBooking: String? }
