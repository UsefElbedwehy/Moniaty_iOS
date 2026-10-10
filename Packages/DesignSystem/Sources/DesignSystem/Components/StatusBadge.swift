import SwiftUI

/// The kind of status a `StatusBadge` represents, driving its color pair and optional icon.
public enum StatusBadgeKind: Sendable {
    case pending
    case live
    case rejected
    case featured
    case verified
}

/// Small pill-ish label used to convey listing/moderation status (pending, live,
/// rejected) or promotional state (featured, verified).
public struct StatusBadge: View {
    private let kind: StatusBadgeKind
    private let text: LocalizedStringKey

    public init(kind: StatusBadgeKind, text: LocalizedStringKey) {
        self.kind = kind
        self.text = text
    }

    private var backgroundColor: Color {
        switch kind {
        case .pending: return .dsPendingBackground
        case .live: return .dsLiveBackground
        case .rejected: return .dsRejectedBackground
        case .featured: return .dsPremiumGold
        case .verified: return .dsPrimary
        }
    }

    /// `.featured`/`.verified` get a subtle diagonal sheen instead of a flat fill — the
    /// premium touch the rest of the badge kinds (status pills) don't need.
    @ViewBuilder
    private var background: some View {
        switch kind {
        case .featured: DSGradient.gold
        case .verified: DSGradient.primary
        case .pending, .live, .rejected: backgroundColor
        }
    }

    private var foregroundColor: Color {
        switch kind {
        case .pending: return .dsPendingForeground
        case .live: return .dsLiveForeground
        case .rejected: return .dsRejectedForeground
        case .featured, .verified: return .white
        }
    }

    private var systemImage: String? {
        switch kind {
        case .featured: return "star.fill"
        case .verified: return "checkmark.seal.fill"
        case .pending, .live, .rejected: return nil
        }
    }

    public var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.dsCaption.weight(.bold))
        }
        .foregroundStyle(foregroundColor)
        .padding(.vertical, 6)
        .padding(.horizontal, 11)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .modifier(ShineIfNeeded(kind: kind))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
    }
}

/// Only `.featured`/`.verified` shine — status pills (pending/live/rejected) stay flat and calm.
private struct ShineIfNeeded: ViewModifier {
    let kind: StatusBadgeKind

    func body(content: Content) -> some View {
        switch kind {
        case .featured, .verified: content.shimmering()
        case .pending, .live, .rejected: content
        }
    }
}
