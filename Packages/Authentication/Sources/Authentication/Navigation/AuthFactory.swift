import SwiftUI
import Core

/// Builds the SwiftUI destination for each `AuthRoute`, and the onboarding root. Views never
/// build each other — they ask the coordinator to navigate, and the coordinator's stack renders
/// through this factory. This is also the single place view models are constructed.
@MainActor
struct AuthFactory: ViewFactory {
    let useCases: AuthUseCases
    let coordinator: AuthCoordinator

    @ViewBuilder
    func makeView(for route: AuthRoute) -> some View {
        switch route {
        case .phoneEntry:
            PhoneEntryView(
                viewModel: PhoneEntryViewModel(sendOTP: useCases.sendOTP),
                coordinator: coordinator
            )
        case .otp(let challengeId):
            otpView(challengeId: challengeId)
        case .name(let challengeId, let code):
            NameEntryView(
                viewModel: NameEntryViewModel(
                    challengeId: challengeId,
                    code: code,
                    role: coordinator.selectedRole,
                    registerWithName: useCases.registerWithName
                ),
                coordinator: coordinator
            )
        }
    }

    /// The feature's root screen (the sign-in landing page), the base of the navigation stack.
    @ViewBuilder
    func makeRoot() -> some View {
        AuthLandingView(
            viewModel: OnboardingViewModel(
                continueAsGuest: useCases.continueAsGuest,
                appleSignIn: useCases.appleSignIn
            ),
            coordinator: coordinator
        )
    }

    @ViewBuilder
    private func otpView(challengeId: String) -> some View {
        // The OTP screen needs the full challenge (phone + resend interval), held on the
        // coordinator. If it's missing (e.g. state restoration mid-flow), fall back to a minimal
        // challenge from the route's id so the screen still renders and can verify.
        let challenge = coordinator.activeChallenge
            ?? OTPChallenge(id: challengeId, phoneE164: "", resendInterval: defaultResendIntervalSeconds)
        OTPView(
            viewModel: OTPViewModel(
                challenge: challenge,
                verifyOTP: useCases.verifyOTP,
                sendOTP: useCases.sendOTP
            ),
            coordinator: coordinator
        )
    }
}
