import Foundation
import Observation
import Core

/// Holds the six-digit code and a single `ViewState<User>` for the verify action, plus a resend
/// countdown driven by a `Task`. The countdown starts at the challenge's `resendInterval` and
/// ticks to zero, at which point "Resend" becomes an active button.
@MainActor
@Observable
public final class OTPViewModel {
    public let challenge: OTPChallenge

    /// The code as entered, capped to `otpCodeLength` digits. The view binds its six boxes here.
    /// Sanitizing happens in the setter (not a `didSet`, which would re-enter and recurse under
    /// `@Observable`), so any assignment — including autofill — is normalized to digits only.
    public var code: String {
        get { rawCode }
        set { rawCode = Self.sanitize(newValue) }
    }
    private var rawCode: String = ""

    public private(set) var state: ViewState<User> = .empty
    /// Whole seconds remaining before resend is allowed; 0 means "Resend" is live.
    public private(set) var resendSecondsRemaining: Int = 0

    private let verifyOTP: any VerifyOTPUseCase
    private let sendOTP: any SendOTPUseCase
    private var countdownTask: Task<Void, Never>?

    public init(
        challenge: OTPChallenge,
        verifyOTP: any VerifyOTPUseCase,
        sendOTP: any SendOTPUseCase
    ) {
        self.challenge = challenge
        self.verifyOTP = verifyOTP
        self.sendOTP = sendOTP
    }

    public var isVerifying: Bool { state.isLoading }
    public var canResend: Bool { resendSecondsRemaining <= 0 && !isVerifying }
    public var isComplete: Bool { code.count == otpCodeLength }

    /// The inline error to show, if the last verify failed.
    public var errorMessage: AppError? {
        if case .error(let error) = state { return error }
        return nil
    }

    /// "0:24" style string for the resend line.
    public var resendCountdownText: String {
        let minutes = resendSecondsRemaining / 60
        let seconds = resendSecondsRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Begin (or restart) the resend countdown from the challenge's interval. The ticking `Task`
    /// holds `self` weakly, so it stops on its own once the view model is gone; `stopCountdown()`
    /// lets the view cancel it eagerly on disappear.
    public func startCountdown() {
        countdownTask?.cancel()
        resendSecondsRemaining = max(0, Int(challenge.resendInterval.rounded()))
        guard resendSecondsRemaining > 0 else { return }
        countdownTask = Task { [weak self] in
            while let self, self.resendSecondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                self.decrementCountdown()
            }
        }
    }

    /// Cancel the countdown (e.g. the screen disappeared).
    public func stopCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func decrementCountdown() {
        if resendSecondsRemaining > 0 { resendSecondsRemaining -= 1 }
    }

    /// Verify the current code. On success `onUser` hands the user to the coordinator. If the
    /// number is brand-new, the code is accepted but the account can't be created yet — `onNeedsName`
    /// fires so the flow can push the name screen (the same `code` is reused there).
    public func verify(onUser: @escaping (User) -> Void, onNeedsName: @escaping (String) -> Void) async {
        guard !isVerifying else { return }
        state = .loading
        let submittedCode = code
        do {
            let user = try await verifyOTP(challengeId: challenge.id, code: submittedCode)
            state = .loaded(user)
            onUser(user)
        } catch is OTPFlowError {
            state = .empty          // not an error — just needs a name; don't show a red message
            onNeedsName(submittedCode)
        } catch let error as AppError {
            state = .error(error)
        } catch {
            state = .error(.unknown(message: error.localizedDescription))
        }
    }

    /// Resend the code for the same number and restart the countdown. Clears any prior error.
    public func resend() async {
        guard canResend else { return }
        do {
            _ = try await sendOTP(phoneE164: challenge.phoneE164)
            code = ""
            state = .empty
            startCountdown()
        } catch let error as AppError {
            state = .error(error)
        } catch {
            state = .error(.unknown(message: error.localizedDescription))
        }
    }

    /// ASCII digits only — `\.isNumber` alone also accepts Arabic-Indic digits (٠-٩), which are a
    /// different Unicode codepoint from "0-9" and would never match the ASCII code the server
    /// generated, silently failing verification. The UIKit-backed field already keeps these out at
    /// the keystroke level; this guards the autofill path too (`.oneTimeCode` inserts the whole
    /// string in one write, bypassing per-keystroke filtering).
    private static func sanitize(_ raw: String) -> String {
        String(raw.filter { $0.isASCII && $0.isNumber }.prefix(otpCodeLength))
    }
}
