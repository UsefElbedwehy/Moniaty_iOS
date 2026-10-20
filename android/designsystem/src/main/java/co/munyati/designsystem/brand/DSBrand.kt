package co.munyati.designsystem.brand

import android.app.Activity
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import co.munyati.designsystem.R
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSGradient
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing

/** Munyati brand marks, bundled as vector drawables (see `design/logo/README.md`). */
object DSBrand {
    /** The calligraphic منيتي wordmark in burgundy and gold. Primary logo: splash, landing, about. */
    @Composable
    fun Wordmark(modifier: Modifier = Modifier, contentDescription: String? = null) =
        Image(painterResource(R.drawable.brand_wordmark), contentDescription, modifier, contentScale = ContentScale.Fit)

    /** The same wordmark for burgundy backgrounds. */
    @Composable
    fun WordmarkReversed(modifier: Modifier = Modifier, contentDescription: String? = null) =
        Image(painterResource(R.drawable.brand_wordmark_reversed), contentDescription, modifier, contentScale = ContentScale.Fit)

    /** The ring-meem symbol used for the app icon; small brand moments (paywall, empty states). */
    @Composable
    fun Ring(modifier: Modifier = Modifier, contentDescription: String? = null) =
        Image(painterResource(R.drawable.brand_ring), contentDescription, modifier, contentScale = ContentScale.Fit)
}

/** The small four-point gold sparkle from the logo, used as an ornament between sections. */
@Composable
fun DSSparkle(size: Dp = 12.dp, modifier: Modifier = Modifier) {
    val gold = DS.colors.premiumGold
    Canvas(modifier.size(size)) {
        val cx = this.size.width / 2
        val cy = this.size.height / 2
        val w = this.size.width / 2
        val h = this.size.height / 2
        val k = 0.1f // how far the concave sides pull toward the centre
        val path = Path().apply {
            moveTo(cx, cy - h)
            quadraticBezierTo(cx + w * k, cy - h * k, cx + w, cy)
            quadraticBezierTo(cx + w * k, cy + h * k, cx, cy + h)
            quadraticBezierTo(cx - w * k, cy + h * k, cx - w, cy)
            quadraticBezierTo(cx - w * k, cy - h * k, cx, cy - h)
            close()
        }
        drawPath(path, gold)
    }
}

/**
 * The burgundy brand header behind the top of Home and Profile: the primary gradient with rounded
 * bottom corners, a faint gold ring watermark and two sparkles on the ring's side. Content sits on
 * top in white (and gold for ornaments). Mirrors iOS `DSBrandHeroBackground`.
 */
@Composable
fun DSBrandHero(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    val shape = RoundedCornerShape(bottomStart = DSRadius.sheet + 6.dp, bottomEnd = DSRadius.sheet + 6.dp)
    Box(modifier.clip(shape).background(DSGradient.primary)) {
        Image(
            painterResource(R.drawable.brand_ring),
            contentDescription = null,
            colorFilter = ColorFilter.tint(DS.colors.premiumGold.copy(alpha = 0.14f)),
            modifier = Modifier.align(Alignment.TopEnd).offset(x = 60.dp, y = (-30).dp).size(230.dp).rotate(12f),
        )
        Column(
            Modifier.align(Alignment.BottomEnd).padding(end = 48.dp, bottom = 64.dp),
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(DSSpacing.sm),
        ) {
            DSSparkle(14.dp, Modifier.alpha(0.8f))
            DSSparkle(9.dp, Modifier.padding(end = DSSpacing.lg).alpha(0.6f))
        }
        content()
    }
}

/**
 * Light status-bar icons while this is on screen (a burgundy hero sits under the clock); restores
 * the theme's default when it leaves.
 */
@Composable
fun LightStatusBarIcons() {
    val view = LocalView.current
    val isDark = DS.colors.isDark
    if (view.isInEditMode) return
    DisposableEffect(view, isDark) {
        val window = (view.context as? Activity)?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        controller?.isAppearanceLightStatusBars = false
        onDispose { controller?.isAppearanceLightStatusBars = !isDark }
    }
}
