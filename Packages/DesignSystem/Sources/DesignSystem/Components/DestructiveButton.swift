import SwiftUI

/// Filled destructive-action button. `.dsError` fill, white text, 44pt tall.
public struct DestructiveButton: View {
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
                font: .dsBody.weight(.semibold),
                foregroundColor: .white
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(isEnabled ? Color.dsError : Color.dsDisabled)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isLoading ? Text("common.loading", bundle: .module) : Text(""))
    }
}
