@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package co.munyati.booking.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.CreditCard
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import co.munyati.booking.R
import co.munyati.booking.data.dayString
import co.munyati.booking.domain.ActionResult
import co.munyati.booking.domain.BookableService
import co.munyati.booking.domain.BookingRole
import co.munyati.booking.domain.BookingStatus
import co.munyati.booking.domain.BookingSummary
import co.munyati.core.dates.DisplayDates
import co.munyati.core.error.AppError
import co.munyati.core.state.ViewState
import co.munyati.designsystem.components.DSCard
import co.munyati.designsystem.components.DSTopBar
import co.munyati.designsystem.components.EmptyStateView
import co.munyati.designsystem.components.ErrorStateView
import co.munyati.designsystem.components.LargeHeaderBar
import co.munyati.designsystem.components.PrimaryButton
import co.munyati.designsystem.components.StatusBadge
import co.munyati.designsystem.components.StatusBadgeKind
import co.munyati.designsystem.components.TopBarIconButton
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.analytics.AnalyticsEvent
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** Catches everything but cancellation, as `ViewState.Error`. */
internal suspend fun <T> loadState(empty: (T) -> Boolean = { false }, fetch: suspend () -> T): ViewState<T> = try {
    fetch().let { if (empty(it)) ViewState.Empty else ViewState.Loaded(it) }
} catch (e: CancellationException) {
    throw e
} catch (e: Exception) {
    ViewState.Error(AppError.from(e))
}

@Composable
internal fun Spinner(modifier: Modifier = Modifier) = Box(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
    CircularProgressIndicator(color = DS.colors.primary, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
}

@Composable
internal fun MessageDialog(message: String?, onDismiss: () -> Unit) {
    if (message == null) return
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(message) },
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.booking_common_ok)) } },
    )
}

// Request (mockup 4)

@Composable
internal fun BookingRequestScreen(feature: BookingFeature, service: BookableService) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val today = remember { LocalDate.now(ZoneId.systemDefault()) }
    val days = remember { (0L until 21L).map { today.plusDays(it) } }
    var day by remember { mutableStateOf(today) }
    var slots: ViewState<List<Instant>> by remember { mutableStateOf(ViewState.Loading) }
    var selected by remember { mutableStateOf<Instant?>(null) }
    var note by remember { mutableStateOf("") }
    var isSending by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    suspend fun loadSlots() {
        slots = ViewState.Loading
        slots = loadState({ it.isEmpty() }) { feature.repository.availableSlots(service.id, dayString(day)) }
    }
    LaunchedEffect(Unit) { analytics.screen("booking_request") }
    LaunchedEffect(day) { loadSlots() }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.booking_request_title), onBack = null, backDescription = "") {
            TopBarIconButton(Icons.Outlined.Close, stringResource(R.string.booking_common_cancel)) { navigator.back() }
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.lg)) {
            DSCard(Modifier.fillMaxWidth()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(service.title, style = DS.type.headline, color = DS.colors.textPrimary)
                        Text(service.providerName.orEmpty(), style = DS.type.footnote, color = DS.colors.textSecondary)
                    }
                    Text(formatSar(service.price), style = DS.type.headline, color = DS.colors.primary)
                }
            }

            Text(stringResource(R.string.booking_request_day), style = DS.type.headline, color = DS.colors.textPrimary)
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                days.forEach { d ->
                    val isOn = d == day
                    val instant = d.atTime(12, 0).atZone(ZoneId.systemDefault()).toInstant()
                    val shape = RoundedCornerShape(16.dp)
                    Column(
                        Modifier.width(56.dp).height(64.dp).clip(shape)
                            .background(if (isOn) DS.colors.primary else DS.colors.surface)
                            .border(1.dp, if (isOn) androidx.compose.ui.graphics.Color.Transparent else DS.colors.border, shape)
                            .clickable(role = Role.RadioButton) { day = d; selected = null },
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                    ) {
                        val fg = if (isOn) DS.colors.background else DS.colors.textPrimary
                        Text(DisplayDates.pattern(instant, "EEE"), style = DS.type.caption, color = fg)
                        Text(DisplayDates.pattern(instant, "d"), style = DS.type.title2, color = fg)
                    }
                }
            }

            Text(stringResource(R.string.booking_request_time), style = DS.type.headline, color = DS.colors.textPrimary)
            when (val s = slots) {
                ViewState.Loading -> Spinner()
                is ViewState.Loaded -> Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                    s.value.chunked(4).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                            row.forEach { slot ->
                                val isOn = selected == slot
                                val shape = RoundedCornerShape(14.dp)
                                Box(
                                    Modifier.weight(1f).heightIn(min = 44.dp).clip(shape)
                                        .background(if (isOn) DS.colors.textPrimary else DS.colors.surface)
                                        .border(1.dp, if (isOn) androidx.compose.ui.graphics.Color.Transparent else DS.colors.border, shape)
                                        .clickable(role = Role.RadioButton) { selected = slot },
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Text(DisplayDates.pattern(slot, "jmm"), style = DS.type.subhead, color = if (isOn) DS.colors.background else DS.colors.textPrimary)
                                }
                            }
                            repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
                        }
                    }
                }
                is ViewState.Error -> ErrorStateView(s.error) { scope.launch { loadSlots() } }
                else -> Text(stringResource(R.string.booking_request_noSlots), style = DS.type.footnote, color = DS.colors.textSecondary)
            }

            val shape = RoundedCornerShape(14.dp)
            BasicTextField(
                value = note,
                onValueChange = { note = it },
                minLines = 2,
                textStyle = DS.type.body.copy(color = DS.colors.textPrimary),
                cursorBrush = SolidColor(DS.colors.primary),
                decorationBox = { inner ->
                    Box(Modifier.fillMaxWidth().clip(shape).background(DS.colors.surface).border(1.dp, DS.colors.border, shape).padding(DSSpacing.sm)) {
                        if (note.isEmpty()) Text(stringResource(R.string.booking_request_note), style = DS.type.body, color = DS.colors.textSecondary.copy(alpha = 0.6f))
                        inner()
                    }
                },
            )

            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(DSRadius.card)).background(DS.colors.primaryMuted).padding(DSSpacing.md),
                verticalArrangement = Arrangement.spacedBy(DSSpacing.xs),
            ) {
                feature.remainingBudget()?.let { remaining ->
                    Text(stringResource(R.string.booking_request_budgetAfter, formatSar(remaining - service.price)), style = DS.type.subhead, color = DS.colors.textPrimary)
                }
                Text(stringResource(R.string.booking_request_paymentInfo), style = DS.type.footnote, color = DS.colors.textSecondary)
            }
        }
        Column(Modifier.background(DS.colors.surface)) {
            HorizontalDivider(color = DS.colors.border)
            PrimaryButton(
                stringResource(R.string.booking_request_send), isLoading = isSending, isEnabled = selected != null,
                modifier = Modifier.padding(horizontal = DSSpacing.lg, vertical = DSSpacing.sm),
            ) {
                val slot = selected ?: return@PrimaryButton
                isSending = true
                scope.launch {
                    try {
                        when (val result = feature.repository.createBooking(service.id, slot, note.ifEmpty { null })) {
                            is ActionResult.Ok -> {
                                analytics(AnalyticsEvent.BookingSubmitted, service.id)
                                feature.onBookingsChanged()
                                navigator.back()
                                result.id?.let(feature.onBookingCreated)
                            }
                            is ActionResult.Refused -> {
                                message = refusal(context, result.code)
                                if (result.code == "slot_unavailable") loadSlots()
                            }
                        }
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        message = context.getString(R.string.booking_error_generic)
                    } finally {
                        isSending = false
                    }
                }
            }
        }
    }
    MessageDialog(message) { message = null }
}

// List (mockup 5 / provider inbox, mockup 7)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun BookingsListScreen(feature: BookingFeature, role: BookingRole) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var showActive by remember { mutableStateOf(true) }
    var state: ViewState<List<BookingSummary>> by remember { mutableStateOf(ViewState.Loading) }
    var refreshing by remember { mutableStateOf(false) }

    suspend fun load() {
        val fresh = loadState({ it.isEmpty() }) { feature.repository.bookings(showActive) }
        if (fresh is ViewState.Error && state.value != null) return
        state = fresh
    }
    LaunchedEffect(Unit) { analytics.screen(if (role == BookingRole.Bride) "my_bookings" else "provider_bookings") }
    LaunchedEffect(showActive) { load() }
    // Coming back from a booking (or the app) shows its new status.
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { scope.launch { load() } }

    Column(Modifier.fillMaxSize().background(DS.colors.background).statusBarsPadding()) {
        LargeHeaderBar(stringResource(if (role == BookingRole.Bride) R.string.booking_list_title_bride else R.string.booking_list_title_provider))
        PullToRefreshBox(isRefreshing = refreshing, onRefresh = { scope.launch { refreshing = true; load(); refreshing = false } }, modifier = Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
                val options = listOf(true to R.string.booking_list_active, false to R.string.booking_list_past)
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    options.forEachIndexed { index, (value, label) ->
                        SegmentedButton(
                            selected = showActive == value,
                            onClick = { showActive = value },
                            shape = SegmentedButtonDefaults.itemShape(index, options.size),
                            colors = SegmentedButtonDefaults.colors(activeContainerColor = DS.colors.primaryMuted, activeContentColor = DS.colors.primary),
                        ) { Text(stringResource(label)) }
                    }
                }
                when (val s = state) {
                    ViewState.Loading -> Spinner(Modifier.padding(top = DSSpacing.xl))
                    is ViewState.Error -> ErrorStateView(s.error) { scope.launch { load() } }
                    ViewState.Offline -> ErrorStateView(AppError.Offline) { scope.launch { load() } }
                    ViewState.Empty -> EmptyStateView(
                        Icons.Outlined.CalendarMonth,
                        stringResource(R.string.booking_list_empty_title),
                        stringResource(if (role == BookingRole.Bride) R.string.booking_list_empty_bride else R.string.booking_list_empty_provider),
                    )
                    is ViewState.Loaded, is ViewState.Refreshing -> s.value.orEmpty().forEach { booking ->
                        // A booking waiting on the bride's payment carries its main action on the card (mockup 5).
                        DSCard(Modifier.fillMaxWidth()) {
                            BookingRow(booking, role) { navigator.navigate(feature.detailRoute(booking.id, role)) }
                            if (role == BookingRole.Bride && booking.status == BookingStatus.AwaitingPayment && !booking.isDemo) {
                                PrimaryButton(stringResource(R.string.booking_action_pay), icon = Icons.Outlined.CreditCard, modifier = Modifier.padding(top = DSSpacing.sm)) {
                                    navigator.navigate(BookingPaymentRoute(booking.id))
                                }
                            }
                        }
                    }
                }
                Spacer(Modifier.height(DSSpacing.lg))
            }
        }
    }
}

@Composable
internal fun BookingRow(booking: BookingSummary, role: BookingRole, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth().clickable(onClick = onClick), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
            StatusPill(booking.status, role)
            if (booking.isDemo) {
                Text(stringResource(R.string.booking_demo_badge), style = DS.type.caption, color = DS.colors.textPrimary,
                    modifier = Modifier.clip(RoundedCornerShape(DSRadius.pill)).background(DS.colors.primaryMuted).padding(horizontal = 8.dp, vertical = 3.dp))
            }
            Spacer(Modifier.weight(1f))
            Text(booking.referenceCode, style = DS.type.caption, color = DS.colors.textSecondary)
        }
        val who = if (role == BookingRole.Bride) booking.provider.name.orEmpty() else booking.brideName.orEmpty()
        Text("${booking.serviceTitle} · $who", style = DS.type.headline, color = DS.colors.textPrimary, maxLines = 2)
        Text("${bookingDateText(booking.startsAt)} · ${formatSar(booking.price)}", style = DS.type.footnote, color = DS.colors.textSecondary)
        // Where the booking stands at a glance, for bookings still in progress.
        if (booking.status.isActive && booking.status.step > 0) ProgressSteps(booking.status.step, Modifier.padding(top = 4.dp))
    }
}

@Composable
internal fun StatusPill(status: BookingStatus, role: BookingRole) {
    val kind = when {
        status == BookingStatus.PaymentConfirmed || status == BookingStatus.Completed -> StatusBadgeKind.Live
        status in setOf(BookingStatus.Declined, BookingStatus.CancelledByBride, BookingStatus.CancelledByProvider, BookingStatus.Expired, BookingStatus.Disputed) -> StatusBadgeKind.Rejected
        status == BookingStatus.AwaitingPayment && role == BookingRole.Bride -> StatusBadgeKind.Action
        status == BookingStatus.PaymentSubmitted && role == BookingRole.Provider -> StatusBadgeKind.Action
        status == BookingStatus.Requested && role == BookingRole.Provider -> StatusBadgeKind.Action
        else -> StatusBadgeKind.Pending
    }
    StatusBadge(kind, bookingString("status.${status.rawValue}"))
}

/** Five-segment progress bar (request → approval → payment → confirmation → done). */
@Composable
internal fun ProgressSteps(step: Int, modifier: Modifier = Modifier) {
    val label = stringResource(R.string.booking_progress_label, step, 5)
    Row(modifier.fillMaxWidth().semantics(mergeDescendants = true) { contentDescription = label }, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        (1..5).forEach { index ->
            // Gold marks the step in progress; the last step (completed) has nothing left to do.
            val color = when {
                index < step || step == 5 -> DS.colors.primary
                index == step -> DS.colors.premiumGold
                else -> DS.colors.border
            }
            Box(Modifier.weight(1f).height(4.dp).clip(RoundedCornerShape(DSRadius.pill)).background(color))
        }
    }
}

