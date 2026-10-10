import SwiftUI
#if canImport(UIKit)
import UIKit
#else
/// Host-platform fallback so this file type-checks when compiled for macOS (this
/// package's `swift build`/`swift test` host). The real `UIKit.UIKeyboardType` is used
/// on iOS; on macOS `keyboardType` is accepted but has no visual effect.
public struct UIKeyboardType: Sendable, Equatable {
    public static let `default` = UIKeyboardType()
    public static let emailAddress = UIKeyboardType()
    public static let numberPad = UIKeyboardType()
    public static let phonePad = UIKeyboardType()
    public static let decimalPad = UIKeyboardType()
    public static let URL = UIKeyboardType()
}
#endif

/// Text field with three visual states: default (`.dsElevated` fill, thin neutral border),
/// focused (`.dsSurface` fill, 2pt `.dsPrimary` border + a soft primary-tinted glow), and error
/// (2pt `.dsError` border plus a message below).
public struct AppTextField: View {
    private let title: LocalizedStringKey
    @Binding private var text: String
    private let isSecure: Bool
    private let errorMessage: LocalizedStringKey?
    private let keyboardType: UIKeyboardType

    @FocusState private var isFocused: Bool
    @Environment(\.dsRaisedSurface) private var raisedSurface

    public init(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        isSecure: Bool = false,
        errorMessage: LocalizedStringKey? = nil,
        keyboardType: UIKeyboardType = .default
    ) {
        self.title = title
        self._text = text
        self.isSecure = isSecure
        self.errorMessage = errorMessage
        self.keyboardType = keyboardType
    }

    private var hasError: Bool { errorMessage != nil }

    private var borderColor: Color {
        if hasError { return .dsError }
        if isFocused { return .dsPrimary }
        return .dsBorder
    }

    private var borderWidth: CGFloat {
        hasError || isFocused ? 2 : 1
    }

    /// A light neutral fill at rest (so the field reads as a control against a plain white
    /// screen rather than an invisible white-on-white box), lifting to the surface color once
    /// focused or in error.
    private var fillColor: Color {
        // Under a skin the field takes the one raised surface in both states: the focus ring and
        // glow already say which field is active, and a two-tone fill would only reintroduce the
        // old palette on a repainted ground.
        if let raisedSurface { return raisedSurface }
        return isFocused || hasError ? .dsSurface : .dsElevated
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    fieldWithKeyboardType
                }
            }
            .font(.dsBody)
            .foregroundStyle(Color.dsTextPrimary)
            .focused($isFocused)
            .padding(.horizontal, DSSpacing.md)
            .frame(height: 52)
            .background(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .dsShadow(isFocused ? DSShadowStyle(color: Color.dsPrimary.opacity(0.18), radius: 10, x: 0, y: 3) : DSShadowStyle(color: .clear, radius: 0, x: 0, y: 0))
            .animation(.easeOut(duration: 0.18), value: isFocused)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(text))

            if let errorMessage {
                Text(errorMessage)
                    .font(.dsFootnote)
                    .foregroundStyle(Color.dsError)
                    .accessibilityLabel(Text(errorMessage))
            }
        }
    }

    @ViewBuilder
    private var fieldWithKeyboardType: some View {
        #if canImport(UIKit)
        TextField(title, text: $text)
            .keyboardType(keyboardType)
        #else
        TextField(title, text: $text)
        #endif
    }
}
