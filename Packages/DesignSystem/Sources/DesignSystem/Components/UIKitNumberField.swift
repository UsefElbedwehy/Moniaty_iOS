import SwiftUI

#if canImport(UIKit)
import UIKit

/// A UIKit-backed, digits-only text field — for phone numbers and OTP codes, screens where
/// SwiftUI's own `TextField` behaves badly once the app runs in Arabic (RTL):
///
/// - `.keyboardType(.phonePad)`/`.numberPad` respects the system locale, so in Arabic it shows an
///   **Arabic-Indic** numeric keypad (٠١٢٣...) by default — every digit the user types is a
///   different Unicode character from the ASCII "0123456789" the rest of the app (validation, the
///   OTP hash comparison on the server) expects, so typed input either gets silently stripped or
///   never matches.
/// - SwiftUI `TextField` has long-standing cursor/selection bugs for digit-only content once the
///   surrounding layout direction is RTL — the caret jumps, and digit order can visually flip.
///
/// This sidesteps both: `keyboardType = .asciiCapableNumberPad` forces a Western-numeral keypad
/// regardless of locale, and `semanticContentAttribute = .forceLeftToRight` pins the field itself
/// to LTR — phone numbers and codes are always read left-to-right, exactly like every other app.
public struct UIKitNumberField: UIViewRepresentable {
    @Binding private var text: String
    @Binding private var isFocused: Bool
    private let placeholder: String
    private let font: UIFont
    private let textColor: UIColor
    private let placeholderColor: UIColor
    private let maxLength: Int?
    private let textContentType: UITextContentType?
    private let onCommit: (() -> Void)?

    public init(
        text: Binding<String>,
        isFocused: Binding<Bool> = .constant(false),
        placeholder: String = "",
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        placeholderColor: UIColor = .placeholderText,
        maxLength: Int? = nil,
        textContentType: UITextContentType? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self._text = text
        self._isFocused = isFocused
        self.placeholder = placeholder
        self.font = font
        self.textColor = textColor
        self.placeholderColor = placeholderColor
        self.maxLength = maxLength
        self.textContentType = textContentType
        self.onCommit = onCommit
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = .asciiCapableNumberPad
        field.textContentType = textContentType
        field.font = font
        field.textColor = textColor
        field.tintColor = textColor
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor]
        )
        field.semanticContentAttribute = .forceLeftToRight
        field.textAlignment = .left
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        return field
    }

    public func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text { uiView.text = text }
        if uiView.attributedPlaceholder?.string != placeholder {
            uiView.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: placeholderColor]
            )
        }
        if isFocused, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    /// Keeps ASCII digits, and **translates** Arabic-Indic ones rather than dropping them.
    ///
    /// The keypad is forced to Western numerals, but digits can still arrive in Arabic-Indic form
    /// — a third-party or hardware keyboard, dictation, or a pasted code from an SMS the system
    /// rendered in Arabic. The previous version filtered those out silently, so a user typing
    /// ٠٥٠… or pasting their code saw the field stay empty with no explanation and simply could
    /// not sign in. Translating means whatever they enter works.
    static func normalizedDigits(_ raw: String) -> String {
        var out = ""
        for scalar in raw.unicodeScalars {
            switch scalar.value {
            case 0x30...0x39:   out.unicodeScalars.append(scalar)                                  // 0-9
            case 0x0660...0x0669: out.unicodeScalars.append(UnicodeScalar(scalar.value - 0x0660 + 0x30)!) // ٠-٩
            case 0x06F0...0x06F9: out.unicodeScalars.append(UnicodeScalar(scalar.value - 0x06F0 + 0x30)!) // ۰-۹
            default: break
            }
        }
        return out
    }

    public final class Coordinator: NSObject, UITextFieldDelegate {
        fileprivate var parent: UIKitNumberField
        init(_ parent: UIKitNumberField) { self.parent = parent }

        @objc func editingChanged(_ field: UITextField) {
            let digitsOnly = UIKitNumberField.normalizedDigits(field.text ?? "")
            let clamped = parent.maxLength.map { String(digitsOnly.prefix($0)) } ?? digitsOnly
            if field.text != clamped { field.text = clamped }
            if parent.text != clamped { parent.text = clamped }
        }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { DispatchQueue.main.async { self.parent.isFocused = true } }
        }

        public func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused { DispatchQueue.main.async { self.parent.isFocused = false } }
        }

        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit?()
            textField.resignFirstResponder()
            return true
        }
    }
}
#endif
