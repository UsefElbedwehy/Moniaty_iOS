import SwiftUI

/// Tappable pill-shaped filter chip with a selected/unselected visual state. When given a
/// `namespace`, the selected fill glides between chips via `matchedGeometryEffect` instead of
/// just flipping state instantly — pass the same `namespace`/`matchedId` pair across every chip
/// in one row so only one "selection" element exists at a time for SwiftUI to animate between.
public struct Chip: View {
    private let title: LocalizedStringKey
    private let isSelected: Bool
    private let namespace: Namespace.ID?
    private let matchedId: String
    private let action: () -> Void

    public init(
        _ title: LocalizedStringKey,
        isSelected: Bool,
        namespace: Namespace.ID? = nil,
        matchedId: String = "chipSelection",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.namespace = namespace
        self.matchedId = matchedId
        self.action = action
    }

    public var body: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                action()
            }
        } label: {
            Text(title)
                .font(.dsSubhead.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.dsTextPrimary)
                .padding(.vertical, DSSpacing.xs)
                .padding(.horizontal, DSSpacing.md - 1)
                .frame(minHeight: 44)
                .background {
                    if isSelected {
                        selectionFill
                    } else {
                        Color.dsElevated
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var selectionFill: some View {
        if let namespace {
            DSGradient.primary
                .matchedGeometryEffect(id: matchedId, in: namespace)
        } else {
            DSGradient.primary
        }
    }
}
