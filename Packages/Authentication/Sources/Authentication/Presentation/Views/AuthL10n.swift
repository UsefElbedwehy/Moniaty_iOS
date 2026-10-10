import SwiftUI

/// Localization access for the Authentication module. A bare `LocalizedStringKey` in a SwiftUI
/// `Text` resolves against the *main app* bundle, which would miss these strings — everything
/// here routes through `Bundle.module` so the feature's own `.strings` files are used.
enum AuthL10n {
    /// A `Text` localized from this module's bundle.
    static func text(_ key: LocalizedStringKey) -> Text {
        Text(key, bundle: .module)
    }

    /// A plain localized `String` from this module's bundle (for accessibility labels and format
    /// strings with arguments).
    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }

    /// A `LocalizedStringKey` safe to pass to a DesignSystem component. Those components resolve
    /// a `LocalizedStringKey` against *their own* bundle, which lacks these strings — so resolve
    /// here (against `.module`) and wrap as an interpolated key, which renders verbatim.
    static func dsKey(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey("\(string(key))")
    }

    /// "Sent to +966 55 123 4567."
    static func sentTo(_ phone: String) -> String {
        String(format: string("auth.otp.sentTo"), phone)
    }

    /// "Resend code in 0:24"
    static func resendIn(_ countdown: String) -> String {
        String(format: string("auth.otp.resendIn"), countdown)
    }
}
