import SwiftUI

/// Shared premium gradients — used sparingly for depth on brand surfaces (avatars, CTAs,
/// the Featured badge), matching the diagonal sheen the design spec uses on its logo mark
/// and business-avatar circles. Fixed literal stops (not asset-catalog colors) since these
/// are decorative accents layered over both light and dark surfaces alike.
public enum DSGradient {
    public static let primary = LinearGradient(
        colors: [Color(red: 0.604, green: 0.078, blue: 0.267), Color(red: 0.431, green: 0.039, blue: 0.180)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let gold = LinearGradient(
        colors: [Color(red: 0.906, green: 0.808, blue: 0.604), Color(red: 0.792, green: 0.678, blue: 0.443)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Destructive actions (sign out) — same diagonal treatment, red instead of brand burgundy/gold.
    public static let error = LinearGradient(
        colors: [Color(red: 1.0, green: 0.35, blue: 0.32), Color(red: 0.84, green: 0.0, blue: 0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
