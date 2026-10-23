package co.munyati.core.error

import android.content.Context
import co.munyati.core.R

/**
 * Centralized error type for the whole app. Every layer (Networking, Data, Domain) maps its own
 * failures into this type before they cross into Presentation, so a ViewModel only ever has to
 * handle one error type with localized, user-facing copy.
 */
sealed class AppError : Exception() {
    data class Network(val reason: NetworkFailureReason) : AppError()

    /** `message` is either user-facing text or a feature string key (e.g. "auth.error.phoneInvalid"). */
    data class Validation(val field: String?, override val message: String) : AppError()
    data class Authentication(val reason: AuthFailureReason) : AppError()
    data class Server(val statusCode: Int, override val message: String?) : AppError()
    data object Offline : AppError() {
        private fun readResolve(): Any = Offline
    }
    data class Unknown(override val message: String?) : AppError()

    enum class NetworkFailureReason { TimedOut, NoConnection, Cancelled, DecodingFailed, InvalidResponse }

    enum class AuthFailureReason { InvalidCredentials, SessionExpired, OtpExpired, OtpIncorrect, NotAuthenticated }

    /** True for "you're offline"-type failures (drives the offline variant of the error state). */
    val isOffline: Boolean
        get() = this is Offline || (this is Network && reason == NetworkFailureReason.NoConnection)

    /** User-facing, localized message. */
    fun description(context: Context): String = when (this) {
        is Network -> when (reason) {
            NetworkFailureReason.TimedOut -> context.getString(R.string.error_network_timedOut)
            NetworkFailureReason.NoConnection -> context.getString(R.string.error_network_noConnection)
            NetworkFailureReason.Cancelled -> context.getString(R.string.error_network_cancelled)
            NetworkFailureReason.DecodingFailed, NetworkFailureReason.InvalidResponse ->
                context.getString(R.string.error_network_invalidResponse)
        }
        is Validation -> message
        is Authentication -> when (reason) {
            AuthFailureReason.InvalidCredentials -> context.getString(R.string.error_auth_invalidCredentials)
            AuthFailureReason.SessionExpired -> context.getString(R.string.error_auth_sessionExpired)
            AuthFailureReason.OtpExpired -> context.getString(R.string.error_auth_otpExpired)
            AuthFailureReason.OtpIncorrect -> context.getString(R.string.error_auth_otpIncorrect)
            AuthFailureReason.NotAuthenticated -> context.getString(R.string.error_auth_notAuthenticated)
        }
        is Server -> message ?: context.getString(R.string.error_server_generic)
        Offline -> context.getString(R.string.error_offline)
        is Unknown -> message ?: context.getString(R.string.error_unknown)
    }

    companion object {
        /** Wraps any throwable as an `AppError` (the `catch { ... }` fallback every ViewModel uses). */
        fun from(throwable: Throwable): AppError =
            throwable as? AppError ?: Unknown(throwable.localizedMessage)
    }
}
