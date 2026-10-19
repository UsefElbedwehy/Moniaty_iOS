package co.munyati.designsystem.brand

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import co.munyati.designsystem.R
import co.munyati.designsystem.theme.DS

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
