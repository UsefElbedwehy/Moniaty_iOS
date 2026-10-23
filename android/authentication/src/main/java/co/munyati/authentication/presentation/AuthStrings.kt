package co.munyati.authentication.presentation

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import co.munyati.authentication.R
import co.munyati.core.error.AppError

/** Validation errors carry this module's string keys; everything else uses the shared copy. */
private val validationKeys = mapOf(
    "auth.error.phoneEmpty" to R.string.auth_error_phoneEmpty,
    "auth.error.phoneInvalid" to R.string.auth_error_phoneInvalid,
    "auth.error.codeInvalid" to R.string.auth_error_codeInvalid,
    "auth.error.nameRequired" to R.string.auth_error_nameRequired,
    "auth.error.generic" to R.string.auth_error_generic,
)

@Composable
internal fun AppError.authMessage(): String {
    val context = LocalContext.current
    val keyed = (this as? AppError.Validation)?.message?.let(validationKeys::get)
    return if (keyed != null) context.getString(keyed) else description(context)
}

/** Wraps a phone number in left-to-right isolates, or the bidi algorithm moves the "+" in Arabic. */
internal fun ltr(text: String) = "⁦$text⁩"
