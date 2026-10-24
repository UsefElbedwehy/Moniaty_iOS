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

    /**
     * Uploads a photo with its small list copy side by side (`<id>.full.jpg`, `<id>.thumb.jpg`) and
     * returns the full photo's URL; `MediaThumbnail.url` derives the other. Same as iOS.
     */
    suspend fun uploadPhoto(photo: PreparedPhoto, folder: String): String
}

/** A picked photo ready to upload: the full photo and the small copy shown in lists and grids. */
class PreparedPhoto(val full: ByteArray, val thumbnail: ByteArray)

/**
 * Where a photo's small copy lives. Photos uploaded since thumbnails exist end in `.full.jpg` and
 * have a `.thumb.jpg` beside them; older photos have none, so they are shown as they are.
 */
object MediaThumbnail {
    const val FULL_SUFFIX = ".full.jpg"
    const val THUMBNAIL_SUFFIX = ".thumb.jpg"
    /** Longest side of the small copy: a two-column card at 3x. */
    const val MAX_DIMENSION = 600

    /** The small copy's URL, or null when the photo has none. */
    fun url(full: String?): String? =
        full?.takeIf { it.endsWith(FULL_SUFFIX) }?.let { it.removeSuffix(FULL_SUFFIX) + THUMBNAIL_SUFFIX }
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

    /** The full photo (1600 px) and its list copy (600 px), both from the picked original. */
    fun photo(context: Context, uri: Uri): PreparedPhoto? {
        val full = jpeg(context, uri) ?: return null
        val thumbnail = jpeg(context, uri, maxDimension = MediaThumbnail.MAX_DIMENSION, quality = 75) ?: return null
        return PreparedPhoto(full, thumbnail)
    }
}
