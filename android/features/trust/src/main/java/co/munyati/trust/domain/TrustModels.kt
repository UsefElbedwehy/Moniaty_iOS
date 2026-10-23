package co.munyati.trust.domain

import co.munyati.core.dates.PostgresDate
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

/**
 * A public review. `authorName` is already masked by the server («نو**** مح****») unless it's the
 * viewer's own review.
 */
@Serializable
data class Review(
    val id: String,
    val rating: Int,
    val body: String? = null,
    val photoUrls: List<String> = emptyList(),
    val authorName: String,
    val isMine: Boolean = false,
    val serviceTitle: String? = null,
    val providerReply: String? = null,
    /** pending | approved | rejected | hidden */
    val status: String = "approved",
    @SerialName("created_at") val createdAtRaw: String,
) {
    val createdAt: Instant? get() = PostgresDate.parse(createdAtRaw)
}

/** `get_provider_reviews`: summary plus a page of reviews. */
@Serializable
data class ReviewsPage(
    val ratingAvg: Double? = null,
    val ratingCount: Int = 0,
    val distribution: Map<String, Int> = emptyMap(),
    val items: List<Review> = emptyList(),
)

/** `get_my_review`: the caller's review of a booking, and whether they can still write one. */
@Serializable
data class MyReviewState(val review: Review? = null, val canReview: Boolean = false)

/** Which side is writing: the bride's review is public, the provider's note is private. */
enum class ReviewRole(val rawValue: String) { Bride("bride"), Provider("provider") }

/** Anything that can be reported (must match the SQL `report_target` enum). */
sealed class ReportTarget(val type: String, val id: String) {
    class Provider(id: String) : ReportTarget("provider", id)
    class Service(id: String) : ReportTarget("service", id)
    class Store(id: String) : ReportTarget("store", id)
    class Review(id: String) : ReportTarget("review", id)
    class Booking(id: String) : ReportTarget("booking", id)
    class User(id: String) : ReportTarget("user", id)
}

enum class ReportReason(val rawValue: String) {
    Spam("spam"), Inappropriate("inappropriate"), Fake("fake"), Harassment("harassment"), Fraud("fraud"), Other("other"),
}

@Serializable
data class BlockedUser(val userId: String, val name: String, @SerialName("created_at") val createdAtRaw: String? = null)

@Serializable
data class SupportTicket(
    val id: String,
    val subject: String,
    val message: String,
    /** open | answered | closed */
    val status: String,
    val adminReply: String? = null,
    @SerialName("replied_at") val repliedAtRaw: String? = null,
    @SerialName("created_at") val createdAtRaw: String? = null,
    val bookingReference: String? = null,
)

/** Result of a write the server may refuse with a code. */
sealed interface TrustResult {
    data object Ok : TrustResult
    data class Refused(val code: String) : TrustResult
}

/** A support channel from remote config (`support.contact_methods`). */
data class SupportContact(val kind: Kind, val value: String) {
    enum class Kind(val rawValue: String) { Email("email"), Whatsapp("whatsapp"), Phone("phone") }

    val url: String
        get() = when (kind) {
            Kind.Email -> "mailto:$value"
            Kind.Phone -> "tel:" + value.filter { it.isDigit() || it == '+' }
            Kind.Whatsapp -> "https://wa.me/" + value.filter { it.isDigit() }
        }
}
