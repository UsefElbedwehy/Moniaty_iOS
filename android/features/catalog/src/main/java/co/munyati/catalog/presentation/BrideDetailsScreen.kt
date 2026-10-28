package co.munyati.catalog.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import co.munyati.catalog.R
import co.munyati.catalog.domain.BrideDetails
import co.munyati.designsystem.components.DSFormDivider
import co.munyati.designsystem.components.DSFormSection
import co.munyati.designsystem.components.DSPickerRow
import co.munyati.designsystem.components.DSTextFieldRow
import co.munyati.designsystem.components.DSToggleRow
import co.munyati.designsystem.components.DSTopBar
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.Locale

/**
 * "Bride details" (تفاصيل العروس): the wedding date and city, the venue, the number of guests and
 * notes. Filled once from Profile; the provider of each of her bookings sees them, so the screen
 * says so at the top. The date is the budget's date too. Mirrors iOS `BrideDetailsScreen`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun BrideDetailsScreen(feature: CatalogFeature) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    val store = feature.brideDetails
    val arabic = Locale.getDefault().language == "ar"

    var filled by remember { mutableStateOf(false) }
    var hasDate by remember { mutableStateOf(false) }
    val today = remember { LocalDate.now(ZoneOffset.UTC).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() }
    val dateState = rememberDatePickerState(
        initialSelectedDateMillis = LocalDate.now().plusMonths(3).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        selectableDates = object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis >= today
        },
    )
    var pickingDate by remember { mutableStateOf(false) }
    var cityId by remember { mutableStateOf("") }
    var venue by remember { mutableStateOf("") }
    var guestsText by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    var isSaving by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }

    // Arabic-Indic digits typed on an Arabic keyboard count too.
    val guestCount = guestsText.map { if (it in '٠'..'٩') '0' + (it - '٠') else it }.filter { it.isDigit() }.joinToString("").toIntOrNull()
    val guestsValid = guestsText.isEmpty() || (guestCount != null && guestCount in 1..10_000)

    // Fills the form once from what she saved (not again after edits start).
    LaunchedEffect(Unit) {
        analytics.screen("bride_details")
        store.load(feature.context.isGuest)
        if (!filled) {
            filled = true
            val saved = store.details
            (saved?.weddingDate ?: feature.weddingDate)?.let { day ->
                runCatching { LocalDate.parse(day).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() }.getOrNull()?.let {
                    hasDate = true
                    dateState.selectedDateMillis = it
                }
            }
            cityId = saved?.cityId.orEmpty()
            venue = saved?.venue.orEmpty()
            guestsText = saved?.guestCount?.toString().orEmpty()
            notes = saved?.notes.orEmpty()
        }
    }

    fun save() {
        val day = dateState.selectedDateMillis?.let { java.time.Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate().toString() }
        val details = BrideDetails(
            weddingDate = if (hasDate) day else null,
            cityId = cityId.ifEmpty { null },
            venue = venue.trim().ifEmpty { null }?.take(120),
            guestCount = guestCount,
            notes = notes.trim().ifEmpty { null }?.take(1000),
        )
        isSaving = true
        scope.launch {
            try {
                store.save(details)
                feature.refreshBudget() // the date is the budget's date too
                navigator.back()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                failed = true
            } finally {
                isSaving = false
            }
        }
    }

    Column(Modifier.fillMaxSize().background(DS.colors.surface)) {
        DSTopBar(stringResource(R.string.catalog_brideDetails_title), navigator.back, stringResource(R.string.catalog_back)) {
            TextButton(enabled = !isSaving && guestsValid, onClick = ::save) {
                Text(stringResource(R.string.catalog_common_save), color = if (guestsValid) DS.colors.primary else DS.colors.disabled)
            }
        }
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.lg),
        ) {
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(DSRadius.card / 2 + 4.dp)).background(DS.colors.background).padding(DSSpacing.md),
                horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Outlined.Info, contentDescription = null, tint = DS.colors.textSecondary, modifier = Modifier.size(20.dp))
                Text(stringResource(R.string.catalog_brideDetails_intro), style = DS.type.footnote, color = DS.colors.textSecondary)
            }

            DSFormSection(stringResource(R.string.catalog_brideDetails_section_wedding)) {
                DSToggleRow(stringResource(R.string.catalog_budget_hasDate), hasDate) { hasDate = it }
                if (hasDate) {
                    DSFormDivider()
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Button) { pickingDate = true }.padding(horizontal = DSSpacing.md),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(stringResource(R.string.catalog_budget_date), style = DS.type.body, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                        Text(dateState.selectedDateMillis?.let { displayDay(it) }.orEmpty(), style = DS.type.body, color = DS.colors.primary)
                    }
                }
                DSFormDivider()
                val options = listOf("") + feature.context.cities.map { it.id }
                val noneLabel = stringResource(R.string.catalog_brideDetails_city_none)
                DSPickerRow(
                    title = stringResource(R.string.catalog_brideDetails_city),
                    options = options,
                    selected = cityId,
                    label = { id ->
                        val city = feature.context.cities.firstOrNull { it.id == id }
                        when {
                            city == null -> noneLabel
                            arabic -> city.nameAr
                            else -> city.nameEn
                        }
                    },
                    onSelect = { cityId = it },
                )
            }
            DSFormSection(stringResource(R.string.catalog_brideDetails_venue)) {
                DSTextFieldRow(venue, { venue = it }, stringResource(R.string.catalog_brideDetails_venue_placeholder))
            }
            DSFormSection(
                stringResource(R.string.catalog_brideDetails_guests),
                footer = if (guestsValid) null else stringResource(R.string.catalog_brideDetails_guests_invalid),
            ) {
                DSTextFieldRow(guestsText, { guestsText = it }, stringResource(R.string.catalog_brideDetails_guests_placeholder), keyboardType = KeyboardType.Number)
            }
            DSFormSection(stringResource(R.string.catalog_brideDetails_notes)) {
                DSTextFieldRow(notes, { notes = it }, stringResource(R.string.catalog_brideDetails_notes_placeholder), minLines = 3)
            }
        }
    }

    if (pickingDate) {
        DatePickerDialog(
            onDismissRequest = { pickingDate = false },
            confirmButton = { TextButton(onClick = { pickingDate = false }) { Text(stringResource(R.string.catalog_common_ok)) } },
        ) { DatePicker(dateState) }
    }
    if (failed) {
        AlertDialog(
            onDismissRequest = { failed = false },
            confirmButton = { TextButton(onClick = { failed = false }) { Text(stringResource(R.string.catalog_common_ok)) } },
            text = { Text(stringResource(R.string.catalog_common_saveFailed)) },
        )
    }
}

private fun displayDay(millis: Long): String =
    SimpleDateFormat("d MMMM yyyy", Locale.getDefault()).apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }.format(millis)
