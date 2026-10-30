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
import androidx.compose.material.icons.filled.Lock
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

/** Labels for the choice fields' values, by value (the server's keys). */
private val skinTypeLabels = mapOf(
    "normal" to R.string.catalog_brideDetails_skinType_normal, "dry" to R.string.catalog_brideDetails_skinType_dry,
    "oily" to R.string.catalog_brideDetails_skinType_oily, "combination" to R.string.catalog_brideDetails_skinType_combination,
    "sensitive" to R.string.catalog_brideDetails_skinType_sensitive,
)
private val skinToneLabels = mapOf(
    "light" to R.string.catalog_brideDetails_skinTone_light, "medium" to R.string.catalog_brideDetails_skinTone_medium,
    "tan" to R.string.catalog_brideDetails_skinTone_tan, "deep" to R.string.catalog_brideDetails_skinTone_deep,
)
private val hairTypeLabels = mapOf(
    "straight" to R.string.catalog_brideDetails_hairType_straight, "wavy" to R.string.catalog_brideDetails_hairType_wavy,
    "curly" to R.string.catalog_brideDetails_hairType_curly,
)
private val hairLengthLabels = mapOf(
    "short" to R.string.catalog_brideDetails_hairLength_short, "medium" to R.string.catalog_brideDetails_hairLength_medium,
    "long" to R.string.catalog_brideDetails_hairLength_long,
)

/** A Saudi mobile in any common form (05…, 5…, 9665…, +9665…) → +9665XXXXXXXX; null if not one. */
private fun saudiMobile(text: String): String? {
    var digits = text.map { if (it in '٠'..'٩') '0' + (it - '٠') else it }.filter { it.isDigit() }.joinToString("")
    digits = when {
        digits.startsWith("00966") -> digits.drop(5)
        digits.startsWith("966") -> digits.drop(3)
        else -> digits
    }.removePrefix("0")
    return if (digits.length == 9 && digits.startsWith("5")) "+966$digits" else null
}

/** +9665XXXXXXXX → 05XXXXXXXX, how people write it. */
private fun localPhone(phone: String): String = if (phone.startsWith("+966")) "0" + phone.drop(4) else phone

/** The number in a field, counting Arabic-Indic digits typed on an Arabic keyboard. */
private fun number(text: String): Int? = text.map { if (it in '٠'..'٩') '0' + (it - '٠') else it }.filter { it.isDigit() }.joinToString("").toIntOrNull()

/**
 * "Bride details" (تفاصيل العروس): about her (name, age, nationality, phone; skin and hair;
 * allergies), then the wedding (date, city, venue, guests, notes). Every field is optional. The
 * provider of each of her bookings sees them (name and phone once the payment is confirmed), so the
 * screen says so at the top. The date is the budget's date too. Mirrors iOS `BrideDetailsScreen`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun BrideDetailsScreen(feature: CatalogFeature) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    val store = feature.brideDetails
    val arabic = Locale.getDefault().language == "ar"
    val defaultNationality = stringResource(R.string.catalog_brideDetails_nationality_default)

    var filled by remember { mutableStateOf(false) }
    var fullName by remember { mutableStateOf("") }
    var ageText by remember { mutableStateOf("") }
    var nationality by remember { mutableStateOf("") }
    var extraPhone by remember { mutableStateOf("") }
    var skinType by remember { mutableStateOf("") }
    var skinTone by remember { mutableStateOf("") }
    var hairType by remember { mutableStateOf("") }
    var hairLength by remember { mutableStateOf("") }
    var allergies by remember { mutableStateOf("") }
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

    val age = number(ageText)
    val guestCount = number(guestsText)
    val ageValid = ageText.isEmpty() || (age != null && age in 16..70)
    val guestsValid = guestsText.isEmpty() || (guestCount != null && guestCount in 1..10_000)
    val phoneValid = extraPhone.isBlank() || saudiMobile(extraPhone) != null
    // The number she signed in with: shown, not editable.
    val loginPhone = store.details?.phone ?: feature.context.phone
    val canSave = ageValid && guestsValid && phoneValid && !isSaving

    // Fills the form once from what she saved; her account's name and phone pre-fill empty fields.
    LaunchedEffect(Unit) {
        analytics.screen("bride_details")
        store.load(feature.context.isGuest)
        if (!filled) {
            filled = true
            val saved = store.details
            fullName = saved?.fullName ?: feature.context.displayName.orEmpty()
            ageText = saved?.age?.toString().orEmpty()
            // Saudi by default; she can change it.
            nationality = saved?.nationality ?: defaultNationality
            extraPhone = saved?.extraPhone?.let(::localPhone).orEmpty()
            skinType = saved?.skinType.orEmpty()
            skinTone = saved?.skinTone.orEmpty()
            hairType = saved?.hairType.orEmpty()
            hairLength = saved?.hairLength.orEmpty()
            allergies = saved?.allergies.orEmpty()
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
            fullName = fullName.trim().ifEmpty { null }?.take(80),
            age = age,
            nationality = nationality.trim().ifEmpty { null }?.take(40),
            extraPhone = saudiMobile(extraPhone),
            skinType = skinType.ifEmpty { null },
            skinTone = skinTone.ifEmpty { null },
            hairType = hairType.ifEmpty { null },
            hairLength = hairLength.ifEmpty { null },
            allergies = allergies.trim().ifEmpty { null }?.take(500),
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
            TextButton(enabled = canSave, onClick = ::save) {
                Text(stringResource(R.string.catalog_common_save), color = if (canSave) DS.colors.primary else DS.colors.disabled)
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

            val noneLabel = stringResource(R.string.catalog_brideDetails_none)
            DSFormSection(
                stringResource(R.string.catalog_brideDetails_section_me),
                footer = when {
                    !ageValid -> stringResource(R.string.catalog_brideDetails_age_invalid)
                    !phoneValid -> stringResource(R.string.catalog_brideDetails_phone_invalid)
                    else -> stringResource(R.string.catalog_brideDetails_privacy)
                },
            ) {
                DSTextFieldRow(fullName, { fullName = it }, stringResource(R.string.catalog_brideDetails_name))
                DSFormDivider()
                DSTextFieldRow(ageText, { ageText = it }, stringResource(R.string.catalog_brideDetails_age), keyboardType = KeyboardType.Number)
                DSFormDivider()
                DSTextFieldRow(nationality, { nationality = it }, stringResource(R.string.catalog_brideDetails_nationality))
                if (loginPhone != null) {
                    DSFormDivider()
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = DSSpacing.md),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
                    ) {
                        Text(stringResource(R.string.catalog_brideDetails_phone), style = DS.type.body, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                        Text(localPhone(loginPhone), style = DS.type.body, color = DS.colors.textSecondary)
                        Icon(Icons.Filled.Lock, contentDescription = stringResource(R.string.catalog_brideDetails_phone_locked), tint = DS.colors.textSecondary, modifier = Modifier.size(16.dp))
                    }
                }
                DSFormDivider()
                DSTextFieldRow(extraPhone, { extraPhone = it }, stringResource(R.string.catalog_brideDetails_extraPhone), keyboardType = KeyboardType.Phone)
            }
            DSFormSection(stringResource(R.string.catalog_brideDetails_section_looks)) {
                ChoiceRow(stringResource(R.string.catalog_brideDetails_skinType), skinTypeLabels, skinType, noneLabel) { skinType = it }
                DSFormDivider()
                ChoiceRow(stringResource(R.string.catalog_brideDetails_skinTone), skinToneLabels, skinTone, noneLabel) { skinTone = it }
                DSFormDivider()
                ChoiceRow(stringResource(R.string.catalog_brideDetails_hairType), hairTypeLabels, hairType, noneLabel) { hairType = it }
                DSFormDivider()
                ChoiceRow(stringResource(R.string.catalog_brideDetails_hairLength), hairLengthLabels, hairLength, noneLabel) { hairLength = it }
            }
            DSFormSection(stringResource(R.string.catalog_brideDetails_allergies)) {
                DSTextFieldRow(allergies, { allergies = it }, stringResource(R.string.catalog_brideDetails_allergies_placeholder), minLines = 2)
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

/** A picker over one choice field, with «لم تُحدَّد» first. */
@Composable
private fun ChoiceRow(title: String, labels: Map<String, Int>, selected: String, noneLabel: String, onSelect: (String) -> Unit) {
    val names = labels.mapValues { stringResource(it.value) }
    DSPickerRow(
        title = title,
        options = listOf("") + labels.keys,
        selected = selected,
        label = { if (it.isEmpty()) noneLabel else names[it] ?: it },
        onSelect = onSelect,
    )
}

private fun displayDay(millis: Long): String =
    SimpleDateFormat("d MMMM yyyy", Locale.getDefault()).apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }.format(millis)
