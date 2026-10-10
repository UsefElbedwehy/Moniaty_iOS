import SwiftUI

/// Filled primary call-to-action button. `.dsPrimary` fill, white text, 50pt tall.
public struct PrimaryButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let isLoading: Bool
    private let isEnabled: Bool
    private let action: () -> Void

    public init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
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
                foregroundColor: .white,
                systemImage: systemImage
            )
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background {
                if isEnabled {
                    DSGradient.primary
                } else {
                    Color.dsDisabled
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
        }
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isLoading ? Text("common.loading", bundle: .module) : Text(""))
    }
}
