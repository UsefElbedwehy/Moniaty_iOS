package co.munyati.authentication.data

import co.munyati.authentication.domain.AuthRepository
import co.munyati.authentication.domain.AuthState
import co.munyati.authentication.domain.OtpChallenge
import co.munyati.authentication.domain.User
import co.munyati.authentication.domain.UserRole
import co.munyati.core.configuration.Audience
import co.munyati.core.error.AppError
import java.util.UUID
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** In-memory [AuthRepository] for running without a backend. Accepts the code 123456. */
class MockAuthRepository(private val artificialDelayMs: Long = 350) : AuthRepository {
    private val mutex = Mutex()
    private var state: AuthState = AuthState.Guest
    private val challenges = mutableMapOf<String, String>() // challengeId → phoneE164

    override suspend fun sendOtp(phoneE164: String): OtpChallenge {
        tick()
        val id = UUID.randomUUID().toString()
        mutex.withLock { challenges[id] = phoneE164 }
        return OtpChallenge(id, phoneE164, RESEND_INTERVAL_SECONDS)
    }

    override suspend fun verifyOtp(challengeId: String, code: String, role: UserRole?): User {
        tick()
        return mutex.withLock {
            val phone = challenges[challengeId] ?: throw AppError.Authentication(AppError.AuthFailureReason.OtpExpired)
            if (code != ACCEPTED_CODE) throw AppError.Authentication(AppError.AuthFailureReason.OtpIncorrect)
            challenges.remove(challengeId)
            User(UUID.randomUUID().toString(), phoneNumber = phone).also { state = AuthState.Authenticated(it) }
        }
    }

    // The mock has no "is this a new number" state, so registration just verifies.
    override suspend fun registerWithName(
        challengeId: String,
        code: String,
        firstName: String,
        lastName: String,
        role: UserRole,
        audience: Audience,
    ) =
        verifyOtp(challengeId, code)

    override suspend fun continueAsGuest(): AuthState {
        tick()
        return mutex.withLock { AuthState.Guest.also { state = it } }
    }

    override suspend fun currentState(): AuthState = mutex.withLock { state }

    private suspend fun tick() {
        if (artificialDelayMs > 0) delay(artificialDelayMs)
    }

    companion object {
        const val ACCEPTED_CODE = "123456"
        private const val RESEND_INTERVAL_SECONDS = 30
    }
}
