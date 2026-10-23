package co.munyati.providerstudio.presentation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material.icons.outlined.Schedule
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import co.munyati.catalog.domain.CatalogCategory
import co.munyati.catalog.domain.City
import co.munyati.core.error.AppError
import co.munyati.core.state.ViewState
import co.munyati.providerstudio.R
import co.munyati.providerstudio.data.StudioRepository
import co.munyati.providerstudio.domain.MyBusiness
import co.munyati.providerstudio.domain.PlanCheckout
import co.munyati.providerstudio.domain.SubscriptionOverview
import co.munyati.shared.media.MediaUploading
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.Serializable

// Studio destinations, registered on the provider's NavHosts (iOS `StudioRoute` plus the editors
// iOS presents as sheets).
@Serializable data class PlansRoute(val reason: String? = null)
@Serializable data object InsightsRoute
@Serializable data object BusinessEditRoute
@Serializable data object ServicesListRoute
@Serializable data class ServiceEditRoute(val id: String? = null)
@Serializable data object StoresListRoute
@Serializable data class StoreEditRoute(val id: String? = null)

/** Studio rows whose screens live in another feature (Booking). */
enum class StudioSettingsLink(internal val icon: ImageVector, internal val title: Int, internal val subtitle: Int) {
    Availability(Icons.Outlined.Schedule, R.string.studio_studio_availability, R.string.studio_studio_availability_subtitle),
    PaymentMethods(Icons.Outlined.Payments, R.string.studio_studio_paymentMethods, R.string.studio_studio_paymentMethods_subtitle),
}

/**
 * Public entry point of the provider studio: the provider's Home tab, where they build the profile,
 * services and stores brides will see once an admin approves them.
 */
class StudioFeature(
    repository: StudioRepository,
    internal val uploader: MediaUploading,
    internal val checkout: PlanCheckout,
    internal val mapsAvailable: Boolean,
) {
    internal val store = StudioStore(repository)

    /** Booking settings screens (working hours, payout methods), supplied by the App. */
    internal var settingsRoute: ((StudioSettingsLink) -> Any)? = null

    fun setSettingsRoutes(route: (StudioSettingsLink) -> Any) {
        settingsRoute = route
    }

    @Composable
    fun HomeScreen() = StudioHomeScreen(this)

    /** Registers the studio's pushed screens on a NavHost. */
    fun NavGraphBuilder.destinations() {
        composable<PlansRoute> { PlansScreen(this@StudioFeature, it.toRoute<PlansRoute>().reason) }
        composable<InsightsRoute> { InsightsScreen(this@StudioFeature) }
        composable<BusinessEditRoute> { BusinessEditScreen(this@StudioFeature) }
        composable<ServicesListRoute> { ServicesListScreen(this@StudioFeature) }
        composable<ServiceEditRoute> { ServiceEditScreen(this@StudioFeature, it.toRoute<ServiceEditRoute>().id) }
        composable<StoresListRoute> { StoresListScreen(this@StudioFeature) }
        composable<StoreEditRoute> { StoreEditScreen(this@StudioFeature, it.toRoute<StoreEditRoute>().id) }
    }
}

/** Shared state for every studio screen, reloaded after each save. */
internal class StudioStore(val repository: StudioRepository) {
    var state: ViewState<MyBusiness> by mutableStateOf(ViewState.Loading)
        private set
    /** Plan, trial and limits (null until loaded, or if it failed: the studio still works). */
    var subscription: SubscriptionOverview? by mutableStateOf(null)
        private set
    var categories: List<CatalogCategory> by mutableStateOf(emptyList())
        private set
    var cities: List<City> by mutableStateOf(emptyList())
        private set

    val business: MyBusiness? get() = state.value

    suspend fun load() {
        try {
            coroutineScope {
                val b = async { repository.business() }
                val c = async { repository.categories() }
                val ci = async { repository.cities() }
                categories = c.await()
                cities = ci.await()
                state = ViewState.Loaded(b.await())
            }
            subscription = runCatching { repository.subscription() }.getOrNull()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            if (state.value == null) state = ViewState.Error(AppError.from(e))
        }
    }

    suspend fun reload() {
        runCatching { repository.business() }.getOrNull()?.let { state = ViewState.Loaded(it) }
        runCatching { repository.subscription() }.getOrNull()?.let { subscription = it }
    }

    fun categoryName(id: String) = categories.firstOrNull { it.id == id }?.name ?: id
    fun cityName(id: String) = cities.firstOrNull { it.id == id }?.name() ?: id
}
