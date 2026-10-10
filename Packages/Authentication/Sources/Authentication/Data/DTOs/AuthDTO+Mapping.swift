import Foundation

/// Default resend window when the backend does not specify one. Matches the mock's 30s so the
/// countdown behaves identically whether we're on real or mock infrastructure.
let defaultResendIntervalSeconds: Double = 30

extension SendOTPResponseDTO {
    func toDomain() -> OTPChallenge {
        OTPChallenge(
            id: challengeId,
            phoneE164: phone,
            resendInterval: resendIntervalSeconds ?? defaultResendIntervalSeconds
        )
    }
}

extension VerifyOTPResponseDTO {
    func toDomain() -> User {
        User(id: userId, phoneNumber: phone, displayName: displayName, role: role.flatMap(UserRole.init(rawValue:)))
    }
}
