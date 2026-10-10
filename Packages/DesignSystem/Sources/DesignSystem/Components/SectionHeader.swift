import SwiftUI

/// Section title with an optional trailing text-button action (e.g. "See all").
public struct SectionHeader: View {
    private let title: LocalizedStringKey
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    public init(
        _ title: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.dsHeadline)
                .foregroundStyle(Color.dsTextPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.dsSubhead)
                        .foregroundStyle(Color.dsPrimary)
                        .frame(minHeight: 44)
                }
                .accessibilityLabel(Text(actionTitle))
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}
