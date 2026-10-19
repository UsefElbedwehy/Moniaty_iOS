package co.munyati.networking

import co.munyati.core.error.AppError
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * OkHttp-backed [ApiClient]: the only place in the app that knows about OkHttp, HTTP status codes
 * or the JSON wire format. Authentication is injected as an opaque token provider so this module
 * never knows about the Authentication feature — it just asks for a bearer token before each call.
 */
class OkHttpApiClient(
    private val configuration: NetworkConfiguration,
    private val authTokenProvider: (suspend () -> String?)? = null,
    httpClient: OkHttpClient = OkHttpClient(),
) : ApiClient {
    private val http = httpClient.newBuilder()
        .callTimeout(configuration.timeoutSeconds, TimeUnit.SECONDS)
        .build()

    override suspend fun sendRaw(endpoint: ApiEndpoint, bodyJson: String?): String {
        val builder = makeRequest(endpoint, configuration, bodyJson)
        authTokenProvider?.invoke()?.let { builder.header("Authorization", "Bearer $it") }

        val response = try {
            http.newCall(builder.build()).await()
        } catch (e: IOException) {
            throw mapTransportError(e)
        }
        return response.use {
            val body = withContext(Dispatchers.IO) { it.body?.string().orEmpty() }
            if (!it.isSuccessful) throw mapHttpError(it.code, body)
            body
        }
    }

    companion object {
        private val JSON = "application/json".toMediaType()

        /** Builds the request from the base URL and endpoint. Pure, so it can be unit tested. */
        fun makeRequest(endpoint: ApiEndpoint, configuration: NetworkConfiguration, bodyJson: String?): Request.Builder {
            val url = (configuration.baseUrl.trimEnd('/') + endpoint.path).toHttpUrl().newBuilder().apply {
                endpoint.queryItems.forEach { (name, value) -> addQueryParameter(name, value) }
            }.build()
            val body = bodyJson?.toRequestBody(JSON)
                ?: if (endpoint.method == ApiEndpoint.HttpMethod.GET) null else ByteArray(0).toRequestBody(null)
            return Request.Builder().url(url).method(endpoint.method.name, body).apply {
                configuration.defaultHeaders.forEach { (key, value) -> header(key, value) }
            }
        }

        /** Maps a failure thrown before any HTTP response arrived. */
        fun mapTransportError(error: IOException): AppError = when (error) {
            is UnknownHostException, is ConnectException -> AppError.Network(AppError.NetworkFailureReason.NoConnection)
            is SocketTimeoutException -> AppError.Network(AppError.NetworkFailureReason.TimedOut)
            else -> if (error.message == "Canceled") {
                AppError.Network(AppError.NetworkFailureReason.Cancelled)
            } else {
                AppError.Unknown(error.localizedMessage)
            }
        }

        /** Maps a non-2xx response, best-effort reading a `{ "message": ... }` error body. */
        fun mapHttpError(statusCode: Int, body: String): AppError {
            val serverMessage = runCatching { ApiJson.decodeFromString(ApiErrorResponse.serializer(), body).message }.getOrNull()
            return when (statusCode) {
                401 -> AppError.Authentication(AppError.AuthFailureReason.SessionExpired)
                400, 422 -> if (serverMessage != null) {
                    AppError.Validation(field = null, message = serverMessage)
                } else {
                    AppError.Server(statusCode, null)
                }
                else -> AppError.Server(statusCode, serverMessage)
            }
        }
    }
}

@Serializable
internal data class ApiErrorResponse(val message: String? = null)

private suspend fun Call.await(): Response = suspendCancellableCoroutine { continuation ->
    enqueue(object : Callback {
        override fun onResponse(call: Call, response: Response) = continuation.resume(response)
        override fun onFailure(call: Call, e: IOException) {
            if (!continuation.isCancelled) continuation.resumeWithException(e)
        }
    })
    continuation.invokeOnCancellation { runCatching { cancel() } }
}
