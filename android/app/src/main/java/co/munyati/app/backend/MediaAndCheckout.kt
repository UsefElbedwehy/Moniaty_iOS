package co.munyati.app.backend

import co.munyati.core.error.AppError
import co.munyati.providerstudio.domain.CheckoutStart
import co.munyati.providerstudio.domain.PlanCheckout
import co.munyati.providerstudio.domain.PlanPaymentStatus
import co.munyati.shared.media.MediaUploading
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.TimeUnit

/**
 * Uploads picked images and videos to the public `media` bucket under the signed-in user's own
 * folder (`<uid>/<folder>/<uuid>.<ext>`), which the storage policies require. Same as iOS.
 */
class SupabaseMediaUploader(
    private val baseUrl: String,
    private val anonKey: String,
    private val accessToken: suspend () -> String?,
    private val currentUserId: suspend () -> String?,
    private val http: OkHttpClient = OkHttpClient.Builder()
        // Videos can take a while on mobile data.
        .writeTimeout(5, TimeUnit.MINUTES)
        .build(),
) : MediaUploading {
    override suspend fun uploadJpeg(jpeg: ByteArray, folder: String): String =
        upload("jpg", folder, jpeg.toRequestBody("image/jpeg".toMediaType()))

    override suspend fun uploadFile(file: File, contentType: String, fileExtension: String, folder: String): String =
        upload(fileExtension, folder, file.asRequestBody(contentType.toMediaType()))

    private suspend fun upload(fileExtension: String, folder: String, body: RequestBody): String {
        val uid = currentUserId() ?: throw AppError.Authentication(AppError.AuthFailureReason.NotAuthenticated)
        val token = accessToken() ?: throw AppError.Authentication(AppError.AuthFailureReason.NotAuthenticated)
        val path = "$uid/$folder/${UUID.randomUUID()}.$fileExtension"
        val request = Request.Builder()
            .url("${baseUrl.trimEnd('/')}/storage/v1/object/media/$path")
            .header("apikey", anonKey)
            .header("Authorization", "Bearer $token")
            // Paths are never reused, so the bytes are immutable: cache for a year (cuts egress cost).
            .header("Cache-Control", "public, max-age=31536000, immutable")
            .post(body)
            .build()
        val code = withContext(Dispatchers.IO) {
            try {
                http.newCall(request).execute().use { it.code }
            } catch (e: IOException) {
                throw AppError.Network(AppError.NetworkFailureReason.NoConnection)
            }
        }
        if (code !in 200..299) throw AppError.Server(code, "Upload failed.")
        return "${baseUrl.trimEnd('/')}/storage/v1/object/public/media/$path"
    }
}

/**
 * Offline stand-in: pretends the upload worked. Photos come back as a placeholder image; files
 * are kept on the device so a picked video still plays back.
 */
class MockMediaUploader(private val keepDir: File) : MediaUploading {
    override suspend fun uploadJpeg(jpeg: ByteArray, folder: String) = "https://picsum.photos/seed/${UUID.randomUUID()}/800/600"

    override suspend fun uploadFile(file: File, contentType: String, fileExtension: String, folder: String): String =
        withContext(Dispatchers.IO) {
            val kept = File(keepDir, "${UUID.randomUUID()}.$fileExtension")
            file.copyTo(kept)
            kept.toURI().toString()
        }
}

/**
 * Provider plan payments through the `tap-checkout` edge function (Tap hosted checkout). The
 * function prices the plan on the server and settles open payments with Tap when asked.
 */
class TapPlanCheckout(
    private val baseUrl: String,
    private val anonKey: String,
    private val accessToken: suspend () -> String?,
    private val http: OkHttpClient = OkHttpClient(),
) : PlanCheckout {
    @Serializable
    private data class Response(
        @SerialName("payment_id") val paymentId: String? = null,
        val url: String? = null,
        val status: String? = null,
        val error: String? = null,
    )

    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun start(planId: String): CheckoutStart {
        val response = call(mapOf("plan_id" to planId))
        val id = response.paymentId
        val url = response.url
        return if (id != null && url != null) CheckoutStart.Open(id, url) else CheckoutStart.Refused(response.error ?: "generic")
    }

    override suspend fun status(paymentId: String): PlanPaymentStatus =
        PlanPaymentStatus.from(call(mapOf("payment_id" to paymentId)).status) ?: PlanPaymentStatus.Initiated

    private suspend fun call(body: Map<String, String>): Response {
        val token = accessToken() ?: throw AppError.Authentication(AppError.AuthFailureReason.NotAuthenticated)
        val request = Request.Builder()
            .url("${baseUrl.trimEnd('/')}/functions/v1/tap-checkout")
            .header("apikey", anonKey)
            .header("Authorization", "Bearer $token")
            .post(json.encodeToString(kotlinx.serialization.json.JsonObject.serializer(),
                kotlinx.serialization.json.JsonObject(body.mapValues { kotlinx.serialization.json.JsonPrimitive(it.value) }))
                .toRequestBody("application/json".toMediaType()))
            .build()
        val (code, text) = withContext(Dispatchers.IO) {
            try {
                http.newCall(request).execute().use { it.code to it.body?.string().orEmpty() }
            } catch (e: IOException) {
                throw AppError.Network(AppError.NetworkFailureReason.NoConnection)
            }
        }
        if (code !in 200..299) throw AppError.Server(code, "Plan checkout failed.")
        return json.decodeFromString(Response.serializer(), text)
    }
}

/**
 * Payment receipts live in the private `receipts` bucket under `<bookingId>/`; the storage
 * policies let only the booking's bride, its provider and admins read them. Same as iOS.
 */
class SupabaseReceiptStorage(
    private val baseUrl: String,
    private val anonKey: String,
    private val accessToken: suspend () -> String?,
    private val http: OkHttpClient = OkHttpClient(),
) : co.munyati.booking.data.ReceiptStorage {
    override suspend fun upload(jpeg: ByteArray, bookingId: String): String {
        val path = "$bookingId/${UUID.randomUUID()}.jpg"
        val request = authorized("storage/v1/object/receipts/$path").post(jpeg.toRequestBody("image/jpeg".toMediaType())).build()
        execute(request, "Receipt upload failed.")
        return path
    }

    override suspend fun download(path: String): ByteArray =
        execute(authorized("storage/v1/object/authenticated/receipts/$path").get().build(), "Receipt download failed.")

    private suspend fun authorized(path: String): Request.Builder {
        val token = accessToken() ?: throw AppError.Authentication(AppError.AuthFailureReason.NotAuthenticated)
        return Request.Builder().url("${baseUrl.trimEnd('/')}/$path").header("apikey", anonKey).header("Authorization", "Bearer $token")
    }

    private suspend fun execute(request: Request, failure: String): ByteArray = withContext(Dispatchers.IO) {
        val (code, bytes) = try {
            http.newCall(request).execute().use { it.code to (it.body?.bytes() ?: ByteArray(0)) }
        } catch (e: IOException) {
            throw AppError.Network(AppError.NetworkFailureReason.NoConnection)
        }
        if (code !in 200..299) throw AppError.Server(code, failure)
        bytes
    }
}
