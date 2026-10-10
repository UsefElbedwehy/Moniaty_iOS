import Foundation
import Core

/// In-memory `AuthRepository` used until a real backend exists. This is what the app runs on
/// today, so it is a genuine stand-in, not a stub: it issues real challenge ids, enforces a
/// resend window, and accepts exactly one demo code.
///
/// Contract:
/// - `sendOTP` always succeeds and returns a challenge with a 30s resend interval.
/// - `verifyOTP` accepts the code `"123456"` (→ a `User`) and rejects anything else with
///   `AppError.authentication(.otpIncorrect)`. An unknown challenge id yields `.otpExpired`.
/// - `continueAsGuest` returns `.guest`.
public actor MockAuthRepository: AuthRepository {
    /// The single code the mock accepts. Real infra verifies against an SMS-delivered code.
    public static let acceptedCode = "123456"
    private static let resendIntervalSeconds: TimeInterval = 30

    private var state: AuthState = .guest
    private var challenges: [String: String] = [:]  // challengeId → phoneE164
    private let artificialDelay: Duration

    public init(artificialDelay: Duration = .milliseconds(350)) {
        self.artificialDelay = artificialDelay
    }

    public func sendOTP(phoneE164: String) async throws -> OTPChallenge {
        try await tick()
        let id = UUID().uuidString
        challenges[id] = phoneE164
        return OTPChallenge(id: id, phoneE164: phoneE164, resendInterval: Self.resendIntervalSeconds)
    }

    public func verifyOTP(challengeId: String, code: String) async throws -> User {
        try await tick()
        guard let phone = challenges[challengeId] else {
            throw AppError.authentication(.otpExpired)
        }
        guard code == Self.acceptedCode else {
            throw AppError.authentication(.otpIncorrect)
        }
        challenges[challengeId] = nil
        let user = User(id: UUID().uuidString, phoneNumber: phone, displayName: nil)
        state = .authenticated(user)
        return user
    }

    public func registerWithName(challengeId: String, code: String, firstName: String, lastName: String, role: UserRole) async throws -> User {
        // The mock has no server-side "is this a new number" state, so it just verifies.
        try await verifyOTP(challengeId: challengeId, code: code)
    }

    public func signInWithApple(idToken: String, nonce: String) async throws -> User {
        try await tick()
        let user = User(id: UUID().uuidString, phoneNumber: nil, displayName: "Apple User")
        state = .authenticated(user)
        return user
    }

    public func continueAsGuest() async throws -> AuthState {
        try await tick()
        state = .guest
        return state
    }

    public var currentState: AuthState {
        get async { state }
    }

    private func tick() async throws {
        guard artificialDelay > .zero else { return }
        try? await Task.sleep(for: artificialDelay)
    }
}
