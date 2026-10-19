package co.munyati.app.backend

import android.content.Context
import co.munyati.authentication.domain.UserRole
import co.munyati.core.configuration.ConfigurationRepository
import co.munyati.core.configuration.RemoteConfig
import co.munyati.networking.ApiClient
import co.munyati.networking.ApiEndpoint
import co.munyati.networking.EmptyBody
import co.munyati.networking.EmptyResponse
import co.munyati.networking.send
import co.munyati.shared.persistence.CacheStore
import co.munyati.shared.persistence.FileCacheStore
import kotlinx.serialization.Serializable
import co.munyati.catalog.domain.City

/** The signed-in person's profile: who they are, which side they're on, which cities they browse. */
data class MyProfile(
    val id: String,
    val displayName: String?,
    val phone: String?,
    val role: UserRole?,
    val cityIds: List<String>,
    val isAnonymous: Boolean,
    /** Provider accounts only: "pending" until an admin approves the join request. */
    val providerStatus: String?,
)

interface ProfileRepository {
    suspend fun fetchMyProfile(): MyProfile
    suspend fun setMyCities(cityIds: List<String>)
    suspend fun registerDeviceToken(token: String)
}

interface ContentRepository {
    suspend fun fetchCities(): List<City>
    /** Remote string overrides for one language (key → text). */
    suspend fun fetchStrings(language: String): Map<String, String>
}

class SupabaseProfileRepository(private val client: ApiClient) : ProfileRepository {
    override suspend fun fetchMyProfile(): MyProfile {
        val dto: ProfileDto = client.send(ApiEndpoint.Profile.get, EmptyBody())
        return MyProfile(
            id = dto.id,
            displayName = dto.displayName,
            phone = dto.phone,
            role = UserRole.from(dto.role),
            cityIds = dto.cityIds.orEmpty(),
            isAnonymous = dto.isAnonymous ?: false,
            providerStatus = dto.providerStatus,
        )
    }

    override suspend fun setMyCities(cityIds: List<String>) {
        client.send<SetCitiesArgs, EmptyResponse>(ApiEndpoint.Profile.setCities, SetCitiesArgs(cityIds))
    }

    override suspend fun registerDeviceToken(token: String) {
        client.send<RegisterTokenArgs, EmptyResponse>(ApiEndpoint.Notifications.registerDeviceToken, RegisterTokenArgs(token, "android"))
    }
}

class SupabaseContentRepository(private val client: ApiClient) : ContentRepository {
    override suspend fun fetchCities(): List<City> = client.send(ApiEndpoint.Catalog.cities, EmptyBody())

    override suspend fun fetchStrings(language: String): Map<String, String> {
        val rows: List<StringRow> = client.send(ApiEndpoint.Configuration.strings, StringsArgs(language))
        return rows.associate { it.key to it.value }
    }
}

/**
 * Production [ConfigurationRepository] over `get_config`. Caches the last good fetch on disk so a
 * cold, offline launch still has a config.
 */
class SupabaseConfigurationRepository(
    private val client: ApiClient,
    private val cache: CacheStore<RemoteConfigDto>,
) : ConfigurationRepository {
    constructor(client: ApiClient, context: Context) :
        this(client, FileCacheStore(context, "remote_config", RemoteConfigDto.serializer()))

    override suspend fun fetchConfiguration(): RemoteConfig {
        val dto: RemoteConfigDto = client.send(ApiEndpoint.Configuration.get)
        runCatching { cache.save(dto) }
        return dto.toDomain()
    }

    override suspend fun cachedConfiguration(): RemoteConfig? = cache.load()?.toDomain()
}

// Offline / test stand-ins

class MockProfileRepository : ProfileRepository {
    // role null: keep the role chosen at sign-in, so both shells can be tried on sample data.
    override suspend fun fetchMyProfile() =
        MyProfile("mock-user", "نورة", "+966500000000", null, listOf("dammam"), isAnonymous = false, providerStatus = null)
    override suspend fun setMyCities(cityIds: List<String>) = Unit
    override suspend fun registerDeviceToken(token: String) = Unit
}

class MockContentRepository : ContentRepository {
    override suspend fun fetchCities() = listOf(
        City("dammam", "الدمام", "Dammam"),
        City("khobar", "الخبر", "Khobar"),
        City("qatif", "القطيف", "Qatif"),
    )
    override suspend fun fetchStrings(language: String) = emptyMap<String, String>()
}

class MockConfigurationRepository : ConfigurationRepository {
    private val config = RemoteConfig(
        branding = RemoteConfig.Branding("Munyati", null, "#8A0D3A", "#DFC389"),
        featureFlags = emptyMap(),
        enabledModules = emptyList(),
        supportedLanguages = listOf("ar", "en"),
        supportedCurrencies = listOf("SAR"),
        regions = emptyList(),
        cities = emptyList(),
        socialLinks = emptyMap(),
        support = RemoteConfig.SupportInfo(null, "https://munyati.co/terms", "https://munyati.co/privacy", emptyList()),
        update = RemoteConfig.UpdateInfo(null, null, false, null),
    )
    override suspend fun fetchConfiguration() = config
    override suspend fun cachedConfiguration() = config
}

// Wire shapes (snake_case via the client's JSON naming strategy)

@Serializable
private data class ProfileDto(
    val id: String,
    val displayName: String? = null,
    val phone: String? = null,
    val role: String? = null,
    val cityIds: List<String>? = null,
    val isAnonymous: Boolean? = null,
    val providerStatus: String? = null,
)

@Serializable private data class SetCitiesArgs(val pCityIds: List<String>)
@Serializable private data class RegisterTokenArgs(val pToken: String, val pPlatform: String)
@Serializable private data class StringsArgs(val pLang: String)
@Serializable private data class StringRow(val key: String, val value: String)

@Serializable
data class RemoteConfigDto(
    val branding: Branding = Branding(),
    val featureFlags: Map<String, Boolean> = emptyMap(),
    val enabledModules: List<String> = emptyList(),
    val supportedLanguages: List<String> = emptyList(),
    val supportedCurrencies: List<String> = emptyList(),
    val regions: List<String> = emptyList(),
    val cities: List<String> = emptyList(),
    val socialLinks: Map<String, String> = emptyMap(),
    val support: Support = Support(),
    val update: Update? = null,
) {
    @Serializable
    data class Branding(
        val appName: String = "Munyati",
        val logoUrl: String? = null,
        val primaryColorHex: String = "#8A0D3A",
        val accentColorHex: String = "#DFC389",
    )

    @Serializable data class ContactMethod(val id: String, val kind: String, val value: String)

    @Serializable
    data class Support(
        val helpCenterUrl: String? = null,
        val termsUrl: String? = null,
        val privacyPolicyUrl: String? = null,
        val contactMethods: List<ContactMethod> = emptyList(),
    )

    @Serializable
    data class Update(
        val minRequiredVersion: String? = null,
        val updateMessage: String? = null,
        val forceUpdate: Boolean? = null,
        val storeUrl: String? = null,
        /** Android may carry its own store link; falls back to `store_url`. */
        val playStoreUrl: String? = null,
    )

    fun toDomain() = RemoteConfig(
        branding = RemoteConfig.Branding(branding.appName, branding.logoUrl, branding.primaryColorHex, branding.accentColorHex),
        featureFlags = featureFlags,
        enabledModules = enabledModules,
        supportedLanguages = supportedLanguages,
        supportedCurrencies = supportedCurrencies,
        regions = regions,
        cities = cities,
        socialLinks = socialLinks,
        support = RemoteConfig.SupportInfo(
            support.helpCenterUrl,
            support.termsUrl,
            support.privacyPolicyUrl,
            support.contactMethods.map { RemoteConfig.ContactMethod(it.id, it.kind, it.value) },
        ),
        update = RemoteConfig.UpdateInfo(
            update?.minRequiredVersion,
            update?.updateMessage,
            update?.forceUpdate ?: false,
            update?.playStoreUrl ?: update?.storeUrl,
        ),
    )
}
