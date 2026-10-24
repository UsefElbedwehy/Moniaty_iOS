package co.munyati.catalog.presentation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import co.munyati.catalog.data.CatalogRepository
import co.munyati.catalog.domain.Budget
import co.munyati.catalog.domain.ServiceCard
import co.munyati.catalog.domain.ServiceFilter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

/**
 * What the catalog needs from the App, kept observable so screens reload when it changes (e.g. the
 * bride picks other cities).
 */
class CatalogContext(cityIds: List<String>? = null, citySummary: String = "", displayName: String? = null, isGuest: Boolean = true) {
    /** null = all cities. */
    var cityIds by mutableStateOf(cityIds)
    /** Short label for the city button, e.g. "الدمام، الخبر". */
    var citySummary by mutableStateOf(citySummary)
    var displayName by mutableStateOf(displayName)
    /** Guests (no account) are asked to sign in before favoriting or setting a budget. */
    var isGuest by mutableStateOf(isGuest)
    /**
     * False for provider accounts: bookings are made from a bride account (which can be created on
     * the same number), so the service page shows a note instead of the Book button.
     */
    var canBook by mutableStateOf(true)
    /** The built-in Home slides (budget, discover); the dashboard can hide them to leave the carousel to paid banners. */
    var showsBudgetSlide by mutableStateOf(true)
    var showsDiscoverSlide by mutableStateOf(true)
}

// Destinations inside the catalog. The App registers `destinations()` on each tab's NavHost and
// navigates to these for deep links. Mirrors iOS `CatalogRoute`.
@Serializable
data class ServicesRoute(
    val categoryId: String? = null,
    val title: String? = null,
    val withinBudget: Boolean = false,
    val sort: String = ServiceFilter.Sort.Recommended.rawValue,
) {
    val filter get() = ServiceFilter(categoryId = categoryId, title = title, withinBudget = withinBudget, sort = ServiceFilter.Sort.from(sort))
}
@Serializable data class ServiceRoute(val id: String)
@Serializable data class ProviderRoute(val id: String)
@Serializable data class StoreRoute(val id: String)
@Serializable data object FavoritesRoute

/** Content a catalog screen can report. */
sealed interface CatalogContentRef {
    data class Provider(val id: String) : CatalogContentRef
    data class Service(val id: String) : CatalogContentRef
    data class Store(val id: String) : CatalogContentRef
}

/** Views supplied by the App from the Trust feature, so Catalog doesn't depend on it. */
class CatalogTrustViews(
    val reviews: @Composable (providerId: String) -> Unit,
    val moreMenu: @Composable (CatalogContentRef) -> Unit,
)

/**
 * Public entry point of the Catalog feature (bride discovery: Home, search, details, map,
 * favorites, budget). The App builds one, mounts its screens in the tab shells and registers
 * [destinations] on each NavHost.
 */
class CatalogFeature(
    internal val repository: CatalogRepository,
    val context: CatalogContext,
    internal val openCityPicker: () -> Unit,
    internal val requireSignIn: () -> Unit,
    /** False when the build has no Google Maps key: Explore shows a notice instead of a blank map. */
    internal val mapsAvailable: Boolean,
) {
    internal val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    internal val favorites = FavoritesStore(repository, scope)
    val budget = BudgetStore(repository)

    /** The "Book" action on a service; null shows "coming soon". Set by the App (Booking). */
    internal var onBook: ((ServiceCard) -> Unit)? = null

    /** Reviews and report/block menus from the Trust feature. */
    internal var trustViews: CatalogTrustViews? = null

    /**
     * Opens a Home banner's link: app links go through the App's deep-link router, other pages
     * open in the browser. Set by the App.
     */
    internal var openLink: ((String) -> Unit)? = null

    /** Opens the website page that invites providers to join. Set by the App. */
    internal var openProviderInvite: (() -> Unit)? = null

    fun setLinkHandlers(openLink: (String) -> Unit, openProviderInvite: () -> Unit) {
        this.openLink = openLink
        this.openProviderInvite = openProviderInvite
    }

    /** Days until the wedding (null without a date or once it has passed), for Home and Profile. */
    val daysUntilWedding: Int? get() = budget.budget?.daysUntilWedding()

    /** How many services the bride saved, for Profile (null for guests or on failure). */
    suspend fun favoritesCount(): Int? {
        if (context.isGuest) return null
        return try {
            repository.favorites().size
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            null
        }
    }

    fun setBookingHandler(handler: (ServiceCard) -> Unit) {
        onBook = handler
    }

    fun setTrustViews(views: CatalogTrustViews) {
        trustViews = views
    }

    /** Reloads per-account state after sign-in / sign-out. */
    fun accountChanged() {
        favorites.reset()
        refreshBudget()
    }

    /** Reloads the budget after bookings change what is reserved. */
    fun refreshBudget() {
        scope.launch { budget.load(context.isGuest) }
    }

    /** What is left of the bride's budget (null without one), for the booking request. */
    val remainingBudget: Double? get() = budget.budget?.remaining

    @Composable
    fun HomeScreen() = HomeScreen(this)

    @Composable
    fun ExploreScreen() = ExploreScreen(this)

    /** The budget editor, for presenting from outside Home (e.g. Profile). */
    @Composable
    fun BudgetEditor(onDismiss: () -> Unit) = BudgetSheet(budget, onDismiss)

    /** Registers the catalog's pushed screens on a tab's NavHost. */
    fun NavGraphBuilder.destinations() {
        composable<ServicesRoute> { ServiceListScreen(this@CatalogFeature, it.toRoute<ServicesRoute>().filter) }
        composable<ServiceRoute> { ServiceDetailScreen(this@CatalogFeature, it.toRoute<ServiceRoute>().id) }
        composable<ProviderRoute> { ProviderScreen(this@CatalogFeature, it.toRoute<ProviderRoute>().id) }
        composable<StoreRoute> { StoreScreen(this@CatalogFeature, it.toRoute<StoreRoute>().id) }
        composable<FavoritesRoute> { FavoritesScreen(this@CatalogFeature) }
    }

    internal fun toggleFavorite(card: ServiceCard) {
        if (context.isGuest) {
            requireSignIn()
            return
        }
        scope.launch { favorites.toggle(card) }
    }
}

/**
 * Favorite state shared by every card on screen, so a heart tapped in one list updates the others
 * immediately (optimistic, rolled back on failure).
 */
internal class FavoritesStore(private val repository: CatalogRepository, private val scope: CoroutineScope) {
    private val overrides = mutableStateMapOf<String, Boolean>()

    fun isFavorite(card: ServiceCard): Boolean = overrides[card.id] ?: card.isFavorite

    suspend fun toggle(card: ServiceCard) {
        val wanted = !isFavorite(card)
        overrides[card.id] = wanted
        overrides[card.id] = runCatching { repository.toggleFavorite(card.id) }.getOrElse { !wanted }
    }

    fun reset() = overrides.clear()
}

/** The bride's budget (requirement 13): loaded once, edited from Home or Profile. */
class BudgetStore internal constructor(private val repository: CatalogRepository) {
    var budget: Budget? by mutableStateOf(null)
        private set

    /** The cap for "within my budget" filters, or null when no budget is set. */
    val maxPrice: Double? get() = budget?.remaining

    suspend fun load(isGuest: Boolean) {
        if (isGuest) {
            budget = null
            return
        }
        runCatching { repository.budget() }.getOrNull()?.let { budget = it }
    }

    suspend fun save(total: Double, weddingDate: String?) {
        budget = repository.setBudget(total, weddingDate)
    }
}
