import Foundation

/// Destinations within the auth flow. Onboarding is the stack root (not a route). Routes carry
/// only `Hashable` payloads — the challenge that OTP verification needs travels as its id, and
/// the phone/resend metadata is re-derived by the factory from the coordinator's held challenge.
public enum AuthRoute: Hashable, Sendable {
    case phoneEntry
    case otp(challengeId: String)
    /// New user who verified their code but must supply a name before the account is created.
    /// Carries the still-valid code so registration reuses it.
    case name(challengeId: String, code: String)
}
