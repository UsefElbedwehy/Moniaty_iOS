package co.munyati.shared.media

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Uploads an image or video the user picked (service photos, logos) and returns its public URL. Implemented
 * in the App against Supabase Storage; features stay storage-agnostic. Same as iOS `MediaUploading`.
 */
interface MediaUploading {
    /** `jpeg` is already resized/compressed. `folder` is a short label such as "services" or "logos". */
    suspend fun uploadJpeg(jpeg: ByteArray, folder: String): String

    /** Uploads a file already on disk (a prepared video), streamed rather than read into memory. */
    suspend fun uploadFile(file: java.io.File, contentType: String, fileExtension: String, folder: String): String
}

/**
 * Downscales and JPEG-encodes picked photos before upload (small uploads, no paid server-side
 * transforms). Longest side 1600 px at quality 80, like iOS `ImageCompressor`.
 */
object ImageCompressor {
    fun jpeg(context: Context, uri: Uri, maxDimension: Int = 1600, quality: Int = 80): ByteArray? = runCatching {
        val resolver = context.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        val longest = max(bounds.outWidth, bounds.outHeight).takeIf { it > 0 } ?: return null
        // Decode at the nearest power of two above the target, then scale exactly.
        var sample = 1
        while (longest / (sample * 2) >= maxDimension) sample *= 2
        val decoded = resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: return null
        val scale = minOf(1f, maxDimension.toFloat() / max(decoded.width, decoded.height))
        val resized = if (scale < 1f) {
            Bitmap.createScaledBitmap(decoded, (decoded.width * scale).roundToInt(), (decoded.height * scale).roundToInt(), true)
        } else {
            decoded
        }
        ByteArrayOutputStream().use { out ->
            resized.compress(Bitmap.CompressFormat.JPEG, quality, out)
            out.toByteArray()
        }
    }.getOrNull()
}
