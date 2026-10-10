import SwiftUI

/// Surface overrides for a subtree running a temporary skin.
///
/// DesignSystem deliberately doesn't know what the skin *is* — a seasonal theme, a white-label
/// tenant, a preview. It only knows that a container's fill can be replaced for a subtree, and
/// that `nil` means "use the standard token". Keeping the mechanism here rather than teaching
/// every component about a particular season is what stops the next skin from needing the same
/// work all over again.
public extension EnvironmentValues {
    /// The skin's fill for anything raised above `dsScreenGround` — cards, and the small chrome
    /// that sits directly on the ground. Every `DSCard` follows it, because a card left on the
    /// standard `.dsElevated` above a repainted ground reads as a leftover from the old palette.
    /// A screen opts out of a skin as a whole by not calling `dsScreenBackground()`.
    @Entry var dsRaisedSurface: Color?

    /// Replaces the ground painted by `dsScreenBackground()`.
    @Entry var dsScreenGround: Color?

    /// The ground the enclosing `dsScreenBackground()` actually painted, published downward so
    /// chrome that sits directly on it — a header bar — can match rather than seam against it.
    /// Nil on a screen that doesn't use `dsScreenBackground()`, which is how a screen opts out
    /// of a skin entirely: neither its ground nor its chrome moves.
    @Entry var dsPaintedGround: Color?
}

public extension View {
    /// A screen's ground, honouring a skin's override when one is set for this subtree.
    func dsScreenBackground(_ base: Color = .dsBackground) -> some View {
        modifier(DSScreenBackground(base: base))
    }
}

private struct DSScreenBackground: ViewModifier {
    let base: Color
    @Environment(\.dsScreenGround) private var ground

    func body(content: Content) -> some View {
        let painted = ground ?? base
        return content
            .environment(\.dsPaintedGround, painted)
            // The ShapeStyle overload, whose `ignoresSafeAreaEdges` defaults to `.all` — the
            // ground has to run under the status bar, navigation bar and tab bar. The
            // ViewBuilder form (`.background { painted }`) does not, and stopping there leaves
            // the window showing through as black bands above and below every themed screen.
            .background(painted)
    }
}
