import Foundation

// Wire formats for the three auth endpoints, kept internal — the domain types (`User`,
// `OTPChallenge`, `AuthState`) are the only things that cross out of the Data layer. Field names
// mirror the expected JSON; mapping to domain lives in `AuthDTO+Mapping`.

// MARK: - Send OTP

struct SendOTPRequestDTO: Encodable, Sendable {
    let phone: String
}

struct SendOTPResponseDTO: Decodable, Sendable {
    let challengeId: String
    let phone: String
    /// Seconds the client must wait before offering "Resend". Optional so a backend that omits
    /// it falls back to a sane default at the mapping boundary.
    let resendIntervalSeconds: Double?
}

// MARK: - Verify OTP

struct VerifyOTPRequestDTO: Encodable, Sendable {
    let challengeId: String
    let code: String
}

struct VerifyOTPResponseDTO: Decodable, Sendable {
    let userId: String
    let phone: String?
    let displayName: String?
    /// "bride" | "provider"; nil for guests.
    let role: String?
}

// MARK: - Apple / OIDC id-token

struct AppleSignInRequestDTO: Encodable, Sendable {
    let provider: String     // "apple"
    let idToken: String
    let nonce: String
}

// MARK: - Guest

struct ContinueAsGuestResponseDTO: Decodable, Sendable {
    /// A guest session token, if the backend issues one. Unused by the domain today but decoded
    /// so the response shape is honored.
    let guestToken: String?
}
