import SwiftUI
import DesignSystem
import Core

/// Phone-number entry: back chevron, title, subtitle, a compact leading country-code field
/// (SA +966) beside the national-number field with an emerald focus ring, a terms footnote, and
/// a "Send code" CTA docked above the keyboard.
struct PhoneEntryView: View {
    @Environment(\.dsRaisedSurface) private var raisedSurface
    @State private var viewModel: PhoneEntryViewModel
    private let coordinator: AuthCoordinator

    // Plain @State, not @FocusState: the number field is UIKit-backed (see `numberField`) and
    // manages its own first-responder state via this binding rather than SwiftUI's focus system.
    @State private var numberFieldFocused = false

    init(viewModel: PhoneEntryViewModel, coordinator: AuthCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    titleBlock
                    numberRow
                    if let error = viewModel.fieldError {
                        AuthL10n.text(LocalizedStringKey(error.errorDescription ?? "auth.error.phoneInvalid"))
                            .font(.dsFootnote)
                            .foregroundStyle(Color.dsError)
                            .accessibilityLabel(AuthL10n.string(error.errorDescription ?? "auth.error.phoneInvalid"))
                    }
                    termsFootnote
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            Spacer(minLength: 0)
            sendButton
        }
        .dsScreenBackground()
        .authHiddenBackButton()
        .authInlineNavigationTitle()
        .onAppear { numberFieldFocused = true }
    }

    private var header: some View {
        HStack {
            BackChevronButton { coordinator.pop() }
            Spacer()
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.top, DSSpacing.sm)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            AuthL10n.text("auth.phone.title")
                .font(.dsTitle1)
                .foregroundStyle(Color.dsTextPrimary)
            AuthL10n.text("auth.phone.subtitle")
                .font(.dsBody)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var numberRow: some View {
        HStack(spacing: DSSpacing.xs) {
            countryCodeField
            numberField
        }
    }

    /// A tappable country picker: ISO badge + dial code + a chevron cue. A `Menu` (rather than a
    /// separate screen) keeps the two-country choice one tap away. With a single selectable country
    /// it collapses to a plain, non-interactive chip.
    private var countryCodeField: some View {
        Menu {
            ForEach(PhoneCountry.selectable) { country in
                Button {
                    viewModel.selectedCountry = country
                } label: {
                    if country == viewModel.selectedCountry {
                        Label("\(country.id)  \(country.dialCode)", systemImage: "checkmark")
                    } else {
                        Text(verbatim: "\(country.id)  \(country.dialCode)")
                    }
                }
            }
        } label: {
            HStack(spacing: DSSpacing.xxs) {
                Text(verbatim: viewModel.selectedCountry.id)
                    .font(.dsCaption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DSSpacing.xxs)
                    .padding(.vertical, 2)
                    .background(Color.dsPrimary, in: RoundedRectangle(cornerRadius: DSRadius.control / 2, style: .continuous))
                Text(verbatim: viewModel.selectedCountry.dialCode)
                    .font(.dsBody)
                    .foregroundStyle(Color.dsTextPrimary)
                if PhoneCountry.selectable.count > 1 {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.dsCaption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .frame(height: 56)
            .background(raisedSurface ?? Color.dsElevated, in: RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
        }
        .disabled(PhoneCountry.selectable.count <= 1)
        .accessibilityLabel(AuthL10n.string("auth.phone.countryAccessibility"))
    }

    private var numberField: some View {
        numberFieldInput
            .padding(.horizontal, DSSpacing.md)
            .frame(height: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(raisedSurface ?? Color.dsSurface, in: RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous)
                    .stroke(numberFieldFocused ? Color.dsPrimary : Color.dsBorder, lineWidth: numberFieldFocused ? 2 : 1)
            )
            .accessibilityLabel(AuthL10n.string("auth.phone.numberAccessibility"))
    }

    // UIKit-backed (not SwiftUI's TextField): in Arabic, `.phonePad`/`.numberPad` show an
    // Arabic-Indic keypad and SwiftUI's own cursor handling breaks under RTL layout for
    // digit-only fields. See `UIKitNumberField`'s doc comment for the full story. `UIKitNumberField`
    // only exists under `canImport(UIKit)`; the macOS host (where `swift build`/`swift test` run)
    // falls back to a plain `TextField` purely so the package still compiles there.
    @ViewBuilder
    private var numberFieldInput: some View {
        #if canImport(UIKit)
        UIKitNumberField(
            text: $viewModel.nationalNumber,
            isFocused: $numberFieldFocused,
            placeholder: viewModel.selectedCountry.example,
            font: .preferredFont(forTextStyle: .body),
            textColor: UIColor(Color.dsTextPrimary),
            placeholderColor: UIColor(Color.dsTextSecondary).withAlphaComponent(0.5),
            textContentType: .telephoneNumber
        )
        #else
        TextField("", text: $viewModel.nationalNumber, prompt: Text(verbatim: viewModel.selectedCountry.example))
            .font(.dsBody)
        #endif
    }

    private var termsFootnote: some View {
        AuthL10n.text("auth.phone.terms")
            .font(.dsFootnote)
            .foregroundStyle(Color.dsTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var sendButton: some View {
        PrimaryButton(
            AuthL10n.dsKey("auth.phone.sendCode"),
            isLoading: viewModel.isSending,
            isEnabled: viewModel.canSubmit
        ) {
            numberFieldFocused = false
            Task {
                await viewModel.sendCode { challenge in
                    coordinator.didSendOTP(challenge)
                }
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.sm)
        .dsScreenBackground()
    }
}
