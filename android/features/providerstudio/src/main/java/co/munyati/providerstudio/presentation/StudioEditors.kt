package co.munyati.providerstudio.presentation

import co.munyati.shared.media.VideoLimits
import co.munyati.shared.media.GalleryTile
import co.munyati.shared.media.GalleryItem
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberSwipeToDismissBoxState
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import co.munyati.catalog.domain.formatAmount
import co.munyati.designsystem.components.DSFormDivider
import co.munyati.designsystem.components.DSFormSection
import co.munyati.designsystem.components.DSNavRow
import co.munyati.designsystem.components.DSPickerRow
import co.munyati.designsystem.components.DSTextFieldRow
import co.munyati.designsystem.components.DSToggleRow
import co.munyati.designsystem.components.DSTopBar
import co.munyati.designsystem.components.EmptyStateView
import co.munyati.designsystem.components.StatusBadge
import co.munyati.designsystem.components.StatusBadgeKind
import co.munyati.designsystem.components.TopBarIconButton
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.providerstudio.R
import co.munyati.providerstudio.domain.BusinessDraft
import co.munyati.providerstudio.domain.MyService
import co.munyati.providerstudio.domain.SaveResult
import co.munyati.providerstudio.domain.ServiceDraft
import co.munyati.providerstudio.domain.StoreDraft
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.images.RemoteImage
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/** "SAR 250" with this module's price format. */
@Composable
internal fun formatSar(amount: Double) = stringResource(co.munyati.catalog.R.string.catalog_price_sar, formatAmount(amount))

/** A pushed form screen: back arrow, title, a Save action, and a scrolling column of sections. */
@Composable
private fun FormScreen(
    title: String,
    canSave: Boolean,
    onSave: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    val navigator = LocalNavigator.current
    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(title, navigator.back, stringResource(R.string.studio_back)) {
            TextButton(onClick = onSave, enabled = canSave) {
                Text(stringResource(R.string.studio_common_save), style = DS.type.headline, color = if (canSave) DS.colors.primary else DS.colors.disabled)
            }
        }
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.lg),
            content = content,
        )
    }
}

@Composable
private fun MessageDialog(message: String?, onDismiss: () -> Unit) {
    if (message == null) return
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(message) },
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.studio_common_ok)) } },
    )
}

// Business profile (the join form, decision #6)

@Composable
internal fun BusinessEditScreen(feature: StudioFeature) {
    val store = feature.store
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    val business = store.business ?: return
    var draft by remember { mutableStateOf(BusinessDraft(business)) }
    var isSaving by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var picking by remember { mutableStateOf<String?>(null) } // "categories" | "cities"
    val saveFailed = stringResource(R.string.studio_common_saveFailed)
    LaunchedEffect(Unit) { analytics.screen("studio_business") }

    FormScreen(stringResource(R.string.studio_studio_business), draft.isValid && !isSaving, onSave = {
        isSaving = true
        scope.launch {
            try {
                store.repository.updateBusiness(draft)
                store.reload()
                navigator.back()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                message = saveFailed
            } finally {
                isSaving = false
            }
        }
    }) {
        DSFormSection(stringResource(R.string.studio_business_section_identity)) {
            DSTextFieldRow(draft.businessName, { draft = draft.copy(businessName = it) }, stringResource(R.string.studio_business_name))
            DSFormDivider()
            DSTextFieldRow(draft.bio, { draft = draft.copy(bio = it) }, stringResource(R.string.studio_business_bio), minLines = 3)
            DSFormDivider()
            Row(Modifier.padding(horizontal = DSSpacing.md, vertical = DSSpacing.xs), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
                RemoteImage(draft.logoUrl, thumbnail = true, modifier = Modifier.size(56.dp).clip(CircleShape), placeholder = DS.colors.primaryMuted)
                PhotoUploadButton(feature.uploader, "logos", 1) { draft = draft.copy(logoUrl = it.first()) }
            }
            DSFormDivider()
            DSToggleRow(stringResource(R.string.studio_business_femaleOnly), draft.femaleStaffOnly) { draft = draft.copy(femaleStaffOnly = it) }
        }

        DSFormSection(stringResource(R.string.studio_business_section_coverage)) {
            DSNavRow(stringResource(R.string.studio_business_categories), draft.categoryIds.map(store::categoryName).sorted().joinToString("، ")) { picking = "categories" }
            DSFormDivider()
            DSNavRow(stringResource(R.string.studio_business_cities), draft.cityIds.map(store::cityName).sorted().joinToString("، ")) { picking = "cities" }
        }

        DSFormSection(stringResource(R.string.studio_business_section_location), footer = stringResource(R.string.studio_location_hint)) {
            DSTextFieldRow(draft.address, { draft = draft.copy(address = it) }, stringResource(R.string.studio_business_address))
            DSFormDivider()
            val none = stringResource(R.string.studio_none)
            DSPickerRow(stringResource(R.string.studio_business_city), listOf<String?>(null) + store.cities.map { it.id }, draft.cityId,
                label = { id -> id?.let(store::cityName) ?: none }) { draft = draft.copy(cityId = it) }
            LocationPicker(draft.lat, draft.lng, feature.mapsAvailable) { lat, lng -> draft = draft.copy(lat = lat, lng = lng) }
        }

        DSFormSection(stringResource(R.string.studio_business_section_verification), footer = stringResource(R.string.studio_business_verification_footer)) {
            DSTextFieldRow(draft.crNumber, { draft = draft.copy(crNumber = it) }, stringResource(R.string.studio_business_cr), keyboardType = KeyboardType.Number)
            DSFormDivider()
            DSTextFieldRow(draft.freelanceDocNumber, { draft = draft.copy(freelanceDocNumber = it) }, stringResource(R.string.studio_business_freelance), keyboardType = KeyboardType.Number)
            DSFormDivider()
            DSTextFieldRow(draft.instagram, { draft = draft.copy(instagram = it) }, stringResource(R.string.studio_business_instagram), keyboardType = KeyboardType.Uri)
        }
    }

    when (picking) {
        "categories" -> MultiSelectDialog(stringResource(R.string.studio_business_categories), store.categories.map { it.id to it.name }, draft.categoryIds) {
            draft = draft.copy(categoryIds = it); picking = null
        }
        "cities" -> MultiSelectDialog(stringResource(R.string.studio_business_cities), store.cities.map { it.id to it.name() }, draft.cityIds) {
            draft = draft.copy(cityIds = it); picking = null
        }
    }
    MessageDialog(message) { message = null }
}

// Services

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ServicesListScreen(feature: StudioFeature) {
    val store = feature.store
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var deleteFailed by remember { mutableStateOf(false) }
    val business = store.business
    LaunchedEffect(Unit) { analytics.screen("studio_services") }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.studio_studio_services), navigator.back, stringResource(R.string.studio_back)) {
            TopBarIconButton(Icons.Filled.Add, stringResource(R.string.studio_services_add)) { navigator.navigate(ServiceEditRoute()) }
        }
        if (business == null) return@Column
        if (business.services.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                EmptyStateView(Icons.Outlined.AutoAwesome, stringResource(R.string.studio_services_empty_title), stringResource(R.string.studio_services_empty_message),
                    actionTitle = stringResource(R.string.studio_services_add)) { navigator.navigate(ServiceEditRoute()) }
            }
            return@Column
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg)) {
            DSFormSection(footer = stringResource(R.string.studio_studio_services_count, business.activeServiceCount, business.limits.maxServices)) {
                business.services.forEachIndexed { index, service ->
                    if (index > 0) DSFormDivider()
                    SwipeToDelete(onDelete = {
                        scope.launch {
                            runCatching { store.repository.deleteService(service.id) }.onFailure { deleteFailed = true }
                            store.reload()
                        }
                    }) { ServiceRow(store, service) { navigator.navigate(ServiceEditRoute(service.id)) } }
                }
            }
        }
    }
    MessageDialog(if (deleteFailed) stringResource(R.string.studio_common_saveFailed) else null) { deleteFailed = false }
}

@Composable
private fun ServiceRow(store: StudioStore, service: MyService, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().background(DS.colors.surface).clickable(onClick = onClick).padding(horizontal = DSSpacing.md, vertical = DSSpacing.sm),
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RemoteImage(service.imageUrls.firstOrNull(), thumbnail = true, modifier = Modifier.size(52.dp).clip(RoundedCornerShape(12.dp)), placeholder = DS.colors.primaryMuted)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(service.title, style = DS.type.headline, color = DS.colors.textPrimary)
            Text("${store.categoryName(service.categoryId)} · ${formatSar(service.price)}", style = DS.type.footnote, color = DS.colors.textSecondary)
        }
        if (service.status == MyService.Status.Paused) StatusBadge(StatusBadgeKind.Pending, stringResource(R.string.studio_service_paused))
    }
}

/** Swipe a row toward the start to delete it, after a confirmation (iOS swipe-to-delete). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeToDelete(onDelete: () -> Unit, content: @Composable () -> Unit) {
    var confirm by remember { mutableStateOf(false) }
    val state = rememberSwipeToDismissBoxState(confirmValueChange = {
        if (it == SwipeToDismissBoxValue.EndToStart) confirm = true
        false
    })
    SwipeToDismissBox(
        state = state,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            Box(Modifier.fillMaxSize().background(DS.colors.error).padding(horizontal = DSSpacing.lg), contentAlignment = Alignment.CenterEnd) {
                Text(stringResource(R.string.studio_delete), style = DS.type.headline, color = androidx.compose.ui.graphics.Color.White)
            }
        },
    ) { content() }
    if (confirm) {
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text(stringResource(R.string.studio_delete_confirm)) },
            confirmButton = { TextButton(onClick = { confirm = false; onDelete() }) { Text(stringResource(R.string.studio_delete), color = DS.colors.error) } },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text(stringResource(R.string.studio_common_cancel)) } },
        )
    }
}

private val durations = listOf(30, 60, 90, 120, 180, 240, 360, 480)

@Composable
internal fun ServiceEditScreen(feature: StudioFeature, serviceId: String?) {
    val store = feature.store
    val navigator = LocalNavigator.current
    val scope = rememberCoroutineScope()
    var draft by remember {
        mutableStateOf(
            store.business?.services?.firstOrNull { it.id == serviceId }?.let(::ServiceDraft)
                // New services default to the provider's first category.
                ?: ServiceDraft(categoryId = store.business?.categoryIds?.firstOrNull()),
        )
    }
    var isSaving by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    val maxPhotos = store.business?.limits?.maxPhotos ?: 10
    val none = stringResource(R.string.studio_none)
    val saveFailed = stringResource(R.string.studio_common_saveFailed)
    val context = LocalContext.current

    FormScreen(stringResource(if (draft.id == null) R.string.studio_services_add else R.string.studio_services_edit), draft.isValid && !isSaving, onSave = {
        isSaving = true
        scope.launch {
            try {
                when (val result = store.repository.saveService(draft)) {
                    is SaveResult.Saved -> { store.reload(); navigator.back() }
                    is SaveResult.LimitReached -> navigator.navigate(PlansRoute(context.getString(R.string.studio_limit_services, result.max)))
                    SaveResult.InvalidMedia -> message = context.getString(R.string.studio_save_invalidMedia)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                message = saveFailed
            } finally {
                isSaving = false
            }
        }
    }) {
        DSFormSection {
            DSTextFieldRow(draft.title, { draft = draft.copy(title = it) }, stringResource(R.string.studio_service_title))
            DSFormDivider()
            DSPickerRow(stringResource(R.string.studio_service_category), listOf<String?>(null) + store.categories.map { it.id }, draft.categoryId,
                label = { id -> id?.let(store::categoryName) ?: none }) { draft = draft.copy(categoryId = it) }
            DSFormDivider()
            DSTextFieldRow(draft.priceText, { draft = draft.copy(priceText = it) }, stringResource(R.string.studio_service_price), keyboardType = KeyboardType.Decimal)
            DSFormDivider()
            DSPickerRow(stringResource(R.string.studio_service_duration), listOf<Int?>(null) + durations, draft.durationMinutes,
                label = { it?.let(::durationLabel) ?: none }) { draft = draft.copy(durationMinutes = it) }
            DSFormDivider()
            DSTextFieldRow(draft.description, { draft = draft.copy(description = it) }, stringResource(R.string.studio_service_description), minLines = 3)
        }

        DSFormSection(stringResource(R.string.studio_service_section_photos)) {
            if (draft.imageUrls.isNotEmpty()) {
                Row(Modifier.horizontalScroll(rememberScrollState()).padding(DSSpacing.sm), horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                    draft.imageUrls.forEach { url ->
                        Box(Modifier.size(84.dp)) {
                            RemoteImage(url, thumbnail = true, modifier = Modifier.size(84.dp).clip(RoundedCornerShape(12.dp)), placeholder = DS.colors.primaryMuted)
                            Icon(
                                Icons.Filled.Cancel, contentDescription = stringResource(R.string.studio_photo_remove), tint = DS.colors.primary,
                                modifier = Modifier.align(Alignment.TopEnd).padding(2.dp).background(DS.colors.surface, CircleShape)
                                    .clickable { draft = draft.copy(imageUrls = draft.imageUrls - url) },
                            )
                        }
                    }
                }
            }
            Box(Modifier.padding(horizontal = DSSpacing.xs, vertical = DSSpacing.xxs)) {
                if (draft.imageUrls.size < maxPhotos) {
                    PhotoUploadButton(feature.uploader, "services", maxPhotos - draft.imageUrls.size) { draft = draft.copy(imageUrls = draft.imageUrls + it) }
                } else {
                    Text(stringResource(R.string.studio_limit_photos, maxPhotos), style = DS.type.footnote, color = DS.colors.textSecondary, modifier = Modifier.padding(DSSpacing.sm))
                }
            }
        }

        DSFormSection(
            stringResource(R.string.studio_service_section_videos),
            footer = stringResource(R.string.studio_service_videos_footer, VideoLimits.PER_SERVICE, VideoLimits.MAX_SECONDS),
        ) {
            if (draft.videos.isNotEmpty()) {
                Row(Modifier.horizontalScroll(rememberScrollState()).padding(DSSpacing.sm), horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                    draft.videos.forEach { video ->
                        Box(Modifier.size(84.dp)) {
                            GalleryTile(GalleryItem.Video(video), playSize = 30.dp, modifier = Modifier.size(84.dp).clip(RoundedCornerShape(12.dp)))
                            Icon(
                                Icons.Filled.Cancel, contentDescription = stringResource(R.string.studio_video_remove), tint = DS.colors.primary,
                                modifier = Modifier.align(Alignment.TopEnd).padding(2.dp).background(DS.colors.surface, CircleShape)
                                    .clickable { draft = draft.copy(videos = draft.videos.filter { it.url != video.url }) },
                            )
                        }
                    }
                }
            }
            if (draft.videos.size < VideoLimits.PER_SERVICE) {
                Box(Modifier.padding(horizontal = DSSpacing.xs, vertical = DSSpacing.xxs)) {
                    VideoUploadButton(feature.uploader, "services") { draft = draft.copy(videos = draft.videos + it) }
                }
            }
        }

        DSFormSection(footer = stringResource(R.string.studio_service_active_footer)) {
            DSToggleRow(stringResource(R.string.studio_service_femaleOnly), draft.femaleStaffOnly) { draft = draft.copy(femaleStaffOnly = it) }
            DSFormDivider()
            DSToggleRow(stringResource(R.string.studio_service_atLocation), draft.atCustomerLocation) { draft = draft.copy(atCustomerLocation = it) }
            val stores = store.business?.stores.orEmpty()
            if (stores.isNotEmpty()) {
                DSFormDivider()
                DSPickerRow(stringResource(R.string.studio_service_store), listOf<String?>(null) + stores.map { it.id }, draft.storeId,
                    label = { id -> stores.firstOrNull { it.id == id }?.name ?: none }) { draft = draft.copy(storeId = it) }
            }
            DSFormDivider()
            DSToggleRow(stringResource(R.string.studio_service_active), draft.isActive) { draft = draft.copy(isActive = it) }
        }
    }
    MessageDialog(message) { message = null }
}

// Stores (requirement 14)

@Composable
internal fun StoresListScreen(feature: StudioFeature) {
    val store = feature.store
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var deleteFailed by remember { mutableStateOf(false) }
    val business = store.business
    LaunchedEffect(Unit) { analytics.screen("studio_stores") }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.studio_studio_stores), navigator.back, stringResource(R.string.studio_back)) {
            TopBarIconButton(Icons.Filled.Add, stringResource(R.string.studio_stores_add)) { navigator.navigate(StoreEditRoute()) }
        }
        if (business == null) return@Column
        if (business.stores.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                EmptyStateView(Icons.Outlined.Storefront, stringResource(R.string.studio_stores_empty_title), stringResource(R.string.studio_stores_empty_message),
                    actionTitle = stringResource(R.string.studio_stores_add)) { navigator.navigate(StoreEditRoute()) }
            }
            return@Column
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg)) {
            DSFormSection(footer = stringResource(R.string.studio_studio_stores_count, business.stores.size, business.limits.maxStores)) {
                business.stores.forEachIndexed { index, item ->
                    if (index > 0) DSFormDivider()
                    SwipeToDelete(onDelete = {
                        scope.launch {
                            runCatching { store.repository.deleteStore(item.id) }.onFailure { deleteFailed = true }
                            store.reload()
                        }
                    }) {
                        Row(
                            Modifier.fillMaxWidth().background(DS.colors.surface).clickable { navigator.navigate(StoreEditRoute(item.id)) }
                                .padding(horizontal = DSSpacing.md, vertical = DSSpacing.sm),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(item.name, style = DS.type.headline, color = DS.colors.textPrimary)
                                Text(item.address.orEmpty(), style = DS.type.footnote, color = DS.colors.textSecondary)
                            }
                            if (!item.isActive) StatusBadge(StatusBadgeKind.Pending, stringResource(R.string.studio_store_hidden))
                        }
                    }
                }
            }
        }
    }
    MessageDialog(if (deleteFailed) stringResource(R.string.studio_common_saveFailed) else null) { deleteFailed = false }
}

@Composable
internal fun StoreEditScreen(feature: StudioFeature, storeId: String?) {
    val store = feature.store
    val navigator = LocalNavigator.current
    val scope = rememberCoroutineScope()
    var draft by remember { mutableStateOf(store.business?.stores?.firstOrNull { it.id == storeId }?.let(::StoreDraft) ?: StoreDraft()) }
    var isSaving by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    val none = stringResource(R.string.studio_none)
    val saveFailed = stringResource(R.string.studio_common_saveFailed)
    val context = LocalContext.current

    FormScreen(stringResource(if (draft.id == null) R.string.studio_stores_add else R.string.studio_stores_edit), draft.isValid && !isSaving, onSave = {
        isSaving = true
        scope.launch {
            try {
                when (val result = store.repository.saveStore(draft)) {
                    is SaveResult.Saved -> { store.reload(); navigator.back() }
                    is SaveResult.LimitReached -> navigator.navigate(PlansRoute(context.getString(R.string.studio_limit_stores, result.max)))
                    SaveResult.InvalidMedia -> message = saveFailed
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                message = saveFailed
            } finally {
                isSaving = false
            }
        }
    }) {
        DSFormSection {
            DSTextFieldRow(draft.name, { draft = draft.copy(name = it) }, stringResource(R.string.studio_store_name))
            DSFormDivider()
            DSTextFieldRow(draft.description, { draft = draft.copy(description = it) }, stringResource(R.string.studio_store_description), minLines = 2)
            DSFormDivider()
            Row(Modifier.padding(horizontal = DSSpacing.md, vertical = DSSpacing.xs), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
                RemoteImage(draft.logoUrl, thumbnail = true, modifier = Modifier.size(56.dp).clip(RoundedCornerShape(12.dp)), placeholder = DS.colors.primaryMuted)
                PhotoUploadButton(feature.uploader, "stores", 1) { draft = draft.copy(logoUrl = it.first()) }
            }
            DSFormDivider()
            DSTextFieldRow(draft.instagram, { draft = draft.copy(instagram = it) }, stringResource(R.string.studio_business_instagram), keyboardType = KeyboardType.Uri)
        }
        DSFormSection(stringResource(R.string.studio_business_section_location), footer = stringResource(R.string.studio_location_hint)) {
            DSTextFieldRow(draft.address, { draft = draft.copy(address = it) }, stringResource(R.string.studio_business_address))
            DSFormDivider()
            DSPickerRow(stringResource(R.string.studio_business_city), listOf<String?>(null) + store.cities.map { it.id }, draft.cityId,
                label = { id -> id?.let(store::cityName) ?: none }) { draft = draft.copy(cityId = it) }
            LocationPicker(draft.lat, draft.lng, feature.mapsAvailable) { lat, lng -> draft = draft.copy(lat = lat, lng = lng) }
        }
        DSFormSection {
            DSToggleRow(stringResource(R.string.studio_store_visible), draft.isActive) { draft = draft.copy(isActive = it) }
        }
    }
    MessageDialog(message) { message = null }
}
