package co.munyati.designsystem.theme

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/** 4dp-base spacing scale. Use these tokens for all padding and spacing — never a magic number. */
object DSSpacing {
    val xxs = 4.dp
    val xs = 8.dp
    val sm = 12.dp
    val md = 16.dp
    val lg = 20.dp
    val xl = 24.dp
    val xxl = 32.dp
}

/** Corner-radius scale used across controls, buttons, cards, and sheets. */
object DSRadius {
    val control = 8.dp
    val button = 14.dp
    val card = 20.dp
    val sheet = 26.dp
    val pill = 999.dp
}

/** Three-level elevation scale, from subtle card lift to prominent sheet shadow. */
object DSShadow {
    val level1 = 2.dp
    val level2 = 6.dp
    val level3 = 14.dp
}

/**
 * Shared premium gradients, used sparingly on brand surfaces (CTAs, avatars, the Featured badge).
 * Fixed stops, the same as iOS `DSGradient`; diagonal from the top-leading corner.
 */
object DSGradient {
    private fun diagonal(from: Color, to: Color) =
        Brush.linearGradient(listOf(from, to), start = Offset.Zero, end = Offset.Infinite)

    /** The first stop of [primary]: paints the status bar above a brand hero so the two meet seamlessly. */
    val primaryStart = Color(0xFF9A1444)
    val primary = diagonal(primaryStart, Color(0xFF6E0A2E))
    val gold = diagonal(Color(0xFFE7CE9A), Color(0xFFCAAD71))
    val error = diagonal(Color(0xFFFF5952), Color(0xFFD60014))
}
