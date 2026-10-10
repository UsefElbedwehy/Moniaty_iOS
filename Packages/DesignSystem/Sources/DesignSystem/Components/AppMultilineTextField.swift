import SwiftUI

/// The paragraph counterpart to `AppTextField`: same fill, border and focus treatment, but it
/// grows with the text and Return inserts a newline instead of dismissing the keyboard — which
/// is the whole point for a description.
public struct AppMultilineTextField: View {
    private let title: LocalizedStringKey
    @Binding private var text: String
    private let minLines: Int
    private let maxLines: Int

    @FocusState private var isFocused: Bool
    @Environment(\.dsRaisedSurface) private var raisedSurface

    public init(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        minLines: Int = 4,
        maxLines: Int = 12
    ) {
        self.title = title
        self._text = text
        self.minLines = minLines
        self.maxLines = maxLines
    }

    private var borderColor: Color { isFocused ? .dsPrimary : .dsBorder }
    private var fillColor: Color {
        if let raisedSurface { return raisedSurface }
        return isFocused ? .dsSurface : .dsElevated
    }

    public var body: some View {
        TextField(title, text: $text, axis: .vertical)
            .lineLimit(minLines...maxLines)
            .font(.dsBody)
            .foregroundStyle(Color.dsTextPrimary)
            .focused($isFocused)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .background(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .dsShadow(isFocused
                ? DSShadowStyle(color: Color.dsPrimary.opacity(0.18), radius: 10, x: 0, y: 3)
                : DSShadowStyle(color: .clear, radius: 0, x: 0, y: 0))
            .animation(.easeOut(duration: 0.18), value: isFocused)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(text))
    }
}
