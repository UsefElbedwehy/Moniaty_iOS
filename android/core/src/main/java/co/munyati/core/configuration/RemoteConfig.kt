package co.munyati.core.configuration

/**
 * White-label, backend-driven app configuration. Nothing in this class is ever hardcoded in a
 * screen — Presentation reads it through [ConfigurationRepository].
 */
data class RemoteConfig(
    val branding: Branding,
    val featureFlags: Map<String, Boolean>,
    val enabledModules: List<String>,
    val supportedLanguages: List<String>,
    val supportedCurrencies: List<String>,
    val regions: List<String>,
    val cities: List<String>,
    val socialLinks: Map<String, String>,
    val support: SupportInfo,
    val update: UpdateInfo,
) {
    data class Branding(
        val appName: String,
        val logoUrl: String?,
        val primaryColorHex: String,
        val accentColorHex: String,
    )

    data class ContactMethod(val id: String, val type: String, val value: String)

    data class SupportInfo(
        val helpCenterUrl: String?,
        val termsUrl: String?,
        val privacyPolicyUrl: String?,
        val contactMethods: List<ContactMethod>,
    )

    /**
     * Admin-settable minimum app version — when `forceUpdate` is on and the running build is older
     * than `minRequiredVersion`, the whole app is blocked behind an update screen.
     */
    data class UpdateInfo(
        val minRequiredVersion: String?,
        val updateMessage: String?,
        val forceUpdate: Boolean,
        val storeUrl: String?,
    )

    fun isFeatureEnabled(key: String): Boolean = featureFlags[key] ?: false
}

/**
 * Boundary between Presentation and the backend-driven config. Implementations cache the last
 * successful fetch so the app remains usable offline with the last-known configuration.
 */
interface ConfigurationRepository {
    suspend fun fetchConfiguration(): RemoteConfig
    suspend fun cachedConfiguration(): RemoteConfig?
}
