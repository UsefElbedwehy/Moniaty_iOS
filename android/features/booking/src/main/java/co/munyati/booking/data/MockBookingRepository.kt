package co.munyati.booking.data

import co.munyati.booking.domain.ActionResult
import co.munyati.booking.domain.Availability
import co.munyati.booking.domain.AvailableDays
import co.munyati.booking.domain.BookingBrideDetails
import co.munyati.booking.domain.BookingDetail
import co.munyati.booking.domain.BookingEvent
import co.munyati.booking.domain.BookingProposal
import co.munyati.booking.domain.BookingProvider
import co.munyati.booking.domain.BookingReceipt
import co.munyati.booking.domain.BookingStatus
import co.munyati.booking.domain.BookingSummary
import co.munyati.booking.domain.DisputeReason
import co.munyati.booking.domain.PaymentMethod
import co.munyati.booking.domain.PaymentMethodDraft
import co.munyati.booking.domain.PaymentMethodSnapshot
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.UUID

/** The time zone bookings are shown and stored in (Saudi Arabia). */
val Riyadh: ZoneId = ZoneId.of("Asia/Riyadh")

/** "yyyy-MM-dd" in Riyadh, what the slot RPC expects for a day. */
fun dayString(date: LocalDate): String = date.toString()

/**
 * In-memory bookings for running without a backend. One instance is shared by the bride and
 * provider shells, so a request made as a bride shows up in the provider inbox. It follows the
 * server's state machine without its permission checks — the same as iOS.
 */
class MockBookingRepository : BookingRepository {
    private data class Row(
        var summary: BookingSummary,
        var paymentMethods: List<PaymentMethodSnapshot> = emptyList(),
        var proposal: BookingProposal? = null,
        val receipts: MutableList<BookingReceipt> = mutableListOf(),
        val events: MutableList<BookingEvent> = mutableListOf(),
    )

    private val mutex = Mutex()
    private val rows = linkedMapOf<String, Row>()
    private val methods = linkedMapOf<String, PaymentMethodDraft>()
    private var hours = Availability((0..6).map { Availability.Rule(it, "10:00", "22:00") }, emptyList())

    private fun now() = Instant.now().toString()

    private fun move(id: String, to: BookingStatus, by: String) {
        val row = rows[id] ?: return
        row.summary = row.summary.copy(status = to, statusChangedAtRaw = now())
        row.events.add(BookingEvent(to, by, null, now()))
    }

    override suspend fun availableSlots(serviceId: String, day: String): List<Instant> {
        val date = runCatching { LocalDate.parse(day) }.getOrNull() ?: return emptyList()
        // Like the server's modes: "request" opens the day, "dates" only the listed days.
        val hoursOfDay = when (hours.mode) {
            "request" -> (8..23).toList()
            "dates" -> if (hours.dates.orEmpty().any { it.day == day }) (14..20 step 2).toList() else emptyList()
            else -> (10..20 step 2).toList()
        }
        return hoursOfDay.map { date.atTime(it, 0).atZone(Riyadh).toInstant() }.filter { it.isAfter(Instant.now()) }
    }

    override suspend fun availableDays(serviceId: String): AvailableDays {
        val days = (0L until 60L).map { LocalDate.now(Riyadh).plusDays(it).toString() }
        val open = if (hours.mode == "dates") days.filter { d -> hours.dates.orEmpty().any { it.day == d } } else days
        return AvailableDays(hours.mode ?: "weekly", open)
    }

    override suspend fun createBooking(serviceId: String, startsAt: Instant, note: String?): ActionResult = mutex.withLock {
        val id = UUID.randomUUID().toString()
        val code = "MN-" + UUID.randomUUID().toString().take(5).uppercase()
        rows[id] = Row(
            BookingSummary(
                id = id, referenceCode = code, status = BookingStatus.Requested, serviceId = serviceId,
                serviceTitle = "مكياج العروس", price = 2800.0, startsAtRaw = startsAt.toString(),
                endsAtRaw = startsAt.plus(3, ChronoUnit.HOURS).toString(), note = note.orEmpty(), statusChangedAtRaw = now(),
                provider = BookingProvider("p-lamsa", "لمسة جمال", isVerified = true), brideName = "نورة",
            ),
            events = mutableListOf(BookingEvent(BookingStatus.Requested, "bride", null, now())),
        )
        ActionResult.Ok(id)
    }

    override suspend fun respondToProposal(bookingId: String, accept: Boolean): ActionResult = mutex.withLock {
        val row = rows[bookingId] ?: return@withLock ActionResult.Refused("not_found")
        val proposal = row.proposal
        if (accept && proposal != null) row.summary = row.summary.copy(startsAtRaw = proposal.startsAtRaw)
        row.proposal = null
        move(bookingId, if (accept) BookingStatus.AwaitingPayment else BookingStatus.CancelledByBride, "bride")
        if (accept) snapshotMethods(bookingId)
        ActionResult.Ok(bookingId)
    }

    override suspend fun submitReceipt(bookingId: String, storagePath: String, amount: Double, transferredAt: Instant, senderBank: String?, sha256: String) = mutex.withLock {
        rows[bookingId]?.receipts?.add(0, BookingReceipt(UUID.randomUUID().toString(), storagePath, amount, transferredAt.toString(), senderBank, "pending", null, now()))
        move(bookingId, BookingStatus.PaymentSubmitted, "bride")
        ActionResult.Ok(bookingId)
    }

    private fun snapshotMethods(id: String) {
        val row = rows[id] ?: return
        row.paymentMethods = methods.values.filter { it.isActive }.map { PaymentMethodSnapshot(it.kind, it.label, it.accountName, it.value) }
            .ifEmpty { listOf(PaymentMethodSnapshot("iban", "مصرف الراجحي", "لمسة جمال", "SA0380000000608010167519")) }
        row.summary = row.summary.copy(paymentDueAtRaw = Instant.now().plus(48, ChronoUnit.HOURS).toString())
    }

    override suspend fun approve(bookingId: String) = mutex.withLock {
        move(bookingId, BookingStatus.AwaitingPayment, "provider")
        snapshotMethods(bookingId)
        ActionResult.Ok(bookingId)
    }

    override suspend fun decline(bookingId: String, reason: String?) = mutex.withLock {
        move(bookingId, BookingStatus.Declined, "provider")
        ActionResult.Ok(bookingId)
    }

    override suspend fun proposeReschedule(bookingId: String, startsAt: Instant, note: String?) = mutex.withLock {
        rows[bookingId]?.proposal = BookingProposal(UUID.randomUUID().toString(), startsAt.toString(),
            startsAt.plus(3, ChronoUnit.HOURS).toString(), note.orEmpty(), Instant.now().plus(1, ChronoUnit.DAYS).toString())
        move(bookingId, BookingStatus.RescheduleProposed, "provider")
        ActionResult.Ok(bookingId)
    }

    override suspend fun confirmPayment(bookingId: String) = mutex.withLock {
        reviewPendingReceipts(bookingId, "accepted", null)
        move(bookingId, BookingStatus.PaymentConfirmed, "provider")
        ActionResult.Ok(bookingId)
    }

    override suspend fun rejectPayment(bookingId: String, reason: String) = mutex.withLock {
        reviewPendingReceipts(bookingId, "rejected", reason)
        move(bookingId, BookingStatus.AwaitingPayment, "provider")
        ActionResult.Ok(bookingId)
    }

    /** Like the server's confirm/reject: settles the pending receipts. */
    private fun reviewPendingReceipts(id: String, status: String, reason: String?) {
        val receipts = rows[id]?.receipts ?: return
        receipts.replaceAll { if (it.status == "pending") it.copy(status = status, rejectReason = reason ?: it.rejectReason) else it }
    }

    override suspend fun complete(bookingId: String) = mutex.withLock {
        move(bookingId, BookingStatus.Completed, "provider")
        ActionResult.Ok(bookingId)
    }

    override suspend fun cancel(bookingId: String, reason: String?) = mutex.withLock {
        move(bookingId, BookingStatus.CancelledByBride, "bride")
        ActionResult.Ok(bookingId)
    }

    override suspend fun openDispute(bookingId: String, reason: DisputeReason, details: String?) = mutex.withLock {
        move(bookingId, BookingStatus.Disputed, "bride")
        ActionResult.Ok(bookingId)
    }

    override suspend fun bookings(active: Boolean) = mutex.withLock {
        rows.values.filter { it.summary.status.isActive == active }.map { it.summary }
    }

    override suspend fun booking(id: String): BookingDetail? = mutex.withLock {
        val row = rows[id] ?: return@withLock null
        val hidesMethods = row.summary.status == BookingStatus.Requested || row.summary.status == BookingStatus.RescheduleProposed
        // Sample bride details, as the provider would see them (never on demos).
        val paid = row.summary.status in setOf(BookingStatus.PaymentConfirmed, BookingStatus.Completed, BookingStatus.Disputed)
        val details = if (row.summary.isDemo) null else BookingBrideDetails(
            // Like the server: her name and phone only once the payment is confirmed.
            fullName = if (paid) "نورة محمد" else null, phone = if (paid) "+966551234567" else null, extraPhone = if (paid) "+966561112222" else null,
            age = 27, nationality = "سعودية", skinType = "dry", skinTone = "medium", hairType = "wavy", hairLength = "long",
            allergies = "حساسية من الحناء السوداء",
            weddingDate = row.summary.startsAt.atZone(Riyadh).toLocalDate().toString(), cityNameAr = "الدمام", cityNameEn = "Dammam",
            venue = "قاعة الماسة", guestCount = 300, notes = "أفضّل المكياج الناعم",
        )
        BookingDetail(row.summary, if (hidesMethods) emptyList() else row.paymentMethods, row.proposal, row.receipts.toList(), row.events.toList(), null, details)
    }

    override suspend fun availability() = mutex.withLock { hours }

    override suspend fun saveAvailability(availability: Availability) = mutex.withLock { hours = availability }

    override suspend fun paymentMethods() = mutex.withLock {
        methods.values.map { PaymentMethod(it.id!!, it.kind, it.label, it.accountName, it.value, it.isActive) }
    }

    override suspend fun savePaymentMethod(draft: PaymentMethodDraft): ActionResult = mutex.withLock {
        if (draft.kind == "iban" && !draft.value.uppercase().startsWith("SA")) return@withLock ActionResult.Refused("invalid_iban")
        val id = draft.id ?: UUID.randomUUID().toString()
        methods[id] = draft.copy(id = id)
        ActionResult.Ok(id)
    }

    override suspend fun deletePaymentMethod(id: String) = mutex.withLock { methods.remove(id); Unit }
}

/** Offline stand-in: keeps receipts in memory so the viewer can show what was uploaded. */
class MockReceiptStorage : ReceiptStorage {
    private val files = mutableMapOf<String, ByteArray>()

    override suspend fun upload(jpeg: ByteArray, bookingId: String): String {
        val path = "$bookingId/${UUID.randomUUID()}.jpg"
        synchronized(files) { files[path] = jpeg }
        return path
    }

    override suspend fun download(path: String): ByteArray =
        synchronized(files) { files[path] } ?: throw co.munyati.core.error.AppError.Unknown("Receipt not found.")
}
