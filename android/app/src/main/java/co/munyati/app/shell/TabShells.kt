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
import androidx.compose.material.icons.outlined.Storefront
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
import co.munyati.app.R
import co.munyati.app.composition.AppEnvironment
import co.munyati.app.composition.DeepLink
import co.munyati.app.composition.l10n
import co.munyati.catalog.presentation.ProviderRoute
import co.munyati.catalog.presentation.ServiceRoute
import co.munyati.catalog.presentation.ServicesRoute
import co.munyati.catalog.presentation.StoreRoute
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
    TabShell(environment, bookingsTitle = R.string.tab_bookings) { tab, controller ->
        when (tab) {
            AppTab.Home -> TabNavHost(controller, { catalog.HomeScreen() }) { with(catalog) { destinations() } }
            AppTab.Explore -> TabNavHost(controller, { catalog.ExploreScreen() }) { with(catalog) { destinations() } }
            AppTab.Bookings -> TabNavHost(controller, { BookingsTab(environment, R.string.tab_bookings) }) { with(catalog) { destinations() } }
            AppTab.Profile -> TabNavHost(controller, { ProfileScreen(environment) }) { with(catalog) { destinations() } }
        }
    }
}

/** The provider's tabs: the studio Home (ProviderStudio, coming next), Explore, Bookings, Profile. */
@Composable
fun ProviderShell(environment: AppEnvironment) {
    val catalog = environment.catalog
    TabShell(environment, bookingsTitle = R.string.tab_providerBookings) { tab, controller ->
        when (tab) {
            AppTab.Home -> TabNavHost(controller, {
                ComingSoonTab(l10n(R.string.tab_home), Icons.Outlined.Storefront, R.string.provider_home_comingSoon_title, R.string.provider_home_comingSoon_message)
            }) { with(catalog) { destinations() } }
            AppTab.Explore -> TabNavHost(controller, { catalog.ExploreScreen() }) { with(catalog) { destinations() } }
            AppTab.Bookings -> TabNavHost(controller, { BookingsTab(environment, R.string.tab_providerBookings) }) { with(catalog) { destinations() } }
            AppTab.Profile -> TabNavHost(controller, { ProfileScreen(environment) }) { with(catalog) { destinations() } }
        }
    }
}

/** One tab's navigation stack: its root screen plus the feature destinations it can push. */
@Composable
private fun TabNavHost(controller: NavHostController, root: @Composable () -> Unit, destinations: NavGraphBuilder.() -> Unit) {
    val navigator = remember(controller) { Navigator(navigate = { controller.navigate(it) }, back = { controller.popBackStack() }) }
    CompositionLocalProvider(LocalNavigator provides navigator) {
        NavHost(controller, startDestination = TabRoot) {
            composable<TabRoot> { root() }
            destinations()
        }
    }
}

@Composable
private fun TabShell(
    environment: AppEnvironment,
    bookingsTitle: Int,
    content: @Composable (AppTab, NavHostController) -> Unit,
) {
    var tab by rememberSaveable { mutableStateOf(AppTab.Home) }
    // One controller per tab, so each tab keeps its own stack (like a NavigationStack per tab).
    val controllers = AppTab.entries.associateWith { rememberNavController() }

    // Deep links: switch tab, then open the screen.
    val pending = environment.deepLink.pending
    LaunchedEffect(pending) {
        val home = controllers.getValue(AppTab.Home)
        when (pending) {
            null -> return@LaunchedEffect
            is DeepLink.Booking -> tab = AppTab.Bookings // detail arrives with the Booking feature
            is DeepLink.Provider -> { tab = AppTab.Home; home.navigate(ProviderRoute(pending.id)) }
            is DeepLink.Service -> { tab = AppTab.Home; home.navigate(ServiceRoute(pending.id)) }
            is DeepLink.Store -> { tab = AppTab.Home; home.navigate(StoreRoute(pending.id)) }
            is DeepLink.Category -> { tab = AppTab.Home; home.navigate(ServicesRoute(categoryId = pending.id)) }
            DeepLink.Plans, DeepLink.Notifications -> tab = AppTab.Home
        }
        environment.deepLink.pending = null
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
        Box(Modifier.fillMaxSize().padding(padding)) { content(tab, controllers.getValue(tab)) }
    }

    if (environment.session.isPickingCities) CityPickerDialog(environment) { environment.session.isPickingCities = false }
}

/** Placeholder for a tab whose feature module isn't ported yet. */
@Composable
private fun ComingSoonTab(title: String, icon: androidx.compose.ui.graphics.vector.ImageVector, titleRes: Int, messageRes: Int) {
    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        LargeHeaderBar(title, Modifier.statusBarsPadding())
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            EmptyStateView(icon = icon, title = l10n(titleRes), message = l10n(messageRes))
        }
    }
}

/** The bookings tab: the Booking feature's list for an account, a sign-in prompt for a guest. */
@Composable
private fun BookingsTab(environment: AppEnvironment, titleRes: Int) {
    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        LargeHeaderBar(l10n(titleRes), Modifier.statusBarsPadding())
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            if (environment.session.hasAccount) {
                EmptyStateView(
                    icon = Icons.Outlined.CalendarMonth,
                    title = l10n(titleRes),
                    message = l10n(R.string.provider_home_comingSoon_message),
                )
            } else {
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
}
