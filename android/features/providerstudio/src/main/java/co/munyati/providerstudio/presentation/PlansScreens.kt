package co.munyati.providerstudio.presentation

import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.RadioButtonChecked
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.CardGiftcard
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.HourglassEmpty
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material.icons.outlined.PersonOutline
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import co.munyati.core.dates.DisplayDates
import co.munyati.core.error.AppError
import co.munyati.core.state.ViewState
import co.munyati.designsystem.components.DSCard
import co.munyati.designsystem.components.DSTopBar
import co.munyati.designsystem.components.ErrorStateView
import co.munyati.designsystem.components.PrimaryButton
import co.munyati.designsystem.components.StatusBadge
import co.munyati.designsystem.components.StatusBadgeKind
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.providerstudio.R
import co.munyati.providerstudio.domain.CheckoutStart
import co.munyati.providerstudio.domain.Entitlement
import co.munyati.providerstudio.domain.Insights
import co.munyati.providerstudio.domain.PlanPaymentStatus
import co.munyati.providerstudio.domain.SubscriptionOverview
import co.munyati.providerstudio.domain.SubscriptionPlan
import co.munyati.shared.analytics.AnalyticsEvent
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant

/** "19 Dec 2026" / "١٩ ديسمبر ٢٠٢٦", like iOS `.abbreviated`. */
private fun day(instant: Instant?) = instant?.let { DisplayDates.pattern(it, "yMMMd") }.orEmpty()

// Subscription card (studio home)

/** Trial countdown, current plan, or "your services are hidden" (docs/PLAN.md §4.7). */
@Composable
internal fun SubscriptionCard(subscription: SubscriptionOverview) {
    val navigator = LocalNavigator.current
    val e = subscription.entitlement
    val days = e.daysLeft()
    val urgent = e.state == Entitlement.State.Expired || ((days?.let { it <= 14 } ?: false) && e.nextPlanId == null)
    val (icon, title) = when (e.state) {
        Entitlement.State.Trial -> Icons.Outlined.CardGiftcard to stringResource(R.string.studio_plan_card_trial)
        Entitlement.State.Subscribed -> Icons.Outlined.WorkspacePremium to stringResource(R.string.studio_plan_card_subscribed)
        Entitlement.State.Expired -> Icons.Outlined.VisibilityOff to stringResource(R.string.studio_plan_card_expired)
        Entitlement.State.Pending -> Icons.Outlined.HourglassEmpty to ""
    }
    DSCard(Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                Icon(icon, contentDescription = null, tint = if (e.state == Entitlement.State.Expired) DS.colors.error else DS.colors.primary)
                Text(title, style = DS.type.headline, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                val plan = subscription.currentPlan
                if (e.state == Entitlement.State.Subscribed && plan != null) {
                    StatusBadge(if (plan.isFeatured) StatusBadgeKind.Featured else StatusBadgeKind.Live, plan.name)
                }
            }
            val message = when (e.state) {
                Entitlement.State.Trial, Entitlement.State.Subscribed ->
                    if (days != null && e.listedUntil != null) stringResource(R.string.studio_plan_card_until, day(e.listedUntil), days) else ""
                Entitlement.State.Expired -> stringResource(R.string.studio_plan_card_expired_message)
                Entitlement.State.Pending -> ""
            }
            Text(message, style = DS.type.subhead, color = DS.colors.textSecondary)
            val next = subscription.nextPlan
            if (next != null && e.nextStartsAt != null) {
                Text(stringResource(R.string.studio_plan_card_next, next.name, day(e.nextStartsAt)), style = DS.type.footnote, color = DS.colors.textSecondary)
            }
            if (urgent) {
                PrimaryButton(
                    stringResource(if (e.state == Entitlement.State.Subscribed) R.string.studio_plan_card_renew else R.string.studio_plan_card_choose),
                ) { navigator.navigate(PlansRoute()) }
            }
        }
    }
}

// Plans / paywall (mockup "Paywall")

@Composable
internal fun PlansScreen(feature: StudioFeature, reason: String?) {
    val store = feature.store
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var selectedId by remember { mutableStateOf<String?>(null) }
    var isPaying by remember { mutableStateOf(false) }
    var alert by remember { mutableStateOf<Pair<String, String?>?>(null) }
    /** A Tap payment opened in the browser, confirmed with the server when the app comes back. */
    var awaiting by remember { mutableStateOf<Pair<String, SubscriptionPlan>?>(null) }

    LaunchedEffect(Unit) {
        analytics.screen("paywall")
        store.reload()
        analytics(AnalyticsEvent.PaywallView, context = if (reason == null) "studio" else "limit")
    }

    suspend fun finish(paymentId: String, plan: SubscriptionPlan) {
        // Polls the server a few times while Tap settles the charge (the browser closing is not
        // proof of payment).
        var status = PlanPaymentStatus.Initiated
        for (attempt in 0 until 5) {
            runCatching { feature.checkout.status(paymentId) }.getOrNull()?.let { status = it }
            if (status != PlanPaymentStatus.Initiated) break
            delay(if (attempt == 0) 1_000 else 2_000)
        }
        store.reload()
        alert = when (status) {
            PlanPaymentStatus.Captured -> context.getString(R.string.studio_plans_result_captured) to
                context.getString(R.string.studio_plans_result_captured_message, plan.name)
            PlanPaymentStatus.Failed -> context.getString(R.string.studio_plans_result_failed) to null
            PlanPaymentStatus.Review -> context.getString(R.string.studio_plans_result_review) to null
            PlanPaymentStatus.Initiated -> null // closed before paying, or still processing
        }
    }

    // Back from Tap's page (the return redirect or the user closing the tab): confirm the payment.
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            val pending = awaiting
            if (event == Lifecycle.Event.ON_RESUME && pending != null) {
                awaiting = null
                scope.launch {
                    isPaying = true
                    finish(pending.first, pending.second)
                    isPaying = false
                }
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }

    fun pay(plan: SubscriptionPlan) {
        isPaying = true
        analytics(AnalyticsEvent.PlanPurchaseStarted, plan.id)
        scope.launch {
            try {
                when (val start = feature.checkout.start(plan.id)) {
                    is CheckoutStart.Refused -> alert = context.getString(refusalMessage(start.code)) to null
                    is CheckoutStart.Completed -> finish(start.paymentId, plan)
                    is CheckoutStart.Open -> {
                        awaiting = start.paymentId to plan
                        CustomTabsIntent.Builder()
                            .setDefaultColorSchemeParams(CustomTabColorSchemeParams.Builder().setToolbarColor(0xFF8A0D3A.toInt()).build())
                            .build()
                            .launchUrl(context, Uri.parse(start.url))
                        return@launch // the spinner stays until we're back
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                alert = context.getString(R.string.studio_plans_error_generic) to null
            }
            isPaying = false
        }
    }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.studio_plans_title), navigator.back, stringResource(R.string.studio_back))
        val subscription = store.subscription
        if (subscription == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = DS.colors.primary, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
            }
            return@Column
        }
        val selected = subscription.plan(selectedId ?: defaultSelection(subscription))
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(DSSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.md),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                Text(stringResource(R.string.studio_plans_headline), style = DS.type.title1, color = DS.colors.textPrimary)
                Text(headline(subscription), style = DS.type.subhead, color = DS.colors.textSecondary)
            }
            if (reason != null) {
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(DS.colors.pendingBackground).padding(DSSpacing.sm),
                    horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Outlined.ErrorOutline, contentDescription = null, tint = DS.colors.pendingForeground)
                    Text(reason, style = DS.type.subhead, color = DS.colors.textPrimary)
                }
            }
            subscription.plans.forEach { plan ->
                PlanCard(
                    plan,
                    isSelected = plan.id == selected?.id,
                    isCurrent = subscription.entitlement.state == Entitlement.State.Subscribed && plan.id == subscription.entitlement.planId,
                ) { selectedId = plan.id }
            }
            Disclosure()
            if (subscription.payments.isNotEmpty()) Payments(subscription)
        }
        if (selected != null) {
            Column(Modifier.background(DS.colors.surface)) {
                HorizontalDivider(color = DS.colors.border)
                PrimaryButton(
                    ctaTitle(selected, subscription),
                    isLoading = isPaying,
                    isEnabled = subscription.entitlement.state != Entitlement.State.Pending,
                    modifier = Modifier.padding(horizontal = DSSpacing.lg, vertical = DSSpacing.sm),
                ) { pay(selected) }
            }
        }
    }

    alert?.let { (title, message) ->
        AlertDialog(
            onDismissRequest = { alert = null },
            title = { Text(title) },
            text = message?.let { { Text(it) } },
            confirmButton = { TextButton(onClick = { alert = null }) { Text(stringResource(R.string.studio_common_ok)) } },
        )
    }
}

private fun refusalMessage(code: String) = when (code) {
    "not_approved" -> R.string.studio_plans_error_not_approved
    "plan_unavailable" -> R.string.studio_plans_error_plan_unavailable
    "too_many_attempts" -> R.string.studio_plans_error_too_many_attempts
    else -> R.string.studio_plans_error_generic
}

private fun defaultSelection(s: SubscriptionOverview): String? {
    if (s.entitlement.state == Entitlement.State.Subscribed && s.entitlement.planId != null) return s.entitlement.planId
    return s.plans.firstOrNull { it.isRecommended }?.id ?: s.plans.firstOrNull()?.id
}

@Composable
private fun headline(s: SubscriptionOverview): String {
    val e = s.entitlement
    return when (e.state) {
        Entitlement.State.Pending -> stringResource(R.string.studio_plans_sub_pending)
        Entitlement.State.Trial -> stringResource(R.string.studio_plans_sub_trial, day(e.trialEndsAt ?: Instant.now()))
        Entitlement.State.Subscribed -> stringResource(R.string.studio_plans_sub_subscribed, s.currentPlan?.name.orEmpty(), day(e.paidUntil ?: e.periodEndsAt ?: Instant.now()))
        Entitlement.State.Expired -> stringResource(R.string.studio_plans_sub_expired)
    }
}

@Composable
private fun ctaTitle(plan: SubscriptionPlan, s: SubscriptionOverview): String {
    val e = s.entitlement
    val price = formatSar(plan.priceSar)
    val current = s.currentPlan
    return when {
        e.state == Entitlement.State.Subscribed && plan.id == e.planId -> stringResource(R.string.studio_plans_cta_renew, price)
        e.state == Entitlement.State.Subscribed && current != null && plan.rank > current.rank -> stringResource(R.string.studio_plans_cta_upgrade, plan.name, price)
        else -> stringResource(R.string.studio_plans_cta_subscribe, plan.name, price)
    }
}

@Composable
private fun PlanCard(plan: SubscriptionPlan, isSelected: Boolean, isCurrent: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(DSRadius.card)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(DS.colors.surface)
            .border(if (isSelected) 2.dp else 1.dp, if (isSelected) DS.colors.primary else DS.colors.border, shape)
            .clickable(role = Role.RadioButton, onClick = onClick).padding(DSSpacing.md),
        verticalArrangement = Arrangement.spacedBy(DSSpacing.sm),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
            Text(plan.name, style = DS.type.title2, color = DS.colors.textPrimary)
            if (plan.isRecommended) StatusBadge(StatusBadgeKind.Featured, stringResource(R.string.studio_plans_recommended))
            if (isCurrent) StatusBadge(StatusBadgeKind.Live, stringResource(R.string.studio_plans_current))
            Box(Modifier.weight(1f))
            Icon(if (isSelected) Icons.Filled.RadioButtonChecked else Icons.Outlined.RadioButtonUnchecked, contentDescription = null,
                tint = if (isSelected) DS.colors.primary else DS.colors.disabled)
        }
        Text(stringResource(R.string.studio_plans_price, formatSar(plan.priceSar)), style = DS.type.headline, color = DS.colors.primary)
        plan.features.forEach { feature ->
            Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Check, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(18.dp))
                Text(feature, style = DS.type.subhead, color = DS.colors.textPrimary)
            }
        }
    }
}

@Composable
private fun Disclosure() {
    val context = LocalContext.current
    fun open(url: String) = context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
        Text(stringResource(R.string.studio_plans_disclosure), style = DS.type.footnote, color = DS.colors.textSecondary)
        Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
            Text(stringResource(R.string.studio_plans_terms), style = DS.type.footnote, color = DS.colors.primary,
                modifier = Modifier.clickable { open("https://munyati.co/terms") })
            Text(stringResource(R.string.studio_plans_privacy), style = DS.type.footnote, color = DS.colors.primary,
                modifier = Modifier.clickable { open("https://munyati.co/privacy") })
        }
    }
}

@Composable
private fun Payments(s: SubscriptionOverview) {
    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
        Text(stringResource(R.string.studio_plans_payments), style = DS.type.headline, color = DS.colors.textPrimary)
        s.payments.forEach { payment ->
            Row(Modifier.padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(s.plan(payment.planId)?.name ?: payment.planId, style = DS.type.subhead, color = DS.colors.textPrimary)
                    Text(payment.createdAt?.let { DisplayDates.pattern(it, "yMMMdjmm") }.orEmpty(),
                        style = DS.type.caption, color = DS.colors.textSecondary)
                }
                Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(formatSar(payment.amount), style = DS.type.subhead, color = DS.colors.textPrimary)
                    val status = when (payment.status) {
                        PlanPaymentStatus.Initiated -> R.string.studio_plans_payment_initiated
                        PlanPaymentStatus.Captured -> R.string.studio_plans_payment_captured
                        PlanPaymentStatus.Failed -> R.string.studio_plans_payment_failed
                        PlanPaymentStatus.Review -> R.string.studio_plans_payment_review
                    }
                    Text(stringResource(status), style = DS.type.caption,
                        color = if (payment.status == PlanPaymentStatus.Captured) DS.colors.success else DS.colors.textSecondary)
                }
            }
        }
    }
}

// Insights

@Composable
internal fun InsightsScreen(feature: StudioFeature) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var days by remember { mutableIntStateOf(30) }
    var state: ViewState<Insights> by remember { mutableStateOf(ViewState.Loading) }

    suspend fun load() {
        try {
            state = ViewState.Loaded(feature.store.repository.insights(days))
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            if (state.value == null) state = ViewState.Error(AppError.from(e))
        }
    }
    LaunchedEffect(Unit) { analytics.screen("studio_insights") }
    LaunchedEffect(days) { load() }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.studio_insights_title), navigator.back, stringResource(R.string.studio_back))
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
            val options = listOf(7 to R.string.studio_insights_days_7, 30 to R.string.studio_insights_days_30, 90 to R.string.studio_insights_days_90)
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                options.forEachIndexed { index, (value, label) ->
                    SegmentedButton(
                        selected = days == value,
                        onClick = { days = value },
                        shape = SegmentedButtonDefaults.itemShape(index, options.size),
                        colors = SegmentedButtonDefaults.colors(activeContainerColor = DS.colors.primaryMuted, activeContentColor = DS.colors.primary),
                    ) { Text(stringResource(label)) }
                }
            }
            when (val s = state) {
                ViewState.Loading -> Box(Modifier.fillMaxWidth().heightIn(min = 200.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = DS.colors.primary, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
                }
                is ViewState.Error -> ErrorStateView(s.error) { scope.launch { load() } }
                is ViewState.Loaded -> InsightsContent(s.value)
                is ViewState.Refreshing -> InsightsContent(s.value)
                ViewState.Empty, ViewState.Offline -> ErrorStateView(AppError.Offline) { scope.launch { load() } }
            }
        }
    }
}

@Composable
private fun InsightsContent(insights: Insights) {
    val navigator = LocalNavigator.current
    val tiles = buildList {
        add(Triple(stringResource(R.string.studio_insights_profileViews), localizedNumber("${insights.profileViews}"), Icons.Outlined.PersonOutline))
        add(Triple(stringResource(R.string.studio_insights_serviceViews), localizedNumber("${insights.serviceViews}"), Icons.Outlined.Visibility))
        add(Triple(stringResource(R.string.studio_insights_requests), localizedNumber("${insights.requests}"), Icons.Outlined.CalendarMonth))
        insights.contactTaps?.let { add(Triple(stringResource(R.string.studio_insights_contacts), localizedNumber("$it"), Icons.Outlined.ChatBubbleOutline)) }
        insights.favorites?.let { add(Triple(stringResource(R.string.studio_insights_favorites), localizedNumber("$it"), Icons.Outlined.FavoriteBorder)) }
        insights.revenue?.let { add(Triple(stringResource(R.string.studio_insights_revenue), formatSar(it), Icons.Outlined.Payments)) }
    }
    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
        tiles.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
                row.forEach { (title, value, icon) -> StatTile(title, value, icon, Modifier.weight(1f)) }
                if (row.size == 1) Box(Modifier.weight(1f))
            }
        }
    }
    if (insights.isFull) {
        DSCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
                Text(stringResource(R.string.studio_insights_funnel), style = DS.type.headline, color = DS.colors.textPrimary)
                FunnelRow(stringResource(R.string.studio_insights_serviceViews), insights.serviceViews, insights.serviceViews)
                FunnelRow(stringResource(R.string.studio_insights_requests), insights.requests, insights.serviceViews)
                FunnelRow(stringResource(R.string.studio_insights_approved), insights.approved ?: 0, insights.serviceViews)
                FunnelRow(stringResource(R.string.studio_insights_completed), insights.completed ?: 0, insights.serviceViews)
            }
        }
        val rows = insights.services.orEmpty()
        if (rows.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                Text(stringResource(R.string.studio_insights_byService), style = DS.type.headline, color = DS.colors.textPrimary)
                rows.forEach { row ->
                    Row(Modifier.padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
                        Text(row.title, style = DS.type.subhead, color = DS.colors.textPrimary, maxLines = 1, modifier = Modifier.weight(1f))
                        IconValue(Icons.Outlined.Visibility, localizedNumber("${row.views}"))
                        IconValue(Icons.Outlined.CalendarMonth, localizedNumber("${row.requests}"))
                    }
                }
            }
        }
    } else {
        DSCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
                Text(stringResource(R.string.studio_insights_upsell), style = DS.type.subhead, color = DS.colors.textPrimary)
                PrimaryButton(stringResource(R.string.studio_insights_upsell_cta)) { navigator.navigate(PlansRoute()) }
            }
        }
    }
}

/** Integers in the current locale's digits, like iOS string interpolation of numbers. */
private fun localizedNumber(value: String): String =
    value.toLongOrNull()?.let { java.text.NumberFormat.getIntegerInstance().format(it) } ?: value

@Composable
private fun IconValue(icon: ImageVector, value: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(2.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = DS.colors.textSecondary, modifier = Modifier.size(16.dp))
        Text(value, style = DS.type.footnote, color = DS.colors.textPrimary)
    }
}

@Composable
private fun StatTile(title: String, value: String, icon: ImageVector, modifier: Modifier) {
    val shape = RoundedCornerShape(DSRadius.card)
    Column(
        modifier.clip(shape).background(DS.colors.surface).border(1.dp, DS.colors.border, shape).padding(DSSpacing.md),
        verticalArrangement = Arrangement.spacedBy(DSSpacing.xs),
    ) {
        Icon(icon, contentDescription = null, tint = DS.colors.primary)
        Text(value, style = DS.type.title2, color = DS.colors.textPrimary)
        Text(title, style = DS.type.footnote, color = DS.colors.textSecondary, maxLines = 2)
    }
}

@Composable
private fun FunnelRow(title: String, value: Int, of: Int) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row {
            Text(title, style = DS.type.subhead, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
            Text(localizedNumber("$value"), style = DS.type.subhead, color = DS.colors.primary)
        }
        val fraction = if (of > 0) minOf(value, of).toFloat() / of else 0f
        Box(Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(DSRadius.pill)).background(DS.colors.primaryMuted)) {
            Box(Modifier.fillMaxWidth(fraction).height(6.dp).clip(RoundedCornerShape(DSRadius.pill)).background(DS.colors.primary))
        }
    }
}

