package co.munyati.app.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Map
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.PersonAddAlt
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import co.munyati.app.R
import co.munyati.app.composition.AppEnvironment
import co.munyati.app.composition.DeepLink
import co.munyati.app.composition.l10n
import co.munyati.catalog.presentation.ProviderRoute
import co.munyati.catalog.presentation.ServiceRoute
import co.munyati.catalog.presentation.ServicesRoute
import co.munyati.catalog.presentation.StoreRoute
import co.munyati.providerstudio.presentation.PlansRoute
import co.munyati.booking.domain.BookingRole
import co.munyati.designsystem.components.EmptyStateView
import co.munyati.designsystem.components.LargeHeaderBar
import co.munyati.designsystem.theme.DS
import co.munyati.shared.navigation.LocalNavigator
import co.munyati.shared.navigation.Navigator
import kotlinx.serialization.Serializable

/** The four tabs (`docs/PLAN.md` §3), the same for both roles; only the content differs. */
enum class AppTab { Home, Explore, Bookings, Profile }

// Each tab's root destination.
@Serializable private data object TabRoot

/** The bride's tabs: Catalog Home and Explore, Bookings, Profile. */
@Composable
fun BrideShell(environment: AppEnvironment) {
    val catalog = environment.catalog
    val booking = environment.booking
    val destinations: NavGraphBuilder.() -> Unit = {
        with(catalog) { destinations() }
        with(booking) { destinations() }
        appDestinations(environment)
    }
    TabShell(environment, BookingRole.Bride, bookingsTitle = R.string.tab_bookings) { tab, controller ->
        when (tab) {
            AppTab.Home -> TabNavHost(controller, { catalog.HomeScreen() }, destinations)
            AppTab.Explore -> TabNavHost(controller, { catalog.ExploreScreen() }, destinations)
            AppTab.Bookings -> TabNavHost(controller, { BookingsTab(environment, BookingRole.Bride, R.string.tab_bookings) }, destinations)
            AppTab.Profile -> TabNavHost(controller, { ProfileScreen(environment) }, destinations)
        }
    }
}

/** The provider's tabs: the studio Home (ProviderStudio), Explore, Bookings, Profile. */
@Composable
fun ProviderShell(environment: AppEnvironment) {
    val catalog = environment.catalog
    val studio = environment.studio
    val booking = environment.booking
    val destinations: NavGraphBuilder.() -> Unit = {
        with(catalog) { destinations() }
        with(studio) { destinations() }
        with(booking) { destinations() }
        appDestinations(environment)
    }
    TabShell(environment, BookingRole.Provider, bookingsTitle = R.string.tab_providerBookings) { tab, controller ->
        when (tab) {
            AppTab.Home -> TabNavHost(controller, { studio.HomeScreen() }, destinations)
            AppTab.Explore -> TabNavHost(controller, { catalog.ExploreScreen() }, destinations)
            AppTab.Bookings -> TabNavHost(controller, { BookingsTab(environment, BookingRole.Provider, R.string.tab_providerBookings) }, destinations)
            AppTab.Profile -> TabNavHost(controller, { ProfileScreen(environment) }, destinations)
        }
    }
}

/** Screens every tab can push: Trust (reviews, support, blocked accounts) and CMS pages. */
private fun NavGraphBuilder.appDestinations(environment: AppEnvironment) {
    with(environment.trust) { destinations() }
    composable<CmsPageRoute> { CmsPageScreen(it.toRoute<CmsPageRoute>().slug, environment.cmsPageRepository) }
}

/**
 * A route waiting to be pushed on a tab. A tab's NavHost only exists once the tab has been shown,
 * so routes for another tab (deep links, a new booking) are queued and pushed when it appears.
 */
private data class PendingRoute(val route: Any, val fromRoot: Boolean)

private val LocalPendingRoutes = androidx.compose.runtime.staticCompositionLocalOf { mutableStateMapOf<NavHostController, PendingRoute>() }

/** One tab's navigation stack: its root screen plus the feature destinations it can push. */
@Composable
private fun TabNavHost(controller: NavHostController, root: @Composable () -> Unit, destinations: NavGraphBuilder.() -> Unit) {
    val navigator = remember(controller) { Navigator(navigate = { controller.navigate(it) }, back = { controller.popBackStack() }) }
    val pendingRoutes = LocalPendingRoutes.current
    CompositionLocalProvider(LocalNavigator provides navigator) {
        NavHost(controller, startDestination = TabRoot) {
            composable<TabRoot> { root() }
            destinations()
        }
    }
    val pending = pendingRoutes[controller]
    LaunchedEffect(pending) {
        if (pending == null) return@LaunchedEffect
        if (pending.fromRoot) controller.popBackStack(TabRoot, inclusive = false)
        controller.navigate(pending.route)
        pendingRoutes.remove(controller)
    }
}

@Composable
private fun TabShell(
    environment: AppEnvironment,
    role: BookingRole,
    bookingsTitle: Int,
    content: @Composable (AppTab, NavHostController) -> Unit,
) {
    var tab by rememberSaveable { mutableStateOf(AppTab.Home) }
    // One controller per tab, so each tab keeps its own stack (like a NavigationStack per tab).
    val controllers = AppTab.entries.associateWith { rememberNavController() }
    val pendingRoutes = remember { mutableStateMapOf<NavHostController, PendingRoute>() }
    fun open(target: AppTab, route: Any, fromRoot: Boolean = false) {
        pendingRoutes[controllers.getValue(target)] = PendingRoute(route, fromRoot)
        tab = target
    }

    // Deep links: switch tab, then open the screen.
    val pending = environment.deepLink.pending
    LaunchedEffect(pending) {
        when (pending) {
            null -> return@LaunchedEffect
            is DeepLink.Booking -> open(AppTab.Bookings, environment.booking.detailRoute(pending.id, role), fromRoot = true)
            is DeepLink.Provider -> open(AppTab.Home, ProviderRoute(pending.id))
            is DeepLink.Service -> open(AppTab.Home, ServiceRoute(pending.id))
            is DeepLink.Store -> open(AppTab.Home, StoreRoute(pending.id))
            is DeepLink.Category -> open(AppTab.Home, ServicesRoute(categoryId = pending.id))
            DeepLink.Plans -> if (role == BookingRole.Provider) open(AppTab.Home, PlansRoute()) else tab = AppTab.Home
            DeepLink.Notifications -> tab = AppTab.Home
        }
        environment.deepLink.pending = null
    }

    // "Book" on a service: the request opens on the tab the bride is browsing.
    val request = environment.session.bookingRequest
    LaunchedEffect(request) {
        if (request == null) return@LaunchedEffect
        open(tab, environment.booking.requestRoute(request))
        environment.session.bookingRequest = null
    }

    val items = listOf(
        Triple(AppTab.Home, R.string.tab_home, Icons.Outlined.Home),
        Triple(AppTab.Explore, R.string.tab_explore, Icons.Outlined.Map),
        Triple(AppTab.Bookings, bookingsTitle, Icons.Outlined.CalendarMonth),
        Triple(AppTab.Profile, R.string.tab_profile, Icons.Outlined.Person),
    )
    Scaffold(
        containerColor = DS.colors.background,
        contentWindowInsets = WindowInsets(0),
        bottomBar = {
            NavigationBar(containerColor = DS.colors.surface) {
                items.forEach { (item, title, icon) ->
                    NavigationBarItem(
                        selected = tab == item,
                        onClick = {
                            // Tapping the current tab again returns to its root, like iOS.
                            if (tab == item) controllers.getValue(item).popBackStack(TabRoot, inclusive = false)
                            tab = item
                        },
                        icon = { Icon(icon, contentDescription = null) },
                        label = { Text(l10n(title), style = DS.type.caption) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = DS.colors.primary,
                            selectedTextColor = DS.colors.primary,
                            indicatorColor = DS.colors.primaryMuted,
                            unselectedIconColor = DS.colors.textSecondary,
                            unselectedTextColor = DS.colors.textSecondary,
                        ),
                    )
                }
            }
        },
    ) { padding ->
        CompositionLocalProvider(LocalPendingRoutes provides pendingRoutes) {
            Box(Modifier.fillMaxSize().padding(padding)) { content(tab, controllers.getValue(tab)) }
        }
    }

    if (environment.session.isPickingCities) CityPickerDialog(environment) { environment.session.isPickingCities = false }
}

/** The bookings tab: the Booking feature's list for an account, a sign-in prompt for a guest. */
@Composable
private fun BookingsTab(environment: AppEnvironment, role: BookingRole, titleRes: Int) {
    if (environment.session.hasAccount) {
        environment.booking.BookingsScreen(role)
        return
    }
    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        LargeHeaderBar(l10n(titleRes), Modifier.statusBarsPadding())
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            EmptyStateView(
                icon = Icons.Outlined.PersonAddAlt,
                title = l10n(R.string.bookings_guest_title),
                message = l10n(R.string.bookings_guest_message),
                actionTitle = l10n(R.string.auth_signIn),
                onAction = { environment.session.isPresentingAuth = true },
            )
        }
    }
}
