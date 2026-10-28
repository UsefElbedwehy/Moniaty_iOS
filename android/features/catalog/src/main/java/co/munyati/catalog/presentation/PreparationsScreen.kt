package co.munyati.catalog.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Checklist
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import co.munyati.catalog.R
import co.munyati.catalog.domain.Preparation
import co.munyati.core.error.AppError
import co.munyati.designsystem.components.DSCard
import co.munyati.designsystem.components.DSFormSection
import co.munyati.designsystem.components.DSTextFieldRow
import co.munyati.designsystem.components.DSTopBar
import co.munyati.designsystem.components.EmptyStateView
import co.munyati.designsystem.components.ErrorStateView
import co.munyati.designsystem.components.TopBarIconButton
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/** What the editor sheet starts from: an existing item (id) or a new one (null). */
private data class PreparationDraft(val id: String?, val title: String, val note: String)

private sealed interface Phase {
    data object Loading : Phase
    data class Failed(val error: AppError) : Phase
    data object Ready : Phase
}

/**
 * "My preparations" (تجهيزاتي): the bride's own checklist for the wedding. She adds an item in the
 * field at the top (or with a note from +), ticks it when it's done, and taps it to edit its text
 * and note or delete it. Done items move to their own section below. Mirrors iOS `PreparationsScreen`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun PreparationsScreen(feature: CatalogFeature) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    val store = feature.preparations
    var phase: Phase by remember { mutableStateOf(Phase.Loading) }
    var refreshing by remember { mutableStateOf(false) }
    var newTitle by remember { mutableStateOf("") }
    var isAdding by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<PreparationDraft?>(null) }
    var failed by remember { mutableStateOf(false) }

    suspend fun load() {
        if (feature.context.isGuest) {
            phase = Phase.Ready
            return
        }
        if (store.hasLoaded) phase = Phase.Ready
        try {
            store.reload()
            phase = Phase.Ready
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            if (!store.hasLoaded) phase = Phase.Failed(AppError.from(e))
        }
    }
    LaunchedEffect(Unit) {
        analytics.screen("preparations")
        load()
    }

    fun add() {
        val title = newTitle.trim()
        if (title.isEmpty() || isAdding) return
        if (feature.context.isGuest) {
            feature.requireSignIn()
            return
        }
        isAdding = true
        scope.launch {
            try {
                store.save(null, title.take(120), null)
                newTitle = ""
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                failed = true
                analytics.error("preparation_add", e.message.orEmpty(), "preparations")
            } finally {
                isAdding = false
            }
        }
    }

    fun run(block: suspend () -> Unit) {
        scope.launch {
            try {
                block()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                failed = true
            }
        }
    }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.catalog_preparations_title), navigator.back, stringResource(R.string.catalog_back)) {
            if (!feature.context.isGuest) {
                TopBarIconButton(Icons.Outlined.Add, stringResource(R.string.catalog_preparations_new)) {
                    editing = PreparationDraft(null, newTitle, "")
                }
            }
        }
        PullToRefreshBox(
            isRefreshing = refreshing,
            onRefresh = { scope.launch { refreshing = true; load(); refreshing = false } },
            modifier = Modifier.fillMaxSize(),
        ) {
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg),
                verticalArrangement = Arrangement.spacedBy(DSSpacing.lg),
            ) {
                when (val current = phase) {
                    Phase.Loading -> Box(Modifier.fillMaxWidth().heightIn(min = 240.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = DS.colors.primary)
                    }
                    is Phase.Failed -> ErrorStateView(current.error) { scope.launch { load() } }
                    Phase.Ready -> {
                        AddField(newTitle, { newTitle = it }, isAdding, ::add)
                        if (store.items.isEmpty()) {
                            EmptyStateView(
                                Icons.Outlined.Checklist,
                                stringResource(R.string.catalog_preparations_empty_title),
                                stringResource(R.string.catalog_preparations_empty_message),
                                Modifier.padding(top = DSSpacing.lg),
                            )
                        } else {
                            Progress(done = store.done.size, total = store.items.size)
                            PreparationSection(R.string.catalog_preparations_section_todo, store.open,
                                onToggle = { run { store.toggle(it) } },
                                onOpen = { editing = PreparationDraft(it.id, it.title, it.note.orEmpty()) })
                            PreparationSection(R.string.catalog_preparations_section_done, store.done,
                                onToggle = { run { store.toggle(it) } },
                                onOpen = { editing = PreparationDraft(it.id, it.title, it.note.orEmpty()) })
                        }
                    }
                }
            }
        }
    }

    editing?.let { draft ->
        PreparationEditor(
            draft = draft,
            store = store,
            onClose = { saved ->
                if (saved && draft.id == null) newTitle = ""
                editing = null
            },
        )
    }

    if (failed) {
        AlertDialog(
            onDismissRequest = { failed = false },
            confirmButton = { TextButton(onClick = { failed = false }) { Text(stringResource(R.string.catalog_common_ok)) } },
            text = { Text(stringResource(R.string.catalog_common_saveFailed)) },
        )
    }
}

@Composable
private fun AddField(value: String, onValueChange: (String) -> Unit, isAdding: Boolean, onAdd: () -> Unit) {
    val canAdd = value.isNotBlank() && !isAdding
    Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm), verticalAlignment = Alignment.CenterVertically) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            textStyle = DS.type.body.copy(color = DS.colors.textPrimary),
            cursorBrush = SolidColor(DS.colors.primary),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onAdd() }),
            modifier = Modifier.weight(1f),
            decorationBox = { inner ->
                Box(
                    Modifier.fillMaxWidth().heightIn(min = 46.dp)
                        .clip(RoundedCornerShape(DSRadius.button)).background(DS.colors.surface)
                        .border(1.dp, DS.colors.border, RoundedCornerShape(DSRadius.button))
                        .padding(horizontal = DSSpacing.md),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    if (value.isEmpty()) {
                        Text(stringResource(R.string.catalog_preparations_add_placeholder), style = DS.type.body, color = DS.colors.textSecondary.copy(alpha = 0.6f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    inner()
                }
            },
        )
        Box(
            Modifier.size(46.dp).clip(RoundedCornerShape(DSRadius.button))
                .background(if (canAdd) DS.colors.primary else DS.colors.disabled)
                .clickable(enabled = canAdd, role = Role.Button, onClick = onAdd),
            contentAlignment = Alignment.Center,
        ) {
            if (isAdding) {
                CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
            } else {
                Icon(Icons.Outlined.Add, contentDescription = stringResource(R.string.catalog_preparations_add), tint = Color.White)
            }
        }
    }
}

@Composable
private fun Progress(done: Int, total: Int) {
    DSCard {
        Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.catalog_preparations_progress, done, total), style = DS.type.headline, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                if (done == total) Icon(Icons.Filled.Verified, contentDescription = null, tint = DS.colors.success)
            }
            LinearProgressIndicator(
                progress = { if (total == 0) 0f else done.toFloat() / total },
                modifier = Modifier.fillMaxWidth(),
                color = DS.colors.primary,
                trackColor = DS.colors.border,
                drawStopIndicator = {},
            )
            if (done == total) Text(stringResource(R.string.catalog_preparations_allDone), style = DS.type.footnote, color = DS.colors.textSecondary)
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PreparationSection(titleRes: Int, items: List<Preparation>, onToggle: (Preparation) -> Unit, onOpen: (Preparation) -> Unit) {
    if (items.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
        Text("${stringResource(titleRes)} (${items.size})", style = DS.type.subhead, color = DS.colors.textSecondary)
        DSCard(padding = 0.dp) {
            items.forEachIndexed { index, item ->
                Row(Modifier.fillMaxWidth().padding(horizontal = DSSpacing.md, vertical = DSSpacing.sm), verticalAlignment = Alignment.Top) {
                    Box(
                        Modifier.size(30.dp).clickable(role = Role.Checkbox) { onToggle(item) },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            if (item.isDone) Icons.Filled.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
                            contentDescription = stringResource(if (item.isDone) R.string.catalog_preparations_markOpen else R.string.catalog_preparations_markDone),
                            tint = if (item.isDone) DS.colors.success else DS.colors.border,
                            modifier = Modifier.size(24.dp),
                        )
                    }
                    Column(
                        Modifier.weight(1f).clickable(role = Role.Button) { onOpen(item) }.padding(start = DSSpacing.sm, top = 4.dp),
                        verticalArrangement = Arrangement.spacedBy(DSSpacing.xxs),
                    ) {
                        Text(
                            item.title, style = DS.type.body,
                            color = if (item.isDone) DS.colors.textSecondary else DS.colors.textPrimary,
                            textDecoration = if (item.isDone) TextDecoration.LineThrough else null,
                        )
                        if (!item.note.isNullOrEmpty()) {
                            Text(item.note, style = DS.type.footnote, color = DS.colors.textSecondary, maxLines = 3, overflow = TextOverflow.Ellipsis)
                        }
                    }
                }
                if (index < items.lastIndex) HorizontalDivider(color = DS.colors.border, modifier = Modifier.padding(start = DSSpacing.md + 30.dp))
            }
        }
    }
}

/** Edits an item's text and note, or deletes it. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PreparationEditor(draft: PreparationDraft, store: PreparationsStore, onClose: (saved: Boolean) -> Unit) {
    val scope = rememberCoroutineScope()
    var title by remember { mutableStateOf(draft.title) }
    var note by remember { mutableStateOf(draft.note) }
    var isSaving by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    val canSave = title.isNotBlank() && !isSaving

    fun attempt(block: suspend () -> Unit) {
        isSaving = true
        failed = false
        scope.launch {
            try {
                block()
                onClose(true)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                failed = true
            } finally {
                isSaving = false
            }
        }
    }

    ModalBottomSheet(onDismissRequest = { onClose(false) }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = DS.colors.background) {
        Column(Modifier.fillMaxWidth().padding(horizontal = DSSpacing.lg).padding(bottom = DSSpacing.xl), verticalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { onClose(false) }) { Text(stringResource(R.string.catalog_common_cancel), color = DS.colors.primary) }
                Text(
                    stringResource(if (draft.id == null) R.string.catalog_preparations_new else R.string.catalog_preparations_edit),
                    style = DS.type.headline, color = DS.colors.textPrimary, modifier = Modifier.weight(1f), textAlign = TextAlign.Center,
                )
                TextButton(enabled = canSave, onClick = {
                    attempt { store.save(draft.id, title.trim().take(120), note.take(1000)) }
                }) { Text(stringResource(R.string.catalog_common_save), color = if (canSave) DS.colors.primary else DS.colors.disabled) }
            }
            DSFormSection(stringResource(R.string.catalog_preparations_field_title)) {
                DSTextFieldRow(title, { title = it }, stringResource(R.string.catalog_preparations_add_placeholder))
            }
            DSFormSection(stringResource(R.string.catalog_preparations_field_note)) {
                DSTextFieldRow(note, { note = it }, stringResource(R.string.catalog_preparations_note_placeholder), minLines = 3)
            }
            if (draft.id != null) {
                DSFormSection {
                    Box(
                        Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Button) { confirmDelete = true }.padding(horizontal = DSSpacing.md),
                        contentAlignment = Alignment.CenterStart,
                    ) { Text(stringResource(R.string.catalog_preparations_delete), style = DS.type.body, color = DS.colors.error) }
                }
            }
            if (failed) Text(stringResource(R.string.catalog_common_saveFailed), style = DS.type.footnote, color = DS.colors.error)
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text(stringResource(R.string.catalog_preparations_delete_confirm)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    val id = draft.id ?: return@TextButton
                    attempt { store.delete(Preparation(id, draft.title)) }
                }) { Text(stringResource(R.string.catalog_preparations_delete), color = DS.colors.error) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(stringResource(R.string.catalog_common_cancel)) } },
        )
    }
}
