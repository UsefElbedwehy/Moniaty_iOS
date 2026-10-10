import SwiftUI

/// Bordered outline button, `.dsTextPrimary` text, 1.5pt `.dsBorder` stroke.
public struct TertiaryButton: View {
    private let title: LocalizedStringKey
    private let isLoading: Bool
    private let isEnabled: Bool
    private let action: () -> Void

    public init(
        _ title: LocalizedStringKey,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            DSButtonLabel(
                title: title,
                isLoading: isLoading,
                font: .dsHeadline,
                foregroundColor: isEnabled ? .dsTextPrimary : .dsDisabled
            )
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.dsBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous)
                    .stroke(isEnabled ? Color.dsBorder : Color.dsDisabled, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
        }
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isLoading ? Text("common.loading", bundle: .module) : Text(""))
    }
}
