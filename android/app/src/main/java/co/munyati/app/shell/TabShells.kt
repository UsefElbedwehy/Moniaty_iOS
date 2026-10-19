package co.munyati.app.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Map
import androidx.compose.material.icons.outlined.PersonAddAlt
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import co.munyati.app.R
import co.munyati.app.composition.AppEnvironment
import co.munyati.app.composition.DeepLink
import co.munyati.app.composition.l10n
import co.munyati.designsystem.components.EmptyStateView
import co.munyati.designsystem.components.LargeHeaderBar
import co.munyati.designsystem.theme.DS

/** The four tabs (`docs/PLAN.md` §3), the same for both roles; only the content differs. */
enum class AppTab { Home, Explore, Bookings, Profile }

@Composable
fun BrideShell(environment: AppEnvironment) = TabShell(environment, bookingsTitle = R.string.tab_bookings) { tab ->
    when (tab) {
        AppTab.Home -> ComingSoonTab(l10n(R.string.tab_home), Icons.Outlined.AutoAwesome, R.string.home_comingSoon_title, R.string.home_comingSoon_message)
        AppTab.Explore -> ComingSoonTab(l10n(R.string.tab_explore), Icons.Outlined.Map, R.string.tab_explore, R.string.explore_comingSoon)
        AppTab.Bookings -> BookingsTab(environment, R.string.tab_bookings)
        AppTab.Profile -> ProfileScreen(environment)
    }
}

@Composable
fun ProviderShell(environment: AppEnvironment) = TabShell(environment, bookingsTitle = R.string.tab_providerBookings) { tab ->
    when (tab) {
        AppTab.Home -> ComingSoonTab(l10n(R.string.tab_home), Icons.Outlined.Storefront, R.string.provider_home_comingSoon_title, R.string.provider_home_comingSoon_message)
        AppTab.Explore -> ComingSoonTab(l10n(R.string.tab_explore), Icons.Outlined.Map, R.string.tab_explore, R.string.explore_comingSoon)
        AppTab.Bookings -> BookingsTab(environment, R.string.tab_providerBookings)
        AppTab.Profile -> ProfileScreen(environment)
    }
}

@Composable
private fun TabShell(environment: AppEnvironment, bookingsTitle: Int, content: @Composable (AppTab) -> Unit) {
    var tab by rememberSaveable { mutableStateOf(AppTab.Home) }

    // Deep links: switch to the right tab. Detail screens arrive with the Catalog/Booking features.
    val pending = environment.deepLink.pending
    LaunchedEffect(pending) {
        when (pending) {
            null -> return@LaunchedEffect
            is DeepLink.Booking -> tab = AppTab.Bookings
            else -> tab = AppTab.Home
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
        bottomBar = {
            NavigationBar(containerColor = DS.colors.surface) {
                items.forEach { (item, title, icon) ->
                    NavigationBarItem(
                        selected = tab == item,
                        onClick = { tab = item },
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
        Box(Modifier.fillMaxSize().padding(padding)) { content(tab) }
    }
}

/** Placeholder for a tab whose feature module isn't ported yet. */
@Composable
private fun ComingSoonTab(title: String, icon: ImageVector, titleRes: Int, messageRes: Int) {
    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        LargeHeaderBar(title)
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            EmptyStateView(icon = icon, title = l10n(titleRes), message = l10n(messageRes))
        }
    }
}

/** The bookings tab: the Booking feature's list for an account, a sign-in prompt for a guest. */
@Composable
private fun BookingsTab(environment: AppEnvironment, titleRes: Int) {
    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        LargeHeaderBar(l10n(titleRes))
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
