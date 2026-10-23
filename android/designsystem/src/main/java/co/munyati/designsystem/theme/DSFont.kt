package co.munyati.designsystem.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import co.munyati.designsystem.R

/**
 * Munyati's type scale, matching iOS `Font.ds…`. Display styles (large title, title 1) use
 * **Amiri**, the calligraphic Naskh face the منيتي wordmark is built on; everything else uses the
 * system font. Sizes are in sp, so they follow the user's font-size setting (Dynamic Type).
 */
val Amiri = FontFamily(
    Font(R.font.amiri_regular, FontWeight.Normal),
    Font(R.font.amiri_bold, FontWeight.Bold),
)

@Immutable
data class DSTypography(
    val largeTitle: TextStyle = TextStyle(fontFamily = Amiri, fontWeight = FontWeight.Bold, fontSize = 30.sp, lineHeight = 44.sp),
    val title1: TextStyle = TextStyle(fontFamily = Amiri, fontWeight = FontWeight.Bold, fontSize = 24.sp, lineHeight = 36.sp),
    val title2: TextStyle = TextStyle(fontWeight = FontWeight.Bold, fontSize = 20.sp, lineHeight = 26.sp),
    val headline: TextStyle = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 17.sp, lineHeight = 22.sp),
    val body: TextStyle = TextStyle(fontWeight = FontWeight.Normal, fontSize = 17.sp, lineHeight = 24.sp),
    val subhead: TextStyle = TextStyle(fontWeight = FontWeight.Medium, fontSize = 15.sp, lineHeight = 20.sp),
    val footnote: TextStyle = TextStyle(fontWeight = FontWeight.Normal, fontSize = 13.sp, lineHeight = 18.sp),
    val caption: TextStyle = TextStyle(fontWeight = FontWeight.Medium, fontSize = 12.sp, lineHeight = 16.sp),
)

val LocalDSTypography = staticCompositionLocalOf { DSTypography() }
