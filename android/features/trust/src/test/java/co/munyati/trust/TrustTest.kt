package co.munyati.trust

import co.munyati.networking.ApiClient
import co.munyati.networking.ApiEndpoint
import co.munyati.trust.data.MockTrustRepository
import co.munyati.trust.data.RemoteTrustRepository
import co.munyati.trust.domain.ReportReason
import co.munyati.trust.domain.ReportTarget
import co.munyati.trust.domain.SupportContact
import co.munyati.trust.domain.TrustResult
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TrustTest {
    @Test fun `a booking can be reviewed once and the summary updates`() = runTest {
        val repo = MockTrustRepository()
        assertEquals(2, repo.providerReviews("p-lamsa", 3, 0).ratingCount)
        assertTrue(repo.myReview("b1")!!.canReview)
        assertEquals(TrustResult.Ok, repo.submitReview("b1", 3, "جيد", emptyList()))
        assertEquals(TrustResult.Refused("already_reviewed"), repo.submitReview("b1", 5, null, emptyList()))
        val page = repo.providerReviews("p-lamsa", 3, 0)
        assertEquals(3, page.ratingCount)
        assertEquals(4.0, page.ratingAvg!!, 0.001)
        assertEquals(1, page.distribution["3"])
        assertEquals(3, repo.myReview("b1")!!.review!!.rating)
    }

    @Test fun `block and unblock`() = runTest {
        val repo = MockTrustRepository()
        repo.block("u1")
        repo.block("u1")
        assertEquals(1, repo.blockedUsers().size)
        repo.unblock("u1")
        assertTrue(repo.blockedUsers().isEmpty())
    }

    @Test fun `support contacts open the right apps`() {
        assertEquals("https://wa.me/966500000000", SupportContact(SupportContact.Kind.Whatsapp, "+966 50 000 0000").url)
        assertEquals("tel:+966500000000", SupportContact(SupportContact.Kind.Phone, "+966 50-000-0000").url)
        assertEquals("mailto:contact@munyati.co", SupportContact(SupportContact.Kind.Email, "contact@munyati.co").url)
    }

    @Test fun `reports send the SQL target type and decode refusals`() = runTest {
        var sent = ""
        val client = object : ApiClient {
            override suspend fun sendRaw(endpoint: ApiEndpoint, bodyJson: String?): String {
                sent = bodyJson.orEmpty()
                return """{"ok":false,"error":"too_many"}"""
            }
        }
        val result = RemoteTrustRepository(client).report(ReportTarget.Review("r1"), ReportReason.Fake, null)
        assertEquals(TrustResult.Refused("too_many"), result)
        assertEquals("""{"p_target_type":"review","p_target_id":"r1","p_reason":"fake"}""", sent)
    }
}
