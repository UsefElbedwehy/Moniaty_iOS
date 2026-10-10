import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Semantic color tokens backed by `Resources/Colors.xcassets`.
///
/// These are the ONLY colors the app should ever reference — never a raw hex or
/// `Color(red:green:blue:)` literal at a call site. Every token defines both a light
/// and dark appearance in the asset catalog, so light/dark mode and future white-label
/// re-theming require zero code changes downstream of `DesignSystem`.
public extension Color {
    // MARK: Brand

    static let dsPrimary = Color("Primary", bundle: .module)
    static let dsPrimaryPress = Color("PrimaryPress", bundle: .module)
    static let dsPrimaryMuted = Color("PrimaryMuted", bundle: .module)
    static let dsPremiumGold = Color("PremiumGold", bundle: .module)

    // MARK: Semantic status

    static let dsSuccess = Color("Success", bundle: .module)
    static let dsWarning = Color("Warning", bundle: .module)
    static let dsError = Color("Error", bundle: .module)
    static let dsInfo = Color("Info", bundle: .module)

    // MARK: Surfaces

    static let dsBackground = Color("Background", bundle: .module)
    static let dsSurface = Color("Surface", bundle: .module)
    static let dsElevated = Color("Elevated", bundle: .module)

    // MARK: Text

    static let dsTextPrimary = Color("TextPrimary", bundle: .module)
    static let dsTextSecondary = Color("TextSecondary", bundle: .module)
    static let dsDisabled = Color("Disabled", bundle: .module)

    // MARK: Border

    static let dsBorder = Color("Border", bundle: .module)

    // MARK: Status badge pairs

    static let dsPendingBackground = Color("PendingBackground", bundle: .module)
    static let dsPendingForeground = Color("PendingForeground", bundle: .module)
    static let dsLiveBackground = Color("LiveBackground", bundle: .module)
    static let dsLiveForeground = Color("LiveForeground", bundle: .module)
    static let dsRejectedBackground = Color("RejectedBackground", bundle: .module)
    static let dsRejectedForeground = Color("RejectedForeground", bundle: .module)

    // MARK: Appearance-aware pairs

    /// Builds a color that resolves per appearance, for the few values that are computed rather
    /// than authored — a tint derived from another color, or a seasonal accent that ships with
    /// the code. Anything with a fixed pair of authored values belongs in the asset catalog
    /// above instead; this is the escape hatch, not the pattern.
    /// Raises a color's brightness to at least `minimum`, keeping its hue and easing off its
    /// saturation a little — for palettes authored against white that also have to read on a
    /// near-black ground.
    static func dsBrightened(_ color: Color, to minimum: Double) -> Color {
        #if canImport(UIKit)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return color
        }
        return Color(uiColor: UIColor(
            hue: hue,
            saturation: saturation * 0.82,
            brightness: max(brightness, CGFloat(minimum)),
            alpha: alpha
        ))
        #else
        return color
        #endif
    }

    static func dsAdaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        return light
        #endif
    }
}
