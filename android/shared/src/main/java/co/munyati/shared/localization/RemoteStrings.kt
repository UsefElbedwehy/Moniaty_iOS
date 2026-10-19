package co.munyati.shared.localization

import androidx.compose.runtime.mutableStateMapOf

/**
 * Dashboard-edited text (`app_strings`) for the current language, keyed by the iOS string key
 * (e.g. "tab.home"). Backed by snapshot state, so screens recompose when overrides arrive.
 */
object RemoteStrings {
    private val overrides = mutableStateMapOf<String, String>()

    /** Replaces all overrides for the current language (key → text). */
    fun install(newOverrides: Map<String, String>) {
        overrides.clear()
        overrides.putAll(newOverrides)
    }

    /** The override for [key], or [fallback] (normally the bundled localized value). */
    fun string(key: String, fallback: String): String =
        overrides[key]?.takeIf { it.isNotEmpty() } ?: fallback
}
