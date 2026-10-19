package co.munyati.networking

import co.munyati.core.error.AppError
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNamingStrategy
import kotlinx.serialization.serializer

/**
 * Generic transport abstraction. Repositories depend on this interface (never on OkHttp or
 * Supabase directly) so they can be tested against a fake and the transport can be swapped.
 * Every failure is thrown as an [AppError].
 */
interface ApiClient {
    /** Sends [bodyJson] (or no body) and returns the raw response body ("" for an empty one). */
    suspend fun sendRaw(endpoint: ApiEndpoint, bodyJson: String?): String

    /** The JSON format shared by every request: snake_case on the wire, camelCase in Kotlin. */
    val json: Json get() = ApiJson
}

/** Decodes successfully regardless of body content (void RPCs, fire-and-forget calls). */
@Serializable
object EmptyResponse

/** An empty JSON object body (`{}`), for RPCs and endpoints that take no arguments. */
@Serializable
class EmptyBody

@OptIn(ExperimentalSerializationApi::class)
val ApiJson: Json = Json {
    namingStrategy = JsonNamingStrategy.SnakeCase
    ignoreUnknownKeys = true
    explicitNulls = false // nil optionals are omitted, like Swift's JSONEncoder
    coerceInputValues = true
}

suspend inline fun <reified R> ApiClient.send(endpoint: ApiEndpoint): R =
    decode(serializer<R>(), sendRaw(endpoint, null))

suspend inline fun <reified B, reified R> ApiClient.send(endpoint: ApiEndpoint, body: B): R =
    decode(serializer<R>(), sendRaw(endpoint, json.encodeToString(serializer<B>(), body)))

fun <R> ApiClient.decode(deserializer: KSerializer<R>, raw: String): R {
    @Suppress("UNCHECKED_CAST")
    if (deserializer.descriptor == EmptyResponse.serializer().descriptor) return EmptyResponse as R
    return try {
        json.decodeFromString(deserializer, raw)
    } catch (e: Exception) {
        throw AppError.Network(AppError.NetworkFailureReason.DecodingFailed)
    }
}
