import Foundation
import Core
import Networking
import Authentication

/// Supabase-backed `AuthRepository`, living in the App composition root (the only layer allowed
/// to know the backend is Supabase). It talks to GoTrue (`/auth/v1/*`) through the shared
/// `APIClient` and holds the resulting session, exposing the access token + user id to the
/// networking client and the image uploader so authenticated RPC/Storage calls carry the user's
/// bearer token (which is what Row Level Security keys off).
///
/// The session survives app relaunches (Keychain-backed via `KeychainSessionStore`) and renews
/// itself transparently as the access token nears expiry (via GoTrue's `refresh_token` grant) —
/// every caller already reads the token through `currentAccessToken()`, so callers get this for
/// free with no changes on their end.
public actor SupabaseAuthRepository: AuthRepository {
    private let client: APIClient
    private let keychainStore = KeychainSessionStore()
    private var session: Session?
    /// In-flight token refresh, shared by concurrent callers so only one refresh network call
    /// ever runs at a time (see `refreshIfNeeded`).
    private var refreshTask: Task<Void, Never>?

    private struct Session: Sendable {
        let accessToken: String
        let refreshToken: String?
        let userId: String
        let phone: String?
        let expiresAt: Date
    }

    public init(client: APIClient) {
        self.client = client
    }

    /// Restores a Keychain-persisted session at launch, refreshing it first if it's stale.
    /// Returns `.guest` if there's nothing to restore, or if what's saved turns out to be
    /// unrecoverable (e.g. the refresh token itself has since been revoked).
    public func restoreSession() async -> AuthState {
        guard let persisted = keychainStore.load() else { return .guest }
        session = Session(
            accessToken: persisted.accessToken,
            refreshToken: persisted.refreshToken,
            userId: persisted.userId,
            phone: persisted.phone,
            expiresAt: persisted.expiresAt
        )
        guard await currentAccessToken() != nil, let session else { return .guest }
        return .authenticated(User(id: session.userId, phoneNumber: session.phone, displayName: nil))
    }

    // Exposed to the composition root for the networking token provider + Storage uploads.
    // A function (not a stored property) because reading it may trigger a refresh.
    public func currentAccessToken() async -> String? {
        await refreshIfNeeded()
        return session?.accessToken
    }

    public var currentUserId: String? { session?.userId }

    /// Whether the current session belongs to an anonymous "Browse as guest" user, decoded from
    /// the access-token JWT's `is_anonymous` claim. True for guests, false for Apple/phone
    /// accounts (or when there's no session). Used to gate identity-requiring actions like
    /// reviewing, which a guest must sign in for first. Works for restored sessions too, since it
    /// reads the token itself rather than any separately-persisted flag.
    public var currentUserIsAnonymous: Bool {
        guard let token = session?.accessToken else { return false }
        return Self.jwtClaimIsAnonymous(token)
    }

    private static func jwtClaimIsAnonymous(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return false }
        var payload = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return (json["is_anonymous"] as? Bool) ?? false
    }

    public var currentState: AuthState {
        guard let session else { return .guest }
        return .authenticated(User(id: session.userId, phoneNumber: session.phone, displayName: nil))
    }

    /// Anonymous sign-in: yields a real session so a "guest" can still browse with a stable
    /// identity. Requires "Anonymous sign-ins" enabled in the project's Auth settings.
    ///
    /// Crucially, we reuse an existing persisted session before minting a brand-new anonymous user.
    /// The Keychain survives app uninstall on iOS, so a guest who deletes and re-downloads the app
    /// (or just taps "Browse as guest" again) keeps the *same* guest account rather than spawning a
    /// fresh one each time — which is what caused dozens of throwaway guest users to pile up.
    public func continueAsGuest() async throws -> AuthState {
        if session == nil, let persisted = keychainStore.load() {
            session = Session(
                accessToken: persisted.accessToken,
                refreshToken: persisted.refreshToken,
                userId: persisted.userId,
                phone: persisted.phone,
                expiresAt: persisted.expiresAt
            )
        }
        // If that session is still usable (refreshing if needed), reuse it as-is.
        if await currentAccessToken() != nil, let session {
            return .authenticated(User(id: session.userId, phoneNumber: session.phone, displayName: nil))
        }
        // Nothing reusable → create a fresh anonymous user.
        let dto: GoTrueSessionDTO = try await client.send(.authentication.signUpAnonymous, body: EmptyBody())
        store(dto)
        return .authenticated(User(id: dto.user.id, phoneNumber: dto.user.phone, displayName: nil))
    }

    /// Request a phone OTP. Delivered by the `send-otp` Edge Function, which generates the code,
    /// stores an HMAC of it, and sends the SMS via OurSMS. On the server's own failures (bad
    /// number, rate limit, unapproved sender, no balance) it responds non-2xx and `client.send`
    /// throws — the OTP screen surfaces that as an error rather than advancing to code entry.
    public func sendOTP(phoneE164: String) async throws -> OTPChallenge {
        let _: SendOTPResponseDTO = try await client.send(
            .authentication.sendOTP,
            body: SendOTPBody(phone: phoneE164)
        )
        // The OTP flow is keyed by phone number, so the challenge id IS the phone.
        return OTPChallenge(id: phoneE164, phoneE164: phoneE164, resendInterval: 60)
    }

    public func signInWithApple(idToken: String, nonce: String) async throws -> User {
        let dto: GoTrueSessionDTO = try await client.send(
            .authentication.signInWithIdToken,
            body: AppleIdTokenBody(provider: "apple", idToken: idToken, nonce: nonce)
        )
        store(dto)
        return User(id: dto.user.id, phoneNumber: dto.user.phone, displayName: nil)
    }

    /// Verify a phone OTP for a returning user. If the number is brand-new (no account yet), the
    /// `verify-otp` function replies `requires_registration` and we surface
    /// `OTPFlowError.requiresRegistration` so the UI can collect a name, then call
    /// `registerWithName` with the same still-valid code.
    public func verifyOTP(challengeId: String, code: String) async throws -> User {
        try await verifyOrRegister(phone: challengeId, code: code, firstName: nil, lastName: nil, role: nil)
    }

    /// Complete a new user's signup: same code + a required first/last name. The function creates
    /// the account and mints a session, which we persist like any other sign-in. This also
    /// transparently replaces a "Browse as guest" anonymous session with the real phone account.
    public func registerWithName(challengeId: String, code: String, firstName: String, lastName: String, role: UserRole) async throws -> User {
        try await verifyOrRegister(phone: challengeId, code: code, firstName: firstName, lastName: lastName, role: role)
    }

    private func verifyOrRegister(phone: String, code: String, firstName: String?, lastName: String?, role: UserRole?) async throws -> User {
        let dto: VerifyOTPResponseDTO = try await client.send(
            .authentication.verifyOTP,
            body: VerifyOTPBody(phone: phone, code: code, firstName: firstName, lastName: lastName, role: role?.rawValue)
        )
        if dto.requiresRegistration == true { throw OTPFlowError.requiresRegistration }
        guard let accessToken = dto.accessToken, let user = dto.user else {
            throw AppError.unknown(message: "Unexpected verify-otp response")
        }
        store(GoTrueSessionDTO(accessToken: accessToken, refreshToken: dto.refreshToken, expiresIn: dto.expiresIn, user: user))
        return User(id: user.id, phoneNumber: user.phone, displayName: nil, role: dto.role.flatMap(UserRole.init(rawValue:)))
    }

    /// Clears the local session (sign out), including the persisted copy — otherwise the next
    /// launch would silently restore the account the user just signed out of.
    public func signOut() {
        session = nil
        keychainStore.clear()
    }

    /// Refreshes the access token when it's within a minute of expiring (or already expired).
    /// Only an actual auth rejection from GoTrue (the refresh token itself is dead) clears the
    /// session — a transient network error leaves the existing token in place and lets whatever
    /// request triggered this fail on its own terms, rather than forcing a sign-out over a
    /// dropped connection.
    private func refreshIfNeeded() async {
        // Coalesce concurrent refreshes. A pull-to-refresh (Home fans out categories/places/hero
        // at once) calls this from several requests simultaneously; without single-flighting, each
        // would fire its own refresh with the *same* refresh token. GoTrue rotates refresh tokens,
        // so the first refresh invalidates that token and every other concurrent refresh then fails
        // with an auth error — which used to clear the session and make the whole refresh "fail".
        // Here, only the first caller starts the refresh; the rest await the same task.
        if let refreshTask {
            await refreshTask.value
            return
        }
        guard let session, session.expiresAt.timeIntervalSinceNow < 60, session.refreshToken != nil else { return }
        let task = Task { await self.performRefresh() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    /// A rejection from GoTrue (any 4xx - the refresh token itself is dead) clears the session;
    /// a transient failure (5xx, timeout, no connection) leaves the existing token in place and
    /// lets whatever request triggered this fail on its own terms, rather than forcing a
    /// sign-out over a dropped connection.
    private func performRefresh() async {
        guard let session, let refreshToken = session.refreshToken else { return }
        do {
            let dto: GoTrueSessionDTO = try await client.send(
                .authentication.refreshToken,
                body: RefreshTokenBody(refreshToken: refreshToken)
            )
            store(dto)
        } catch {
            // `client.send` has typed throws, so `error` is an `AppError`.
            switch error {
            case .authentication, .validation:
                discardSession()
            case .server(let statusCode, _) where (400..<500).contains(statusCode):
                // GoTrue answers a dead refresh token with **400**, and its body keys the reason
                // as `msg` rather than `message` — which `APIErrorResponseDTO` can't see, so the
                // shared mapper produces `.server(400, nil)` and never `.validation`. Lumping that
                // in with the transient cases below wedged the app permanently: the dead session
                // stayed, every subsequent request went out bearing the expired access token, and
                // PostgREST rejected each one with 401 → "Your session expired. Please sign in
                // again." forever. Reinstalling didn't help either, because the Keychain
                // deliberately outlives the app (see `continueAsGuest`). Any 4xx here means this
                // refresh token is finished; only 5xx and transport errors are worth retrying.
                discardSession()
            case .network, .server, .offline, .unknown:
                break
            }
        }
    }

    /// Drops the session from memory *and* the Keychain. Both, always — leaving the Keychain
    /// copy behind would just resurrect the dead session on the next launch.
    private func discardSession() {
        session = nil
        keychainStore.clear()
    }

    private func store(_ dto: GoTrueSessionDTO) {
        let expiresAt = Date().addingTimeInterval(TimeInterval(dto.expiresIn ?? 3600))
        session = Session(
            accessToken: dto.accessToken,
            refreshToken: dto.refreshToken,
            userId: dto.user.id,
            phone: dto.user.phone,
            expiresAt: expiresAt
        )
        keychainStore.save(.init(
            accessToken: dto.accessToken,
            refreshToken: dto.refreshToken,
            userId: dto.user.id,
            phone: dto.user.phone,
            expiresAt: expiresAt
        ))
    }
}

// MARK: - GoTrue wire shapes (snake_case → decoded via the client's .convertFromSnakeCase)

private struct GoTrueSessionDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let user: GoTrueUserDTO
}

private struct GoTrueUserDTO: Decodable, Sendable {
    let id: String
    let phone: String?
}

/// `send-otp` returns `{ "success": true }` on success (and a non-2xx `{ "error": ... }` on
/// failure, which `client.send` turns into a thrown `AppError` before we ever decode this).
private struct SendOTPResponseDTO: Decodable, Sendable {
    let success: Bool?
}

private struct EmptyBody: Encodable, Sendable {}

private struct SendOTPBody: Encodable, Sendable {
    let phone: String
}

private struct VerifyOTPBody: Encodable, Sendable {
    let phone: String
    let code: String
    // Sent only on the registration call; nil optionals are omitted, and the encoder converts
    // these to first_name / last_name for the Edge Function.
    let firstName: String?
    let lastName: String?
    /// "bride" | "provider"; sent only when registering a new number.
    let role: String?
}

/// `verify-otp` returns either a session (returning/registered user) or `{ requires_registration:
/// true }` (new number, name not yet given) — so every session field is optional here.
private struct VerifyOTPResponseDTO: Decodable, Sendable {
    let requiresRegistration: Bool?
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let user: GoTrueUserDTO?
    /// The account's role from `profiles.role`.
    let role: String?
}

private struct AppleIdTokenBody: Encodable, Sendable {
    let provider: String
    let idToken: String
    let nonce: String
}

private struct RefreshTokenBody: Encodable, Sendable {
    let refreshToken: String
}
