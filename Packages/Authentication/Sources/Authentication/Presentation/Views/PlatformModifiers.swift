import SwiftUI

/// iOS-only navigation modifiers wrapped so the module still compiles for the macOS host (where
/// `swift test` runs). On non-iOS platforms each helper is a no-op that returns `self`.
extension View {
    /// Inline navigation title on iOS; unchanged elsewhere.
    @ViewBuilder
    func authInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Hide the system back button on iOS (screens provide their own chevron); no-op elsewhere.
    @ViewBuilder
    func authHiddenBackButton() -> some View {
        #if os(iOS)
        self.navigationBarBackButtonHidden(true)
        #else
        self
        #endif
    }
}
