import SwiftUI

/// Category icons are lightweight bundled vector assets (Hugeicons' free set, MIT-licensed — see
/// `THIRD_PARTY_NOTICES.txt`), not SF Symbols: the admin dashboard picks a name from this same
/// fixed set (`CategoryIconPicker.tsx`), stored in `categories.icon_system_name` (name kept as-is
/// to avoid an unnecessary column rename — it's a plain icon key now, not literally an SF Symbol
/// name). Each asset is a `template-rendering-intent` image, so it tints via `.foregroundStyle()`
/// exactly like an `Image(systemName:)` would have.
///
/// Unlike SF Symbols (effectively unlimited, built into iOS itself), this is a *finite* set
/// shipped with the app — a category whose stored key doesn't match any bundled asset (a typo, or
/// a key from before this switchover) falls back to a generic pin rather than rendering blank.
public extension Image {
    static func categoryIcon(_ key: String?) -> Image {
        let name = (key?.isEmpty == false) ? key! : CategoryIconKeys.fallback
        return Image(name, bundle: .module)
            .renderingMode(.template)
    }
}

/// The exact set the dashboard's `CategoryIconPicker` offers, mirrored here only for the
/// fallback constant — the source of truth for "which keys exist" is the asset catalog itself
/// (`Resources/Media.xcassets/CategoryIcons`), not this list.
public enum CategoryIconKeys {
    public static let fallback = "map-pin"
}
