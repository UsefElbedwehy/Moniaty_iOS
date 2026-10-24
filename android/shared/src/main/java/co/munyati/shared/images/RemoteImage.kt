package co.munyati.shared.images

import androidx.compose.foundation.background
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import co.munyati.shared.media.MediaThumbnail
import coil.compose.AsyncImage

/**
 * A remote image with a tinted placeholder while it loads (or when there is no URL). Coil caches
 * in memory and on disk, like the iOS `RemoteImageView`. `thumbnail = true` for small spots
 * (cards, rows, avatars): loads the photo's small copy when it has one (`MediaThumbnail`), a
 * fraction of the bytes, and falls back to the full photo if that copy fails.
 */
@Composable
fun RemoteImage(
    url: String?,
    modifier: Modifier = Modifier,
    placeholder: Color = Color.Transparent,
    contentScale: ContentScale = ContentScale.Crop,
    contentDescription: String? = null,
    thumbnail: Boolean = false,
) {
    val small = if (thumbnail) MediaThumbnail.url(url) else null
    var smallFailed by remember(url) { mutableStateOf(false) }
    AsyncImage(
        model = if (small != null && !smallFailed) small else url,
        contentDescription = contentDescription,
        contentScale = contentScale,
        modifier = modifier.background(placeholder),
        onError = { if (small != null) smallFailed = true },
    )
}
