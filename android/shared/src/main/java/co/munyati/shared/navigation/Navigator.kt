package co.munyati.shared.navigation

import androidx.compose.runtime.staticCompositionLocalOf

/**
 * How a feature screen moves inside the tab it lives in, without knowing the tab's NavHost: the App
 * provides one per tab. Routes are each feature's `@Serializable` route objects (like iOS pushing
 * a `CatalogRoute` value onto the tab's NavigationStack).
 */
class Navigator(val navigate: (route: Any) -> Unit, val back: () -> Unit)

val LocalNavigator = staticCompositionLocalOf { Navigator(navigate = {}, back = {}) }
