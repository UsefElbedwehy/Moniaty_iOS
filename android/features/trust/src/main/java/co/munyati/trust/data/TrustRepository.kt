package co.munyati.trust.data

import co.munyati.networking.ApiClient
import co.munyati.networking.ApiEndpoint
import co.munyati.networking.EmptyBody
import co.munyati.networking.send
import co.munyati.trust.domain.BlockedUser
import co.munyati.trust.domain.MyReviewState
import co.munyati.trust.domain.ReportReason
import co.munyati.trust.domain.ReportTarget
import co.munyati.trust.domain.Review
import co.munyati.trust.domain.ReviewsPage
import co.munyati.trust.domain.SupportTicket
import co.munyati.trust.domain.TrustResult
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

interface TrustRepository {
    suspend fun providerReviews(providerId: String, limit: Int, offset: Int): ReviewsPage
    suspend fun myReview(bookingId: String): MyReviewState?
    suspend fun submitReview(bookingId: String, rating: Int, body: String?, photoUrls: List<String>): TrustResult
    suspend fun reply(reviewId: String, text: String)
    suspend fun report(target: ReportTarget, reason: ReportReason, details: String?): TrustResult
    suspend fun block(userId: String)
    suspend fun blockBookingParty(bookingId: String)
    suspend fun unblock(userId: String)
    suspend fun blockedUsers(): List<BlockedUser>
    suspend fun createTicket(subject: String, message: String, bookingId: String?): TrustResult
    suspend fun tickets(): List<SupportTicket>
}

/** Supabase RPCs from `supabase/migrations/20261014000000_trust.sql`. */
class RemoteTrustRepository(private val client: ApiClient) : TrustRepository {
    override suspend fun providerReviews(providerId: String, limit: Int, offset: Int): ReviewsPage =
        client.send(ApiEndpoint.rpc("get_provider_reviews"), ReviewsArgs(providerId, limit, offset))

    override suspend fun myReview(bookingId: String): MyReviewState? = client.send(ApiEndpoint.rpc("get_my_review"), BookingArgs(bookingId))

    override suspend fun submitReview(bookingId: String, rating: Int, body: String?, photoUrls: List<String>): TrustResult =
        client.send<SubmitArgs, ResultDto>(ApiEndpoint.rpc("submit_review"), SubmitArgs(bookingId, rating, body, photoUrls)).domain

    override suspend fun reply(reviewId: String, text: String) {
        client.send<ReplyArgs, ResultDto>(ApiEndpoint.rpc("reply_to_review"), ReplyArgs(reviewId, text))
    }

    override suspend fun report(target: ReportTarget, reason: ReportReason, details: String?): TrustResult =
        client.send<ReportArgs, ResultDto>(ApiEndpoint.rpc("report_content"), ReportArgs(target.type, target.id, reason.rawValue, details)).domain

    override suspend fun block(userId: String) {
        client.send<UserArgs, ResultDto>(ApiEndpoint.rpc("block_user"), UserArgs(userId))
    }

    override suspend fun blockBookingParty(bookingId: String) {
        client.send<BookingArgs, ResultDto>(ApiEndpoint.rpc("block_booking_party"), BookingArgs(bookingId))
    }

    override suspend fun unblock(userId: String) {
        client.send<UserArgs, ResultDto>(ApiEndpoint.rpc("unblock_user"), UserArgs(userId))
    }

    override suspend fun blockedUsers(): List<BlockedUser> = client.send(ApiEndpoint.rpc("get_my_blocks"), EmptyBody())

    override suspend fun createTicket(subject: String, message: String, bookingId: String?): TrustResult =
        client.send<TicketArgs, ResultDto>(ApiEndpoint.rpc("create_support_ticket"), TicketArgs(subject, message, bookingId)).domain

    override suspend fun tickets(): List<SupportTicket> = client.send(ApiEndpoint.rpc("get_my_support_tickets"), EmptyBody())
}

@Serializable
private data class ResultDto(val ok: Boolean, val error: String? = null) {
    val domain: TrustResult get() = if (ok) TrustResult.Ok else TrustResult.Refused(error ?: "unknown")
}

@Serializable private data class UserArgs(val pUser: String)
@Serializable private data class BookingArgs(val pBooking: String)
@Serializable private data class ReviewsArgs(val pProvider: String, val pLimit: Int, val pOffset: Int)
@Serializable private data class SubmitArgs(val pBooking: String, val pRating: Int, val pBody: String?, val pPhotoUrls: List<String>)
@Serializable private data class ReplyArgs(val pReview: String, val pReply: String)
@Serializable private data class ReportArgs(val pTargetType: String, val pTargetId: String, val pReason: String, val pDetails: String?)
@Serializable private data class TicketArgs(val pSubject: String, val pMessage: String, val pBooking: String?)

/**
 * In-memory reviews, reports, blocks and tickets for running without a backend (the same data as
 * iOS). Reviews are published at once (no moderation queue offline).
 */
class MockTrustRepository : TrustRepository {
    private val mutex = Mutex()
    private val reviews = mutableMapOf<String, MutableList<Review>>()
    private val reviewedBookings = mutableSetOf<String>()
    private val blocks = mutableListOf<BlockedUser>()
    private val ticketList = mutableListOf<SupportTicket>()

    init {
        val now = Instant.now()
        reviews["p-lamsa"] = mutableListOf(
            Review("r1", 5, "مكياج ناعم وثابت طول الليل، والتعامل راقي جداً.", (1..2).map { "https://picsum.photos/seed/review-r1-$it/900/1200" }, "نو**** مح****", false, "مكياج العروس",
                "شكراً لكِ يا عروستنا الجميلة!", "approved", now.minus(9, ChronoUnit.DAYS).toString()),
            Review("r2", 4, "التزام بالموعد وشغل نظيف.", emptyList(), "سا**** عل****", false, "مكياج سهرة",
                null, "approved", now.minus(30, ChronoUnit.DAYS).toString()),
        )
    }

    override suspend fun providerReviews(providerId: String, limit: Int, offset: Int) = mutex.withLock {
        val items = reviews[providerId].orEmpty()
        ReviewsPage(
            ratingAvg = if (items.isEmpty()) null else items.map { it.rating }.average(),
            ratingCount = items.size,
            distribution = (1..5).associate { star -> star.toString() to items.count { it.rating == star } },
            items = items.drop(offset).take(limit),
        )
    }

    override suspend fun myReview(bookingId: String) = mutex.withLock {
        MyReviewState(reviews.values.flatten().firstOrNull { it.isMine && it.id == "mine-$bookingId" }, bookingId !in reviewedBookings)
    }

    override suspend fun submitReview(bookingId: String, rating: Int, body: String?, photoUrls: List<String>): TrustResult = mutex.withLock {
        if (bookingId in reviewedBookings) return@withLock TrustResult.Refused("already_reviewed")
        reviewedBookings += bookingId
        reviews.getOrPut("p-lamsa") { mutableListOf() }
            .add(0, Review("mine-$bookingId", rating, body, photoUrls, "أنا", true, null, null, "approved", Instant.now().toString()))
        TrustResult.Ok
    }

    override suspend fun reply(reviewId: String, text: String) = Unit

    override suspend fun report(target: ReportTarget, reason: ReportReason, details: String?): TrustResult = TrustResult.Ok

    override suspend fun block(userId: String) = mutex.withLock {
        if (blocks.none { it.userId == userId }) blocks.add(0, BlockedUser(userId, userId, Instant.now().toString()))
    }

    override suspend fun blockBookingParty(bookingId: String) = block("booking-$bookingId")

    override suspend fun unblock(userId: String) = mutex.withLock { blocks.removeAll { it.userId == userId }; Unit }

    override suspend fun blockedUsers() = mutex.withLock { blocks.toList() }

    override suspend fun createTicket(subject: String, message: String, bookingId: String?): TrustResult = mutex.withLock {
        ticketList.add(0, SupportTicket(UUID.randomUUID().toString(), subject, message, "open", createdAtRaw = Instant.now().toString()))
        TrustResult.Ok
    }

    override suspend fun tickets() = mutex.withLock { ticketList.toList() }
}
