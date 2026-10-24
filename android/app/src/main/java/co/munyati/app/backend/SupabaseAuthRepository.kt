package co.munyati.app.backend

import android.util.Base64
import co.munyati.authentication.domain.AuthRepository
import co.munyati.authentication.domain.AuthState
import co.munyati.authentication.domain.OtpChallenge
import co.munyati.authentication.domain.RequiresRegistration
import co.munyati.authentication.domain.User
import co.munyati.authentication.domain.UserRole
import co.munyati.core.error.AppError
import co.munyati.networking.ApiClient
import co.munyati.networking.ApiEndpoint
import co.munyati.networking.EmptyBody
import co.munyati.networking.send
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import org.json.JSONObject

/**
 * Supabase-backed [AuthRepository], living in the App composition root (the only layer allowed to
 * know the backend is Supabase). Talks to GoTrue and the OTP edge functions through the shared
 * [ApiClient], persists the session in [SessionStore], and renews the access token transparently
 * when it nears expiry. Mirrors the iOS `SupabaseAuthRepository` behavior exactly.
 */
class SupabaseAuthRepository(
    private val client: ApiClient,
    private val store: SessionStore,
) : AuthRepository {
    private data class Session(
        val accessToken: String,
        val refreshToken: String?,
        val userId: String,
        val phone: String?,
        val expiresAtMillis: Long,
    )

    private val lock = Mutex()
    private var session: Session? = null
    /** In-flight refresh shared by concurrent callers, so only one refresh call runs at a time. */
    private var refresh: CompletableDeferred<Unit>? = null

    /** Restores the persisted session at launch, refreshing it first if stale. */
    suspend fun restoreSession(): AuthState {
        val persisted = store.load() ?: return AuthState.Guest
        lock.withLock { session = persisted.toSession() }
        currentAccessToken() ?: return AuthState.Guest
        val s = lock.withLock { session } ?: return AuthState.Guest
        return AuthState.Authenticated(User(s.userId, s.phone))
    }

    /** The bearer for networking and storage uploads. May trigger a refresh. */
    suspend fun currentAccessToken(): String? {
        refreshIfNeeded()
        return lock.withLock { session?.accessToken }
    }

    suspend fun currentUserId(): String? = lock.withLock { session?.userId }

    /** Whether the session belongs to an anonymous "Browse as guest" user (the JWT `is_anonymous` claim). */
    suspend fun currentUserIsAnonymous(): Boolean {
        val token = lock.withLock { session?.accessToken } ?: return false
        return runCatching {
            val payload = token.split(".")[1]
            JSONObject(String(Base64.decode(payload, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)))
                .optBoolean("is_anonymous", false)
        }.getOrDefault(false)
    }

    override suspend fun currentState(): AuthState {
        val s = lock.withLock { session } ?: return AuthState.Guest
        return AuthState.Authenticated(User(s.userId, s.phone))
    }

    /**
     * Anonymous sign-in. Reuses a persisted session first, so tapping "Browse as guest" again keeps
     * the same guest account instead of minting a new anonymous user each time.
     */
    override suspend fun continueAsGuest(): AuthState {
        lock.withLock { if (session == null) session = store.load()?.toSession() }
        if (currentAccessToken() != null) {
            lock.withLock { session }?.let { return AuthState.Authenticated(User(it.userId, it.phone)) }
        }
        val dto: GoTrueSession = client.send(ApiEndpoint.Authentication.signUpAnonymous, EmptyBody())
        store(dto)
        return AuthState.Authenticated(User(dto.user.id, dto.user.phone))
    }

    /** Requests a phone OTP from the `send-otp` function. The challenge id is the phone itself. */
    override suspend fun sendOtp(phoneE164: String): OtpChallenge {
        val _ignored: SendOtpResponse = client.send(ApiEndpoint.Authentication.sendOtp, SendOtpBody(phoneE164))
        return OtpChallenge(id = phoneE164, phoneE164 = phoneE164, resendIntervalSeconds = 60)
    }

    override suspend fun verifyOtp(challengeId: String, code: String, role: UserRole?): User =
        verifyOrRegister(challengeId, code, null, null, role)

    override suspend fun registerWithName(challengeId: String, code: String, firstName: String, lastName: String, role: UserRole): User =
        verifyOrRegister(challengeId, code, firstName, lastName, role)

    private suspend fun verifyOrRegister(phone: String, code: String, firstName: String?, lastName: String?, role: UserRole?): User {
        val dto: VerifyOtpResponse = client.send(
            ApiEndpoint.Authentication.verifyOtp,
            VerifyOtpBody(phone, code, firstName, lastName, role?.rawValue),
        )
        if (dto.requiresRegistration == true) throw RequiresRegistration(UserRole.from(dto.otherRole))
        val accessToken = dto.accessToken ?: throw AppError.Unknown("Unexpected verify-otp response")
        val user = dto.user ?: throw AppError.Unknown("Unexpected verify-otp response")
        store(GoTrueSession(accessToken, dto.refreshToken, dto.expiresIn, user))
        return User(user.id, user.phone, role = UserRole.from(dto.role))
    }

    /** Clears the session, including the persisted copy. */
    suspend fun signOut() = discardSession()

    /**
     * Refreshes the access token within a minute of expiry. Concurrent callers await the same
     * refresh: GoTrue rotates refresh tokens, so parallel refreshes would invalidate each other.
     */
    private suspend fun refreshIfNeeded() {
        val (deferred, owner) = lock.withLock {
            refresh?.let { return@withLock it to false }
            val s = session ?: return
            if (s.expiresAtMillis - System.currentTimeMillis() >= 60_000 || s.refreshToken == null) return
            CompletableDeferred<Unit>().also { refresh = it } to true
        }
        if (!owner) {
            deferred.await()
            return
        }
        try {
            performRefresh()
        } finally {
            lock.withLock { refresh = null }
            deferred.complete(Unit)
        }
    }

    /**
     * A 4xx from GoTrue means the refresh token is dead: clear the session. A 5xx or transport
     * failure keeps the token and lets the triggering request fail on its own terms.
     */
    private suspend fun performRefresh() {
        val refreshToken = lock.withLock { session?.refreshToken } ?: return
        try {
            val dto: GoTrueSession = client.send(ApiEndpoint.Authentication.refreshToken, RefreshTokenBody(refreshToken))
            store(dto)
        } catch (e: AppError) {
            when {
                e is AppError.Authentication || e is AppError.Validation -> discardSession()
                e is AppError.Server && e.statusCode in 400..499 -> discardSession()
                else -> Unit
            }
        }
    }

    private suspend fun discardSession() {
        lock.withLock { session = null }
        store.clear()
    }

    private suspend fun store(dto: GoTrueSession) {
        val expiresAt = System.currentTimeMillis() + (dto.expiresIn ?: 3600) * 1000L
        val s = Session(dto.accessToken, dto.refreshToken, dto.user.id, dto.user.phone, expiresAt)
        lock.withLock { session = s }
        store.save(PersistedSession(s.accessToken, s.refreshToken, s.userId, s.phone, s.expiresAtMillis))
    }

    private fun PersistedSession.toSession() = Session(accessToken, refreshToken, userId, phone, expiresAtMillis)
}

// GoTrue / edge function wire shapes (snake_case via the client's JSON naming strategy).

@Serializable
private data class GoTrueSession(val accessToken: String, val refreshToken: String? = null, val expiresIn: Int? = null, val user: GoTrueUser)

@Serializable
private data class GoTrueUser(val id: String, val phone: String? = null)

@Serializable
private data class SendOtpResponse(val success: Boolean? = null)

@Serializable
private data class SendOtpBody(val phone: String)

@Serializable
private data class VerifyOtpBody(
    val phone: String,
    val code: String,
    val firstName: String?,
    val lastName: String?,
    /**
     * "bride" | "provider": the side picked on the landing screen. One number may hold one account
     * of each kind; the server signs in to (or creates) the one for this side.
     */
    val role: String?,
)

@Serializable
private data class VerifyOtpResponse(
    val requiresRegistration: Boolean? = null,
    val accessToken: String? = null,
    val refreshToken: String? = null,
    val expiresIn: Int? = null,
    val user: GoTrueUser? = null,
    val role: String? = null,
    /** With `requires_registration`: the role of the number's other account, if it has one. */
    val otherRole: String? = null,
)

@Serializable
private data class RefreshTokenBody(val refreshToken: String)
