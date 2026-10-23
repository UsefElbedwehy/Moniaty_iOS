import SwiftUI

/// Munyati brand marks, bundled as vector assets (see `design/logo/README.md`).
public enum DSBrand {
    /// The calligraphic منيتي wordmark in burgundy and gold. Primary logo: splash, landing, about.
    public static let wordmark = Image("BrandWordmark", bundle: .module)
    /// The same wordmark for burgundy backgrounds.
    public static let wordmarkReversed = Image("BrandWordmarkReversed", bundle: .module)
    /// The ring-meem symbol used for the app icon. Use for small brand moments (paywall, empty states).
    public static let ring = Image("BrandRing", bundle: .module)
}

/// The small four-point gold sparkle from the logo, used as an ornament between sections.
public struct DSSparkle: View {
    private let size: CGFloat

    public init(size: CGFloat = 12) {
        self.size = size
    }

    public var body: some View {
        SparkleShape()
            .fill(Color.dsPremiumGold)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let w = rect.width / 2, h = rect.height / 2
        let k: CGFloat = 0.1 // how far the concave sides pull toward the centre
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - h))
        p.addQuadCurve(to: CGPoint(x: c.x + w, y: c.y), control: CGPoint(x: c.x + w * k, y: c.y - h * k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + h), control: CGPoint(x: c.x + w * k, y: c.y + h * k))
        p.addQuadCurve(to: CGPoint(x: c.x - w, y: c.y), control: CGPoint(x: c.x - w * k, y: c.y + h * k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - h), control: CGPoint(x: c.x - w * k, y: c.y - h * k))
        p.closeSubpath()
        return p
    }
}

/// The burgundy brand header behind the top of Home and Profile: the primary gradient with
/// rounded bottom corners, a faint gold ring watermark and two sparkles. Content sits on top in
/// white (and gold for ornaments).
public struct DSBrandHeroBackground: View {
    public init() {}

    public var body: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: DSRadius.sheet + 6, bottomTrailingRadius: DSRadius.sheet + 6)
        shape
            .fill(DSGradient.primary)
            .overlay(alignment: .topTrailing) {
                DSBrand.ring
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.dsPremiumGold.opacity(0.14))
                    .frame(width: 230, height: 230)
                    .rotationEffect(.degrees(12))
                    .offset(x: 60, y: -30)
            }
            // Sparkles on the ring's side, away from the text that starts at the leading edge.
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: DSSpacing.sm) {
                    DSSparkle(size: 14).opacity(0.8)
                    DSSparkle(size: 9).opacity(0.6).padding(.trailing, DSSpacing.lg)
                }
                .padding(.trailing, 48)
                .padding(.bottom, 64)
            }
            .clipShape(shape)
            .accessibilityHidden(true)
    }
}
