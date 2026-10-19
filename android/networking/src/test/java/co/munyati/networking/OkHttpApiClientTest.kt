package co.munyati.networking

import co.munyati.core.error.AppError
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.Serializable
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

class OkHttpApiClientTest {
    private val config = NetworkConfiguration("https://example.supabase.co", mapOf("apikey" to "anon"))

    @Test fun `builds the correct URL, path and method for an RPC endpoint`() {
        val request = OkHttpApiClient.makeRequest(ApiEndpoint.Profile.get, config, "{}").build()
        assertEquals("https://example.supabase.co/rest/v1/rpc/get_my_profile", request.url.toString())
        assertEquals("POST", request.method)
    }

    @Test fun `appends query items`() {
        val request = OkHttpApiClient.makeRequest(ApiEndpoint.Authentication.refreshToken, config, "{}").build()
        assertEquals("refresh_token", request.url.queryParameter("grant_type"))
    }

    @Test fun `applies default headers`() {
        val request = OkHttpApiClient.makeRequest(ApiEndpoint.Catalog.cities, config, null).build()
        assertEquals("anon", request.header("apikey"))
    }

    @Test fun `transport errors map to network reasons`() {
        assertEquals(AppError.Network(AppError.NetworkFailureReason.TimedOut), OkHttpApiClient.mapTransportError(SocketTimeoutException()))
        assertEquals(AppError.Network(AppError.NetworkFailureReason.NoConnection), OkHttpApiClient.mapTransportError(UnknownHostException()))
        assertEquals(AppError.Network(AppError.NetworkFailureReason.Cancelled), OkHttpApiClient.mapTransportError(IOException("Canceled")))
        assertTrue(OkHttpApiClient.mapTransportError(IOException("boom")) is AppError.Unknown)
    }

    @Test fun `HTTP errors map like iOS`() {
        assertEquals(AppError.Authentication(AppError.AuthFailureReason.SessionExpired), OkHttpApiClient.mapHttpError(401, ""))
        assertEquals(AppError.Validation(null, "bad phone"), OkHttpApiClient.mapHttpError(400, """{"message":"bad phone"}"""))
        assertEquals(AppError.Server(422, null), OkHttpApiClient.mapHttpError(422, "nope"))
        assertEquals(AppError.Server(500, null), OkHttpApiClient.mapHttpError(500, ""))
        assertEquals(AppError.Server(500, "down"), OkHttpApiClient.mapHttpError(500, """{"message":"down"}"""))
    }

    // End to end against a local server

    private lateinit var server: MockWebServer

    @Before fun start() { server = MockWebServer().apply { start() } }
    @After fun stop() = server.shutdown()

    @Serializable private data class Args(val pCityIds: List<String>)
    @Serializable private data class Profile(val displayName: String, val isAnonymous: Boolean, val missing: String? = null)

    @Test fun `encodes snake_case, decodes snake_case and sends the bearer`() = runTest {
        server.enqueue(MockResponse().setBody("""{"display_name":"نورة","is_anonymous":false,"extra":1}"""))
        val client = OkHttpApiClient(NetworkConfiguration(server.url("/").toString()), authTokenProvider = { "user-token" })
        val profile: Profile = client.send(ApiEndpoint.Profile.get, Args(listOf("dammam")))
        assertEquals(Profile("نورة", false), profile)
        val recorded = server.takeRequest()
        assertEquals("""{"p_city_ids":["dammam"]}""", recorded.body.readUtf8())
        assertEquals("Bearer user-token", recorded.getHeader("Authorization"))
        assertNull(profile.missing)
    }

    @Test fun `a void RPC's empty 204 decodes as EmptyResponse`() = runTest {
        server.enqueue(MockResponse().setResponseCode(204))
        val client = OkHttpApiClient(NetworkConfiguration(server.url("/").toString()))
        val result: EmptyResponse = client.send(ApiEndpoint.Profile.setCities, Args(emptyList()))
        assertEquals(EmptyResponse, result)
    }

    @Test fun `a body that doesn't match throws decodingFailed`() = runTest {
        server.enqueue(MockResponse().setBody("[]"))
        val client = OkHttpApiClient(NetworkConfiguration(server.url("/").toString()))
        val error = runCatching { client.send<Profile>(ApiEndpoint.Profile.get) }.exceptionOrNull()
        assertEquals(AppError.Network(AppError.NetworkFailureReason.DecodingFailed), error)
    }
}
