import SwiftUI

/// A custom two/three-way segmented switcher matching the design's pill tab style (a grouped
/// track with a white sliding selection pill) — used in place of the native `Picker(.segmented)`
/// style, which reads as a plain system control rather than a designed element. The selection
/// pill glides between segments via `matchedGeometryEffect`.
public struct PillSwitcher<T: Hashable>: View {
    private let items: [(value: T, title: LocalizedStringKey)]
    @Binding private var selection: T
    private let namespace: Namespace.ID

    /// A skin's raised surface, so this sits on a repainted ground instead of against it.
    @Environment(\.dsRaisedSurface) private var raisedSurface
    /// The selection pill is a shade *under* the track — the same relationship `dsSurface` has
    /// to `dsElevated` — so it follows the screen's ground rather than a fixed token.
    @Environment(\.dsPaintedGround) private var paintedGround

    public init(items: [(value: T, title: LocalizedStringKey)], selection: Binding<T>, namespace: Namespace.ID) {
        self.items = items
        self._selection = selection
        self.namespace = namespace
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.value) { item in
                let isSelected = item.value == selection
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        selection = item.value
                    }
                } label: {
                    Text(item.title)
                        .font(.dsSubhead.weight(isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? Color.dsTextPrimary : Color.dsTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(paintedGround ?? Color.dsSurface)
                                    .dsShadow(DSShadow.level1)
                                    .matchedGeometryEffect(id: "pillSwitcherSelection", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(raisedSurface ?? Color.dsElevated, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
