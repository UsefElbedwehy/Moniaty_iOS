package co.munyati.shared.media

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Turns a picked video into what gets uploaded: a 720p H.264 MP4 (small enough to stream over
 * mobile data and to stay under the storage upload limit), a JPEG poster frame and the length in
 * seconds. Done on the phone so the backend never transcodes (cost). Same as iOS `VideoPreparer`.
 */
object VideoPreparer {
    class Prepared(val file: File, val poster: ByteArray?, val durationSeconds: Int)

    sealed class Failure : Exception() {
        data class TooLong(val maxSeconds: Int) : Failure()
        data object TooLarge : Failure()
        data object Unreadable : Failure()
    }

    suspend fun prepare(
        context: Context,
        uri: Uri,
        maxSeconds: Int = VideoLimits.MAX_SECONDS,
        maxBytes: Long = VideoLimits.MAX_BYTES,
    ): Prepared {
        val info = withContext(Dispatchers.IO) { probe(context, uri) } ?: throw Failure.Unreadable
        // A little slack: phones round a 60-second recording to 60.4 and so on.
        if (info.durationMs > maxSeconds * 1000L + 900) throw Failure.TooLong(maxSeconds)

        val output = File(context.cacheDir, "${UUID.randomUUID()}.mp4")
        try {
            export(context, uri, output, info)
        } catch (e: Exception) {
            output.delete()
            throw if (e is Failure) e else Failure.Unreadable
        }
        val size = output.length()
        if (size <= 0L) throw Failure.Unreadable
        if (size > maxBytes) {
            output.delete()
            throw Failure.TooLarge
        }
        return Prepared(output, info.poster, (info.durationMs / 1000.0).roundToInt())
    }

    private class Info(val durationMs: Long, val width: Int, val height: Int, val poster: ByteArray?)

    /** Length, displayed size (rotation applied) and a poster frame about a second in. */
    private fun probe(context: Context, uri: Uri): Info? = runCatching {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(context, uri)
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: return null
            if (duration <= 0) return null
            val w = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            val h = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            val (width, height) = if (rotation % 180 != 0) h to w else w to h
            val frame = retriever.getFrameAtTime(min(1_000_000L, duration * 500), MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            Info(duration, width, height, frame?.let(::posterJpeg))
        } finally {
            retriever.release()
        }
    }.getOrNull()

    private fun posterJpeg(frame: Bitmap): ByteArray {
        val scale = min(1f, 1280f / max(frame.width, frame.height))
        val sized = if (scale < 1f) {
            Bitmap.createScaledBitmap(frame, (frame.width * scale).roundToInt(), (frame.height * scale).roundToInt(), true)
        } else {
            frame
        }
        return ByteArrayOutputStream().use { out ->
            sized.compress(Bitmap.CompressFormat.JPEG, 80, out)
            out.toByteArray()
        }
    }

    /** Re-encodes with the short side at most 720 px. Transformer must run on a looper thread. */
    @OptIn(UnstableApi::class)
    private suspend fun export(context: Context, uri: Uri, output: File, info: Info) = withContext(Dispatchers.Main) {
        suspendCancellableCoroutine { cont ->
            val shortSide = min(info.width, info.height)
            val effects = if (shortSide > 720) {
                val scale = 720f / shortSide
                // Even dimensions: H.264 encoders reject odd ones.
                val w = ((info.width * scale).roundToInt() / 2) * 2
                val h = ((info.height * scale).roundToInt() / 2) * 2
                Effects(emptyList(), listOf(Presentation.createForWidthAndHeight(w, h, Presentation.LAYOUT_SCALE_TO_FIT)))
            } else {
                Effects.EMPTY
            }
            val transformer = Transformer.Builder(context)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        if (cont.isActive) cont.resume(Unit)
                    }

                    override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                        if (cont.isActive) cont.resumeWithException(Failure.Unreadable)
                    }
                })
                .build()
            val item = EditedMediaItem.Builder(MediaItem.fromUri(uri)).setEffects(effects).build()
            transformer.start(item, output.absolutePath)
            cont.invokeOnCancellation { transformer.cancel() }
        }
    }
}
