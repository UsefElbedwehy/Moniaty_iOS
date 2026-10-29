@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package co.munyati.booking.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import co.munyati.booking.R
import co.munyati.booking.domain.ActionResult
import co.munyati.booking.domain.Availability
import co.munyati.booking.domain.PaymentMethod
import co.munyati.booking.domain.PaymentMethodDraft
import co.munyati.core.dates.DisplayDates
import co.munyati.core.error.AppError
import co.munyati.core.state.ViewState
import co.munyati.designsystem.components.DSFormDivider
import co.munyati.designsystem.components.DSFormSection
import co.munyati.designsystem.components.DSPickerRow
import co.munyati.designsystem.components.DSTextFieldRow
import co.munyati.designsystem.components.DSToggleRow
import co.munyati.designsystem.components.DSTopBar
import co.munyati.designsystem.components.EmptyStateView
import co.munyati.designsystem.components.ErrorStateView
import co.munyati.designsystem.components.TopBarIconButton
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.TextStyle
import java.util.Locale

@Composable
private fun SaveAction(enabled: Boolean, onClick: () -> Unit) {
    TextButton(onClick = onClick, enabled = enabled) {
        Text(stringResource(R.string.booking_common_save), style = DS.type.headline, color = if (enabled) DS.colors.primary else DS.colors.disabled)
    }
}

// Availability (provider studio)

private data class Day(val weekday: Int, val isOpen: Boolean, val start: LocalTime, val end: LocalTime)

private fun parseTime(hhmm: String): LocalTime = runCatching { LocalTime.parse(hhmm.take(5)) }.getOrDefault(LocalTime.of(10, 0))
private fun hhmm(time: LocalTime) = "%02d:%02d".format(time.hour, time.minute)

/** 0 = Sunday, matching Postgres `extract(dow …)`. */
private fun weekdayName(weekday: Int): String =
    DayOfWeek.of(if (weekday == 0) 7 else weekday).getDisplayName(TextStyle.FULL, Locale.getDefault())

/** One available date and its hours ("dates" mode). */
private data class DateSlot(val day: LocalDate, val start: LocalTime, val end: LocalTime)

/**
 * How the provider takes bookings, and when: weekly hours (one range per weekday) with days off; or
 * specific dates, each with its hours; or on request (the bride picks any date and time and the
 * provider accepts or declines). Mirrors iOS `AvailabilityScreen`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun AvailabilityScreen(feature: BookingFeature) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val days = remember { mutableStateListOf<Day>() }
    val daysOff = remember { mutableStateListOf<LocalDate>() }
    var state: ViewState<Boolean> by remember { mutableStateOf(ViewState.Loading) }
    var isSaving by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var picking by remember { mutableStateOf<Pair<Int, Boolean>?>(null) } // (weekday, isStart)
    var addingDayOff by remember { mutableStateOf(false) }
    var mode by remember { mutableStateOf("weekly") }
    val dates = remember { mutableStateListOf<DateSlot>() }
    var addingDate by remember { mutableStateOf(false) }
    var pickingDateTime by remember { mutableStateOf<Pair<Int, Boolean>?>(null) } // (index in dates, isStart)
    val isValid = days.all { !it.isOpen || it.start < it.end } && dates.all { it.start < it.end }

    suspend fun load() {
        try {
            val availability = feature.repository.availability()
            days.clear()
            days.addAll((0..6).map { weekday ->
                availability.rules.firstOrNull { it.weekday == weekday }
                    ?.let { Day(weekday, true, parseTime(it.startTime), parseTime(it.endTime)) }
                    ?: Day(weekday, false, LocalTime.of(10, 0), LocalTime.of(22, 0))
            })
            daysOff.clear()
            daysOff.addAll(availability.daysOff.mapNotNull { runCatching { LocalDate.parse(it) }.getOrNull() }.sorted())
            mode = availability.mode ?: "weekly"
            dates.clear()
            dates.addAll(availability.dates.orEmpty().mapNotNull { w ->
                runCatching { LocalDate.parse(w.day) }.getOrNull()?.let { DateSlot(it, parseTime(w.startTime), parseTime(w.endTime)) }
            })
            state = ViewState.Loaded(true)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            state = ViewState.Error(AppError.from(e))
        }
    }
    LaunchedEffect(Unit) {
        analytics.screen("studio_availability")
        load()
    }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.booking_availability_title), navigator.back, stringResource(R.string.booking_back)) {
            SaveAction(!isSaving && state.value != null && isValid) {
                isSaving = true
                scope.launch {
                    try {
                        feature.repository.saveAvailability(Availability(
                            rules = days.filter { it.isOpen }.map { Availability.Rule(it.weekday, hhmm(it.start), hhmm(it.end)) },
                            daysOff = daysOff.map { it.toString() },
                            mode = mode,
                            dates = dates.map { Availability.DateWindow(it.day.toString(), hhmm(it.start), hhmm(it.end)) },
                        ))
                        navigator.back()
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        message = context.getString(R.string.booking_error_generic)
                    } finally {
                        isSaving = false
                    }
                }
            }
        }
        when (val s = state) {
            ViewState.Loading -> Spinner(Modifier.padding(top = 120.dp))
            is ViewState.Error -> ErrorStateView(s.error) { scope.launch { load() } }
            else -> Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.lg)) {
                val modes = listOf(
                    "weekly" to R.string.booking_availability_mode_weekly,
                    "dates" to R.string.booking_availability_mode_dates,
                    "request" to R.string.booking_availability_mode_request,
                )
                val footer = mapOf(
                    "weekly" to R.string.booking_availability_mode_footer_weekly,
                    "dates" to R.string.booking_availability_mode_footer_dates,
                    "request" to R.string.booking_availability_mode_footer_request,
                )
                DSFormSection(stringResource(R.string.booking_availability_mode), footer = stringResource(footer.getValue(mode))) {
                    modes.forEachIndexed { index, (value, label) ->
                        if (index > 0) DSFormDivider()
                        Row(
                            Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.RadioButton) { mode = value }.padding(horizontal = DSSpacing.md),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(stringResource(label), style = DS.type.body, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                            if (mode == value) Icon(Icons.Filled.Check, contentDescription = null, tint = DS.colors.primary)
                        }
                    }
                }
                if (mode == "dates") {
                    DSFormSection(stringResource(R.string.booking_availability_dates)) {
                        if (dates.isEmpty()) {
                            Text(stringResource(R.string.booking_availability_dates_empty), style = DS.type.body, color = DS.colors.textSecondary,
                                modifier = Modifier.padding(DSSpacing.md))
                        }
                        dates.forEachIndexed { index, slot ->
                            if (index > 0) DSFormDivider()
                            Column(Modifier.padding(horizontal = DSSpacing.md, vertical = DSSpacing.xs)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    val instant = slot.day.atStartOfDay(ZoneId.systemDefault()).plusHours(12).toInstant()
                                    Text(DisplayDates.pattern(instant, "EEEEdMMMM"), style = DS.type.headline, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                                    Icon(Icons.Outlined.Delete, contentDescription = stringResource(R.string.booking_delete), tint = DS.colors.error,
                                        modifier = Modifier.clickable(role = Role.Button) { dates.removeAt(index) }.padding(DSSpacing.xs))
                                }
                                Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
                                    TimeChip(stringResource(R.string.booking_availability_from), slot.start) { pickingDateTime = index to true }
                                    TimeChip(stringResource(R.string.booking_availability_to), slot.end) { pickingDateTime = index to false }
                                }
                            }
                        }
                        DSFormDivider()
                        Row(
                            Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Button) { addingDate = true }.padding(horizontal = DSSpacing.md),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
                        ) {
                            Icon(Icons.Filled.Add, contentDescription = null, tint = DS.colors.primary)
                            Text(stringResource(R.string.booking_availability_addDate), style = DS.type.body, color = DS.colors.primary)
                        }
                    }
                }
                if (mode == "weekly") WeeklySections(days, daysOff, onPick = { picking = it }, onAddDayOff = { addingDayOff = true })
            }
        }
    }

    pickingDateTime?.let { (index, isStart) ->
        val slot = dates[index]
        TimeDialog(if (isStart) slot.start else slot.end, onDismiss = { pickingDateTime = null }) { time ->
            dates[index] = if (isStart) slot.copy(start = time) else slot.copy(end = time)
        }
    }
    if (addingDate) {
        val today = LocalDate.now().atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        val pickerState = rememberDatePickerState(
            initialSelectedDateMillis = today,
            selectableDates = object : SelectableDates { override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis >= today },
        )
        DatePickerDialog(onDismissRequest = { addingDate = false }, confirmButton = {
            TextButton(onClick = {
                pickerState.selectedDateMillis?.let {
                    val day = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()
                    dates.add(DateSlot(day, LocalTime.of(16, 0), LocalTime.of(22, 0)))
                    dates.sortBy { slot -> slot.day }
                }
                addingDate = false
            }) { Text(stringResource(R.string.booking_common_ok)) }
        }) { DatePicker(pickerState) }
    }
    WeeklyDialogs(days, daysOff, picking, addingDayOff, onPickDone = { picking = null }, onAddDayOffDone = { addingDayOff = false })
    MessageDialog(message) { message = null }
}

/** "weekly" mode: the hours for each weekday and the days off. */
@Composable
private fun WeeklySections(days: MutableList<Day>, daysOff: MutableList<LocalDate>, onPick: (Pair<Int, Boolean>) -> Unit, onAddDayOff: () -> Unit) {
                DSFormSection(stringResource(R.string.booking_availability_weekly), footer = stringResource(R.string.booking_availability_weeklyFooter)) {
                    days.forEachIndexed { index, day ->
                        if (index > 0) DSFormDivider()
                        Column(Modifier.padding(horizontal = DSSpacing.md, vertical = DSSpacing.xs)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(weekdayName(day.weekday), style = DS.type.headline, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                                Switch(day.isOpen, { days[index] = day.copy(isOpen = it) }, colors = SwitchDefaults.colors(checkedTrackColor = DS.colors.primary))
                            }
                            if (day.isOpen) {
                                Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
                                    TimeChip(stringResource(R.string.booking_availability_from), day.start) { onPick(day.weekday to true) }
                                    TimeChip(stringResource(R.string.booking_availability_to), day.end) { onPick(day.weekday to false) }
                                }
                            }
                        }
                    }
                }
                DSFormSection(stringResource(R.string.booking_availability_daysOff)) {
                    daysOff.forEach { day ->
                        Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).padding(horizontal = DSSpacing.md), verticalAlignment = Alignment.CenterVertically) {
                            val instant = day.atStartOfDay(ZoneId.systemDefault()).plusHours(12).toInstant()
                            Text(DisplayDates.pattern(instant, "EEEEdMMMM"), style = DS.type.body, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                            Icon(Icons.Outlined.Delete, contentDescription = stringResource(R.string.booking_delete), tint = DS.colors.error,
                                modifier = Modifier.clickable(role = Role.Button) { daysOff.remove(day) }.padding(DSSpacing.xs))
                        }
                        DSFormDivider()
                    }
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Button, onClick = onAddDayOff).padding(horizontal = DSSpacing.md),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
                    ) {
                        Icon(Icons.Filled.Add, contentDescription = null, tint = DS.colors.primary)
                        Text(stringResource(R.string.booking_availability_addDayOff), style = DS.type.body, color = DS.colors.primary)
                    }
                }
}

/** The weekly mode's time and day-off pickers. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WeeklyDialogs(
    days: MutableList<Day>, daysOff: MutableList<LocalDate>, picking: Pair<Int, Boolean>?, addingDayOff: Boolean,
    onPickDone: () -> Unit, onAddDayOffDone: () -> Unit,
) {
    picking?.let { (weekday, isStart) ->
        val index = days.indexOfFirst { it.weekday == weekday }
        val day = days[index]
        TimeDialog(if (isStart) day.start else day.end, onDismiss = onPickDone) { time ->
            days[index] = if (isStart) day.copy(start = time) else day.copy(end = time)
        }
    }
    if (addingDayOff) {
        val today = LocalDate.now().atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        val pickerState = rememberDatePickerState(
            initialSelectedDateMillis = today,
            selectableDates = object : SelectableDates { override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis >= today },
        )
        DatePickerDialog(onDismissRequest = onAddDayOffDone, confirmButton = {
            TextButton(onClick = {
                pickerState.selectedDateMillis?.let {
                    val day = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()
                    if (day !in daysOff) { daysOff.add(day); daysOff.sort() }
                }
                onAddDayOffDone()
            }) { Text(stringResource(R.string.booking_common_ok)) }
        }) { DatePicker(pickerState) }
    }
}

@Composable
private fun TimeChip(label: String, time: LocalTime, onClick: () -> Unit) {
    val instant = LocalDate.now().atTime(time).atZone(ZoneId.systemDefault()).toInstant()
    Row(Modifier.clickable(role = Role.Button, onClick = onClick).heightIn(min = 44.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, style = DS.type.footnote, color = DS.colors.textSecondary)
        Text(DisplayDates.pattern(instant, "jmm"), style = DS.type.subhead, color = DS.colors.primary)
    }
}

// Payment methods (provider studio)

/** Where brides transfer money. Approved bookings keep a snapshot, so edits never change them. */
@Composable
internal fun PaymentMethodsScreen(feature: BookingFeature) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var state: ViewState<List<PaymentMethod>> by remember { mutableStateOf(ViewState.Loading) }
    var deleting by remember { mutableStateOf<PaymentMethod?>(null) }
    var deleteFailed by remember { mutableStateOf(false) }

    suspend fun load() {
        val fresh = loadState({ it.isEmpty() }) { feature.repository.paymentMethods() }
        if (fresh is ViewState.Error && state.value != null) return
        state = fresh
    }
    LaunchedEffect(Unit) { analytics.screen("studio_payment_methods") }
    androidx.lifecycle.compose.LifecycleEventEffect(androidx.lifecycle.Lifecycle.Event.ON_RESUME) { scope.launch { load() } }
    LaunchedEffect(Unit) { load() }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.booking_methods_title), navigator.back, stringResource(R.string.booking_back)) {
            TopBarIconButton(Icons.Filled.Add, stringResource(R.string.booking_methods_add)) { navigator.navigate(PaymentMethodEditRoute()) }
        }
        when (val s = state) {
            ViewState.Loading -> Spinner(Modifier.padding(top = 120.dp))
            is ViewState.Error -> ErrorStateView(s.error) { scope.launch { load() } }
            ViewState.Offline -> ErrorStateView(AppError.Offline) { scope.launch { load() } }
            ViewState.Empty -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                EmptyStateView(Icons.Outlined.Payments, stringResource(R.string.booking_methods_empty_title), stringResource(R.string.booking_methods_empty_message))
            }
            is ViewState.Loaded, is ViewState.Refreshing -> Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg)) {
                DSFormSection(footer = stringResource(R.string.booking_methods_footer)) {
                    s.value.orEmpty().forEachIndexed { index, method ->
                        if (index > 0) DSFormDivider()
                        Row(
                            Modifier.fillMaxWidth().clickable { navigator.navigate(PaymentMethodEditRoute(method.id)) }.padding(horizontal = DSSpacing.md, vertical = DSSpacing.sm),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Row {
                                    Text(method.label, style = DS.type.headline, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                                    if (!method.isActive) Text(stringResource(R.string.booking_methods_inactive), style = DS.type.caption, color = DS.colors.textSecondary)
                                }
                                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                                    Text("${bookingString("method.${method.kind}")} · ${method.value}", style = DS.type.footnote, color = DS.colors.textSecondary)
                                }
                            }
                            Icon(Icons.Outlined.Delete, contentDescription = stringResource(R.string.booking_delete), tint = DS.colors.error,
                                modifier = Modifier.clickable(role = Role.Button) { deleting = method }.padding(DSSpacing.xs))
                        }
                    }
                }
            }
        }
    }

    deleting?.let { method ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            title = { Text(stringResource(R.string.booking_delete_confirm)) },
            confirmButton = {
                TextButton(onClick = {
                    deleting = null
                    scope.launch {
                        runCatching { feature.repository.deletePaymentMethod(method.id) }.onFailure { deleteFailed = true }
                        load()
                    }
                }) { Text(stringResource(R.string.booking_delete), color = DS.colors.error) }
            },
            dismissButton = { TextButton(onClick = { deleting = null }) { Text(stringResource(R.string.booking_common_cancel)) } },
        )
    }
    MessageDialog(if (deleteFailed) stringResource(R.string.booking_error_generic) else null) { deleteFailed = false }
}

private val kinds = listOf("iban", "sarie_alias", "wallet")

@Composable
internal fun PaymentMethodEditor(feature: BookingFeature, methodId: String?) {
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var draft by remember { mutableStateOf(PaymentMethodDraft()) }
    var loaded by remember { mutableStateOf(methodId == null) }
    var isSaving by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(methodId) {
        if (methodId != null) {
            runCatching { feature.repository.paymentMethods() }.getOrNull()?.firstOrNull { it.id == methodId }?.let { draft = PaymentMethodDraft(it) }
            loaded = true
        }
    }
    val kindLabels = kinds.associateWith { bookingString("method.$it") }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(if (draft.id == null) R.string.booking_methods_add else R.string.booking_methods_edit), navigator.back, stringResource(R.string.booking_back)) {
            SaveAction(loaded && !isSaving && draft.isValid) {
                isSaving = true
                scope.launch {
                    try {
                        when (val result = feature.repository.savePaymentMethod(draft)) {
                            is ActionResult.Ok -> navigator.back()
                            is ActionResult.Refused -> message = refusal(context, result.code)
                        }
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        message = context.getString(R.string.booking_error_generic)
                    } finally {
                        isSaving = false
                    }
                }
            }
        }
        if (!loaded) {
            Spinner(Modifier.padding(top = 120.dp))
            return@Column
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg)) {
            DSFormSection(footer = bookingString("methods.hint.${draft.kind}")) {
                DSPickerRow(stringResource(R.string.booking_methods_kind), kinds, draft.kind, label = { kindLabels.getValue(it) }) { draft = draft.copy(kind = it) }
                DSFormDivider()
                DSTextFieldRow(draft.label, { draft = draft.copy(label = it) }, stringResource(R.string.booking_methods_label))
                DSFormDivider()
                DSTextFieldRow(draft.accountName, { draft = draft.copy(accountName = it) }, stringResource(R.string.booking_methods_accountName))
                DSFormDivider()
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                    DSTextFieldRow(draft.value, { draft = draft.copy(value = if (draft.kind == "iban") it.uppercase() else it) }, bookingString("methods.value.${draft.kind}"),
                        keyboardType = if (draft.kind == "iban") KeyboardType.Ascii else KeyboardType.Phone)
                }
                DSFormDivider()
                DSToggleRow(stringResource(R.string.booking_methods_active), draft.isActive) { draft = draft.copy(isActive = it) }
            }
        }
    }
    MessageDialog(message) { message = null }
}

