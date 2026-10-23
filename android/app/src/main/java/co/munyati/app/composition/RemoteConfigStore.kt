package co.munyati.app.composition

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.munyati.core.configuration.RemoteConfig

/** The app-wide backend config, fetched once at launch alongside session restore. */
class RemoteConfigStore(private val currentVersion: String) {
    var config: RemoteConfig? by mutableStateOf(null)
        private set

    /**
     * Fail-closed: before the config loads, or without an explicit admin decision, this is false,
     * so a fresh launch or a failed fetch never blocks the app.
     */
    val forceUpdateRequired: Boolean
        get() {
            val update = config?.update ?: return false
            val minVersion = update.minRequiredVersion ?: return false
            return update.forceUpdate && compareVersions(currentVersion, minVersion) < 0
        }

    /** Admin switch for maintenance mode (shows the update/maintenance screen). */
    val isMaintenanceMode: Boolean get() = config?.isFeatureEnabled("maintenanceMode") ?: false

    fun update(config: RemoteConfig) {
        this.config = config
    }

    companion object {
        /** Numeric, dot-separated comparison ("1.10" > "1.9"), like iOS `.numeric` compare. */
        fun compareVersions(a: String, b: String): Int {
            val x = a.split(".").map { it.toIntOrNull() ?: 0 }
            val y = b.split(".").map { it.toIntOrNull() ?: 0 }
            for (i in 0 until maxOf(x.size, y.size)) {
                val diff = x.getOrElse(i) { 0 } - y.getOrElse(i) { 0 }
                if (diff != 0) return diff
            }
            return 0
        }
    }
}
