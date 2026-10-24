package co.munyati.authentication.domain

/** Which side of the marketplace an account is on. Chosen once at sign-up; decides the tab shell. */
enum class UserRole(val rawValue: String) {
    Bride("bride"),
    Provider("provider");

    companion object {
        fun from(raw: String?): UserRole? = entries.firstOrNull { it.rawValue == raw }
    }
}

/**
 * A signed-in person. `phoneNumber` is the E.164 value we verified; `displayName` is optional
 * because a freshly verified user has no profile yet. `role` is null only for anonymous guests and
 * sessions whose profile has not been fetched yet.
 */
data class User(
    val id: String,
    val phoneNumber: String? = null,
    val displayName: String? = null,
    val role: UserRole? = null,
)

/** The two outcomes of the auth flow. "Auth is never a wall" — guest is a first-class state. */
sealed interface AuthState {
    data object Guest : AuthState
    data class Authenticated(val user: User) : AuthState
}

/**
 * The server's response to `sendOtp`: an opaque challenge id, the number it was sent to (shown as
 * "Sent to …"), and how long the user must wait before a resend is allowed.
 */
data class OtpChallenge(val id: String, val phoneE164: String, val resendIntervalSeconds: Int)

/**
 * Raised when the code was accepted but the number has no account for the picked side: the UI
 * collects a name, then calls `registerWithName` with the same still-valid code. [otherRole] is set
 * when the number already has an account of the other kind.
 */
class RequiresRegistration(val otherRole: UserRole? = null) : Exception()
