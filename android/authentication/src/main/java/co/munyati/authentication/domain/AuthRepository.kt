package co.munyati.authentication.domain

import co.munyati.core.configuration.Audience

/**
 * The Domain-facing contract for authentication. Presentation only talks to use cases, which talk
 * to this. Two implementations: the App's Supabase repository and [co.munyati.authentication.data.MockAuthRepository].
 */
interface AuthRepository {
    /** Start a phone verification. Returns a challenge the OTP screen verifies against. */
    suspend fun sendOtp(phoneE164: String): OtpChallenge

    /**
     * Verify a code and sign in to the number's account for [role] (one phone may hold a bride
     * account and a provider account). If the number has no account for that side yet this throws
     * [RequiresRegistration]; the code stays valid for [registerWithName].
     */
    suspend fun verifyOtp(challengeId: String, code: String, role: UserRole? = null): User

    /**
     * Complete a new user's signup with first + last name and the role picked on the landing screen
     * («عروس» and «معازيم» are both bride accounts; [audience] says which she picked).
     */
    suspend fun registerWithName(
        challengeId: String,
        code: String,
        firstName: String,
        lastName: String,
        role: UserRole,
        audience: Audience,
    ): User

    /** Enter the app without signing in. */
    suspend fun continueAsGuest(): AuthState

    /** The current known auth state. */
    suspend fun currentState(): AuthState
}
