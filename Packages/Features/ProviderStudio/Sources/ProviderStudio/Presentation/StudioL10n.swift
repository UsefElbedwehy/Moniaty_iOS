import SwiftUI

/// Localization for the ProviderStudio module (strings live in this module's bundle).
enum StudioL10n {
    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }

    static func text(_ key: String) -> Text {
        Text(verbatim: string(key))
    }

    static func key(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey("\(string(key))")
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), arguments: args)
    }
}
