import SwiftUI

/// Centered empty-state placeholder: icon, title, message, and an optional primary action.
public struct EmptyStateView: View {
    private let systemImage: String
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    /// A skin's raised surface, so this sits on a repainted ground instead of against it.
    @Environment(\.dsRaisedSurface) private var raisedSurface

    public init(
        systemImage: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: 88, height: 88)
                .background(raisedSurface ?? Color.dsElevated, in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: DSSpacing.xxs) {
                Text(title)
                    .font(.dsTitle2)
                    .foregroundStyle(Color.dsTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.dsSubhead)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                PrimaryButton(actionTitle, action: action)
                    .padding(.top, DSSpacing.xs)
            }
        }
        .padding(DSSpacing.xl)
        .accessibilityElement(children: .contain)
    }
}
