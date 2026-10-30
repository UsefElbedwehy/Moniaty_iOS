package co.munyati.booking.data

import co.munyati.booking.domain.ActionResult
import co.munyati.booking.domain.Availability
import co.munyati.booking.domain.AvailableDays
import co.munyati.booking.domain.BookingBrideDetails
import co.munyati.booking.domain.BookingDetail
import co.munyati.booking.domain.BookingDispute
import co.munyati.booking.domain.BookingEvent
import co.munyati.booking.domain.BookingProposal
import co.munyati.booking.domain.BookingReceipt
import co.munyati.booking.domain.BookingSummary
import co.munyati.booking.domain.DisputeReason
import co.munyati.booking.domain.PaymentMethod
import co.munyati.booking.domain.PaymentMethodDraft
import co.munyati.booking.domain.PaymentMethodSnapshot
import co.munyati.core.dates.PostgresDate
import co.munyati.networking.ApiClient
import co.munyati.networking.ApiEndpoint
import co.munyati.networking.EmptyBody
import co.munyati.networking.decode
import co.munyati.networking.send
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import java.time.Instant

interface BookingRepository {
    // Bride
    suspend fun availableSlots(serviceId: String, day: String): List<Instant>
    /** The days with a free time in the next weeks, and the provider's booking mode. */
    suspend fun availableDays(serviceId: String): AvailableDays
    suspend fun createBooking(serviceId: String, startsAt: Instant, note: String?): ActionResult
    suspend fun respondToProposal(bookingId: String, accept: Boolean): ActionResult
    suspend fun submitReceipt(bookingId: String, storagePath: String, amount: Double, transferredAt: Instant, senderBank: String?, sha256: String): ActionResult
    // Provider
    suspend fun approve(bookingId: String): ActionResult
    suspend fun decline(bookingId: String, reason: String?): ActionResult
    suspend fun proposeReschedule(bookingId: String, startsAt: Instant, note: String?): ActionResult
    suspend fun confirmPayment(bookingId: String): ActionResult
    suspend fun rejectPayment(bookingId: String, reason: String): ActionResult
    suspend fun complete(bookingId: String): ActionResult
    // Either
    suspend fun cancel(bookingId: String, reason: String?): ActionResult
    suspend fun openDispute(bookingId: String, reason: DisputeReason, details: String?): ActionResult
    suspend fun bookings(active: Boolean): List<BookingSummary>
    suspend fun booking(id: String): BookingDetail?
    // Provider settings
    suspend fun availability(): Availability
    suspend fun saveAvailability(availability: Availability)
    suspend fun paymentMethods(): List<PaymentMethod>
    suspend fun savePaymentMethod(draft: PaymentMethodDraft): ActionResult
    suspend fun deletePaymentMethod(id: String)
}

/** Where receipt images live (private storage, readable only by the two parties and admins). */
interface ReceiptStorage {
    /** Uploads under `<bookingId>/` and returns the storage path for `submit_receipt`. */
    suspend fun upload(jpeg: ByteArray, bookingId: String): String
    suspend fun download(path: String): ByteArray
}

/** Supabase RPCs from `supabase/migrations/20261012000000_booking.sql`. */
class RemoteBookingRepository(private val client: ApiClient) : BookingRepository {
    private suspend inline fun <reified B> act(rpc: String, body: B): ActionResult {
        val result: ResultDto = client.send(ApiEndpoint.rpc(rpc), body)
        return result.toDomain()
    }

    override suspend fun availableSlots(serviceId: String, day: String): List<Instant> =
        client.send<SlotsArgs, List<String>>(ApiEndpoint.rpc("get_available_slots"), SlotsArgs(serviceId, day)).mapNotNull(PostgresDate::parse)

    override suspend fun createBooking(serviceId: String, startsAt: Instant, note: String?) =
        act("create_booking", CreateArgs(serviceId, startsAt.toString(), note))

    override suspend fun respondToProposal(bookingId: String, accept: Boolean) = act("respond_to_proposal", RespondArgs(bookingId, accept))

    override suspend fun submitReceipt(bookingId: String, storagePath: String, amount: Double, transferredAt: Instant, senderBank: String?, sha256: String) =
        act("submit_receipt", ReceiptArgs(bookingId, storagePath, amount, transferredAt.toString(), senderBank, sha256))

    override suspend fun approve(bookingId: String) = act("approve_booking", BookingArgs(bookingId))
    override suspend fun decline(bookingId: String, reason: String?) = act("decline_booking", ReasonArgs(bookingId, reason))
    override suspend fun proposeReschedule(bookingId: String, startsAt: Instant, note: String?) =
        act("propose_reschedule", ProposeArgs(bookingId, startsAt.toString(), note))
    override suspend fun confirmPayment(bookingId: String) = act("confirm_payment", BookingArgs(bookingId))
    override suspend fun rejectPayment(bookingId: String, reason: String) = act("reject_payment", ReasonArgs(bookingId, reason))
    override suspend fun complete(bookingId: String) = act("complete_booking", BookingArgs(bookingId))
    override suspend fun cancel(bookingId: String, reason: String?) = act("cancel_booking", ReasonArgs(bookingId, reason))
    override suspend fun openDispute(bookingId: String, reason: DisputeReason, details: String?) =
        act("open_dispute", DisputeArgs(bookingId, reason.rawValue, details))

    override suspend fun bookings(active: Boolean): List<BookingSummary> =
        client.send(ApiEndpoint.rpc("get_my_bookings"), ScopeArgs(if (active) "active" else "past"))

    override suspend fun booking(id: String): BookingDetail? {
        val raw = client.sendRaw(ApiEndpoint.rpc("get_booking"), client.json.encodeToString(BookingArgs.serializer(), BookingArgs(id)))
        if (raw.isBlank() || raw.trim() == "null") return null
        val summary = client.decode(BookingSummary.serializer(), raw)
        val extras = client.decode(DetailExtras.serializer(), raw)
        return BookingDetail(summary, extras.paymentMethods, extras.proposal, extras.receipts, extras.events, extras.openDispute, extras.brideDetails)
    }

    override suspend fun availability(): Availability = client.send(ApiEndpoint.rpc("get_my_availability"), EmptyBody())

    override suspend fun availableDays(serviceId: String): AvailableDays =
        client.send(ApiEndpoint.rpc("get_available_days"), DaysArgs(serviceId, 90))

    override suspend fun saveAvailability(availability: Availability) {
        // The weekly hours are kept whatever the mode, so switching back finds them.
        client.send<AvailabilityArgs, Availability>(ApiEndpoint.rpc("set_my_availability"), AvailabilityArgs(availability.rules, availability.daysOff))
        availability.dates?.let { client.send<DatesArgs, Availability>(ApiEndpoint.rpc("set_my_available_dates"), DatesArgs(it)) }
        availability.mode?.let { client.send<ModeArgs, Availability>(ApiEndpoint.rpc("set_my_booking_mode"), ModeArgs(it)) }
    }

    override suspend fun paymentMethods(): List<PaymentMethod> = client.send(ApiEndpoint.rpc("get_my_payment_methods"), EmptyBody())

    /** `p_id` has no SQL default, so a new method sends it as an explicit null. */
    override suspend fun savePaymentMethod(draft: PaymentMethodDraft): ActionResult {
        val d = draft
        val encoded = client.json.encodeToJsonElement(PaymentMethodArgs.serializer(),
            PaymentMethodArgs(d.id, d.kind, d.label, d.accountName, d.value, d.isActive)).jsonObject
        val body = if (d.id == null) JsonObject(encoded + ("p_id" to JsonNull)) else encoded
        return client.decode(ResultDto.serializer(), client.sendRaw(ApiEndpoint.rpc("upsert_my_payment_method"), body.toString())).toDomain()
    }

    override suspend fun deletePaymentMethod(id: String) {
        client.send<IdArgs, ResultDto>(ApiEndpoint.rpc("delete_my_payment_method"), IdArgs(id))
    }
}

@Serializable
internal data class ResultDto(val ok: Boolean, val id: String? = null, val error: String? = null) {
    fun toDomain(): ActionResult = if (ok) ActionResult.Ok(id) else ActionResult.Refused(error ?: "unknown")
}

@Serializable
private data class DetailExtras(
    val paymentMethods: List<PaymentMethodSnapshot> = emptyList(),
    val proposal: BookingProposal? = null,
    val receipts: List<BookingReceipt> = emptyList(),
    val events: List<BookingEvent> = emptyList(),
    val openDispute: BookingDispute? = null,
    val brideDetails: BookingBrideDetails? = null,
)

@Serializable private data class IdArgs(val pId: String)
@Serializable private data class BookingArgs(val pBooking: String)
@Serializable private data class ScopeArgs(val pScope: String)
@Serializable private data class SlotsArgs(val pServiceId: String, val pDay: String)
@Serializable private data class CreateArgs(val pServiceId: String, val pStartsAt: String, val pNote: String?)
@Serializable private data class RespondArgs(val pBooking: String, val pAccept: Boolean)
@Serializable private data class ReasonArgs(val pBooking: String, val pReason: String?)
@Serializable private data class ProposeArgs(val pBooking: String, val pStartsAt: String, val pNote: String?)
@Serializable private data class DisputeArgs(val pBooking: String, val pReason: String, val pDetails: String?)
@Serializable
private data class ReceiptArgs(val pBooking: String, val pStoragePath: String, val pAmount: Double, val pTransferredAt: String, val pSenderBank: String?, val pSha256: String)
@Serializable private data class AvailabilityArgs(val pRules: List<Availability.Rule>, val pDaysOff: List<String>)
@Serializable private data class DatesArgs(val pDates: List<Availability.DateWindow>)
@Serializable private data class ModeArgs(val pMode: String)
@Serializable private data class DaysArgs(val pServiceId: String, val pDays: Int)
@Serializable
private data class PaymentMethodArgs(val pId: String?, val pKind: String, val pLabel: String, val pAccountName: String, val pValue: String, val pIsActive: Boolean)

