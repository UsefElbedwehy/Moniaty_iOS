import SwiftUI

/// Loading-placeholder shape for `SkeletonView`.
public enum SkeletonShape: Sendable {
    case rectangle(cornerRadius: CGFloat)
    case circle(diameter: CGFloat)
}

/// Shimmering content placeholder shown while data loads. When Reduce Motion is
/// enabled, renders a static fill instead of an animating shimmer.
public struct SkeletonView: View {
    private let shape: SkeletonShape

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    public init(shape: SkeletonShape) {
        self.shape = shape
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [.dsSurface, .dsDisabled.opacity(0.5), .dsSurface],
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
    }

    public var body: some View {
        Group {
            switch shape {
            case .rectangle(let cornerRadius):
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillStyle)
            case .circle(let diameter):
                Circle()
                    .fill(fillStyle)
                    .frame(width: diameter, height: diameter)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
        .accessibilityHidden(true)
    }

    private var fillStyle: AnyShapeStyle {
        reduceMotion ? AnyShapeStyle(Color.dsSurface) : AnyShapeStyle(gradient)
    }
}
