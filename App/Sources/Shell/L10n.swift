import SwiftUI
import Shared

/// App-target strings. Every lookup checks the dashboard overrides first (`RemoteStrings`,
/// `docs/PLAN.md` §4.13) and falls back to the bundled `Localizable.strings`.
enum L10n {
    static func string(_ key: String) -> String {
        RemoteStrings.shared.string(key, fallback: String(localized: String.LocalizationValue(key)))
    }

    static func text(_ key: String) -> Text {
        Text(verbatim: string(key))
    }

    /// For DesignSystem components, which take a `LocalizedStringKey` and would otherwise
    /// resolve it against their own bundle: interpolate the resolved text so it renders verbatim.
    static func key(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey("\(string(key))")
    }
}
