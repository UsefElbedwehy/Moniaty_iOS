package co.munyati.catalog.presentation

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Sell
import androidx.compose.material.icons.outlined.Checkroom
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import co.munyati.catalog.R
import co.munyati.catalog.domain.DressListing
import co.munyati.catalog.domain.DressListingsPage
import co.munyati.catalog.domain.DressNotice
import co.munyati.core.error.AppError
import co.munyati.designsystem.components.DSTopBar
import co.munyati.designsystem.components.EmptyStateView
import co.munyati.designsystem.components.ErrorStateView
import co.munyati.designsystem.components.PrimaryButton
import co.munyati.designsystem.components.SecondaryButton
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSGradient
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.images.RemoteImage
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

private val kindLabels = mapOf(
    "wedding" to R.string.catalog_dresses_kind_wedding,
    "jalwa" to R.string.catalog_dresses_kind_jalwa,
    "evening" to R.string.catalog_dresses_kind_evening,
)

private sealed interface DressState {
    data object Loading : DressState
    data class Failed(val error: AppError) : DressState
    data class Loaded(val page: DressListingsPage) : DressState
}

/** wa.me wants the number without "+". */
private fun whatsApp(phone: String) = Uri.parse("https://wa.me/${phone.filter { it.isDigit() }}")
private fun call(phone: String) = Uri.parse("tel:$phone")
/** +9665XXXXXXXX → 05XXXXXXXX, how people write it. */
private fun localPhone(phone: String) = if (phone.startsWith("+966")) "0" + phone.drop(4) else phone

/**
 * «فساتين»: dresses for rent, listed by the admin, in three lists (wedding, jalwa, evening). A
 * notice at the top tells dress owners how to list theirs; tapping a dress shows it large with its
 * price and buttons to reach the owner on WhatsApp or by phone. Mirrors iOS `DressesScreen`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DressesScreen(feature: CatalogFeature) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var kind by remember { mutableStateOf("wedding") }
    var state: DressState by remember { mutableStateOf(DressState.Loading) }
    var refreshing by remember { mutableStateOf(false) }
    var open by remember { mutableStateOf<DressListing?>(null) }

    suspend fun load() {
        if (state !is DressState.Loaded) state = DressState.Loading
        state = try {
            DressState.Loaded(feature.repository.dresses(kind))
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            DressState.Failed(AppError.from(e))
        }
    }
    LaunchedEffect(Unit) { analytics.screen("dresses") }
    LaunchedEffect(kind) { load() }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.catalog_dresses_title), navigator.back, stringResource(R.string.catalog_back))
        PullToRefreshBox(
            isRefreshing = refreshing,
            onRefresh = { scope.launch { refreshing = true; load(); refreshing = false } },
            modifier = Modifier.fillMaxSize(),
        ) {
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg),
                verticalArrangement = Arrangement.spacedBy(DSSpacing.lg),
            ) {
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    DressListing.kinds.forEachIndexed { index, value ->
                        SegmentedButton(
                            selected = kind == value,
                            onClick = { kind = value },
                            shape = SegmentedButtonDefaults.itemShape(index, DressListing.kinds.size),
                            colors = SegmentedButtonDefaults.colors(activeContainerColor = DS.colors.primaryMuted, activeContentColor = DS.colors.primary),
                        ) { Text(stringResource(kindLabels.getValue(value)), maxLines = 1) }
                    }
                }
                when (val s = state) {
                    DressState.Loading -> Box(Modifier.fillMaxWidth().heightIn(min = 240.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = DS.colors.primary)
                    }
                    is DressState.Failed -> ErrorStateView(s.error) { scope.launch { load() } }
                    is DressState.Loaded -> {
                        s.page.notice?.takeIf { it.phone != null }?.let { DressNoticeCard(it) }
                        if (s.page.listings.isEmpty()) {
                            EmptyStateView(
                                Icons.Outlined.Checkroom,
                                stringResource(R.string.catalog_dresses_empty_title),
                                stringResource(R.string.catalog_dresses_empty_message),
                            )
                        } else {
                            // Two columns.
                            s.page.listings.chunked(2).forEach { pair ->
                                Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
                                    pair.forEach { dress -> DressCard(dress, Modifier.weight(1f)) { open = dress } }
                                    if (pair.size == 1) Box(Modifier.weight(1f))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    open?.let { dress -> DressSheet(dress) { open = null } }
}

/** A dress in the grid: the photo (3:4) and the price. */
@Composable
private fun DressCard(dress: DressListing, modifier: Modifier, onOpen: () -> Unit) {
    Column(modifier.clickable(role = Role.Button, onClick = onOpen), verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
        RemoteImage(
            dress.imageUrl,
            Modifier.fillMaxWidth().aspectRatio(3f / 4f).clip(RoundedCornerShape(DSRadius.card)),
            placeholder = DS.colors.primaryMuted,
            thumbnail = true,
        )
        Text(formatSar(dress.price), style = DS.type.headline, color = DS.colors.primary)
    }
}

/** The dress large, with its price and the owner's WhatsApp and phone. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DressSheet(dress: DressListing, onDismiss: () -> Unit) {
    val context = LocalContext.current
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = DS.colors.background) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = DSSpacing.lg).padding(bottom = DSSpacing.xl),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.lg),
        ) {
            Text(stringResource(kindLabels[dress.kind] ?: R.string.catalog_dresses_title), style = DS.type.headline, color = DS.colors.textPrimary)
            RemoteImage(
                dress.imageUrl,
                Modifier.fillMaxWidth().clip(RoundedCornerShape(DSRadius.card)),
                placeholder = DS.colors.primaryMuted,
                contentScale = ContentScale.FillWidth,
            )
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xxs)) {
                Text(stringResource(R.string.catalog_dresses_rentPrice), style = DS.type.subhead, color = DS.colors.textSecondary)
                Text(formatSar(dress.price), style = DS.type.title1, color = DS.colors.primary)
            }
            Text(stringResource(R.string.catalog_dresses_contactOwner), style = DS.type.headline, color = DS.colors.textPrimary)
            PrimaryButton(stringResource(R.string.catalog_dresses_whatsapp), icon = Icons.Filled.Chat) {
                context.startActivity(Intent(Intent.ACTION_VIEW, whatsApp(dress.contactPhone)))
            }
            SecondaryButton(stringResource(R.string.catalog_dresses_call), icon = Icons.Filled.Phone) {
                context.startActivity(Intent(Intent.ACTION_DIAL, call(dress.contactPhone)))
            }
            Text(localPhone(dress.contactPhone), style = DS.type.footnote, color = DS.colors.textSecondary, modifier = Modifier.align(Alignment.CenterHorizontally))
        }
    }
}

/** «اعرضي فستانك للإيجار بـ ٢٠ ريال لمدة شهر»: how a dress owner gets listed. */
@Composable
private fun DressNoticeCard(notice: DressNotice) {
    val context = LocalContext.current
    val phone = notice.phone ?: return
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(DSRadius.card)).background(DSGradient.gold).padding(DSSpacing.md),
        verticalArrangement = Arrangement.spacedBy(DSSpacing.sm),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Sell, contentDescription = null, tint = DS.colors.primaryPress)
            Text(stringResource(R.string.catalog_dresses_notice_title, formatSar(notice.price ?: 20.0)), style = DS.type.headline, color = DS.colors.primaryPress)
        }
        Text(stringResource(R.string.catalog_dresses_notice_body), style = DS.type.footnote, color = DS.colors.primaryPress.copy(alpha = 0.85f))
        Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
            Row(
                Modifier.clip(RoundedCornerShape(DSRadius.pill)).background(DS.colors.primary)
                    .clickable(role = Role.Button) { context.startActivity(Intent(Intent.ACTION_VIEW, whatsApp(phone))) }
                    .padding(horizontal = DSSpacing.md, vertical = DSSpacing.xs),
                horizontalArrangement = Arrangement.spacedBy(DSSpacing.xxs), verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Chat, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.catalog_dresses_whatsapp), style = DS.type.subhead, color = Color.White)
            }
            Row(
                Modifier.clip(RoundedCornerShape(DSRadius.pill)).border(1.dp, DS.colors.primary, RoundedCornerShape(DSRadius.pill))
                    .clickable(role = Role.Button) { context.startActivity(Intent(Intent.ACTION_DIAL, call(phone))) }
                    .padding(horizontal = DSSpacing.md, vertical = DSSpacing.xs),
                horizontalArrangement = Arrangement.spacedBy(DSSpacing.xxs), verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Phone, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.catalog_dresses_call), style = DS.type.subhead, color = DS.colors.primary)
            }
        }
    }
}
