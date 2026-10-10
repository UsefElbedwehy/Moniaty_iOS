import Foundation
import Core
import Networking

/// Backend-agnostic `AuthRepository` reference implementation over `Networking.APIClient`.
///
/// NOTE: the live app uses `App/…/SupabaseAuthRepository` instead (which speaks GoTrue's exact
/// wire shapes). This generic version is kept as a clean, provider-neutral example and is still
/// compiled/tested; it maps the `APIEndpoint.authentication.*` endpoints to its own DTOs.
/// Session state is tracked in-memory; persisting a token is the App/Keychain layer's concern.
public actor RemoteAuthRepository: AuthRepository {
    private let client: APIClient
    private var state: AuthState = .guest

    public init(client: APIClient) {
        self.client = client
    }

    public func sendOTP(phoneE164: String) async throws -> OTPChallenge {
        let response: SendOTPResponseDTO = try await client.send(
            APIEndpoint.authentication.sendOTP,
            body: SendOTPRequestDTO(phone: phoneE164)
        )
        return response.toDomain()
    }

    public func verifyOTP(challengeId: String, code: String) async throws -> User {
        let response: VerifyOTPResponseDTO = try await client.send(
            APIEndpoint.authentication.verifyOTP,
            body: VerifyOTPRequestDTO(challengeId: challengeId, code: code)
        )
        let user = response.toDomain()
        state = .authenticated(user)
        return user
    }

    public func registerWithName(challengeId: String, code: String, firstName: String, lastName: String, role: UserRole) async throws -> User {
        // Reference impl doesn't model the two-step name flow; treat it as a plain verify.
        try await verifyOTP(challengeId: challengeId, code: code)
    }

    public func signInWithApple(idToken: String, nonce: String) async throws -> User {
        let response: VerifyOTPResponseDTO = try await client.send(
            APIEndpoint.authentication.signInWithIdToken,
            body: AppleSignInRequestDTO(provider: "apple", idToken: idToken, nonce: nonce)
        )
        let user = response.toDomain()
        state = .authenticated(user)
        return user
    }

    public func continueAsGuest() async throws -> AuthState {
        let _: ContinueAsGuestResponseDTO = try await client.send(APIEndpoint.authentication.signUpAnonymous)
        state = .guest
        return state
    }

    public var currentState: AuthState {
        get async { state }
    }
}
