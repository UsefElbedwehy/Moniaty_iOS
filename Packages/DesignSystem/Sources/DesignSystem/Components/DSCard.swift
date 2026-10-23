import SwiftUI

/// Generic elevated container. `.dsElevated` fill, `DSRadius.card` corners, level-1 shadow.
public struct DSCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content
    /// A skin's fill for cards in this subtree, or nil for the standard `.dsElevated`. Read here
    /// rather than passed per call site: a card is raised above whatever ground its screen
    /// painted, so on a repainted ground every card has to move with it or it reads as a
    /// leftover from the old palette.
    @Environment(\.dsRaisedSurface) private var raisedSurface

    public init(padding: CGFloat = DSSpacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(raisedSurface ?? Color.dsElevated)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .dsShadow(DSShadow.level1)
    }
}
