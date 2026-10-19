package co.munyati.designsystem.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * Semantic color tokens — the ONLY colors the app should reference, never a raw hex at a call
 * site. Values match the iOS asset catalog (`DesignSystem/Resources/Colors.xcassets`) exactly,
 * light and dark.
 */
@Immutable
data class DSColors(
    // Brand
    val primary: Color,
    val primaryPress: Color,
    val primaryMuted: Color,
    val premiumGold: Color,
    // Semantic status
    val success: Color,
    val warning: Color,
    val error: Color,
    val info: Color,
    // Surfaces
    val background: Color,
    val surface: Color,
    val elevated: Color,
    // Text
    val textPrimary: Color,
    val textSecondary: Color,
    val disabled: Color,
    // Border
    val border: Color,
    // Status badge pairs
    val pendingBackground: Color,
    val pendingForeground: Color,
    val liveBackground: Color,
    val liveForeground: Color,
    val rejectedBackground: Color,
    val rejectedForeground: Color,
    val isDark: Boolean,
)

val LightDSColors = DSColors(
    primary = Color(0xFF8A0D3A),
    primaryPress = Color(0xFF6E0A2E),
    primaryMuted = Color(0xFFF2E5D2),
    premiumGold = Color(0xFFDFC389),
    success = Color(0xFF2E7D4F),
    warning = Color(0xFFB7791F),
    error = Color(0xFFB3261E),
    info = Color(0xFF2F5E8C),
    background = Color(0xFFFAFAEC),
    surface = Color(0xFFFFFFFF),
    elevated = Color(0xFFFFFFFF),
    textPrimary = Color(0xFF2A1420),
    textSecondary = Color(0xFF6B5560),
    disabled = Color(0xFFB9A9AE),
    border = Color(0xFFE9DCC6),
    pendingBackground = Color(0xFFF6E9C8),
    pendingForeground = Color(0xFF6A4A00),
    liveBackground = Color(0xFFE2EFE4),
    liveForeground = Color(0xFF1F5A2E),
    rejectedBackground = Color(0xFFF8E1E1),
    rejectedForeground = Color(0xFF8F1D1D),
    isDark = false,
)

val DarkDSColors = DSColors(
    primary = Color(0xFFC2335F),
    primaryPress = Color(0xFFA52A52),
    primaryMuted = Color(0xFF3A1F28),
    premiumGold = Color(0xFFDFC389),
    success = Color(0xFF5BBF84),
    warning = Color(0xFFE0A84A),
    error = Color(0xFFF2766B),
    info = Color(0xFF7FB0E0),
    background = Color(0xFF1A1214),
    surface = Color(0xFF241A1D),
    elevated = Color(0xFF2E2226),
    textPrimary = Color(0xFFF7F0E6),
    textSecondary = Color(0xFFC2B2B8),
    disabled = Color(0xFF6B5A60),
    border = Color(0xFF3D2E33),
    pendingBackground = Color(0xFF3D3218),
    pendingForeground = Color(0xFFF0CF7A),
    liveBackground = Color(0xFF1E3527),
    liveForeground = Color(0xFF8FD3A5),
    rejectedBackground = Color(0xFF3D1D20),
    rejectedForeground = Color(0xFFF2A0A0),
    isDark = true,
)

val LocalDSColors = staticCompositionLocalOf { LightDSColors }
