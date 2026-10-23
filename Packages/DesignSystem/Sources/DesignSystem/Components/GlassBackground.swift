import SwiftUI

/// A frosted "liquid glass" surface: a system material fill, a soft inner highlight stroke, and
/// a diffuse shadow — for elements that float over photographic content (map overlays, the
/// search pill, pin preview cards) rather than sit on a flat list background.
public extension View {
    func glassBackground(cornerRadius: CGFloat = DSRadius.card, strokeOpacity: Double = 0.5) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(strokeOpacity), lineWidth: 0.75)
            )
            .dsShadow(DSShadow.level2)
    }

    /// A fully rounded (pill) variant of `glassBackground(cornerRadius:strokeOpacity:)`.
    func glassPill(strokeOpacity: Double = 0.5) -> some View {
        self
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(strokeOpacity), lineWidth: 0.75))
            .dsShadow(DSShadow.level1)
    }

    /// The real system Liquid Glass material on iOS/macOS 26+ (with the `.interactive()` press
    /// response for tappable surfaces like the search bar), falling back to the hand-rolled
    /// `glassBackground` approximation on older OS versions where the real API doesn't exist.
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = DSRadius.card, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(
                interactive ? .regular.interactive() : .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            self.glassBackground(cornerRadius: cornerRadius)
        }
    }

    /// Pill-shaped counterpart to `liquidGlass(cornerRadius:interactive:)`, for fully-rounded
    /// surfaces like search bars — falls back to `glassPill()` pre-iOS/macOS 26.
    @ViewBuilder
    func liquidGlassPill(interactive: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: Capsule())
        } else {
            self.glassPill()
        }
    }
}
