package co.munyati.designsystem.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable

/**
 * The Munyati theme. Provides the DS tokens and maps them onto Material 3, so stock components
 * (text fields, progress indicators, dialogs) pick up the brand colors without per-call styling.
 */
@Composable
fun MunyatiTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val colors = if (darkTheme) DarkDSColors else LightDSColors
    val scheme = (if (darkTheme) darkColorScheme() else lightColorScheme()).copy(
        primary = colors.primary,
        onPrimary = androidx.compose.ui.graphics.Color.White,
        primaryContainer = colors.primaryMuted,
        onPrimaryContainer = colors.primary,
        secondary = colors.premiumGold,
        background = colors.background,
        onBackground = colors.textPrimary,
        surface = colors.surface,
        onSurface = colors.textPrimary,
        surfaceVariant = colors.elevated,
        onSurfaceVariant = colors.textSecondary,
        surfaceContainer = colors.surface,
        error = colors.error,
        outline = colors.border,
        outlineVariant = colors.border,
    )
    CompositionLocalProvider(
        LocalDSColors provides colors,
        LocalDSTypography provides DSTypography(),
    ) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}

/** Access point for tokens at call sites: `DS.colors.primary`, `DS.type.headline`. */
object DS {
    val colors: DSColors
        @Composable @ReadOnlyComposable get() = LocalDSColors.current
    val type: DSTypography
        @Composable @ReadOnlyComposable get() = LocalDSTypography.current
}
