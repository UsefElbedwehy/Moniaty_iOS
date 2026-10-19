package co.munyati.providerstudio.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Badge
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.ExperimentalMaterial3Api
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import co.munyati.catalog.presentation.ProviderRoute
import co.munyati.core.error.AppError
import co.munyati.core.state.ViewState
import co.munyati.designsystem.components.DSCard
import co.munyati.designsystem.components.ErrorStateView
import co.munyati.designsystem.components.LargeHeaderBar
import co.munyati.designsystem.components.StatusBadge
import co.munyati.designsystem.components.StatusBadgeKind
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.providerstudio.R
import co.munyati.providerstudio.domain.Entitlement
import co.munyati.providerstudio.domain.MyBusiness
import co.munyati.providerstudio.domain.SetupStep
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.launch

/** The provider's Home tab (mockup 7): status, plan, setup checklist and the studio rows. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun StudioHomeScreen(feature: StudioFeature) {
    val store = feature.store
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var refreshing by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        analytics.screen("studio_home")
        store.load()
    }
    val businessName = store.business?.businessName?.ifEmpty { null }

    PullToRefreshBox(
        isRefreshing = refreshing,
        onRefresh = { scope.launch { refreshing = true; store.load(); refreshing = false } },
        modifier = Modifier.fillMaxSize().background(DS.colors.background).statusBarsPadding(),
    ) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            // With a business name the greeting header (mockup 7) replaces the large title.
            if (businessName == null) LargeHeaderBar(stringResource(R.string.studio_studio_title))
            Column(Modifier.padding(DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.lg)) {
                when (val state = store.state) {
                    ViewState.Loading -> Box(Modifier.fillMaxWidth().heightIn(min = 300.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = DS.colors.primary, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
                    }
                    is ViewState.Error -> ErrorStateView(state.error) { scope.launch { store.load() } }
                    is ViewState.Loaded -> Content(feature, state.value, businessName)
                    is ViewState.Refreshing -> Content(feature, state.value, businessName)
                    ViewState.Empty, ViewState.Offline -> ErrorStateView(AppError.Offline) { scope.launch { store.load() } }
                }
            }
        }
    }
}

@Composable
private fun Content(feature: StudioFeature, business: MyBusiness, businessName: String?) {
    val navigator = LocalNavigator.current
    val store = feature.store
    if (businessName != null) {
        Column(Modifier.semantics(mergeDescendants = true) { heading() }, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.studio_studio_greeting), style = DS.type.subhead, color = DS.colors.textSecondary)
            Text(businessName, style = DS.type.largeTitle, color = DS.colors.textPrimary)
        }
    }
    StatusCard(business)
    store.subscription?.takeIf { it.entitlement.state != Entitlement.State.Pending }?.let { SubscriptionCard(it) }

    val steps = business.setupSteps
    if (steps.any { !it.done }) {
        DSCard(Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.studio_studio_setup_title), style = DS.type.headline, color = DS.colors.textPrimary)
            steps.forEach { SetupStepRow(it) }
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
        StudioRow(Icons.Outlined.Badge, stringResource(R.string.studio_studio_business),
            businessName ?: stringResource(R.string.studio_studio_business_empty)) { navigator.navigate(BusinessEditRoute) }
        StudioRow(Icons.Outlined.AutoAwesome, stringResource(R.string.studio_studio_services),
            stringResource(R.string.studio_studio_services_count, business.activeServiceCount, business.limits.maxServices)) { navigator.navigate(ServicesListRoute) }
        StudioRow(Icons.Outlined.Storefront, stringResource(R.string.studio_studio_stores),
            stringResource(R.string.studio_studio_stores_count, business.stores.size, business.limits.maxStores)) { navigator.navigate(StoresListRoute) }
        feature.settingsRoute?.let { route ->
            StudioSettingsLink.entries.forEach { link ->
                StudioRow(link.icon, stringResource(link.title), stringResource(link.subtitle)) { navigator.navigate(route(link)) }
            }
        }
        if (business.status == MyBusiness.Status.Approved) {
            StudioRow(Icons.Outlined.BarChart, stringResource(R.string.studio_studio_insights), stringResource(R.string.studio_studio_insights_subtitle)) { navigator.navigate(InsightsRoute) }
            StudioRow(Icons.Outlined.WorkspacePremium, stringResource(R.string.studio_studio_plans), store.subscription?.currentPlan?.name) { navigator.navigate(PlansRoute()) }
            StudioRow(Icons.Outlined.Visibility, stringResource(R.string.studio_studio_preview), null) { navigator.navigate(ProviderRoute(business.id)) }
        }
    }
}

@Composable
private fun SetupStepRow(step: SetupStep) {
    val title = stringResource(
        when (step.key) {
            SetupStep.Key.Profile -> R.string.studio_studio_step_profile
            SetupStep.Key.Coverage -> R.string.studio_studio_step_coverage
            SetupStep.Key.Location -> R.string.studio_studio_step_location
            SetupStep.Key.Service -> R.string.studio_studio_step_service
        },
    )
    val value = stringResource(if (step.done) R.string.studio_studio_step_done else R.string.studio_studio_step_todo)
    Row(
        Modifier.padding(top = DSSpacing.xs).semantics(mergeDescendants = true) { stateDescription = value },
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(if (step.done) Icons.Filled.CheckCircle else Icons.Outlined.Circle, contentDescription = null,
            tint = if (step.done) DS.colors.success else DS.colors.disabled, modifier = Modifier.size(20.dp))
        Text(title, style = DS.type.subhead, color = DS.colors.textPrimary)
    }
}

@Composable
private fun StatusCard(business: MyBusiness) {
    val (title, message, kind) = when (business.status) {
        MyBusiness.Status.Pending -> Triple(R.string.studio_studio_status_pending, R.string.studio_studio_status_pending_message, StatusBadgeKind.Pending)
        MyBusiness.Status.Approved -> Triple(R.string.studio_studio_status_approved, R.string.studio_studio_status_approved_message, StatusBadgeKind.Live)
        MyBusiness.Status.Rejected -> Triple(R.string.studio_studio_status_rejected, R.string.studio_studio_status_rejected_message, StatusBadgeKind.Rejected)
        MyBusiness.Status.Suspended -> Triple(R.string.studio_studio_status_suspended, R.string.studio_studio_status_suspended_message, StatusBadgeKind.Rejected)
    }
    DSCard(Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
            StatusBadge(kind, stringResource(title))
            Text(stringResource(message), style = DS.type.footnote, color = DS.colors.textSecondary)
            val note = business.reviewNote
            if (!note.isNullOrEmpty() && business.status != MyBusiness.Status.Approved) {
                Text(note, style = DS.type.footnote, color = DS.colors.textPrimary)
            }
            if (business.isVerified) {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Verified, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(16.dp))
                    Text(stringResource(R.string.studio_studio_verified), style = DS.type.footnote, color = DS.colors.primary)
                }
            }
        }
    }
}

/** One studio row: icon tile, title, subtitle and a chevron. */
@Composable
internal fun StudioRow(icon: ImageVector, title: String, subtitle: String?, onClick: () -> Unit) {
    val shape = RoundedCornerShape(DSRadius.card)
    Row(
        Modifier.fillMaxWidth().clip(shape).background(DS.colors.surface).border(1.dp, DS.colors.border, shape)
            .clickable(role = Role.Button, onClick = onClick).padding(DSSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.md),
    ) {
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(14.dp)).background(DS.colors.primaryMuted), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = DS.colors.primary)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = DS.type.headline, color = DS.colors.textPrimary)
            if (!subtitle.isNullOrEmpty()) Text(subtitle, style = DS.type.footnote, color = DS.colors.textSecondary, maxLines = 2)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = DS.colors.textSecondary)
    }
}
