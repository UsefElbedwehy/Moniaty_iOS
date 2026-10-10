import Testing
@testable import DesignSystem

@Suite("Spacing tokens")
struct SpacingTests {
    @Test func matchesSpec() {
        #expect(DSSpacing.xxs == 4)
        #expect(DSSpacing.xs == 8)
        #expect(DSSpacing.sm == 12)
        #expect(DSSpacing.md == 16)
        #expect(DSSpacing.lg == 20)
        #expect(DSSpacing.xl == 24)
        #expect(DSSpacing.xxl == 32)
    }
}

@Suite("Radius tokens")
struct RadiusTests {
    @Test func matchesSpec() {
        #expect(DSRadius.control == 8)
        #expect(DSRadius.button == 14)
        #expect(DSRadius.card == 20)
        #expect(DSRadius.sheet == 26)
        #expect(DSRadius.pill == 999)
    }
}

@Suite("Shadow tokens")
struct ShadowTests {
    @Test func level1MatchesSpec() {
        let style = DSShadow.level1
        #expect(style.radius == 3)
        #expect(style.x == 0)
        #expect(style.y == 1)
    }

    @Test func level2MatchesSpec() {
        let style = DSShadow.level2
        #expect(style.radius == 14)
        #expect(style.x == 0)
        #expect(style.y == 4)
    }

    @Test func level3MatchesSpec() {
        let style = DSShadow.level3
        #expect(style.radius == 30)
        #expect(style.x == 0)
        #expect(style.y == 12)
    }
}
