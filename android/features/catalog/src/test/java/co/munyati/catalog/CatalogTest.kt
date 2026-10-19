package co.munyati.catalog

import co.munyati.catalog.data.MockCatalogRepository
import co.munyati.catalog.data.RemoteCatalogRepository
import co.munyati.catalog.domain.Budget
import co.munyati.catalog.domain.ServiceFilter
import co.munyati.catalog.domain.formatAmount
import co.munyati.networking.ApiClient
import co.munyati.networking.ApiEndpoint
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

class CatalogTest {
    private val repo = MockCatalogRepository()

    @Test fun `search filters by category and sorts by price`() = runTest {
        val cards = repo.search(ServiceFilter(categoryId = "makeup", sort = ServiceFilter.Sort.PriceAsc), null, null, 0)
        assertEquals(listOf("s2", "s1"), cards.map { it.id })
    }

    @Test fun `within budget caps the price, and cities narrow providers`() = runTest {
        val cheap = repo.search(ServiceFilter(withinBudget = true), null, 1000.0, 0)
        assertEquals(listOf("s6"), cheap.map { it.id })
        val qatif = repo.search(ServiceFilter(), listOf("qatif"), null, 0)
        assertEquals(listOf("s6"), qatif.map { it.id })
    }

    @Test fun `favorites toggle on and off`() = runTest {
        assertTrue(repo.toggleFavorite("s1"))
        assertEquals(listOf("s1"), repo.favorites().map { it.id })
        assertTrue(!repo.toggleFavorite("s1"))
    }

    @Test fun `budget fraction is clamped`() {
        assertEquals(0.5f, Budget(1000.0, 500.0, 500.0).usedFraction)
        assertEquals(1f, Budget(1000.0, 1500.0, -500.0).usedFraction)
        assertEquals(0f, Budget(0.0, 0.0, 0.0).usedFraction)
    }

    @Test fun `amounts use the locale's digits`() {
        assertEquals("2,800", formatAmount(2800.0, Locale.US))
        assertEquals("٢٬٨٠٠", formatAmount(2800.0, Locale("ar")))
    }

    /** Detail RPCs put the card at the top level beside the extras; `null` means not found. */
    @Test fun `flattened service detail decodes, and null means missing`() = runTest {
        var body = """{"id":"s1","title":"مكياج","price":2800,"category_id":"makeup","provider_id":"p1","is_verified":true,
            "female_staff_only":true,"is_favorite":false,"duration_minutes":180,"image_urls":["a"],
            "provider":{"id":"p1","name":"لمسة","is_verified":true,"female_staff_only":true,"city_ids":["dammam"]}}"""
        val client = object : ApiClient {
            override suspend fun sendRaw(endpoint: ApiEndpoint, bodyJson: String?) = body
        }
        val remote = RemoteCatalogRepository(client)
        val detail = remote.service("s1")!!
        assertEquals("s1", detail.card.id)
        assertEquals(180, detail.durationMinutes)
        assertEquals("لمسة", detail.provider.name)
        assertTrue(detail.moreFromProvider.isEmpty())
        body = "null"
        assertNull(remote.service("missing"))
    }
}
