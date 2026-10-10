import SwiftUI
import Testing
@testable import DesignSystem

@Suite("Color tokens")
struct DSColorTests {
    @Test("Every semantic color token resolves without crashing")
    func tokensResolve() {
        let tokens: [Color] = [
            .dsPrimary, .dsPrimaryPress, .dsPrimaryMuted, .dsPremiumGold,
            .dsSuccess, .dsWarning, .dsError, .dsInfo,
            .dsBackground, .dsSurface, .dsElevated,
            .dsTextPrimary, .dsTextSecondary, .dsDisabled,
            .dsBorder,
            .dsPendingBackground, .dsPendingForeground,
            .dsLiveBackground, .dsLiveForeground,
            .dsRejectedBackground, .dsRejectedForeground
        ]
        #expect(tokens.count == 21)
    }
}
