package co.munyati.app.composition

import android.net.Uri
import android.content.Intent
import android.content.Context
import android.os.Build
import android.os.Bundle
import co.munyati.app.push.Push
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crashlytics.FirebaseCrashlytics
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
import co.munyati.providerstudio.presentation.StudioSettingsLink
import co.munyati.app.backend.SupabaseReceiptStorage
import co.munyati.booking.data.BookingRepository
import co.munyati.booking.data.MockBookingRepository
import co.munyati.booking.data.MockReceiptStorage
import co.munyati.booking.data.ReceiptStorage
import co.munyati.booking.data.RemoteBookingRepository
import co.munyati.booking.domain.BookableService
import co.munyati.booking.presentation.AvailabilityRoute
import co.munyati.booking.presentation.BookingFeature
import co.munyati.booking.presentation.PaymentMethodsRoute
import co.munyati.catalog.domain.ServiceCard
import co.munyati.app.backend.AccountDeleter
import co.munyati.app.backend.CmsPageRepository
import co.munyati.app.backend.MockCmsPageRepository
import co.munyati.app.backend.SupabaseCmsPageRepository
import co.munyati.core.error.AppError
import co.munyati.shared.media.MediaUploading
import co.munyati.trust.data.MockTrustRepository
import co.munyati.trust.data.RemoteTrustRepository
import co.munyati.trust.data.TrustRepository
import co.munyati.trust.domain.SupportContact
import co.munyati.trust.presentation.TrustFeature
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
    /** Light, dark or follow the system, chosen in Profile. */
    val appearance = AppearanceStore(context)
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
    val booking: BookingFeature
    private val bookingRepository: BookingRepository
    private val receiptStorage: ReceiptStorage
    val trust: TrustFeature
    private val trustRepository: TrustRepository
    private val mediaUploader: MediaUploading
    val cmsPageRepository: CmsPageRepository
    private val accountDeleter: AccountDeleter?

    init {
        val config = backendConfiguration()
        if (config != null) {
            val auth = SupabaseAuthRepository(OkHttpApiClient(config), SessionStore(context))
            val dataClient = OkHttpApiClient(config, authTokenProvider = { auth.currentAccessToken() })
            supabaseAuth = auth
            configurationRepository = SupabaseConfigurationRepository(dataClient, context)
            profileRepository = SupabaseProfileRepository(dataClient)
            contentRepository = SupabaseContentRepository(dataClient)
            cmsPageRepository = SupabaseCmsPageRepository(dataClient)
            analytics = makeAnalytics(dataClient)
            catalogRepository = RemoteCatalogRepository(dataClient)
            mediaUploader = SupabaseMediaUploader(config.baseUrl, BuildConfig.SUPABASE_ANON_KEY, { auth.currentAccessToken() }, { auth.currentUserId() })
            trustRepository = RemoteTrustRepository(dataClient)
            studio = StudioFeature(
                repository = RemoteStudioRepository(dataClient),
                uploader = mediaUploader,
                checkout = TapPlanCheckout(config.baseUrl, BuildConfig.SUPABASE_ANON_KEY, { auth.currentAccessToken() }),
                mapsAvailable = BuildConfig.MAPS_API_KEY.isNotBlank(),
            )
            bookingRepository = RemoteBookingRepository(dataClient)
            receiptStorage = SupabaseReceiptStorage(config.baseUrl, BuildConfig.SUPABASE_ANON_KEY, { auth.currentAccessToken() })
            accountDeleter = AccountDeleter(config.baseUrl, BuildConfig.SUPABASE_ANON_KEY, { auth.currentAccessToken() })
        } else {
            // No backend values: everything runs on in-memory mocks.
            supabaseAuth = null
            configurationRepository = MockConfigurationRepository()
            profileRepository = MockProfileRepository()
            contentRepository = MockContentRepository()
            cmsPageRepository = MockCmsPageRepository()
            analytics = AnalyticsRecorder.disabled
            catalogRepository = MockCatalogRepository()
            mediaUploader = MockMediaUploader(context.filesDir)
            trustRepository = MockTrustRepository()
            val studioRepository = MockStudioRepository()
            studio = StudioFeature(studioRepository, mediaUploader, MockPlanCheckout(studioRepository), BuildConfig.MAPS_API_KEY.isNotBlank())
            // One mock shared by both shells, so a bride's request reaches the provider inbox.
            bookingRepository = MockBookingRepository()
            receiptStorage = MockReceiptStorage()
            accountDeleter = null
        }
        catalog = CatalogFeature(
            repository = catalogRepository,
            context = CatalogContext(citySummary = allCitiesLabel()),
            openCityPicker = { session.isPickingCities = true },
            requireSignIn = { session.isPresentingAuth = true },
            mapsAvailable = BuildConfig.MAPS_API_KEY.isNotBlank(),
        )
        booking = BookingFeature(
            repository = bookingRepository,
            receipts = receiptStorage,
            remainingBudget = { catalog.remainingBudget },
            onBookingsChanged = { catalog.refreshBudget() },
            onBookingCreated = { id -> open(DeepLink.Booking(id)) },
        )
        catalog.setBookingHandler(::requestBooking)
        // Home banners: app links go through the deep-link router, other pages to the browser.
        catalog.setLinkHandlers(
            openLink = { url -> DeepLink.from(url)?.let(::open) ?: openExternal(url) },
            openProviderInvite = { openExternal("https://munyati.co/providers") },
        )
        studio.setSettingsRoutes { link ->
            when (link) {
                StudioSettingsLink.Availability -> AvailabilityRoute
                StudioSettingsLink.PaymentMethods -> PaymentMethodsRoute
            }
        }

        trust = TrustFeature(
            repository = trustRepository,
            uploader = mediaUploader,
            isSignedIn = { session.hasAccount },
            requireSignIn = { session.isPresentingAuth = true },
            supportInfo = { supportContacts() to remoteConfig.config?.support?.helpCenterUrl },
        )
        connectTrustViews(trust, catalog, booking)
    }

    /** Contact channels from remote config, with the published email as a fallback. */
    private fun supportContacts(): List<SupportContact> {
        val methods = remoteConfig.config?.support?.contactMethods.orEmpty()
        val contacts = methods.mapNotNull { m -> SupportContact.Kind.entries.firstOrNull { it.rawValue == m.type }?.let { SupportContact(it, m.value) } }
        return contacts.ifEmpty { listOf(SupportContact(SupportContact.Kind.Email, "contact@munyati.co")) }
    }

    /** Deletes the account on the server, then signs out. Throws when it can't. */
    suspend fun deleteAccount() {
        val deleter = accountDeleter ?: throw AppError.Authentication(AppError.AuthFailureReason.NotAuthenticated)
        deleter.delete()
        signOut()
    }

    /** "Book" on a service: guests sign in first, providers can't book, brides get the request. */
    private fun requestBooking(card: ServiceCard) {
        if (!session.hasAccount) {
            session.isPresentingAuth = true
            return
        }
        if (session.role == UserRole.Provider) return
        session.bookingRequest = BookableService(card.id, card.title, card.price, card.providerName)
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
        ctx.canBook = session.role != UserRole.Provider
        // "Hide" flags, so a missing flag (or a config not loaded yet) keeps the slides.
        ctx.showsBudgetSlide = remoteConfig.config?.isFeatureEnabled("hideHomeBudgetSlide") != true
        ctx.showsDiscoverSlide = remoteConfig.config?.isFeatureEnabled("hideHomeDiscoverSlide") != true
        ctx.displayName = session.user?.displayName
        ctx.cityIds = cities.queryCityIds
        ctx.citySummary = cities.summary(allCitiesLabel())
        ctx.cities = cities.available
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

    /** Firebase Analytics, when the Android app's google-services.json is present. */
    private val firebase: FirebaseAnalytics? =
        if (Push.isAvailable(context)) FirebaseAnalytics.getInstance(context) else null

    /** Curated events → Postgres + Firebase; screens → Firebase; errors → Crashlytics + Postgres (as iOS). */
    private fun makeAnalytics(client: ApiClient) = AnalyticsRecorder(
        onEvent = { event, entityId, context, props ->
            firebase?.let { fb ->
                val params = Bundle().apply {
                    props.forEach { (key, value) -> putString(key, value) }
                    entityId?.let { putString("entity_id", it) }
                    context?.let { putString("context", it) }
                }
                fb.logEvent(event.rawValue, params)
            }
            scope.launch {
                runCatching {
                    client.send<RecordAnalyticsEventArgs, EmptyResponse>(
                        ApiEndpoint.Analytics.record,
                        RecordAnalyticsEventArgs(event.rawValue, entityId, context, props.ifEmpty { null }),
                    )
                }
            }
        },
        onScreen = { name ->
            firebase?.logEvent(FirebaseAnalytics.Event.SCREEN_VIEW, Bundle().apply { putString(FirebaseAnalytics.Param.SCREEN_NAME, name) })
        },
        onError = { code, message, screen ->
            if (firebase != null) {
                FirebaseCrashlytics.getInstance().recordException(RuntimeException("$code: $message (screen: ${screen ?: "-"})"))
            }
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

    /**
     * Finishes sign-in on the app's own scope. The auth sheet's scope is cancelled the moment the
     * sheet closes (which signing in does), and that cut the profile load short: name and phone
     * stayed empty until the next launch.
     */
    fun finishAuth(state: AuthState) {
        scope.launch { authFinished(state) }
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
            phone = profile.phone,
        )
        session.state = AppSession.State.SignedIn(current)
        cities.restore(profile.cityIds)
        refreshCatalogContext()
        firebase?.setUserProperty("role", current.role?.rawValue)
        if (firebase != null) FirebaseCrashlytics.getInstance().setUserId(profile.id)
        // A token that arrived before sign-in is registered again once a user exists.
        Push.currentToken(context, ::registerDeviceToken)
    }

    /** Sends this device's FCM token to the server (`register_device_token`, platform "android"). */
    fun registerDeviceToken(token: String) {
        if (session.user == null) return
        scope.launch { runCatching { profileRepository.registerDeviceToken(token) } }
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
        refreshCatalogContext()
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

    /** Opens a web page (or the Play Store) outside the app. */
    fun openExternal(url: String) {
        runCatching {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    val appVersionString: String get() = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"
}
