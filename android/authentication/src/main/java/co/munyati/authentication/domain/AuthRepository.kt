package co.munyati.authentication.domain

/**
 * The Domain-facing contract for authentication. Presentation only talks to use cases, which talk
 * to this. Two implementations: the App's Supabase repository and [co.munyati.authentication.data.MockAuthRepository].
 */
interface AuthRepository {
    /** Start a phone verification. Returns a challenge the OTP screen verifies against. */
    suspend fun sendOtp(phoneE164: String): OtpChallenge

    /**
     * Verify a code. On success the user is authenticated. For a brand-new number this throws
     * [RequiresRegistration]; the code stays valid for [registerWithName].
     */
    suspend fun verifyOtp(challengeId: String, code: String): User

    /** Complete a new user's signup with first + last name and the role picked on the landing screen. */
    suspend fun registerWithName(challengeId: String, code: String, firstName: String, lastName: String, role: UserRole): User

    /** Enter the app without signing in. */
    suspend fun continueAsGuest(): AuthState

    /** The current known auth state. */
    suspend fun currentState(): AuthState
}
