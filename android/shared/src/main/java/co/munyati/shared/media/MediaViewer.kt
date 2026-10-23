package co.munyati.shared.media

import android.content.Intent
import android.view.ViewGroup
import androidx.annotation.OptIn
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChanged
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.R
import coil.compose.SubcomposeAsyncImage
import kotlinx.coroutines.launch
import kotlin.math.abs

/**
 * Full-screen photo and video viewer (the Lamha Ads viewer): swipe between items, pinch or
 * double-tap to zoom a photo, drag down to close, tap to hide the controls. Exactly one video
 * plays: the one on screen. Same as iOS `MediaViewer`.
 */
@Composable
fun MediaViewer(items: List<GalleryItem>, startIndex: Int, onIndexChange: (Int) -> Unit = {}, onDismiss: () -> Unit) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
        // Full screen like iOS: hide the status and navigation bars while the viewer is open.
        val window = (LocalView.current.parent as? DialogWindowProvider)?.window
        DisposableEffect(window) {
            window?.let {
                // Draw under where the bars and the camera cutout were, not below them.
                WindowCompat.setDecorFitsSystemWindows(it, false)
                it.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
                if (android.os.Build.VERSION.SDK_INT >= 28) {
                    it.attributes = it.attributes.apply {
                        layoutInDisplayCutoutMode = android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                    }
                }
            }
            val controller = window?.let { WindowCompat.getInsetsController(it, it.decorView) }
            controller?.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller?.hide(WindowInsetsCompat.Type.systemBars())
            onDispose { controller?.show(WindowInsetsCompat.Type.systemBars()) }
        }
        ViewerContent(items, startIndex, onIndexChange, onDismiss)
    }
}

@Composable
private fun ViewerContent(items: List<GalleryItem>, startIndex: Int, onIndexChange: (Int) -> Unit, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val pager = rememberPagerState(initialPage = startIndex.coerceIn(0, (items.size - 1).coerceAtLeast(0))) { items.size }
    var showChrome by remember { mutableStateOf(true) }
    // Zoomed pages stop the pager and the drag-to-close, so panning a zoomed photo stays a pan.
    val zoomed = remember { mutableStateMapOf<Int, Boolean>() }
    val currentZoomed = zoomed[pager.currentPage] == true

    // One player for the viewer; it plays whichever video is on screen.
    val player = remember { ExoPlayer.Builder(context).build().apply { repeatMode = Player.REPEAT_MODE_OFF } }
    DisposableEffect(Unit) { onDispose { player.release() } }
    LaunchedEffect(pager.currentPage) {
        onIndexChange(pager.currentPage)
        val item = items.getOrNull(pager.currentPage)
        if (item is GalleryItem.Video) {
            player.setMediaItem(MediaItem.fromUri(item.video.url))
            player.prepare()
            player.play()
        } else {
            player.pause()
        }
    }

    // Drag-to-close: the page follows the finger and fades; a long or fast drag closes.
    val dragY = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    val dragState = rememberDraggableState { delta -> scope.launch { dragY.snapTo(dragY.value + delta) } }

    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 1f - (abs(dragY.value) / 1200f).coerceIn(0f, 0.6f)))) {
        HorizontalPager(
            pager,
            Modifier.fillMaxSize()
                .graphicsLayer { translationY = dragY.value }
                .draggable(
                    dragState, Orientation.Vertical, enabled = !currentZoomed,
                    onDragStopped = { velocity ->
                        if (abs(dragY.value) > 250f || abs(velocity) > 2500f) onDismiss() else dragY.animateTo(0f)
                    },
                ),
            beyondViewportPageCount = 1,
            pageSpacing = 16.dp,
            userScrollEnabled = !currentZoomed,
            key = { items[it].key },
        ) { page ->
            when (val item = items[page]) {
                is GalleryItem.Image -> ZoomableImage(
                    item.url,
                    onTap = { showChrome = !showChrome },
                    onZoomChange = { zoomed[page] = it },
                )
                is GalleryItem.Video -> VideoPage(if (page == pager.currentPage) player else null, item.video)
            }
        }

        AnimatedVisibility(showChrome, enter = fadeIn(), exit = fadeOut()) {
            Row(
                Modifier.fillMaxWidth().safeDrawingPadding().padding(horizontal = DSSpacing.lg, vertical = DSSpacing.sm),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                ViewerButton(Icons.Filled.Close, stringResource(R.string.shared_media_close), onDismiss)
                Spacer(Modifier.weight(1f))
                if (items.size > 1) Counter(pager.currentPage + 1, items.size, large = true)
                Spacer(Modifier.weight(1f))
                val shareLabel = stringResource(R.string.shared_media_share)
                ViewerButton(Icons.Filled.Share, shareLabel) {
                    val url = when (val item = items.getOrNull(pager.currentPage)) {
                        is GalleryItem.Image -> item.url
                        is GalleryItem.Video -> item.video.url
                        null -> return@ViewerButton
                    }
                    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, url)
                    context.startActivity(Intent.createChooser(send, shareLabel))
                }
            }
        }
    }
}

@Composable
private fun ViewerButton(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, onClick: () -> Unit) {
    IconButton(onClick, Modifier.size(44.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.45f))) {
        Icon(icon, label, tint = Color.White)
    }
}

/**
 * Pinch and double-tap zoom (1×–4×). At 1× single-finger drags are left alone, so they page or
 * close the viewer; once zoomed, drags pan the photo within its edges.
 */
@Composable
private fun ZoomableImage(url: String, onTap: () -> Unit, onZoomChange: (Boolean) -> Unit) {
    var scale by remember { mutableFloatStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }
    var size by remember { mutableStateOf(IntSize.Zero) }

    fun clamp(value: Offset, s: Float): Offset {
        val maxX = size.width * (s - 1) / 2
        val maxY = size.height * (s - 1) / 2
        return Offset(value.x.coerceIn(-maxX, maxX), value.y.coerceIn(-maxY, maxY))
    }

    fun apply(newScale: Float, newOffset: Offset) {
        scale = newScale.coerceIn(1f, 4f)
        offset = if (scale <= 1f) Offset.Zero else clamp(newOffset, scale)
        onZoomChange(scale > 1.01f)
    }

    Box(
        Modifier.fillMaxSize()
            .onSizeChanged { size = it }
            .pointerInput(Unit) {
                detectTapGestures(
                    onTap = { onTap() },
                    onDoubleTap = { tap ->
                        if (scale > 1f) {
                            apply(1f, Offset.Zero)
                        } else {
                            // Zoom toward the tapped point.
                            val center = Offset(size.width / 2f, size.height / 2f)
                            apply(3f, (center - tap) * 2f)
                        }
                    },
                )
            }
            .pointerInput(Unit) {
                awaitEachGesture {
                    awaitFirstDown(requireUnconsumed = false)
                    do {
                        val event = awaitPointerEvent()
                        val pinching = event.changes.count { it.pressed } > 1
                        if (pinching || scale > 1.01f) {
                            apply(scale * event.calculateZoom(), offset + event.calculatePan())
                            event.changes.forEach { if (it.positionChanged()) it.consume() }
                        }
                    } while (event.changes.any { it.pressed })
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        SubcomposeAsyncImage(
            model = url,
            contentDescription = null,
            contentScale = ContentScale.Fit,
            loading = { Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Color.White) } },
            modifier = Modifier.fillMaxSize().graphicsLayer {
                scaleX = scale
                scaleY = scale
                translationX = offset.x
                translationY = offset.y
            },
        )
    }
}

/** The video on screen gets the player; neighbours show their poster until swiped to. */
@OptIn(UnstableApi::class)
@Composable
private fun VideoPage(player: ExoPlayer?, video: VideoAsset) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        if (player == null) {
            GalleryTile(GalleryItem.Video(video), playSize = 64.dp, modifier = Modifier.fillMaxSize())
        } else {
            AndroidView(
                factory = { context ->
                    PlayerView(context).apply {
                        layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
                        resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
                        setShowBuffering(PlayerView.SHOW_BUFFERING_WHEN_PLAYING)
                        setBackgroundColor(android.graphics.Color.BLACK)
                    }
                },
                update = { it.player = player },
                onRelease = { it.player = null },
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}
