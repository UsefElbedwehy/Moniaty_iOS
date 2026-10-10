import SwiftUI
import DesignSystem
import Core

/// New-user name capture: first + last name, both required, shown right after the OTP is verified
/// for a brand-new number. Submitting creates the account (via `registerWithName`) and finishes
/// the auth flow. Mirrors `PhoneEntryView`'s chrome (back chevron, title, docked CTA).
struct NameEntryView: View {
    @Environment(\.dsRaisedSurface) private var raisedSurface
    @State private var viewModel: NameEntryViewModel
    private let coordinator: AuthCoordinator

    @FocusState private var focus: Field?
    private enum Field { case first, last }

    init(viewModel: NameEntryViewModel, coordinator: AuthCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    titleBlock
                    VStack(spacing: DSSpacing.sm) {
                        field(text: $viewModel.firstName, prompt: "auth.name.first", field: .first)
                        field(text: $viewModel.lastName, prompt: "auth.name.last", field: .last)
                    }
                    if let error = viewModel.fieldError {
                        AuthL10n.text(LocalizedStringKey(error.errorDescription ?? "auth.error.nameRequired"))
                            .font(.dsFootnote)
                            .foregroundStyle(Color.dsError)
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            Spacer(minLength: 0)
            submitButton
        }
        .dsScreenBackground()
        .authHiddenBackButton()
        .authInlineNavigationTitle()
        .onAppear { focus = .first }
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
            AuthL10n.text("auth.name.title")
                .font(.dsTitle1)
                .foregroundStyle(Color.dsTextPrimary)
            AuthL10n.text("auth.name.subtitle")
                .font(.dsBody)
                .foregroundStyle(Color.dsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func field(text: Binding<String>, prompt: LocalizedStringKey, field: Field) -> some View {
        TextField("", text: text, prompt: AuthL10n.text(prompt))
            .font(.dsBody)
            .autocorrectionDisabled()
            .focused($focus, equals: field)
            .submitLabel(field == .first ? .next : .done)
            .onSubmit { focus = field == .first ? .last : nil }
            .padding(.horizontal, DSSpacing.md)
            .frame(height: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(raisedSurface ?? Color.dsSurface, in: RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous)
                    .stroke(focus == field ? Color.dsPrimary : Color.dsBorder, lineWidth: focus == field ? 2 : 1)
            )
    }

    private var submitButton: some View {
        PrimaryButton(
            AuthL10n.dsKey("auth.name.submit"),
            isLoading: viewModel.isSubmitting,
            isEnabled: viewModel.canSubmit
        ) {
            focus = nil
            Task {
                await viewModel.submit { user in
                    coordinator.didAuthenticate(user)
                }
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.sm)
        .dsScreenBackground()
    }
}
