import SwiftUI

/// A single elevation shadow definition (color, blur radius, and offset).
public struct DSShadowStyle: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

/// Three-level elevation scale, from subtle card lift to prominent sheet/modal shadow.
public enum DSShadow {
    public static let level1 = DSShadowStyle(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
    public static let level2 = DSShadowStyle(color: .black.opacity(0.10), radius: 14, x: 0, y: 4)
    public static let level3 = DSShadowStyle(color: .black.opacity(0.14), radius: 30, x: 0, y: 12)
}

public extension View {
    /// Applies a `DSShadowStyle` elevation token to this view.
    func dsShadow(_ style: DSShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
