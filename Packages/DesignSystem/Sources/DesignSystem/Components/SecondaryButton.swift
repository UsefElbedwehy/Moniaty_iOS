import SwiftUI

/// Pale-mint filled button, `.dsPrimary` text. Use for secondary but still prominent actions.
public struct SecondaryButton: View {
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
                foregroundColor: isEnabled ? .dsPrimary : .dsDisabled,
                systemImage: systemImage
            )
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isEnabled ? Color.dsPrimaryMuted : Color.dsSurface)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
        }
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isLoading ? Text("common.loading", bundle: .module) : Text(""))
    }
}
