package co.munyati.booking

import co.munyati.booking.data.MockBookingRepository
import co.munyati.booking.data.RemoteBookingRepository
import co.munyati.booking.domain.ActionResult
import co.munyati.booking.domain.BookingStatus
import co.munyati.booking.domain.PaymentMethodDraft
import co.munyati.networking.ApiClient
import co.munyati.networking.ApiEndpoint
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.temporal.ChronoUnit

class BookingTest {
    @Test fun `status steps and active set match the SQL state machine`() {
        assertEquals(listOf(1, 1, 2, 3, 4, 5, 0, 0, 0, 0, 4), BookingStatus.entries.map { it.step })
        assertTrue(BookingStatus.Disputed.isActive)
        assertTrue(!BookingStatus.Completed.isActive)
    }

    @Test fun `mock walks a booking through its whole life`() = runTest {
        val repo = MockBookingRepository()
        val id = (repo.createBooking("s1", Instant.now().plus(2, ChronoUnit.DAYS), null) as ActionResult.Ok).id!!
        assertTrue(repo.booking(id)!!.paymentMethods.isEmpty()) // hidden until approved
        repo.approve(id)
        val approved = repo.booking(id)!!
        assertEquals(BookingStatus.AwaitingPayment, approved.summary.status)
        assertTrue(approved.paymentMethods.isNotEmpty())
        repo.submitReceipt(id, "$id/r.jpg", 2800.0, Instant.now(), null, "abc")
        repo.rejectPayment(id, "لم يصل")
        assertEquals("rejected", repo.booking(id)!!.receipts.first().status)
        repo.submitReceipt(id, "$id/r2.jpg", 2800.0, Instant.now(), null, "def")
        repo.confirmPayment(id)
        repo.complete(id)
        val done = repo.booking(id)!!
        assertEquals(BookingStatus.Completed, done.summary.status)
        assertEquals("accepted", done.receipts.first().status)
        assertEquals(7, done.events.size)
        assertTrue(repo.bookings(active = false).any { it.id == id })
    }

    @Test fun `iban must start with SA`() = runTest {
        val repo = MockBookingRepository()
        assertEquals(ActionResult.Refused("invalid_iban"), repo.savePaymentMethod(PaymentMethodDraft(label = "بنك", accountName = "لمسة", value = "GB00123")))
    }

    @Test fun `detail decodes flattened JSON with Postgres timestamps, and null is missing`() = runTest {
        var body = """{"id":"b1","reference_code":"MN-1","status":"payment_submitted","is_demo":false,"service_title":"مكياج",
            "price":2800,"starts_at":"2026-11-11T13:00:00+00:00","ends_at":"2026-11-11T16:00:00.5+00:00",
            "provider":{"id":"p1","name":"لمسة","is_verified":true},"payment_methods":[{"kind":"iban","label":"الراجحي","account_name":"لمسة","value":"SA03"}],
            "receipts":[{"id":"r1","amount":2800,"status":"pending","created_at":"2026-11-10T10:00:00+00:00"}],
            "events":[{"to_status":"requested","actor_role":"bride","created_at":"2026-11-09T10:00:00+00:00"}]}"""
        var sent = ""
        val client = object : ApiClient {
            override suspend fun sendRaw(endpoint: ApiEndpoint, bodyJson: String?): String {
                sent = bodyJson.orEmpty()
                return body
            }
        }
        val remote = RemoteBookingRepository(client)
        val detail = remote.booking("b1")!!
        assertEquals(Instant.parse("2026-11-11T13:00:00Z"), detail.summary.startsAt)
        assertEquals("SA03", detail.paymentMethods.single().value)
        assertEquals(BookingStatus.Requested, detail.events.single().toStatus)
        assertEquals("""{"p_booking":"b1"}""", sent)
        body = "null"
        assertNull(remote.booking("x"))

        body = """{"ok":true,"id":"m1"}"""
        assertEquals(ActionResult.Ok("m1"), remote.savePaymentMethod(PaymentMethodDraft(label = "بنك", accountName = "لمسة", value = "SA0380000000")))
        assertEquals(JsonNull, Json.parseToJsonElement(sent).jsonObject["p_id"]) // p_id has no SQL default
    }
}
