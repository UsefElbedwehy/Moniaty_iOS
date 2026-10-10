import SwiftUI

/// Shared label content for all DesignSystem button styles: swaps the title for a
/// `ProgressView` while loading, and honors Reduce Motion for that transition.
struct DSButtonLabel: View {
    let title: LocalizedStringKey
    let isLoading: Bool
    let font: Font
    let foregroundColor: Color
    var systemImage: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(font)
            .opacity(isLoading ? 0 : 1)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(foregroundColor)
            }
        }
        .foregroundStyle(foregroundColor)
        .animation(reduceMotion ? nil : .default, value: isLoading)
    }
}
