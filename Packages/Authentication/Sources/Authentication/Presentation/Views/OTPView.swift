import SwiftUI
import DesignSystem
import Core

/// OTP entry: back chevron, title, "Sent to <phone>. Edit", six discrete code boxes with an
/// emerald ring on the active box, and a resend countdown that becomes an active button at zero.
///
/// Autofill approach: a single transparent `TextField` with `.textContentType(.oneTimeCode)`
/// overlays the six boxes and owns the real input and keyboard. The boxes are a read-only visual
/// rendering of its text. This gives iOS one-time-code autofill for free while keeping the
/// six-box look, and stays fully usable (tap anywhere focuses the field).
struct OTPView: View {
    @Environment(\.dsRaisedSurface) private var raisedSurface
    @State private var viewModel: OTPViewModel
    private let coordinator: AuthCoordinator

    // Plain @State, not @FocusState: the real input is UIKit-backed (see `codeBoxes`) and manages
    // its own first-responder state via this binding rather than SwiftUI's focus system.
    @State private var fieldFocused = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: OTPViewModel, coordinator: AuthCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                titleBlock
                codeBoxes
                if let error = viewModel.errorMessage {
                    AuthL10n.text(LocalizedStringKey(error.errorDescription ?? "auth.error.codeInvalid"))
                        .font(.dsFootnote)
                        .foregroundStyle(Color.dsError)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(AuthL10n.string(error.errorDescription ?? "auth.error.codeInvalid"))
                }
                resendRow
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.top, DSSpacing.sm)
            Spacer(minLength: 0)
        }
        .dsScreenBackground()
        .authHiddenBackButton()
        .authInlineNavigationTitle()
        .task {
            viewModel.startCountdown()
            fieldFocused = true
        }
        .onDisappear { viewModel.stopCountdown() }
        .onChange(of: viewModel.isComplete) { _, complete in
            if complete { submit() }
        }
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
            AuthL10n.text("auth.otp.title")
                .font(.dsTitle1)
                .foregroundStyle(Color.dsTextPrimary)
            HStack(spacing: DSSpacing.xxs) {
                Text(AuthL10n.sentTo(viewModel.challenge.phoneE164))
                    .font(.dsBody)
                    .foregroundStyle(Color.dsTextSecondary)
                Button {
                    coordinator.editPhoneNumber()
                } label: {
                    AuthL10n.text("auth.otp.edit")
                        .font(.dsBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.dsPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AuthL10n.string("auth.otp.edit"))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var codeBoxes: some View {
        ZStack {
            // Real input + keyboard + one-time-code autofill; visually transparent.
            codeFieldInput
                .accessibilityLabel(AuthL10n.string("auth.otp.codeAccessibility"))

            HStack(spacing: DSSpacing.xs) {
                ForEach(0..<otpCodeLength, id: \.self) { index in
                    codeBox(at: index)
                }
            }
            // A code is a number, and numbers read left-to-right in Arabic too. Without this the
            // HStack mirrors under RTL, so the first digit typed lands in the rightmost box and
            // the code appears reversed against the SMS the user is copying from.
            .environment(\.layoutDirection, .leftToRight)
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { fieldFocused = true }
    }

    // UIKit-backed for the same reason as the phone field: Arabic locale otherwise shows an
    // Arabic-Indic keypad, and typed Arabic-Indic digits would never match the ASCII code the
    // server generated, so verification would silently and confusingly always fail. `UIKitNumberField`
    // only exists under `canImport(UIKit)`; the macOS host (where `swift build`/`swift test` run)
    // falls back to a plain `TextField` purely so the package still compiles there.
    @ViewBuilder
    private var codeFieldInput: some View {
        #if canImport(UIKit)
        UIKitNumberField(
            text: $viewModel.code,
            isFocused: $fieldFocused,
            textColor: .clear,
            maxLength: otpCodeLength,
            textContentType: .oneTimeCode
        )
        #else
        TextField("", text: $viewModel.code)
            .foregroundStyle(Color.clear)
            .tint(Color.clear)
        #endif
    }

    private func codeBox(at index: Int) -> some View {
        let digits = Array(viewModel.code)
        let hasDigit = index < digits.count
        let isActive = fieldFocused && index == digits.count && !viewModel.isComplete

        return Text(hasDigit ? String(digits[index]) : "")
            .font(.dsTitle2)
            .fontWeight(.bold)
            .foregroundStyle(Color.dsTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            // One fill in both states under a skin — the box's own border already marks the
            // active and filled digits.
            .background(
                raisedSurface ?? (hasDigit || isActive ? Color.dsSurface : Color.dsElevated),
                in: RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous)
                    .stroke(
                        isActive || hasDigit ? Color.dsPrimary : Color.dsBorder,
                        lineWidth: isActive || hasDigit ? 2 : 1
                    )
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isActive)
    }

    @ViewBuilder
    private var resendRow: some View {
        HStack {
            Spacer()
            if viewModel.canResend {
                Button {
                    Task { await viewModel.resend() }
                } label: {
                    AuthL10n.text("auth.otp.resend")
                        .font(.dsSubhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.dsPrimary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AuthL10n.string("auth.otp.resend"))
            } else {
                Text(AuthL10n.resendIn(viewModel.resendCountdownText))
                    .font(.dsSubhead)
                    .foregroundStyle(Color.dsTextSecondary)
                    .frame(minHeight: 44)
                    .accessibilityLabel(AuthL10n.resendIn(viewModel.resendCountdownText))
            }
            Spacer()
        }
        .overlay(alignment: .trailing) {
            if viewModel.isVerifying {
                ProgressView().padding(.trailing, DSSpacing.md)
            }
        }
    }

    private func submit() {
        fieldFocused = false
        Task {
            await viewModel.verify { user in
                coordinator.didAuthenticate(user)
            } onNeedsName: { code in
                coordinator.needsName(code: code)
            }
        }
    }
}
