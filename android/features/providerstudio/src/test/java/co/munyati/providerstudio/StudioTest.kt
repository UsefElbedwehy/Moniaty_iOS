package co.munyati.providerstudio

import co.munyati.networking.ApiClient
import co.munyati.networking.ApiEndpoint
import co.munyati.providerstudio.data.MockPlanCheckout
import co.munyati.providerstudio.data.MockStudioRepository
import co.munyati.providerstudio.data.RemoteStudioRepository
import co.munyati.providerstudio.domain.BusinessDraft
import co.munyati.providerstudio.domain.Entitlement
import co.munyati.providerstudio.domain.SaveResult
import co.munyati.providerstudio.domain.ServiceDraft
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class StudioTest {
    @Test fun `prices accept Arabic digits and the Arabic decimal sign`() {
        assertEquals(250.5, ServiceDraft(priceText = "٢٥٠٫٥").price)
        assertEquals(2800.0, ServiceDraft(priceText = "2,800").price)
        assertNull(ServiceDraft(priceText = "").price)
        assertTrue(!ServiceDraft(title = "مكياج", priceText = "100").isValid) // no category
    }

    @Test fun `entitlement counts days to the end of paid time`() {
        val now = Instant.parse("2026-10-20T00:00:00Z")
        val trial = Entitlement(Entitlement.State.Trial, trialEndsAtRaw = "2026-10-30T00:00:00+00:00")
        assertEquals(10, trial.daysLeft(now))
        val paid = Entitlement(Entitlement.State.Subscribed, periodEndsAtRaw = "2026-11-01T00:00:00Z", paidUntilRaw = "2026-12-01T00:00:00.123456+00:00")
        assertEquals(Instant.parse("2026-12-01T00:00:00.123456Z"), paid.listedUntil)
        assertNull(Entitlement(Entitlement.State.Expired).daysLeft(now))
    }

    @Test fun `mock enforces the plan limit and a payment changes the plan`() = runTest {
        val repo = MockStudioRepository()
        repo.updateBusiness(BusinessDraft(businessName = "لمسة"))
        assertEquals(Entitlement.State.Trial, repo.subscription().entitlement.state)
        MockPlanCheckout(repo).start("normal") // 1 service allowed
        assertTrue(repo.saveService(ServiceDraft(title = "مكياج", categoryId = "makeup", priceText = "100")) is SaveResult.Saved)
        assertEquals(SaveResult.LimitReached(1), repo.saveService(ServiceDraft(title = "حناء", categoryId = "henna", priceText = "50")))
        assertEquals(Entitlement.State.Subscribed, repo.subscription().entitlement.state)
        assertTrue(repo.subscription().entitlement.daysLeft()!! in 28..31)
    }

    /** `p_id` has no SQL default: a new service must send it as an explicit null. */
    @Test fun `new services send p_id null and decode the limit`() = runTest {
        var sent = ""
        val client = object : ApiClient {
            override suspend fun sendRaw(endpoint: ApiEndpoint, bodyJson: String?): String {
                sent = bodyJson.orEmpty()
                return """{"ok":false,"error":"limit","max_services":3}"""
            }
        }
        val result = RemoteStudioRepository(client).saveService(ServiceDraft(title = "مكياج", categoryId = "makeup", priceText = "100"))
        assertEquals(SaveResult.LimitReached(3), result)
        val body = Json.parseToJsonElement(sent).jsonObject
        assertEquals(JsonNull, body["p_id"])
        assertEquals("مكياج", body["p_title"].toString().trim('"'))
    }

}
