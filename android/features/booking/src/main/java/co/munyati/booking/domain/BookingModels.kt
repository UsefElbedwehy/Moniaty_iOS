package co.munyati.booking.domain

import co.munyati.core.dates.PostgresDate
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

/** Mirrors the Postgres `booking_status` enum (supabase/migrations/20261012000000_booking.sql). */
@Serializable
enum class BookingStatus(val rawValue: String) {
    @SerialName("requested") Requested("requested"),
    @SerialName("reschedule_proposed") RescheduleProposed("reschedule_proposed"),
    @SerialName("awaiting_payment") AwaitingPayment("awaiting_payment"),
    @SerialName("payment_submitted") PaymentSubmitted("payment_submitted"),
    @SerialName("payment_confirmed") PaymentConfirmed("payment_confirmed"),
    @SerialName("completed") Completed("completed"),
    @SerialName("declined") Declined("declined"),
    @SerialName("cancelled_by_bride") CancelledByBride("cancelled_by_bride"),
    @SerialName("cancelled_by_provider") CancelledByProvider("cancelled_by_provider"),
    @SerialName("expired") Expired("expired"),
    @SerialName("disputed") Disputed("disputed");

    /** Holds a slot (and counts for the one-per-category rule). */
    val isActive: Boolean
        get() = this in setOf(Requested, RescheduleProposed, AwaitingPayment, PaymentSubmitted, PaymentConfirmed, Disputed)

    /** Position on the 5-step progress bar (request → approval → payment → confirmation → done). */
    val step: Int
        get() = when (this) {
            Requested, RescheduleProposed -> 1
            AwaitingPayment -> 2
            PaymentSubmitted -> 3
            PaymentConfirmed, Disputed -> 4
            Completed -> 5
            Declined, CancelledByBride, CancelledByProvider, Expired -> 0
        }
}

/** Which side of the booking the viewer is on. */
enum class BookingRole(val rawValue: String) { Bride("bride"), Provider("provider") }

@Serializable
data class BookingProvider(val id: String, val name: String? = null, val logoUrl: String? = null, val isVerified: Boolean = false)

@Serializable
data class BookingSummary(
    val id: String,
    val referenceCode: String,
    val status: BookingStatus,
    val isDemo: Boolean = false,
    val serviceId: String? = null,
    val serviceTitle: String,
    val categoryId: String? = null,
    val price: Double,
    @SerialName("starts_at") val startsAtRaw: String,
    @SerialName("ends_at") val endsAtRaw: String,
    val note: String? = null,
    @SerialName("payment_due_at") val paymentDueAtRaw: String? = null,
    @SerialName("status_changed_at") val statusChangedAtRaw: String? = null,
    val provider: BookingProvider,
    /** Masked for providers until payment is confirmed. */
    val brideName: String? = null,
) {
    val startsAt: Instant get() = PostgresDate.parse(startsAtRaw) ?: Instant.EPOCH
    val paymentDueAt: Instant? get() = PostgresDate.parse(paymentDueAtRaw)
}

@Serializable
data class PaymentMethodSnapshot(val kind: String, val label: String, val accountName: String, val value: String)

@Serializable
data class BookingProposal(
    val id: String,
    @SerialName("starts_at") val startsAtRaw: String,
    @SerialName("ends_at") val endsAtRaw: String? = null,
    val note: String? = null,
    @SerialName("expires_at") val expiresAtRaw: String,
) {
    val startsAt: Instant get() = PostgresDate.parse(startsAtRaw) ?: Instant.EPOCH
    val expiresAt: Instant get() = PostgresDate.parse(expiresAtRaw) ?: Instant.EPOCH
}

@Serializable
data class BookingReceipt(
    val id: String,
    /** null for the demo booking's sample receipt. */
    val storagePath: String? = null,
    val amount: Double,
    @SerialName("transferred_at") val transferredAtRaw: String? = null,
    val senderBank: String? = null,
    /** pending | accepted | rejected */
    val status: String,
    val rejectReason: String? = null,
    @SerialName("created_at") val createdAtRaw: String? = null,
) {
    val transferredAt: Instant? get() = PostgresDate.parse(transferredAtRaw)
}

@Serializable
data class BookingEvent(
    val toStatus: BookingStatus,
    val actorRole: String? = null,
    val note: String? = null,
    @SerialName("created_at") val createdAtRaw: String,
) {
    val createdAt: Instant? get() = PostgresDate.parse(createdAtRaw)
}

@Serializable
data class BookingDispute(val reason: String, @SerialName("created_at") val createdAtRaw: String? = null)

/** A booking page; the summary fields come at the top level beside the extras. */
data class BookingDetail(
    val summary: BookingSummary,
    val paymentMethods: List<PaymentMethodSnapshot>,
    val proposal: BookingProposal?,
    val receipts: List<BookingReceipt>,
    val events: List<BookingEvent>,
    val openDispute: BookingDispute?,
    /** The bride's details, for the booking's provider only (null for the bride and on demos). */
    val brideDetails: BookingBrideDetails? = null,
)

/** What the bride filled in "Bride details" (Profile), as her booking's provider sees it. */
@Serializable
data class BookingBrideDetails(
    /** Name and phone are null until the payment is confirmed (privacy, like `brideName`). */
    val fullName: String? = null,
    val age: Int? = null,
    val nationality: String? = null,
    val phone: String? = null,
    val extraPhone: String? = null,
    val skinType: String? = null,
    val skinTone: String? = null,
    val hairType: String? = null,
    val hairLength: String? = null,
    val allergies: String? = null,
    val weddingDate: String? = null,
    val cityNameAr: String? = null,
    val cityNameEn: String? = null,
    val venue: String? = null,
    val guestCount: Int? = null,
    val notes: String? = null,
) {
    val isEmpty: Boolean get() = !hasPersonal && !hasWedding

    /** Anything about her (besides the name and phone, which may be hidden). */
    val hasPersonal: Boolean
        get() = fullName != null || age != null || !nationality.isNullOrEmpty() || phone != null || extraPhone != null || skinType != null ||
            skinTone != null || hairType != null || hairLength != null || !allergies.isNullOrEmpty()

    val hasWedding: Boolean
        get() = weddingDate != null || cityNameAr != null || !venue.isNullOrEmpty() || guestCount != null || !notes.isNullOrEmpty()
}

/** A provider's own payment method (managed in the studio). */
@Serializable
data class PaymentMethod(val id: String, val kind: String, val label: String, val accountName: String, val value: String, val isActive: Boolean = true)

data class PaymentMethodDraft(
    val id: String? = null,
    val kind: String = "iban",
    val label: String = "",
    val accountName: String = "",
    val value: String = "",
    val isActive: Boolean = true,
) {
    constructor(m: PaymentMethod) : this(m.id, m.kind, m.label, m.accountName, m.value, m.isActive)

    val isValid: Boolean
        get() = label.trim().length >= 2 && accountName.trim().length >= 2 && value.trim().length >= 5
}

/** Weekly working hours and days off. */
@Serializable
data class Availability(
    val rules: List<Rule> = emptyList(),
    val daysOff: List<String> = emptyList(),
    /**
     * How she takes bookings: "weekly" (the rules above), "dates" ([dates] only) or "request" (the
     * bride picks any date and time; she accepts or declines). Null from older servers.
     */
    val mode: String? = null,
    val dates: List<DateWindow>? = null,
) {
    /** weekday 0 = Sunday; times "HH:mm". */
    @Serializable
    data class Rule(val weekday: Int, val startTime: String, val endTime: String)

    /** One calendar date she is available ("yyyy-MM-dd"), with its hours ("dates" mode). */
    @Serializable
    data class DateWindow(val day: String, val startTime: String, val endTime: String)
}

/** The days a service can be booked in the coming weeks, and the provider's booking mode. */
@Serializable
data class AvailableDays(val mode: String? = null, val days: List<String> = emptyList())

/** The result of an action the server can refuse with a reason code. */
sealed interface ActionResult {
    data class Ok(val id: String?) : ActionResult
    /** e.g. "slot_unavailable", "category_active". */
    data class Refused(val code: String) : ActionResult
}

/** Reasons offered when opening a dispute (must match the SQL check constraint). */
enum class DisputeReason(val rawValue: String) {
    PaymentNotReceived("payment_not_received"),
    ReceiptFake("receipt_fake"),
    NoShow("no_show"),
    ServiceIssue("service_issue"),
    Refund("refund"),
    Other("other"),
}

/** What a booking request needs to know about the service (from the catalog card). */
data class BookableService(val id: String, val title: String, val price: Double, val providerName: String?)
