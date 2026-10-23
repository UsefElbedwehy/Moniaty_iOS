import Foundation
import Core

// Each use case is a thin, single-purpose type behind a protocol so ViewModels can be tested
// against trivial fakes. App-level input validation (a phone must look like E.164; a code must
// be six digits) lives here, before we ever hit the repository — the backend still does the
// real verification, we just avoid obviously-doomed round trips and give instant field errors.

// MARK: - Send OTP

public protocol SendOTPUseCase: Sendable {
    func callAsFunction(phoneE164: String) async throws -> OTPChallenge
}

public struct SendOTP: SendOTPUseCase {
    private let repository: AuthRepository
    public init(repository: AuthRepository) { self.repository = repository }

    public func callAsFunction(phoneE164: String) async throws -> OTPChallenge {
        let normalized = PhoneNumberValidator.normalize(phoneE164)
        try PhoneNumberValidator.validate(normalized)
        return try await repository.sendOTP(phoneE164: normalized)
    }
}

// MARK: - Verify OTP

public protocol VerifyOTPUseCase: Sendable {
    func callAsFunction(challengeId: String, code: String) async throws -> User
}

public struct VerifyOTP: VerifyOTPUseCase {
    private let repository: AuthRepository
    public init(repository: AuthRepository) { self.repository = repository }

    public func callAsFunction(challengeId: String, code: String) async throws -> User {
        try OTPCodeValidator.validate(code)
        return try await repository.verifyOTP(challengeId: challengeId, code: code)
    }
}

// MARK: - Register with name (new user)

public protocol RegisterWithNameUseCase: Sendable {
    func callAsFunction(challengeId: String, code: String, firstName: String, lastName: String, role: UserRole) async throws -> User
}

public struct RegisterWithName: RegisterWithNameUseCase {
    private let repository: AuthRepository
    public init(repository: AuthRepository) { self.repository = repository }

    public func callAsFunction(challengeId: String, code: String, firstName: String, lastName: String, role: UserRole) async throws -> User {
        try OTPCodeValidator.validate(code)
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !first.isEmpty, !last.isEmpty else {
            throw AppError.validation(field: "name", message: "auth.error.nameRequired")
        }
        return try await repository.registerWithName(challengeId: challengeId, code: code, firstName: first, lastName: last, role: role)
    }
}

// MARK: - Apple Sign In

public protocol AppleSignInUseCase: Sendable {
    func callAsFunction(idToken: String, nonce: String) async throws -> User
}

public struct AppleSignIn: AppleSignInUseCase {
    private let repository: AuthRepository
    public init(repository: AuthRepository) { self.repository = repository }

    public func callAsFunction(idToken: String, nonce: String) async throws -> User {
        try await repository.signInWithApple(idToken: idToken, nonce: nonce)
    }
}

// MARK: - Continue as guest

public protocol ContinueAsGuestUseCase: Sendable {
    func callAsFunction() async throws -> AuthState
}

public struct ContinueAsGuest: ContinueAsGuestUseCase {
    private let repository: AuthRepository
    public init(repository: AuthRepository) { self.repository = repository }

    public func callAsFunction() async throws -> AuthState {
        try await repository.continueAsGuest()
    }
}

// MARK: - Validation

/// The number of digits an OTP code must contain. Shared by the validator and the OTP UI so the
/// six-box layout and the accept rule can never drift apart.
public let otpCodeLength = 6

enum PhoneNumberValidator {
    /// Strip spaces and common separators so "55 123 4567" and "+966 55 123 4567" both normalize
    /// to a bare E.164-ish string. A leading "+" is preserved. Arabic-Indic digits (٠-٩) are
    /// converted to ASCII first, rather than dropped — belt-and-suspenders alongside the
    /// UIKit-backed number field, which already keeps these out of `nationalNumber` at the
    /// keystroke level; this guards paste/autofill paths too.
    static func normalize(_ raw: String) -> String {
        let ascii = String(raw.map { char -> Character in
            guard let scalar = char.unicodeScalars.first, char.unicodeScalars.count == 1 else { return char }
            switch scalar.value {
            case 0x0660...0x0669: return Character(UnicodeScalar(scalar.value - 0x0660 + 48)!) // ٠-٩
            case 0x06F0...0x06F9: return Character(UnicodeScalar(scalar.value - 0x06F0 + 48)!) // ۰-۹
            default: return char
            }
        })
        let allowed = CharacterSet(charactersIn: "+0123456789")
        return String(ascii.unicodeScalars.filter { allowed.contains($0) })
    }

    /// Plausible-E.164 gate: `+` optional, 7–15 digits total (ITU E.164 caps national numbers at
    /// 15). We do not verify the number is reachable — that's the backend's job.
    static func validate(_ normalized: String) throws {
        let digits = normalized.hasPrefix("+") ? String(normalized.dropFirst()) : normalized
        guard !digits.isEmpty else {
            throw AppError.validation(field: "phone", message: "auth.error.phoneEmpty")
        }
        // Munyati serves Saudi Arabia only: +966 5X XXX XXXX (12 digits with country code).
        guard digits.allSatisfy(\.isNumber), digits.count == 12, digits.hasPrefix("9665") else {
            throw AppError.validation(field: "phone", message: "auth.error.phoneInvalid")
        }
    }
}

enum OTPCodeValidator {
    static func validate(_ code: String) throws {
        guard code.count == otpCodeLength, code.allSatisfy(\.isNumber) else {
            throw AppError.validation(field: "code", message: "auth.error.codeInvalid")
        }
    }
}
