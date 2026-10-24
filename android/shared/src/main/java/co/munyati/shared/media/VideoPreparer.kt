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
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.InAppMuxer
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
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
            try {
                export(context, uri, output, info, tuned = true)
            } catch (e: Failure) {
                // An unusual file or encoder: retry the plain way (system muxer, default bitrate).
                output.delete()
                export(context, uri, output, info, tuned = false)
            }
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

    private class Info(val durationMs: Long, val width: Int, val height: Int, val bitrate: Int, val poster: ByteArray?)

    /**
     * The video bitrate to encode at, or null to keep the original stream (already 720p or less and
     * light enough). 2.5 Mbit/s is clear 720p on a phone, about 19 MB a minute; a lighter source keeps
     * its own rate, so re-encoding never makes a file bigger. Same numbers as iOS `VideoEncoding`.
     */
    internal fun targetVideoBitrate(shortSide: Int, sourceBitrate: Int): Int? {
        if (shortSide in 1..720 && sourceBitrate in 1..KEEP_UNDER_BITRATE) return null
        if (sourceBitrate <= 0) return TARGET_VIDEO_BITRATE
        return sourceBitrate.coerceIn(500_000, TARGET_VIDEO_BITRATE)
    }

    internal const val TARGET_VIDEO_BITRATE = 2_500_000
    private const val KEEP_UNDER_BITRATE = 3_000_000

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
            val bitrate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toIntOrNull() ?: 0
            val frame = retriever.getFrameAtTime(min(1_000_000L, duration * 500), MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            Info(duration, width, height, bitrate, frame?.let(::posterJpeg))
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

    /**
     * Re-encodes with the short side at most 720 px at `targetVideoBitrate`, into an MP4 whose index
     * comes first (the in-app muxer), so playback starts before the download ends. Transformer must
     * run on a looper thread.
     */
    @OptIn(UnstableApi::class)
    private suspend fun export(context: Context, uri: Uri, output: File, info: Info, tuned: Boolean) = withContext(Dispatchers.Main) {
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
            val bitrate = if (tuned) targetVideoBitrate(shortSide, info.bitrate) else null
            val transformer = Transformer.Builder(context)
                .apply {
                    if (bitrate != null) {
                        setEncoderFactory(
                            DefaultEncoderFactory.Builder(context)
                                .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(bitrate).build())
                                .build(),
                        )
                    }
                    if (tuned) setMuxerFactory(InAppMuxer.Factory.Builder().build())
                }
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
