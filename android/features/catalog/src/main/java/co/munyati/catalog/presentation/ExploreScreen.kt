package co.munyati.catalog.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material.icons.outlined.Map
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import co.munyati.catalog.R
import co.munyati.catalog.domain.CatalogCategory
import co.munyati.catalog.domain.MapPin
import co.munyati.designsystem.components.Chip
import co.munyati.designsystem.components.EmptyStateView
import co.munyati.designsystem.components.LargeHeaderBar
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.navigation.LocalNavigator
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.MarkerComposable
import com.google.maps.android.compose.rememberCameraPositionState
import com.google.maps.android.compose.rememberMarkerState
import kotlinx.coroutines.flow.filter

/** Dammam–Khobar–Qatif, the launch area. */
private val launchArea = LatLng(26.35, 50.12)

/**
 * Explore tab: providers and stores on a map (`docs/PLAN.md` §3, §4.10). Pins load for the visible
 * region whenever the camera settles; a category filter narrows them. Google Maps here, MapKit on iOS.
 */
@Composable
internal fun ExploreScreen(feature: CatalogFeature) {
    val analytics = LocalAnalytics.current
    var categories by remember { mutableStateOf(emptyList<CatalogCategory>()) }
    var categoryId by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        analytics.screen("explore")
        runCatching { feature.repository.home(null, null) }.getOrNull()?.let { categories = it.categories }
    }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        LargeHeaderBar(stringResource(R.string.catalog_explore_title), Modifier.statusBarsPadding())
        Row(
            Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = DSSpacing.md, vertical = DSSpacing.xs),
            horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
        ) {
            Chip(stringResource(R.string.catalog_explore_all), categoryId == null) { categoryId = null }
            categories.forEach { category -> Chip(category.name, categoryId == category.id) { categoryId = category.id } }
        }
        if (feature.mapsAvailable) {
            PinsMap(feature, categoryId)
        } else {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                EmptyStateView(
                    Icons.Outlined.Map,
                    stringResource(R.string.catalog_explore_mapUnavailable_title),
                    stringResource(R.string.catalog_explore_mapUnavailable_message),
                )
            }
        }
    }
}

@Composable
private fun PinsMap(feature: CatalogFeature, categoryId: String?) {
    val navigator = LocalNavigator.current
    val camera = rememberCameraPositionState { position = CameraPosition.fromLatLngZoom(launchArea, 10.3f) }
    var bounds by remember { mutableStateOf<LatLngBounds?>(null) }
    var pins by remember { mutableStateOf(emptyList<MapPin>()) }

    // The visible region, each time the camera settles.
    LaunchedEffect(camera) {
        snapshotFlow { camera.isMoving }.filter { !it }.collect {
            bounds = camera.projection?.visibleRegion?.latLngBounds
        }
    }
    LaunchedEffect(bounds, categoryId, feature.context.cityIds) {
        val b = bounds ?: LatLngBounds(LatLng(26.125, 49.895), LatLng(26.575, 50.345))
        runCatching {
            feature.repository.mapPins(b.southwest.latitude, b.southwest.longitude, b.northeast.latitude, b.northeast.longitude, feature.context.cityIds, categoryId)
        }.getOrNull()?.let { pins = it }
    }

    GoogleMap(
        modifier = Modifier.fillMaxSize(),
        cameraPositionState = camera,
        uiSettings = MapUiSettings(zoomControlsEnabled = false, mapToolbarEnabled = false, compassEnabled = true),
    ) {
        pins.forEach { pin ->
            key(pin.kind + pin.id) {
                MarkerComposable(
                    state = rememberMarkerState(position = LatLng(pin.lat, pin.lng)),
                    title = pin.name,
                    onClick = {
                        navigator.navigate(if (pin.kind == "store") StoreRoute(pin.id) else ProviderRoute(pin.id))
                        true
                    },
                ) {
                    Box(
                        Modifier.size(36.dp).clip(CircleShape).background(DS.colors.primary).border(2.dp, DS.colors.background, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(if (pin.kind == "store") Icons.Filled.Storefront else Icons.Filled.AutoAwesome, contentDescription = pin.name, tint = DS.colors.premiumGold, modifier = Modifier.size(16.dp))
                    }
                }
            }
        }
    }
}

@Composable
private inline fun key(value: Any, content: @Composable () -> Unit) = androidx.compose.runtime.key(value) { content() }
