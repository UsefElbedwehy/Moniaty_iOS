import Testing
import Foundation
import Core
@testable import Authentication

@MainActor
@Suite("OTPViewModel state transitions")
struct OTPViewModelTests {
    private func makeViewModel(repo: MockAuthRepository) async throws -> OTPViewModel {
        let challenge = try await SendOTP(repository: repo)(phoneE164: "+966551234567")
        return OTPViewModel(
            challenge: challenge,
            verifyOTP: VerifyOTP(repository: repo),
            sendOTP: SendOTP(repository: repo)
        )
    }

    @Test("idle → loaded(User) on the correct code")
    func verifiesCorrectCode() async throws {
        let repo = MockAuthRepository(artificialDelay: .zero)
        let vm = try await makeViewModel(repo: repo)

        // Starts idle (no submit yet).
        if case .empty = vm.state {} else { Issue.record("expected .empty initial state, got \(vm.state)") }

        vm.code = MockAuthRepository.acceptedCode
        var reported: User?
        await vm.verify(onUser: { reported = $0 }, onNeedsName: { _, _ in })

        #expect(vm.state.value != nil)
        #expect(reported?.phoneNumber == "+966551234567")
    }

    @Test("idle → error on a wrong code, no user reported")
    func failsWrongCode() async throws {
        let repo = MockAuthRepository(artificialDelay: .zero)
        let vm = try await makeViewModel(repo: repo)

        vm.code = "000000"
        var reported: User?
        await vm.verify(onUser: { reported = $0 }, onNeedsName: { _, _ in })

        #expect(reported == nil)
        #expect(vm.errorMessage == .authentication(.otpIncorrect))
    }

    @Test("code binding sanitizes to digits and caps at six")
    func sanitizesCode() async throws {
        let vm = try await makeViewModel(repo: MockAuthRepository(artificialDelay: .zero))
        vm.code = "12ab34-5678"
        #expect(vm.code == "123456")
        #expect(vm.isComplete)
    }

    @Test("countdown starts from the challenge interval and blocks resend")
    func countdownBlocksResend() async throws {
        let vm = try await makeViewModel(repo: MockAuthRepository(artificialDelay: .zero))
        vm.startCountdown()
        #expect(vm.resendSecondsRemaining == 30)
        #expect(vm.canResend == false)
        #expect(vm.resendCountdownText == "0:30")
        vm.stopCountdown()
    }

    @Test("sends the picked side and reports the number's other account on registration")
    func passesRoleAndOtherAccount() async throws {
        let use = RecordingVerify()
        let vm = OTPViewModel(challenge: OTPChallenge(id: "+966551234567", phoneE164: "+966551234567", resendInterval: 30),
                              verifyOTP: use, sendOTP: SendOTP(repository: MockAuthRepository(artificialDelay: .zero)),
                              role: .bride)
        vm.code = "123456"
        var needsName: (String, UserRole?)?
        await vm.verify(onUser: { _ in }, onNeedsName: { needsName = ($0, $1) })

        #expect(await use.role == .bride)
        #expect(needsName?.0 == "123456")
        #expect(needsName?.1 == .provider)
        if case .empty = vm.state {} else { Issue.record("registration is not an error, got \(vm.state)") }
    }
}

/// A number that has a provider account but no bride account yet.
private actor RecordingVerify: VerifyOTPUseCase {
    private(set) var role: UserRole?
    func callAsFunction(challengeId: String, code: String, role: UserRole?) async throws -> User {
        self.role = role
        throw OTPFlowError.requiresRegistration(otherRole: .provider)
    }
}
