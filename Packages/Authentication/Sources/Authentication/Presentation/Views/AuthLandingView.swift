import SwiftUI
import DesignSystem
import Core

/// The first screen: the منيتي wordmark, the tagline, and the role choice — "I'm a bride" or
/// "I'm a service provider" — plus "Browse as guest". Picking a role starts phone sign-in; the
/// role is held by the coordinator and sent with registration if the number is new.
/// Matches mockup 1 (`design/mockups/Main.dc.html`).
struct AuthLandingView: View {
    @State private var viewModel: OnboardingViewModel
    private let coordinator: AuthCoordinator

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: OnboardingViewModel, coordinator: AuthCoordinator) {
        _viewModel = State(initialValue: viewModel)
        self.coordinator = coordinator
    }

    var body: some View {
        VStack(spacing: 0) {
            brand
                .padding(.top, DSSpacing.xxl)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                AuthL10n.text("auth.landing.prompt")
                    .font(.dsSubhead)
                    .foregroundStyle(Color.dsTextSecondary)
                RoleCard(
                    title: AuthL10n.string("auth.role.bride.title"),
                    subtitle: AuthL10n.string("auth.role.bride.subtitle"),
                    systemImage: "sparkles",
                    isProminent: true
                ) { coordinator.startPhoneSignIn(as: .bride) }
                RoleCard(
                    title: AuthL10n.string("auth.role.provider.title"),
                    subtitle: AuthL10n.string("auth.role.provider.subtitle"),
                    systemImage: "storefront",
                    isProminent: false
                ) { coordinator.startPhoneSignIn(as: .provider) }
            }
            .padding(.top, DSSpacing.xxl)
            .disabled(viewModel.isBusy)

            Spacer(minLength: DSSpacing.xl)

            guestButton
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.bottom, DSSpacing.lg)
        .frame(maxWidth: .infinity)
        .dsScreenBackground()
        .authHiddenBackButton()
    }

    private var brand: some View {
        VStack(spacing: DSSpacing.sm) {
            DSBrand.wordmark
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .accessibilityLabel(AuthL10n.string("auth.brand.name"))
            AuthL10n.text("auth.landing.tagline")
                .font(.dsTitle1)
                .foregroundStyle(Color.dsPrimary)
                .multilineTextAlignment(.center)
            HStack(spacing: DSSpacing.xs) {
                Rectangle().fill(Color.dsPremiumGold).frame(width: 48, height: 1)
                DSSparkle()
                Rectangle().fill(Color.dsPremiumGold).frame(width: 48, height: 1)
            }
            .accessibilityHidden(true)
        }
    }

    private var guestButton: some View {
        VStack(spacing: DSSpacing.xs) {
            Button {
                Task { await viewModel.browseAsGuest { coordinator.didContinueAsGuest($0) } }
            } label: {
                Group {
                    if viewModel.isBusy {
                        ProgressView().tint(Color.dsPrimary)
                    } else {
                        AuthL10n.text("auth.onboarding.browseGuest")
                            .font(.dsHeadline)
                            .foregroundStyle(Color.dsPrimary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isBusy)

            if let error = viewModel.errorMessage {
                AuthL10n.text(LocalizedStringKey(error.errorDescription ?? "auth.error.generic"))
                    .font(.dsFootnote)
                    .foregroundStyle(Color.dsError)
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
    }
}

/// One of the two big role buttons on the landing screen.
private struct RoleCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(isProminent ? Color.dsPremiumGold : Color.dsPrimary)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isProminent ? Color.white.opacity(0.12) : Color.dsPrimaryMuted)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.dsTitle2)
                    Text(subtitle)
                        .font(.dsFootnote)
                        .opacity(isProminent ? 0.85 : 1)
                        .foregroundStyle(isProminent ? Color.dsBackground : Color.dsTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.headline)
            }
            .foregroundStyle(isProminent ? Color.dsBackground : Color.dsTextPrimary)
            .padding(DSSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.card)
                    .fill(isProminent ? Color.dsPrimary : Color.dsSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.card)
                    .strokeBorder(isProminent ? Color.clear : Color.dsBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.card))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
