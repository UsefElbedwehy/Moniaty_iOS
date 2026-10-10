import SwiftUI
import Observation
import Core

/// Owns all navigation for the auth flow. Views express intent by calling these methods; they
/// never push an `AuthRoute` or build a destination themselves.
///
/// The coordinator does not know what happens *after* auth — it just reports completion (either
/// `.authenticated` or `.guest`) through `onFinished`, which the App composition root supplies.
/// This is what keeps the feature mountable anywhere: swap the callback, reuse the flow.
///
/// The active `OTPChallenge` is held here (not smuggled through the route) so the OTP screen can
/// show "Sent to <phone>" and drive its resend countdown from the same interval the send call
/// returned. Routes stay simple, `Hashable` payloads.
@MainActor
@Observable
public final class AuthCoordinator: Coordinator {
    public typealias Route = AuthRoute

    public var path = NavigationPath()
    public var presentedSheet: AuthRoute?
    public var presentedFullScreenCover: AuthRoute?

    /// The challenge from the most recent successful `sendOTP`. Read by the factory when it
    /// builds the OTP screen.
    public private(set) var activeChallenge: OTPChallenge?

    /// The side picked on the landing screen. Sent with registration for new numbers; an
    /// existing account keeps the role stored on its profile.
    public private(set) var selectedRole: UserRole = .bride

    private let onFinished: (AuthState) -> Void

    public init(onFinished: @escaping (AuthState) -> Void) {
        self.onFinished = onFinished
    }

    // MARK: - Intents

    /// Landing → "I'm a bride" / "I'm a service provider".
    public func startPhoneSignIn(as role: UserRole) {
        selectedRole = role
        push(.phoneEntry)
    }

    /// Phone entry sent a code — advance to OTP with the returned challenge.
    public func didSendOTP(_ challenge: OTPChallenge) {
        activeChallenge = challenge
        push(.otp(challengeId: challenge.id))
    }

    /// OTP verified but the number is new — collect a name before creating the account. The code
    /// stays valid; it travels on the route so registration can reuse it.
    public func needsName(code: String) {
        guard let challenge = activeChallenge else { return }
        push(.name(challengeId: challenge.id, code: code))
    }

    /// OTP screen's "Edit" — go back to the number field.
    public func editPhoneNumber() {
        pop()
    }

    /// Verification succeeded. Report completion; the App decides where to go next.
    public func didAuthenticate(_ user: User) {
        // The server always reports the account's role; when it doesn't (mock backend), the
        // side picked on the landing screen is the best answer.
        let resolved = user.role == nil
            ? User(id: user.id, phoneNumber: user.phoneNumber, displayName: user.displayName, role: selectedRole)
            : user
        onFinished(.authenticated(resolved))
    }

    /// Onboarding → "Browse as guest" resolved. Forwards whatever the use case actually
    /// returned — `.authenticated` when the anonymous sign-in succeeded (the normal case, since
    /// it yields a real session), `.guest` only if it didn't. Reporting anything else here would
    /// silently strand a successfully-authenticated guest in guest-looking UI.
    public func didContinueAsGuest(_ state: AuthState) {
        onFinished(state)
    }
}
