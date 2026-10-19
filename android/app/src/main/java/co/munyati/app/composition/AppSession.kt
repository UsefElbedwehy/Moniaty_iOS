package co.munyati.app.composition

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.munyati.authentication.domain.UserRole

/**
 * Who is using the app right now; decides which shell `RootView` shows:
 * - Checking: launch only, restoring the persisted session (splash).
 * - SignedOut: no session; show the landing screen (role choice).
 * - SignedIn: a session exists. An anonymous session is a guest browsing as a bride; `role`
 *   comes from the server profile and is null until it has loaded.
 */
class AppSession {
    sealed interface State {
        data object Checking : State
        data object SignedOut : State
        data class SignedIn(val user: SessionUser) : State
    }

    data class SessionUser(
        val id: String,
        val role: UserRole?,
        val isAnonymous: Boolean,
        val displayName: String?,
    )

    var state: State by mutableStateOf(State.Checking)

    /** Set when a guest taps something that needs an account (book, favorite, review, report). */
    var isPresentingAuth by mutableStateOf(false)

    val user: SessionUser? get() = (state as? State.SignedIn)?.user

    /** A real (non-anonymous) account. */
    val hasAccount: Boolean get() = user?.let { !it.isAnonymous } ?: false

    val role: UserRole? get() = user?.role
}
