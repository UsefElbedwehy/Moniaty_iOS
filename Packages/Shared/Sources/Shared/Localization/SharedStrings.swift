import Foundation
import SwiftUI

/// Typed accessor for the common, cross-cutting localized strings shipped by `Shared`.
/// Call sites should use these instead of sprinkling raw `"common.*"` string keys.
///
/// Implementation note: we resolve strings via `String(localized:bundle:)` against
/// `Bundle.module` rather than `LocalizedStringResource(_:bundle:)`. In local testing,
/// constructing a `LocalizedStringResource` with `Bundle.atURL(Bundle.module.bundleURL)`
/// on Swift 6 / this toolchain either failed to resolve reliably outside of a full app
/// target or added indirection with no real benefit over the simpler API. `String(localized:
/// bundle:)` resolves directly and deterministically from the package's `.lproj` resources,
/// and is trivially unit-testable (see `SharedStringsTests`).
public enum SharedStrings {
    public static var retry: String {
        String(localized: "common.retry", bundle: .module)
    }

    public static var cancel: String {
        String(localized: "common.cancel", bundle: .module)
    }

    public static var save: String {
        String(localized: "common.save", bundle: .module)
    }

    public static var edit: String {
        String(localized: "common.edit", bundle: .module)
    }

    public static var `continue`: String {
        String(localized: "common.continue", bundle: .module)
    }

    public static var submit: String {
        String(localized: "common.submit", bundle: .module)
    }

    public static var done: String {
        String(localized: "common.done", bundle: .module)
    }

    public static var back: String {
        String(localized: "common.back", bundle: .module)
    }

    public static var loading: String {
        String(localized: "common.loading", bundle: .module)
    }

    public static var tryAgain: String {
        String(localized: "common.tryAgain", bundle: .module)
    }

    public static var viewAll: String {
        String(localized: "common.viewAll", bundle: .module)
    }

    public static var seeMore: String {
        String(localized: "common.seeMore", bundle: .module)
    }

    /// SwiftUI `Text` convenience for call sites that want a `View` directly.
    public static func text(_ keyPath: KeyPath<SharedStrings.Type, String>) -> Text {
        Text(SharedStrings.self[keyPath: keyPath])
    }
}
