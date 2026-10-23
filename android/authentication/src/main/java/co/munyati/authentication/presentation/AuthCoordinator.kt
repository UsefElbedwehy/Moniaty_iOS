package co.munyati.authentication.presentation

import co.munyati.authentication.domain.AuthState
import co.munyati.authentication.domain.OtpChallenge
import co.munyati.authentication.domain.User
import co.munyati.authentication.domain.UserRole

/** The intents auth screens can express. The navigation layer implements it. */
interface AuthCoordinator {
    val activeChallenge: OtpChallenge?
    val selectedRole: UserRole

    /** Landing → "I'm a bride" / "I'm a service provider". */
    fun startPhoneSignIn(role: UserRole)

    /** Phone entry sent a code — advance to OTP. */
    fun didSendOtp(challenge: OtpChallenge)

    /** Code accepted for a new number — collect a name before creating the account. */
    fun needsName(code: String)

    /** OTP screen's "Edit" — back to the number field. */
    fun editPhoneNumber()

    fun pop()

    fun didAuthenticate(user: User)

    fun didContinueAsGuest(state: AuthState)
}
