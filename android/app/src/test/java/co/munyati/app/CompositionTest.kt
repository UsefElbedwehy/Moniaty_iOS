package co.munyati.app

import co.munyati.app.backend.City
import co.munyati.app.composition.CityFilterStore
import co.munyati.app.composition.DeepLink
import co.munyati.app.composition.RemoteConfigStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

class CompositionTest {
    @Test fun `web and scheme links parse to the same destinations`() {
        assertEquals(DeepLink.Provider("42"), DeepLink.parse("https", "munyati.co", listOf("p", "42")))
        assertEquals(DeepLink.Provider("42"), DeepLink.parse("munyati", "p", listOf("42")))
        assertEquals(DeepLink.Store("7"), DeepLink.parse("https", "www.munyati.co", listOf("store", "7")))
        assertEquals(DeepLink.Booking("b1"), DeepLink.parse("munyati", "b", listOf("b1")))
        assertEquals(DeepLink.Plans, DeepLink.parse("https", "munyati.co", listOf("plans")))
        assertEquals(DeepLink.Notifications, DeepLink.parse("munyati", "notifications", emptyList()))
    }

    @Test fun `unknown hosts, schemes and missing ids are rejected`() {
        assertNull(DeepLink.parse("https", "example.com", listOf("p", "1")))
        assertNull(DeepLink.parse("http", "munyati.co", listOf("p", "1")))
        assertNull(DeepLink.parse("https", "munyati.co", listOf("p")))
        assertNull(DeepLink.parse("munyati", "unknown", listOf("1")))
    }

    @Test fun `web URLs round-trip`() {
        assertEquals("https://munyati.co/c/makeup", DeepLink.Category("makeup").webUrl)
    }

    @Test fun `versions compare numerically`() {
        assertTrue(RemoteConfigStore.compareVersions("1.9", "1.10") < 0)
        assertTrue(RemoteConfigStore.compareVersions("2.0", "1.10") > 0)
        assertEquals(0, RemoteConfigStore.compareVersions("1.0", "1.0.0"))
    }

    @Test fun `choosing every city means All`() {
        val store = CityFilterStore().apply {
            available = listOf(City("dammam", "الدمام", "Dammam"), City("khobar", "الخبر", "Khobar"), City("qatif", "القطيف", "Qatif"))
        }
        store.toggle("dammam")
        store.toggle("khobar")
        assertEquals(listOf("dammam", "khobar"), store.queryCityIds)
        assertEquals("الدمام، الخبر", store.summary("الكل", Locale("ar")))
        store.toggle("qatif")
        assertTrue(store.isAll)
        assertNull(store.queryCityIds)
    }
}
