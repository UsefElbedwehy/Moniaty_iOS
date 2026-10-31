package co.munyati.catalog.presentation

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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberDatePickerState
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import co.munyati.catalog.R
import co.munyati.catalog.data.SEARCH_PAGE_SIZE
import co.munyati.catalog.domain.CatalogCategory
import co.munyati.catalog.domain.HomeContent
import co.munyati.catalog.domain.ServiceCard
import co.munyati.catalog.domain.ServiceFilter
import co.munyati.core.error.AppError
import co.munyati.core.state.ViewState
import co.munyati.designsystem.components.Chip
import co.munyati.designsystem.components.DSTopBar
import co.munyati.designsystem.components.TopBarIconButton
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.analytics.AnalyticsEvent
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.Locale

// Services list (category, search, "within budget")

@Composable
internal fun ServiceListScreen(feature: CatalogFeature, initialFilter: ServiceFilter) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var filter by remember { mutableStateOf(initialFilter) }
    var state: ViewState<List<ServiceCard>> by remember { mutableStateOf(ViewState.Loading) }
    var canLoadMore by remember { mutableStateOf(true) }
    val isSearch = filter.categoryId == null

    suspend fun load(reset: Boolean) {
        val current = if (reset) emptyList() else state.value.orEmpty()
        if (reset) state = ViewState.Loading
        try {
            val page = feature.repository.search(filter, feature.context.cityIds, feature.budget.maxPrice, current.size)
            val all = current + page
            canLoadMore = page.size >= SEARCH_PAGE_SIZE
            state = if (all.isEmpty()) ViewState.Empty else ViewState.Loaded(all)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            canLoadMore = false
            if (current.isEmpty()) state = ViewState.Error(AppError.from(e))
        }
    }

    LaunchedEffect(filter, feature.context.cityIds, feature.context.audience) {
        // Debounce typing.
        if (isSearch && filter.query.isNotEmpty()) delay(350)
        load(reset = true)
    }
    LaunchedEffect(Unit) { analytics.screen(if (isSearch) "search" else "category") }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(filter.title ?: stringResource(R.string.catalog_search_title), navigator.back, stringResource(R.string.catalog_back))
        SearchField(filter.query, onChange = { filter = filter.copy(query = it) }) {
            analytics(AnalyticsEvent.Search, props = mapOf("query" to filter.query))
        }
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.md),
        ) {
            FilterBar(feature, filter) { filter = it }
            LoadableContent(
                state,
                retry = { scope.launch { load(reset = true) } },
                emptyTitle = R.string.catalog_list_empty_title,
                emptyMessage = R.string.catalog_list_empty_message,
            ) { cards ->
                Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.md), horizontalAlignment = Alignment.CenterHorizontally) {
                    ServiceGrid(cards, feature)
                    if (canLoadMore) {
                        CircularProgressIndicator(color = DS.colors.primary, strokeWidth = 2.dp, modifier = Modifier.size(24.dp))
                        LaunchedEffect(cards.size) { load(reset = false) }
                    }
                }
            }
        }
    }
}

@Composable
private fun SearchField(query: String, onChange: (String) -> Unit, onSubmit: () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    BasicTextField(
        value = query,
        onValueChange = onChange,
        singleLine = true,
        textStyle = DS.type.body.copy(color = DS.colors.textPrimary),
        cursorBrush = SolidColor(DS.colors.primary),
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
        keyboardActions = KeyboardActions(onSearch = { onSubmit() }),
        modifier = Modifier.fillMaxWidth().padding(horizontal = DSSpacing.lg),
        decorationBox = { inner ->
            Row(
                Modifier.fillMaxWidth().heightIn(min = 44.dp).clip(shape).background(DS.colors.elevated).padding(horizontal = DSSpacing.sm),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
            ) {
                Icon(Icons.Outlined.Search, contentDescription = null, tint = DS.colors.textSecondary, modifier = Modifier.size(20.dp))
                Box(Modifier.weight(1f)) {
                    if (query.isEmpty()) Text(stringResource(R.string.catalog_search_placeholder), style = DS.type.body, color = DS.colors.textSecondary)
                    inner()
                }
                if (query.isNotEmpty()) {
                    Icon(
                        Icons.Outlined.Close,
                        contentDescription = stringResource(R.string.catalog_search_clear),
                        tint = DS.colors.textSecondary,
                        modifier = Modifier.size(20.dp).clickable { onChange("") },
                    )
                }
            }
        },
    )
}

@Composable
private fun FilterBar(feature: CatalogFeature, filter: ServiceFilter, onChange: (ServiceFilter) -> Unit) {
    var sortOpen by remember { mutableStateOf(false) }
    var pickingDate by remember { mutableStateOf(false) }
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs), verticalAlignment = Alignment.CenterVertically) {
        if (feature.budget.budget != null) {
            Chip(stringResource(R.string.catalog_filter_withinBudget), filter.withinBudget) { onChange(filter.copy(withinBudget = !filter.withinBudget)) }
        }
        Chip(stringResource(R.string.catalog_filter_femaleOnly), filter.femaleOnly) { onChange(filter.copy(femaleOnly = !filter.femaleOnly)) }
        // «التاريخ المتاح»: only services with a free time that day.
        Chip(filter.date?.let { dayChipLabel(it) } ?: stringResource(R.string.catalog_filter_date), filter.date != null) { pickingDate = true }
        Box {
            val shape = RoundedCornerShape(DSRadius.pill)
            Row(
                Modifier.heightIn(min = 36.dp).clip(shape).border(1.dp, DS.colors.border, shape)
                    .clickable(role = Role.DropdownList, onClickLabel = stringResource(R.string.catalog_sort_title)) { sortOpen = true }
                    .padding(horizontal = DSSpacing.sm),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(Icons.AutoMirrored.Filled.Sort, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(18.dp))
                Text(sortLabel(filter.sort), style = DS.type.subhead, color = DS.colors.primary)
            }
            DropdownMenu(expanded = sortOpen, onDismissRequest = { sortOpen = false }) {
                ServiceFilter.Sort.entries.forEach { sort ->
                    DropdownMenuItem(text = { Text(sortLabel(sort)) }, onClick = {
                        sortOpen = false
                        onChange(filter.copy(sort = sort))
                    })
                }
            }
        }
    }
    if (pickingDate) DateFilterDialog(filter.date, onDone = { onChange(filter.copy(date = it)); pickingDate = false }, onDismiss = { pickingDate = false })
}

@Composable
private fun sortLabel(sort: ServiceFilter.Sort) = stringResource(
    when (sort) {
        ServiceFilter.Sort.Recommended -> R.string.catalog_sort_recommended
        ServiceFilter.Sort.PriceAsc -> R.string.catalog_sort_price_asc
        ServiceFilter.Sort.PriceDesc -> R.string.catalog_sort_price_desc
        ServiceFilter.Sort.Newest -> R.string.catalog_sort_newest
    },
)

// Favorites

@Composable
internal fun FavoritesScreen(feature: CatalogFeature) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var state: ViewState<List<ServiceCard>> by remember { mutableStateOf(ViewState.Loading) }

    suspend fun load() {
        if (feature.context.isGuest) {
            state = ViewState.Empty
            return
        }
        state = try {
            feature.repository.favorites().let { if (it.isEmpty()) ViewState.Empty else ViewState.Loaded(it) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            ViewState.Error(AppError.from(e))
        }
    }
    LaunchedEffect(Unit) {
        analytics.screen("favorites")
        load()
    }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.catalog_favorites_title), navigator.back, stringResource(R.string.catalog_back))
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg)) {
            LoadableContent(
                state,
                retry = { scope.launch { load() } },
                emptyTitle = R.string.catalog_favorites_empty_title,
                emptyMessage = R.string.catalog_favorites_empty_message,
            ) { ServiceGrid(it, feature) }
        }
    }
}

// Budget editor

/** "yyyy-MM-dd" in the Gregorian calendar, the format the budget RPC stores. */
private fun dayString(millis: Long): String = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate().toString()

private fun dayMillis(day: String): Long? =
    runCatching { LocalDate.parse(day).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() }.getOrNull()

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun BudgetSheet(store: BudgetStore, onDismiss: () -> Unit) {
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    val existing = store.budget
    var amountText by remember { mutableStateOf(existing?.total?.let { formatPlain(it) }.orEmpty()) }
    var hasDate by remember { mutableStateOf(existing?.weddingDate != null) }
    val today = remember { LocalDate.now(ZoneOffset.UTC).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() }
    val dateState = rememberDatePickerState(
        initialSelectedDateMillis = existing?.weddingDate?.let(::dayMillis) ?: LocalDate.now().plusMonths(3).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        selectableDates = object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis >= today
        },
    )
    var pickingDate by remember { mutableStateOf(false) }
    var isSaving by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    val amount = amountText.map { if (it in '٠'..'٩') '0' + (it - '٠') else it }.filter { it.isDigit() }.joinToString("").toDoubleOrNull()

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = DS.colors.background) {
        Column(Modifier.fillMaxWidth().padding(horizontal = DSSpacing.lg).padding(bottom = DSSpacing.xl), verticalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) { Text(stringResource(R.string.catalog_common_cancel), color = DS.colors.primary) }
                Text(stringResource(R.string.catalog_budget_title), style = DS.type.headline, color = DS.colors.textPrimary, modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                TextButton(
                    enabled = amount != null && !isSaving,
                    onClick = {
                        val total = amount ?: return@TextButton
                        isSaving = true
                        scope.launch {
                            try {
                                store.save(total, if (hasDate) dateState.selectedDateMillis?.let(::dayString) else null)
                                analytics(AnalyticsEvent.BudgetSet, props = mapOf("amount" to formatPlain(total)))
                                onDismiss()
                            } catch (e: CancellationException) {
                                throw e
                            } catch (e: Exception) {
                                failed = true
                            } finally {
                                isSaving = false
                            }
                        }
                    },
                ) { Text(stringResource(R.string.catalog_common_save), color = if (amount != null) DS.colors.primary else DS.colors.disabled) }
            }

            Text(stringResource(R.string.catalog_budget_amount), style = DS.type.footnote, color = DS.colors.textSecondary)
            BasicTextField(
                value = amountText,
                onValueChange = { amountText = it.filter { c -> c.isDigit() } },
                singleLine = true,
                textStyle = DS.type.title2.copy(color = DS.colors.textPrimary),
                cursorBrush = SolidColor(DS.colors.primary),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                decorationBox = { inner ->
                    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(DSRadius.control)).background(DS.colors.surface).padding(DSSpacing.md)) {
                        if (amountText.isEmpty()) Text(stringResource(R.string.catalog_budget_amountPlaceholder), style = DS.type.title2, color = DS.colors.textSecondary.copy(alpha = 0.5f))
                        inner()
                    }
                },
            )
            Text(stringResource(R.string.catalog_budget_footer), style = DS.type.footnote, color = DS.colors.textSecondary)

            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(DSRadius.control)).background(DS.colors.surface).padding(horizontal = DSSpacing.md, vertical = DSSpacing.xs),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stringResource(R.string.catalog_budget_hasDate), style = DS.type.body, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                Switch(hasDate, { hasDate = it }, colors = SwitchDefaults.colors(checkedTrackColor = DS.colors.primary))
            }
            if (hasDate) {
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(DSRadius.control)).background(DS.colors.surface)
                        .clickable { pickingDate = true }.padding(DSSpacing.md),
                ) {
                    Text(stringResource(R.string.catalog_budget_date), style = DS.type.body, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                    Text(dateState.selectedDateMillis?.let { displayDate(it) }.orEmpty(), style = DS.type.body, color = DS.colors.primary)
                }
            }
            if (failed) Text(stringResource(R.string.catalog_common_saveFailed), style = DS.type.footnote, color = DS.colors.error)
        }
    }

    if (pickingDate) {
        DatePickerDialog(
            onDismissRequest = { pickingDate = false },
            confirmButton = { TextButton(onClick = { pickingDate = false }) { Text(stringResource(R.string.catalog_common_ok)) } },
        ) { DatePicker(dateState) }
    }
}

private fun formatPlain(amount: Double): String = if (amount % 1.0 == 0.0) amount.toLong().toString() else amount.toString()

private fun displayDate(millis: Long): String =
    SimpleDateFormat("d MMMM yyyy", Locale.getDefault()).apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }.format(millis)

/** "yyyy-MM-dd" → "29 أكتوبر" for the date chip. */
private fun dayChipLabel(day: String): String =
    runCatching { LocalDate.parse(day).format(java.time.format.DateTimeFormatter.ofPattern("d MMM", Locale.getDefault())) }.getOrDefault(day)

/** Picks the day for «التاريخ المتاح» (or clears it with «أي تاريخ»). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DateFilterDialog(current: String?, onDone: (String?) -> Unit, onDismiss: () -> Unit) {
    val today = remember { LocalDate.now(ZoneOffset.UTC).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() }
    val state = rememberDatePickerState(
        initialSelectedDateMillis = current?.let(::dayMillis) ?: today,
        selectableDates = object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis >= today
        },
    )
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = { onDone(state.selectedDateMillis?.let(::dayString)) }) { Text(stringResource(R.string.catalog_filter_date_apply)) }
        },
        dismissButton = { TextButton(onClick = { onDone(null) }) { Text(stringResource(R.string.catalog_filter_date_any)) } },
    ) {
        Text(stringResource(R.string.catalog_filter_date_hint), style = DS.type.footnote, color = DS.colors.textSecondary, modifier = Modifier.padding(horizontal = DSSpacing.lg, vertical = DSSpacing.sm))
        DatePicker(state)
    }
}
