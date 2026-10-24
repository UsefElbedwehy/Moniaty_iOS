package co.munyati.authentication.presentation

import co.munyati.authentication.domain.AuthState
import co.munyati.authentication.domain.OtpChallenge
import co.munyati.authentication.domain.User
import co.munyati.authentication.domain.UserRole

/** The intents auth screens can express. The navigation layer implements it. */
interface AuthCoordinator {
    val activeChallenge: OtpChallenge?
    val selectedRole: UserRole

    /** Set when the number already has an account of the other kind (shown on the name screen). */
    val otherAccountRole: UserRole?

    /** Landing → "I'm a bride" / "I'm a service provider". */
    fun startPhoneSignIn(role: UserRole)

    /** Phone entry sent a code — advance to OTP. */
    fun didSendOtp(challenge: OtpChallenge)

    /** Code accepted but no account for the picked side yet — collect a name before creating it. */
    fun needsName(code: String, otherRole: UserRole?)

    /** OTP screen's "Edit" — back to the number field. */
    fun editPhoneNumber()

    fun pop()

    fun didAuthenticate(user: User)

    fun didContinueAsGuest(state: AuthState)
}
