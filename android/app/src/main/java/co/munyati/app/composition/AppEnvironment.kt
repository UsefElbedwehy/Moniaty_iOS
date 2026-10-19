package co.munyati.app.composition

import android.content.Context
import android.os.Build
import co.munyati.app.BuildConfig
import co.munyati.app.backend.ContentRepository
import co.munyati.app.backend.MockConfigurationRepository
import co.munyati.app.backend.MockContentRepository
import co.munyati.app.backend.MockProfileRepository
import co.munyati.app.backend.ProfileRepository
import co.munyati.app.backend.SessionStore
import co.munyati.app.backend.SupabaseAuthRepository
import co.munyati.app.backend.SupabaseConfigurationRepository
import co.munyati.app.backend.SupabaseContentRepository
import co.munyati.app.backend.SupabaseProfileRepository
import co.munyati.authentication.domain.AuthState
import co.munyati.authentication.domain.User
import co.munyati.authentication.domain.UserRole
import co.munyati.authentication.navigation.AuthenticationFeature
import co.munyati.app.R
import co.munyati.catalog.data.CatalogRepository
import co.munyati.catalog.data.MockCatalogRepository
import co.munyati.catalog.data.RemoteCatalogRepository
import co.munyati.catalog.presentation.CatalogContext
import co.munyati.catalog.presentation.CatalogFeature
import co.munyati.app.backend.MockMediaUploader
import co.munyati.app.backend.SupabaseMediaUploader
import co.munyati.app.backend.TapPlanCheckout
import co.munyati.providerstudio.data.MockPlanCheckout
import co.munyati.providerstudio.data.MockStudioRepository
import co.munyati.providerstudio.data.RemoteStudioRepository
import co.munyati.providerstudio.presentation.StudioFeature
import co.munyati.core.configuration.ConfigurationRepository
import co.munyati.networking.ApiClient
import co.munyati.networking.ApiEndpoint
import co.munyati.networking.EmptyResponse
import co.munyati.networking.LogClientErrorArgs
import co.munyati.networking.NetworkConfiguration
import co.munyati.networking.OkHttpApiClient
import co.munyati.networking.RecordAnalyticsEventArgs
import co.munyati.networking.send
import co.munyati.shared.analytics.AnalyticsEvent
import co.munyati.shared.analytics.AnalyticsRecorder
import co.munyati.shared.localization.RemoteStrings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.Locale

/**
 * The composition root: builds every repository and holds app-wide state. The only place that knows
 * the backend is Supabase (and, later, Firebase); features receive interfaces and callbacks. Mirrors
 * the iOS `AppEnvironment`.
 */
class AppEnvironment(private val context: Context) {
    val session = AppSession()
    val remoteConfig = RemoteConfigStore(BuildConfig.VERSION_NAME)
    val cities = CityFilterStore()
    val deepLink = DeepLinkStore()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val supabaseAuth: SupabaseAuthRepository?
    private val configurationRepository: ConfigurationRepository
    private val profileRepository: ProfileRepository
    private val contentRepository: ContentRepository
    val analytics: AnalyticsRecorder
    val catalog: CatalogFeature
    private val catalogRepository: CatalogRepository
    val studio: StudioFeature

    init {
        val config = backendConfiguration()
        if (config != null) {
            val auth = SupabaseAuthRepository(OkHttpApiClient(config), SessionStore(context))
            val dataClient = OkHttpApiClient(config, authTokenProvider = { auth.currentAccessToken() })
            supabaseAuth = auth
            configurationRepository = SupabaseConfigurationRepository(dataClient, context)
            profileRepository = SupabaseProfileRepository(dataClient)
            contentRepository = SupabaseContentRepository(dataClient)
            analytics = makeAnalytics(dataClient)
            catalogRepository = RemoteCatalogRepository(dataClient)
            studio = StudioFeature(
                repository = RemoteStudioRepository(dataClient),
                uploader = SupabaseMediaUploader(config.baseUrl, BuildConfig.SUPABASE_ANON_KEY, { auth.currentAccessToken() }, { auth.currentUserId() }),
                checkout = TapPlanCheckout(config.baseUrl, BuildConfig.SUPABASE_ANON_KEY, { auth.currentAccessToken() }),
                mapsAvailable = BuildConfig.MAPS_API_KEY.isNotBlank(),
            )
        } else {
            // No backend values: everything runs on in-memory mocks.
            supabaseAuth = null
            configurationRepository = MockConfigurationRepository()
            profileRepository = MockProfileRepository()
            contentRepository = MockContentRepository()
            analytics = AnalyticsRecorder.disabled
            catalogRepository = MockCatalogRepository()
            val studioRepository = MockStudioRepository()
            studio = StudioFeature(studioRepository, MockMediaUploader(), MockPlanCheckout(studioRepository), BuildConfig.MAPS_API_KEY.isNotBlank())
        }
        catalog = CatalogFeature(
            repository = catalogRepository,
            context = CatalogContext(citySummary = allCitiesLabel()),
            openCityPicker = { session.isPickingCities = true },
            requireSignIn = { session.isPresentingAuth = true },
            mapsAvailable = BuildConfig.MAPS_API_KEY.isNotBlank(),
        )
    }

    private fun allCitiesLabel() = RemoteStrings.string("cities.all", context.getString(R.string.cities_all))

    /**
     * Mirrors who is signed in and which cities are chosen into the catalog, which reloads its
     * screens when these change.
     */
    fun refreshCatalogContext() {
        val ctx = catalog.context
        val wasGuest = ctx.isGuest
        ctx.isGuest = !session.hasAccount
        ctx.displayName = session.user?.displayName
        ctx.cityIds = cities.queryCityIds
        ctx.citySummary = cities.summary(allCitiesLabel())
        if (wasGuest != ctx.isGuest) catalog.accountChanged()
    }

    /** Supabase needs the anon key on every request plus a bearer (the anon key until sign-in). */
    private fun backendConfiguration(): NetworkConfiguration? {
        val url = BuildConfig.SUPABASE_URL
        val key = BuildConfig.SUPABASE_ANON_KEY
        if (url.isBlank() || key.isBlank()) return null
        return NetworkConfiguration(url, mapOf("apikey" to key, "Authorization" to "Bearer $key"))
    }

    // Analytics

    /** Curated events and handled errors → Postgres (Firebase joins when the Android app is added). */
    private fun makeAnalytics(client: ApiClient) = AnalyticsRecorder(
        onEvent = { event, entityId, context, props ->
            scope.launch {
                runCatching {
                    client.send<RecordAnalyticsEventArgs, EmptyResponse>(
                        ApiEndpoint.Analytics.record,
                        RecordAnalyticsEventArgs(event.rawValue, entityId, context, props.ifEmpty { null }),
                    )
                }
            }
        },
        onScreen = { },
        onError = { code, message, screen ->
            scope.launch {
                runCatching {
                    client.send<LogClientErrorArgs, EmptyResponse>(
                        ApiEndpoint.Analytics.logError,
                        LogClientErrorArgs(code, message, screen, BuildConfig.VERSION_NAME, "Android ${Build.VERSION.RELEASE}"),
                    )
                }
            }
        },
    )

    // Auth

    fun makeAuthFeature(onFinished: (AuthState) -> Unit): AuthenticationFeature =
        supabaseAuth?.let { AuthenticationFeature(it, onFinished) } ?: AuthenticationFeature.makeDefault(onFinished)

    /** Launch: restore the persisted session, then load the profile (which carries the role). */
    suspend fun restoreSession() {
        if (session.state != AppSession.State.Checking) return
        val auth = supabaseAuth ?: run { session.state = AppSession.State.SignedOut; return }
        when (val restored = auth.restoreSession()) {
            AuthState.Guest -> session.state = AppSession.State.SignedOut
            is AuthState.Authenticated -> signedIn(restored.user)
        }
    }

    /** Called when the auth flow finishes (sign-in, registration, or "browse as guest"). */
    suspend fun authFinished(state: AuthState) {
        when (state) {
            // No server session (mock backend): browse as a bride; account actions ask to sign in.
            AuthState.Guest -> session.state = AppSession.State.SignedIn(AppSession.SessionUser("guest", UserRole.Bride, true, null))
            is AuthState.Authenticated -> signedIn(state.user)
        }
        session.isPresentingAuth = false
        refreshCatalogContext()
    }

    private suspend fun signedIn(user: User) {
        val isAnonymous = supabaseAuth?.currentUserIsAnonymous() ?: false
        session.state = AppSession.State.SignedIn(AppSession.SessionUser(user.id, user.role, isAnonymous, user.displayName))
        syncProfile()
        refreshCatalogContext()
    }

    /** Refreshes the role, name and saved cities from the server profile. */
    suspend fun syncProfile() {
        var current = session.user ?: return
        if (current.id == "guest") return
        val profile = runCatching { profileRepository.fetchMyProfile() }.getOrNull()
        if (profile == null) {
            // Offline: keep what we have. A guest browses as a bride.
            if (current.role == null && current.isAnonymous) current = current.copy(role = UserRole.Bride)
            session.state = AppSession.State.SignedIn(current)
            return
        }
        current = current.copy(
            role = profile.role ?: (if (profile.isAnonymous) UserRole.Bride else current.role),
            isAnonymous = profile.isAnonymous,
            displayName = profile.displayName,
        )
        session.state = AppSession.State.SignedIn(current)
        cities.restore(profile.cityIds)
        refreshCatalogContext()
    }

    suspend fun signOut() {
        supabaseAuth?.signOut()
        session.state = AppSession.State.SignedOut
        cities.restore(emptyList())
        refreshCatalogContext()
    }

    // Remote config, strings, cities

    suspend fun loadRemoteConfig() {
        val config = runCatching { configurationRepository.fetchConfiguration() }.getOrNull()
            ?: configurationRepository.cachedConfiguration()
        config?.let(remoteConfig::update)
    }

    /** Installs dashboard-edited text for the current language (falls back to the bundle). */
    suspend fun loadRemoteStrings() {
        val language = if (Locale.getDefault().language == "en") "en" else "ar"
        runCatching { contentRepository.fetchStrings(language) }.getOrNull()?.let(RemoteStrings::install)
    }

    suspend fun loadCities() {
        runCatching { contentRepository.fetchCities() }.getOrNull()?.let {
            cities.available = it
            refreshCatalogContext()
        }
    }

    /** Saves the bride's city choice ("All" = empty list) to her profile. */
    fun saveCities() {
        val ids = if (cities.isAll) emptyList() else cities.selected.sorted()
        refreshCatalogContext()
        analytics(AnalyticsEvent.CityFilterChanged, props = mapOf("cities" to if (cities.isAll) "all" else ids.joinToString(",")))
        if (!session.hasAccount) return
        scope.launch { runCatching { profileRepository.setMyCities(ids) } }
    }

    // Links

    fun open(link: DeepLink?) {
        link?.let { deepLink.pending = it }
    }

    val appVersionString: String get() = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"
}
