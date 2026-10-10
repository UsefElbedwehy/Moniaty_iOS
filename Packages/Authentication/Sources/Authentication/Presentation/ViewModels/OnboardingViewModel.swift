import Foundation
import Observation
import Core

/// Onboarding is mostly routing intent, plus the one async action that has no screen of its own:
/// "Browse as guest" calls the guest use case and reports completion. Apple Sign In is stubbed
/// to route the same way phone does for now (the App layer owns the real ASAuthorization flow);
/// exposed here so the view has a single place to send that intent.
@MainActor
@Observable
public final class OnboardingViewModel {
    /// Tracks the guest action so the button can show a spinner and errors surface inline.
    public private(set) var guestState: ViewState<AuthState> = .empty
    /// Tracks the Apple sign-in exchange.
    public private(set) var appleState: ViewState<User> = .empty

    private let continueAsGuest: any ContinueAsGuestUseCase
    private let appleSignIn: any AppleSignInUseCase

    public init(continueAsGuest: any ContinueAsGuestUseCase, appleSignIn: any AppleSignInUseCase) {
        self.continueAsGuest = continueAsGuest
        self.appleSignIn = appleSignIn
    }

    public var isBusy: Bool { guestState.isLoading || appleState.isLoading }
    public var errorMessage: AppError? { guestState.error ?? appleState.error }

    /// Exchanges an Apple identity token for a session, then reports the authenticated state.
    public func signInWithApple(idToken: String, nonce: String, onDone: @escaping (AuthState) -> Void) async {
        appleState = .loading
        do {
            let user = try await appleSignIn(idToken: idToken, nonce: nonce)
            appleState = .loaded(user)
            onDone(.authenticated(user))
        } catch let error as AppError {
            appleState = .error(error)
        } catch {
            appleState = .error(.unknown(message: error.localizedDescription))
        }
    }

    /// Runs the guest use case. On success `onDone` receives the resolved `AuthState` — normally
    /// `.authenticated`, since the anonymous sign-in yields a real session — which the view
    /// forwards verbatim to `coordinator.didContinueAsGuest(_:)`.
    public func browseAsGuest(onDone: @escaping (AuthState) -> Void) async {
        guestState = .loading
        do {
            let state = try await continueAsGuest()
            guestState = .loaded(state)
            onDone(state)
        } catch let error as AppError {
            guestState = .error(error)
        } catch {
            guestState = .error(.unknown(message: error.localizedDescription))
        }
    }
}
