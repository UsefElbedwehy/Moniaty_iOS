package co.munyati.catalog.presentation

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Groups
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import co.munyati.catalog.R
import co.munyati.catalog.domain.ProviderProfile
import co.munyati.catalog.domain.ServiceDetail
import co.munyati.catalog.domain.StoreDetail
import co.munyati.core.error.AppError
import co.munyati.core.state.ViewState
import co.munyati.designsystem.components.DSTopBar
import co.munyati.designsystem.components.PrimaryButton
import co.munyati.designsystem.components.TopBarIconButton
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.analytics.AnalyticsEvent
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.images.RemoteImage
import co.munyati.shared.media.MediaGallery
import co.munyati.shared.links.MunyatiLinks
import co.munyati.shared.links.shareLink
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/** Loads a detail page: `Loaded`, `Empty` when the RPC says it doesn't exist, or `Error`. */
private suspend fun <T> loadDetail(fetch: suspend () -> T?): ViewState<T> = try {
    fetch()?.let { ViewState.Loaded(it) } ?: ViewState.Empty
} catch (e: CancellationException) {
    throw e
} catch (e: Exception) {
    ViewState.Error(AppError.from(e))
}

// Service detail

@OptIn(ExperimentalFoundationApi::class)
@Composable
internal fun ServiceDetailScreen(feature: CatalogFeature, serviceId: String) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var state: ViewState<ServiceDetail> by remember { mutableStateOf(ViewState.Loading) }
    var showComingSoon by remember { mutableStateOf(false) }

    suspend fun load() {
        state = loadDetail { feature.repository.service(serviceId) }
        state.value?.let { analytics(AnalyticsEvent.ServiceView, serviceId, it.provider.id, mapOf("category_id" to it.card.categoryId)) }
    }
    LaunchedEffect(serviceId) {
        analytics.screen("service_detail")
        load()
    }

    val detail = state.value
    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar("", navigator.back, stringResource(R.string.catalog_back)) {
            if (detail != null) {
                FavoriteButton(detail.card, feature)
                TopBarIconButton(Icons.Outlined.Share, stringResource(R.string.catalog_share)) {
                    analytics(AnalyticsEvent.ShareTap, detail.card.id, "service")
                    context.shareLink(MunyatiLinks.service(detail.card.id), detail.card.title)
                }
                feature.trustViews?.moreMenu?.invoke(CatalogContentRef.Service(detail.card.id))
            }
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
            LoadableContent(
                state,
                retry = { scope.launch { load() } },
                emptyTitle = R.string.catalog_detail_missing_title,
                emptyMessage = R.string.catalog_detail_missing_message,
            ) { ServiceContent(feature, it) }
        }
        if (detail != null) {
            BookBar(detail, canBook = feature.context.canBook) {
                analytics(AnalyticsEvent.BookingStarted, detail.card.id)
                feature.onBook?.invoke(detail.card) ?: run { showComingSoon = true }
            }
        }
    }

    if (showComingSoon) {
        AlertDialog(
            onDismissRequest = { showComingSoon = false },
            title = { Text(stringResource(R.string.catalog_book_comingSoon_title)) },
            text = { Text(stringResource(R.string.catalog_book_comingSoon_message)) },
            confirmButton = { TextButton(onClick = { showComingSoon = false }) { Text(stringResource(R.string.catalog_common_ok)) } },
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ServiceContent(feature: CatalogFeature, detail: ServiceDetail) {
    val navigator = LocalNavigator.current
    // Full width at the top, like Lamha Ads; the rest keeps the page margins.
    Column {
        MediaGallery(detail.galleryItems)
        Column(Modifier.padding(DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.lg)) {
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                Text(detail.card.title, style = DS.type.title1, color = DS.colors.textPrimary)
                Text(formatSar(detail.card.price), style = DS.type.title2, color = DS.colors.primary)
            }
            ProviderRow(detail.provider) { navigator.navigate(ProviderRoute(detail.provider.id)) }
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                detail.durationMinutes?.let { InfoRow(Icons.Outlined.Schedule, durationText(it), null) }
                if (detail.atCustomerLocation) InfoRow(Icons.Outlined.Home, stringResource(R.string.catalog_detail_atLocation), null)
                if (detail.card.femaleStaffOnly) InfoRow(Icons.Outlined.Groups, stringResource(R.string.catalog_detail_femaleOnly), null)
            }
            if (!detail.description.isNullOrEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                    Text(stringResource(R.string.catalog_detail_about), style = DS.type.headline, color = DS.colors.textPrimary)
                    Text(detail.description, style = DS.type.body, color = DS.colors.textSecondary)
                }
            }
            detail.store?.let { store ->
                InfoRow(Icons.Outlined.Storefront, store.name, store.address) { navigator.navigate(StoreRoute(store.id)) }
            }
            ServiceCarousel(stringResource(R.string.catalog_detail_moreFromProvider), detail.moreFromProvider, feature)
        }
    }
}

@Composable
private fun BookBar(detail: ServiceDetail, canBook: Boolean, onBook: () -> Unit) {
    Column(Modifier.background(DS.colors.surface)) {
        HorizontalDivider(color = DS.colors.border)
        Row(
            Modifier.fillMaxWidth().padding(horizontal = DSSpacing.lg, vertical = DSSpacing.sm),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DSSpacing.md),
        ) {
            // The price is already under the title; at the largest sizes the button needs the room.
            if (!isLargeText()) {
                Column {
                    Text(stringResource(R.string.catalog_detail_price), style = DS.type.caption, color = DS.colors.textSecondary)
                    Text(formatSar(detail.card.price), style = DS.type.headline, color = DS.colors.textPrimary)
                }
            }
            if (detail.isOwn || !canBook) {
                Text(
                    stringResource(if (detail.isOwn) R.string.catalog_book_ownService else R.string.catalog_book_providerAccount),
                    style = DS.type.footnote, color = DS.colors.textSecondary, modifier = Modifier.weight(1f),
                )
            } else {
                PrimaryButton(stringResource(R.string.catalog_book_cta), modifier = Modifier.weight(1f), onClick = onBook)
            }
        }
    }
}

// Provider profile

@Composable
internal fun ProviderScreen(feature: CatalogFeature, providerId: String) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var state: ViewState<ProviderProfile> by remember { mutableStateOf(ViewState.Loading) }

    suspend fun load() {
        state = loadDetail { feature.repository.provider(providerId) }
        if (state is ViewState.Loaded) analytics(AnalyticsEvent.ProviderView, providerId)
    }
    LaunchedEffect(providerId) {
        analytics.screen("provider_profile")
        load()
    }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(state.value?.summary?.name.orEmpty(), navigator.back, stringResource(R.string.catalog_back)) {
            TopBarIconButton(Icons.Outlined.Share, stringResource(R.string.catalog_share)) {
                analytics(AnalyticsEvent.ShareTap, providerId, "provider")
                context.shareLink(MunyatiLinks.provider(providerId), state.value?.summary?.name)
            }
            feature.trustViews?.moreMenu?.invoke(CatalogContentRef.Provider(providerId))
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            LoadableContent(
                state,
                retry = { scope.launch { load() } },
                emptyTitle = R.string.catalog_detail_missing_title,
                emptyMessage = R.string.catalog_detail_missing_message,
            ) { profile ->
                Column(Modifier.padding(DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.lg)) {
                    Box(Modifier.fillMaxWidth().padding(bottom = 36.dp)) {
                        RemoteImage(
                            profile.coverUrl,
                            Modifier.fillMaxWidth().height(160.dp).clip(RoundedCornerShape(DSRadius.card)),
                            placeholder = DS.colors.primaryMuted,
                        )
                        Box(Modifier.align(Alignment.BottomStart).offset(x = DSSpacing.lg, y = 36.dp)) {
                            ProviderAvatar(profile.summary.logoUrl, profile.summary.name, 72.dp)
                        }
                    }
                    ProviderRow(profile.summary, showsChevron = false)
                    if (!profile.bio.isNullOrEmpty()) Text(profile.bio, style = DS.type.body, color = DS.colors.textSecondary)
                    if (!profile.address.isNullOrEmpty()) InfoRow(Icons.Outlined.LocationOn, profile.address, null)
                    if (profile.stores.isNotEmpty()) {
                        Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                            Text(stringResource(R.string.catalog_detail_stores), style = DS.type.title2, color = DS.colors.textPrimary)
                            profile.stores.forEach { store ->
                                InfoRow(Icons.Outlined.Storefront, store.name, store.address) { navigator.navigate(StoreRoute(store.id)) }
                            }
                        }
                    }
                    Text(stringResource(R.string.catalog_detail_services), style = DS.type.title2, color = DS.colors.textPrimary)
                    ServiceGrid(profile.services, feature)
                    feature.trustViews?.reviews?.invoke(providerId)
                }
            }
        }
    }
}

// Store

@Composable
internal fun StoreScreen(feature: CatalogFeature, storeId: String) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var state: ViewState<StoreDetail> by remember { mutableStateOf(ViewState.Loading) }

    suspend fun load() {
        state = loadDetail { feature.repository.store(storeId) }
        if (state is ViewState.Loaded) analytics(AnalyticsEvent.StoreView, storeId)
    }
    LaunchedEffect(storeId) {
        analytics.screen("store")
        load()
    }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar("", navigator.back, stringResource(R.string.catalog_back)) {
            feature.trustViews?.moreMenu?.invoke(CatalogContentRef.Store(storeId))
            TopBarIconButton(Icons.Outlined.Share, stringResource(R.string.catalog_share)) {
                context.shareLink(MunyatiLinks.store(storeId), state.value?.summary?.name)
            }
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            LoadableContent(
                state,
                retry = { scope.launch { load() } },
                emptyTitle = R.string.catalog_detail_missing_title,
                emptyMessage = R.string.catalog_detail_missing_message,
            ) { store ->
                Column(Modifier.padding(DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.lg)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.md), verticalAlignment = Alignment.CenterVertically) {
                        ProviderAvatar(store.summary.logoUrl, store.summary.name, 64.dp)
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(store.summary.name, style = DS.type.title1, color = DS.colors.textPrimary)
                            store.summary.address?.let { Text(it, style = DS.type.footnote, color = DS.colors.textSecondary) }
                        }
                    }
                    if (!store.description.isNullOrEmpty()) Text(store.description, style = DS.type.body, color = DS.colors.textSecondary)
                    ProviderRow(store.provider) { navigator.navigate(ProviderRoute(store.provider.id)) }
                    ServiceGrid(store.services, feature)
                }
            }
        }
    }
}
