import SwiftUI

/// A diagonal highlight sweep that loops across the view — the "shine" that makes a flat gold
/// fill (the Featured badge, premium CTAs) read as a lit, reflective surface instead of a solid
/// color block.
public extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.4

    func body(content: Content) -> some View {
        content
            // `.overlay` (not a `ZStack` sibling) — a `ZStack` sizes itself to the union of its
            // children, and `GeometryReader` is layout-greedy (it always accepts however much
            // space its parent offers), so a `ZStack` version inflates the badge's effective
            // frame to whatever it's overlaid on and centers the small pill inside that oversized
            // box. `.overlay` never feeds back into the base view's own reported size, so the
            // badge keeps its real compact size and its designed top-corner position.
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.55), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: proxy.size.width * 0.6)
                    .offset(x: phase * proxy.size.width * 2)
                    .blendMode(.plusLighter)
                }
                .allowsHitTesting(false)
            }
            // Masking by `content` itself (not a fixed rectangle) clips the sweep to the badge's
            // exact rendered shape — rounded corners, capsules, whatever — with no hardcoded
            // radius and no risk of the highlight spilling past the badge's edges.
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}
