import Foundation

/// The Domain-facing contract for authentication. The Presentation layer only ever talks to
/// use cases, which talk to this — never to `Networking` or a concrete impl. Two implementations
/// exist: `RemoteAuthRepository` (real API calls) and `MockAuthRepository` (in-memory, what the
/// app runs on until a backend exists).
public protocol AuthRepository: Sendable {
    /// Start a phone verification. Returns a challenge the OTP screen verifies against.
    func sendOTP(phoneE164: String) async throws -> OTPChallenge
    /// Verify a code against a challenge. On success the user is authenticated. If the phone
    /// belongs to a brand-new user who hasn't given their name yet, this throws
    /// `OTPFlowError.requiresRegistration` — the caller then collects a first/last name and calls
    /// `registerWithName`. The verification code stays valid across the two calls.
    func verifyOTP(challengeId: String, code: String) async throws -> User
    /// Complete a new user's signup: verify the same code and create the account with the given
    /// name (first + last, both required) and the role picked on the landing screen. On success
    /// the user is authenticated.
    func registerWithName(challengeId: String, code: String, firstName: String, lastName: String, role: UserRole) async throws -> User
    /// Exchange an Apple identity token (from Sign in with Apple) for a session.
    /// `nonce` is the RAW nonce whose SHA-256 was sent in the Apple request.
    func signInWithApple(idToken: String, nonce: String) async throws -> User
    /// Enter the app without signing in.
    func continueAsGuest() async throws -> AuthState
    /// The current known auth state (e.g. after guest entry or a completed verification).
    var currentState: AuthState { get async }
}

/// Signals raised by the phone-OTP flow that the UI reacts to specifically (rather than showing a
/// generic error). `requiresRegistration` means the code was accepted but the account can't be
/// created until the user supplies a name.
public enum OTPFlowError: Error, Sendable {
    case requiresRegistration
}

/// The server's response to `sendOTP`: an opaque challenge id, the number it was sent to (so the
/// OTP screen can show "Sent to …"), and how long the user must wait before a resend is allowed.
public struct OTPChallenge: Equatable, Sendable {
    public let id: String
    public let phoneE164: String
    public let resendInterval: TimeInterval

    public init(id: String, phoneE164: String, resendInterval: TimeInterval) {
        self.id = id
        self.phoneE164 = phoneE164
        self.resendInterval = resendInterval
    }
}
