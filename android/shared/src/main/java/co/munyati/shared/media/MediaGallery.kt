package co.munyati.shared.media

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.R
import co.munyati.shared.images.RemoteImage
import kotlinx.coroutines.launch

/**
 * The photo and video strip at the top of a detail page (as in Lamha Ads): swipe through the
 * items, see "2 / 5" and dots, jump with the thumbnails, and tap to open [MediaViewer].
 * Same as iOS `MediaGallery`.
 */
@Composable
fun MediaGallery(items: List<GalleryItem>, modifier: Modifier = Modifier, height: Dp = 320.dp) {
    val pager = rememberPagerState { items.size.coerceAtLeast(1) }
    var viewerOpen by rememberSaveable { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    LaunchedEffect(pager.currentPage) { if (items.size > 1) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove) }

    Column(modifier, verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
        Box(Modifier.fillMaxWidth().height(height).background(DS.colors.primaryMuted)) {
            if (items.isEmpty()) {
                Icon(
                    Icons.Outlined.PhotoLibrary, stringResource(R.string.shared_media_empty),
                    Modifier.size(44.dp).align(Alignment.Center), tint = DS.colors.primary.copy(alpha = 0.5f),
                )
            } else {
                HorizontalPager(pager, Modifier.fillMaxSize(), key = { items[it].key }) { page ->
                    val label = itemLabel(items[page], page, items.size)
                    val hint = stringResource(R.string.shared_media_openHint)
                    GalleryTile(
                        items[page], playSize = 64.dp,
                        modifier = Modifier.fillMaxSize()
                            .clickable(onClickLabel = hint, role = Role.Button) { viewerOpen = true }
                            .semantics { contentDescription = label },
                    )
                }
                if (items.size > 1) {
                    Box(Modifier.fillMaxWidth().align(Alignment.BottomCenter).padding(DSSpacing.md)) {
                        Box(Modifier.align(Alignment.CenterStart)) { Counter(pager.currentPage + 1, items.size) }
                        Box(Modifier.align(Alignment.Center)) { Dots(items.size, pager.currentPage) }
                    }
                }
            }
        }
        if (items.size > 1) {
            val listState = rememberLazyListState()
            LaunchedEffect(pager.currentPage) { listState.animateScrollToItem((pager.currentPage - 2).coerceAtLeast(0)) }
            LazyRow(
                state = listState,
                contentPadding = PaddingValues(horizontal = DSSpacing.lg, vertical = 2.dp),
                horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
            ) {
                itemsIndexed(items, key = { _, item -> item.key }) { index, item ->
                    val selected = index == pager.currentPage
                    val label = itemLabel(item, index, items.size)
                    GalleryTile(
                        item, playSize = 20.dp,
                        modifier = Modifier.width(64.dp).height(48.dp)
                            .clip(RoundedCornerShape(DSRadius.control))
                            .border(2.dp, if (selected) DS.colors.primary else Color.Transparent, RoundedCornerShape(DSRadius.control))
                            .clickable(role = Role.Button) { scope.launch { pager.animateScrollToPage(index) } }
                            .semantics { contentDescription = label; this.selected = selected },
                        dimmed = !selected,
                    )
                }
            }
        }
    }

    if (viewerOpen) {
        MediaViewer(
            items = items,
            startIndex = pager.currentPage,
            onIndexChange = { scope.launch { pager.scrollToPage(it) } },
            onDismiss = { viewerOpen = false },
        )
    }
}

@Composable
internal fun itemLabel(item: GalleryItem, index: Int, count: Int): String = when (item) {
    is GalleryItem.Image -> stringResource(R.string.shared_media_photo, index + 1, count)
    is GalleryItem.Video -> stringResource(R.string.shared_media_video, index + 1, count)
}

/** "2 / 5", isolated left-to-right so it reads the same in Arabic. */
@Composable
internal fun Counter(current: Int, count: Int, large: Boolean = false) {
    Text(
        "⁦$current / $count⁩",
        style = (if (large) DS.type.subhead else DS.type.caption).copy(fontWeight = FontWeight.SemiBold),
        color = Color.White,
        modifier = Modifier.clip(CircleShape).background(Color.Black.copy(alpha = 0.45f))
            .padding(horizontal = if (large) DSSpacing.md else DSSpacing.sm, vertical = if (large) DSSpacing.xs else DSSpacing.xxs),
    )
}

@Composable
private fun Dots(count: Int, current: Int) {
    // Long galleries get smaller dots so they still fit.
    val unit = if (count > 12) 4.dp else 6.dp
    Row(
        Modifier.clip(CircleShape).background(Color.Black.copy(alpha = 0.35f)).padding(horizontal = DSSpacing.xs, vertical = 5.dp),
        horizontalArrangement = Arrangement.spacedBy(unit * 0.8f),
    ) {
        repeat(count) { i ->
            val width by animateDpAsState(if (i == current) unit * 3 else unit, label = "dot")
            Box(Modifier.width(width).height(unit).clip(CircleShape).background(Color.White.copy(alpha = if (i == current) 1f else 0.45f)))
        }
    }
}

/** A photo, or a video's poster with a play button and its length (on large tiles). */
@Composable
fun GalleryTile(item: GalleryItem, playSize: Dp, modifier: Modifier = Modifier, dimmed: Boolean = false) {
    Box(modifier) {
        when (item) {
            is GalleryItem.Image -> RemoteImage(item.url, Modifier.fillMaxSize(), placeholder = DS.colors.primaryMuted)
            is GalleryItem.Video -> {
                Box(Modifier.fillMaxSize().background(Color.Black))
                item.video.posterUrl?.let { RemoteImage(it, Modifier.fillMaxSize()) }
                Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.25f)))
                Box(
                    Modifier.size(playSize).align(Alignment.Center).clip(CircleShape).background(Color.Black.copy(alpha = 0.55f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.PlayArrow, null, Modifier.size(playSize * 0.5f), tint = Color.White)
                }
                val length = item.video.durationText
                if (playSize > 30.dp && length != null) {
                    Text(
                        "⁦$length⁩", style = DS.type.caption.copy(fontWeight = FontWeight.SemiBold), color = Color.White,
                        modifier = Modifier.align(Alignment.TopEnd).padding(DSSpacing.md).clip(CircleShape)
                            .background(Color.Black.copy(alpha = 0.55f)).padding(horizontal = DSSpacing.xs, vertical = 2.dp),
                    )
                }
            }
        }
        if (dimmed) Box(Modifier.fillMaxSize().background(Color.White.copy(alpha = 0.3f)))
    }
}
