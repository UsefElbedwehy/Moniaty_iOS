package co.munyati.shared.media

import kotlinx.serialization.Serializable

/**
 * A video on a service: the file, a poster frame made at upload, and its length. Serializes to
 * the backend shape `{url, poster_url, duration_seconds}` (the JSON config converts key case).
 * Same as iOS `VideoAsset`.
 */
@Serializable
data class VideoAsset(
    val url: String,
    val posterUrl: String? = null,
    val durationSeconds: Int? = null,
) {
    /** "0:42"-style length for badges. */
    val durationText: String?
        get() = durationSeconds?.takeIf { it > 0 }?.let { "%d:%02d".format(java.util.Locale.ROOT, it / 60, it % 60) }
}

/** One page of a media gallery: a photo or a video. */
sealed interface GalleryItem {
    val key: String

    data class Image(val url: String) : GalleryItem {
        override val key get() = "i:$url"
    }

    data class Video(val video: VideoAsset) : GalleryItem {
        override val key get() = "v:${video.url}"
    }

    companion object {
        /** Photos first, then videos (the order the provider added them in each group). */
        fun items(images: List<String>, videos: List<VideoAsset>): List<GalleryItem> =
            images.map(::Image) + videos.map(::Video)
    }
}

/** Limits for videos a provider adds to a service (the backend allows at most 3 per service). */
object VideoLimits {
    const val PER_SERVICE = 3
    const val MAX_SECONDS = 60
    /** Supabase Storage's upload limit on the current plan. */
    const val MAX_BYTES = 50L * 1024 * 1024
}
