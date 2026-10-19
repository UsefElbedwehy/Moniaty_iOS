package co.munyati.app.composition

import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import co.munyati.shared.localization.RemoteStrings

/**
 * App-target strings: the bundled text, unless the dashboard overrides that key (`app_strings`).
 * Same rule as iOS `L10n`.
 */
@Composable
fun l10n(@StringRes id: Int): String {
    val bundled = stringResource(id)
    return l10nKeys[id]?.let { RemoteStrings.string(it, bundled) } ?: bundled
}
