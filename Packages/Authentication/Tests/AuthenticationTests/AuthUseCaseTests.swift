import Testing
import Foundation
import Core
@testable import Authentication

@Suite("SendOTPUseCase validation")
struct SendOTPUseCaseTests {
    private func makeUseCase() -> SendOTP {
        SendOTP(repository: MockAuthRepository(artificialDelay: .zero))
    }

    @Test("rejects an empty phone number with a validation error")
    func rejectsEmpty() async {
        await #expect(throws: AppError.validation(field: "phone", message: "auth.error.phoneEmpty")) {
            _ = try await makeUseCase()(phoneE164: "")
        }
    }

    @Test("rejects a too-short / implausible phone number")
    func rejectsInvalid() async {
        await #expect(throws: AppError.validation(field: "phone", message: "auth.error.phoneInvalid")) {
            _ = try await makeUseCase()(phoneE164: "+9661")
        }
    }

    @Test("rejects non-Saudi and non-mobile numbers")
    func rejectsNonSaudiMobile() async {
        for number in ["+96550123456", "+966112345678", "+20100123456"] {
            await #expect(throws: AppError.validation(field: "phone", message: "auth.error.phoneInvalid")) {
                _ = try await makeUseCase()(phoneE164: number)
            }
        }
    }

    @Test("accepts a plausible E.164 number and returns a challenge")
    func acceptsValid() async throws {
        let challenge = try await makeUseCase()(phoneE164: "+966 55 123 4567")
        #expect(challenge.phoneE164 == "+966551234567")   // normalized
        #expect(challenge.resendInterval == 30)
        #expect(!challenge.id.isEmpty)
    }
}

@Suite("VerifyOTPUseCase")
struct VerifyOTPUseCaseTests {
    private func makeRepo() -> MockAuthRepository { MockAuthRepository(artificialDelay: .zero) }

    @Test("rejects a non-6-digit code without hitting the repository")
    func rejectsShortCode() async {
        let verify = VerifyOTP(repository: makeRepo())
        await #expect(throws: AppError.validation(field: "code", message: "auth.error.codeInvalid")) {
            _ = try await verify(challengeId: "any", code: "123")
        }
    }

    @Test("accepts the demo code 123456 and returns a user")
    func acceptsCorrectCode() async throws {
        let repo = makeRepo()
        let challenge = try await SendOTP(repository: repo)(phoneE164: "+966551234567")
        let user = try await VerifyOTP(repository: repo)(challengeId: challenge.id, code: MockAuthRepository.acceptedCode)
        #expect(user.phoneNumber == "+966551234567")
        #expect(!user.id.isEmpty)
    }

    @Test("rejects a wrong 6-digit code with otpIncorrect")
    func rejectsWrongCode() async {
        let repo = makeRepo()
        await #expect(throws: AppError.authentication(.otpIncorrect)) {
            let challenge = try await SendOTP(repository: repo)(phoneE164: "+966551234567")
            _ = try await VerifyOTP(repository: repo)(challengeId: challenge.id, code: "000000")
        }
    }
}

@Suite("ContinueAsGuestUseCase")
struct ContinueAsGuestUseCaseTests {
    @Test("returns .guest")
    func returnsGuest() async throws {
        let state = try await ContinueAsGuest(repository: MockAuthRepository(artificialDelay: .zero))()
        #expect(state == .guest)
    }
}
