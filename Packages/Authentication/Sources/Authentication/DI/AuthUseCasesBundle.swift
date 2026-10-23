import Foundation

/// A bundle of the auth use cases, resolved once from the repository and handed to view models
/// via initializer injection. Keeps view-model initializers small and lets tests pass a bundle
/// built from fakes.
public struct AuthUseCases: Sendable {
    public let sendOTP: any SendOTPUseCase
    public let verifyOTP: any VerifyOTPUseCase
    public let registerWithName: any RegisterWithNameUseCase
    public let appleSignIn: any AppleSignInUseCase
    public let continueAsGuest: any ContinueAsGuestUseCase

    public init(
        sendOTP: any SendOTPUseCase,
        verifyOTP: any VerifyOTPUseCase,
        registerWithName: any RegisterWithNameUseCase,
        appleSignIn: any AppleSignInUseCase,
        continueAsGuest: any ContinueAsGuestUseCase
    ) {
        self.sendOTP = sendOTP
        self.verifyOTP = verifyOTP
        self.registerWithName = registerWithName
        self.appleSignIn = appleSignIn
        self.continueAsGuest = continueAsGuest
    }

    /// Convenience: build the whole bundle from a single repository.
    public init(repository: AuthRepository) {
        self.init(
            sendOTP: SendOTP(repository: repository),
            verifyOTP: VerifyOTP(repository: repository),
            registerWithName: RegisterWithName(repository: repository),
            appleSignIn: AppleSignIn(repository: repository),
            continueAsGuest: ContinueAsGuest(repository: repository)
        )
    }
}
