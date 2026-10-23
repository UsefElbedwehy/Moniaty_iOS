import SwiftUI

/// Brand glyphs for the social profiles configured in the dashboard.
///
/// SF Symbols ships no brand marks, so these platforms used to borrow the nearest lookalike —
/// a lightning bolt for Snapchat, a music note for TikTok, two people for Facebook. Recognisable
/// they were not. The bundled set is finite and matches the Hugeicons family the category icons
/// already use; a platform with no bundled glyph returns nil so the caller can keep falling back
/// to a symbol rather than rendering blank.
///
/// Template images, so they tint through `.foregroundStyle()` exactly like a symbol would.
public extension Image {
    static func socialIcon(for platform: String) -> Image? {
        guard SocialIconKeys.bundled.contains(platform.lowercased()) else { return nil }
        return Image("social-\(platform.lowercased())", bundle: .module)
            .renderingMode(.template)
    }
}

/// The platforms with real artwork in `Resources/Media.xcassets/SocialIcons`. Adding a glyph
/// means dropping the imageset in and adding its key here.
public enum SocialIconKeys {
    public static let bundled: Set<String> = ["snapchat", "tiktok", "facebook", "instagram"]
}
