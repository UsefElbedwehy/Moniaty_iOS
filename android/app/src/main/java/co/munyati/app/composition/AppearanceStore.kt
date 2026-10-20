package co.munyati.app.composition

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** The app's color scheme setting (Profile → Appearance). Mirrors iOS `Appearance`. */
enum class Appearance(val raw: String) {
    System("system"), Light("light"), Dark("dark");

    /** The iOS string key of its title. */
    val titleKey: String get() = "profile.appearance.$raw"

    companion object {
        fun from(raw: String?) = entries.firstOrNull { it.raw == raw } ?: System
    }
}

/** Keeps the appearance choice in preferences; the theme observes [value]. */
class AppearanceStore(context: Context) {
    private val prefs = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

    var value: Appearance by mutableStateOf(Appearance.from(prefs.getString(KEY, null)))
        private set

    fun set(appearance: Appearance) {
        value = appearance
        prefs.edit().putString(KEY, appearance.raw).apply()
    }

    private companion object {
        const val KEY = "appearance"
    }
}
