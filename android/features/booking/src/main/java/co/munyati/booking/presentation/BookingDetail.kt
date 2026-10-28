@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package co.munyati.booking.presentation

import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material.icons.outlined.Straighten
import androidx.compose.material.icons.outlined.ContentCut
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.WaterDrop
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material.icons.outlined.Public
import androidx.compose.material.icons.outlined.Tag
import androidx.compose.material.icons.outlined.Person
import co.munyati.booking.data.Riyadh
import androidx.compose.foundation.layout.Spacer
import androidx.compose.ui.graphics.vector.ImageVector
import co.munyati.booking.domain.BookingBrideDetails
import androidx.compose.material.icons.outlined.Groups
import androidx.compose.material.icons.outlined.Apartment
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Badge
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.AddPhotoAlternate
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.CreditCard
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.EventBusy
import androidx.compose.material.icons.outlined.HelpOutline
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
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
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import co.munyati.booking.R
import co.munyati.booking.domain.ActionResult
import co.munyati.booking.domain.BookingDetail
import co.munyati.booking.domain.BookingReceipt
import co.munyati.booking.domain.BookingRole
import co.munyati.booking.domain.BookingStatus
import co.munyati.booking.domain.BookingSummary
import co.munyati.booking.domain.DisputeReason
import co.munyati.core.dates.DisplayDates
import co.munyati.core.error.AppError
import co.munyati.core.state.ViewState
import co.munyati.designsystem.components.DSCard
import co.munyati.designsystem.components.DSFormDivider
import co.munyati.designsystem.components.DSFormSection
import co.munyati.designsystem.components.DSNavRow
import co.munyati.designsystem.components.DSPickerRow
import co.munyati.designsystem.components.DSTextFieldRow
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
import co.munyati.shared.media.ImageCompressor
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.security.MessageDigest
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset

private enum class DetailSheet { Propose, Decline, RejectPayment, Dispute }

@Composable
internal fun BookingDetailScreen(feature: BookingFeature, bookingId: String, role: BookingRole) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var state: ViewState<BookingDetail> by remember { mutableStateOf(ViewState.Loading) }
    var isWorking by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var sheet by remember { mutableStateOf<DetailSheet?>(null) }
    var viewing by remember { mutableStateOf<BookingReceipt?>(null) }
    var confirmCancel by remember { mutableStateOf(false) }
    var showHelp by remember { mutableStateOf(false) }
    var showDemoIntro by remember { mutableStateOf(false) }

    suspend fun load() {
        val fresh = loadState { feature.repository.booking(bookingId) }
        state = when {
            fresh is ViewState.Loaded && fresh.value == null -> ViewState.Empty
            fresh is ViewState.Loaded -> ViewState.Loaded(fresh.value!!)
            fresh is ViewState.Error && state.value != null -> state
            fresh is ViewState.Error -> fresh
            else -> ViewState.Empty
        }
        // The provider's one-time practice booking explains itself the first time it opens.
        val loaded = state.value
        if (role == BookingRole.Provider && loaded?.summary?.isDemo == true && !DemoIntro.isSeen(context, bookingId)) showDemoIntro = true
    }

    fun run(action: suspend () -> ActionResult) {
        isWorking = true
        scope.launch {
            try {
                val result = action()
                if (result is ActionResult.Refused) message = refusal(context, result.code)
                feature.onBookingsChanged()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                message = context.getString(R.string.booking_error_generic)
            }
            load()
            isWorking = false
        }
    }

    LaunchedEffect(bookingId) {
        analytics.screen("booking_detail")
        load()
    }
    androidx.lifecycle.compose.LifecycleEventEffect(androidx.lifecycle.Lifecycle.Event.ON_RESUME) { scope.launch { load() } }

    val detail = state.value
    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(detail?.summary?.referenceCode.orEmpty(), navigator.back, stringResource(R.string.booking_back)) {
            val trust = feature.trustViews
            if (trust != null && detail?.summary?.isDemo == false) trust.moreMenu(bookingId)
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            when (val s = state) {
                ViewState.Loading -> Spinner(Modifier.padding(top = 120.dp))
                is ViewState.Error -> ErrorStateView(s.error) { scope.launch { load() } }
                ViewState.Offline -> ErrorStateView(AppError.Offline) { scope.launch { load() } }
                ViewState.Empty -> EmptyStateView(Icons.Outlined.EventBusy, stringResource(R.string.booking_detail_missing), stringResource(R.string.booking_error_generic))
                is ViewState.Loaded, is ViewState.Refreshing -> s.value?.let { d ->
                    DetailContent(feature, d, role, isWorking,
                        onAction = ::run,
                        onSheet = { sheet = it },
                        onReceipt = { viewing = it },
                        onCancel = { confirmCancel = true },
                        onHelp = { showHelp = true },
                        onDemoHow = { showDemoIntro = true })
                }
            }
        }
    }

    when (sheet) {
        DetailSheet.Propose -> ProposeTimeSheet(onDismiss = { sheet = null }) { date, note ->
            feature.repository.proposeReschedule(bookingId, date, note).also { if (it is ActionResult.Ok) load() }
        }
        DetailSheet.Decline -> ReasonSheet(R.string.booking_action_decline, optional = true, onDismiss = { sheet = null }) { reason ->
            feature.repository.decline(bookingId, reason).also { load() }
        }
        DetailSheet.RejectPayment -> ReasonSheet(R.string.booking_action_rejectPayment, optional = false, onDismiss = { sheet = null }) { reason ->
            feature.repository.rejectPayment(bookingId, reason.orEmpty()).also { load() }
        }
        DetailSheet.Dispute -> DisputeSheet(onDismiss = { sheet = null }) { reason, details ->
            feature.repository.openDispute(bookingId, reason, details).also { load() }
        }
        null -> Unit
    }
    viewing?.let { ReceiptViewer(feature, it) { viewing = null } }
    if (showHelp) feature.trustViews?.helpSheet?.invoke(bookingId) { showHelp = false }
    if (showDemoIntro) {
        DemoIntroSheet {
            DemoIntro.markSeen(context, bookingId)
            showDemoIntro = false
        }
    }
    if (confirmCancel) {
        AlertDialog(
            onDismissRequest = { confirmCancel = false },
            title = { Text(stringResource(R.string.booking_action_cancel_confirm)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmCancel = false
                    run { feature.repository.cancel(bookingId, null) }
                }) { Text(stringResource(R.string.booking_action_cancel), color = DS.colors.error) }
            },
            dismissButton = { TextButton(onClick = { confirmCancel = false }) { Text(stringResource(R.string.booking_common_cancel)) } },
        )
    }
    MessageDialog(message) { message = null }
}

@Composable
private fun DetailContent(
    feature: BookingFeature,
    detail: BookingDetail,
    role: BookingRole,
    isWorking: Boolean,
    onAction: (suspend () -> ActionResult) -> Unit,
    onSheet: (DetailSheet) -> Unit,
    onReceipt: (BookingReceipt) -> Unit,
    onCancel: () -> Unit,
    onHelp: () -> Unit,
    onDemoHow: () -> Unit,
) {
    val navigator = LocalNavigator.current
    val b = detail.summary
    val repo = feature.repository
    Column(Modifier.padding(DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.lg)) {
        if (b.isDemo) {
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(DS.colors.primaryMuted).padding(DSSpacing.sm),
                horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs), verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Outlined.AutoAwesome, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(18.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(stringResource(R.string.booking_demo_banner), style = DS.type.footnote, color = DS.colors.textPrimary)
                    if (role == BookingRole.Provider) {
                        Text(
                            stringResource(R.string.booking_demo_intro_how),
                            style = DS.type.footnote.copy(fontWeight = FontWeight.SemiBold), color = DS.colors.primary,
                            modifier = Modifier.clickable(role = Role.Button, onClick = onDemoHow),
                        )
                    }
                }
            }
        }
        DSCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                StatusPill(b.status, role)
                Text(b.serviceTitle, style = DS.type.title2, color = DS.colors.textPrimary)
                Text(if (role == BookingRole.Bride) b.provider.name.orEmpty() else b.brideName.orEmpty(), style = DS.type.subhead, color = DS.colors.textPrimary)
                Text(bookingDateText(b.startsAt), style = DS.type.subhead, color = DS.colors.textSecondary)
                Text(formatSar(b.price), style = DS.type.headline, color = DS.colors.primary)
                if (!b.note.isNullOrEmpty()) Text(b.note, style = DS.type.footnote, color = DS.colors.textSecondary)
                ProgressSteps(b.status.step)
                Text(bookingString("hint.${role.rawValue}.${b.status.rawValue}"), style = DS.type.footnote, color = DS.colors.textSecondary)
                val due = b.paymentDueAt
                if (due != null && b.status == BookingStatus.AwaitingPayment) {
                    Text(stringResource(R.string.booking_detail_payBy, bookingDateText(due)), style = DS.type.footnote, color = DS.colors.primary)
                }
            }
        }

        val brideDetails = detail.brideDetails
        if (role == BookingRole.Provider && brideDetails != null && !brideDetails.isEmpty) {
            BrideDetailsCard(brideDetails, isRevealed = b.status in setOf(BookingStatus.PaymentConfirmed, BookingStatus.Completed, BookingStatus.Disputed))
        }

        detail.proposal?.let { proposal ->
            DSCard(Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                    Text(stringResource(R.string.booking_proposal_title), style = DS.type.headline, color = DS.colors.textPrimary)
                    Text(bookingDateText(proposal.startsAt), style = DS.type.subhead, color = DS.colors.textPrimary)
                    if (!proposal.note.isNullOrEmpty()) Text(proposal.note, style = DS.type.footnote, color = DS.colors.textPrimary)
                    Text(stringResource(R.string.booking_proposal_expires, bookingDateText(proposal.expiresAt)), style = DS.type.caption, color = DS.colors.textSecondary)
                }
            }
        }

        // The buttons depend on the viewer's side and the booking's status (mirrors the SQL state machine).
        Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm), horizontalAlignment = Alignment.CenterHorizontally) {
            when {
                role == BookingRole.Bride && b.status == BookingStatus.RescheduleProposed -> {
                    PrimaryButton(stringResource(R.string.booking_action_acceptTime), isLoading = isWorking) { onAction { repo.respondToProposal(b.id, true) } }
                    SecondaryButton(stringResource(R.string.booking_action_rejectTime)) { onAction { repo.respondToProposal(b.id, false) } }
                }
                role == BookingRole.Bride && b.status == BookingStatus.AwaitingPayment ->
                    PrimaryButton(stringResource(R.string.booking_action_pay), icon = Icons.Outlined.CreditCard) { navigator.navigate(BookingPaymentRoute(b.id)) }
                role == BookingRole.Provider && b.status == BookingStatus.Requested -> {
                    PrimaryButton(stringResource(R.string.booking_action_approve), isLoading = isWorking) { onAction { repo.approve(b.id) } }
                    SecondaryButton(stringResource(R.string.booking_action_propose)) { onSheet(DetailSheet.Propose) }
                    SecondaryButton(stringResource(R.string.booking_action_decline)) { onSheet(DetailSheet.Decline) }
                }
                role == BookingRole.Provider && b.status == BookingStatus.PaymentSubmitted -> {
                    detail.receipts.firstOrNull()?.let { receipt ->
                        SecondaryButton(stringResource(R.string.booking_action_viewReceipt), icon = Icons.Outlined.Description) { onReceipt(receipt) }
                    }
                    PrimaryButton(stringResource(R.string.booking_action_confirmPayment), isLoading = isWorking) { onAction { repo.confirmPayment(b.id) } }
                    SecondaryButton(stringResource(R.string.booking_action_rejectPayment)) { onSheet(DetailSheet.RejectPayment) }
                }
                role == BookingRole.Provider && b.status == BookingStatus.PaymentConfirmed ->
                    PrimaryButton(stringResource(R.string.booking_action_complete), isLoading = isWorking) { onAction { repo.complete(b.id) } }
            }
            if (b.status in setOf(BookingStatus.Requested, BookingStatus.RescheduleProposed, BookingStatus.AwaitingPayment)) {
                TextButton(onClick = onCancel, modifier = Modifier.heightIn(min = 44.dp)) {
                    Text(stringResource(R.string.booking_action_cancel), style = DS.type.body, color = DS.colors.error)
                }
            }
            if (!b.isDemo && detail.openDispute == null &&
                b.status in setOf(BookingStatus.AwaitingPayment, BookingStatus.PaymentSubmitted, BookingStatus.PaymentConfirmed, BookingStatus.Completed)
            ) {
                TextButton(onClick = { onSheet(DetailSheet.Dispute) }, modifier = Modifier.heightIn(min = 44.dp)) {
                    Text(stringResource(R.string.booking_action_dispute), style = DS.type.footnote, color = DS.colors.primary)
                }
            }
        }

        if (detail.receipts.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                Text(stringResource(R.string.booking_receipts_title), style = DS.type.headline, color = DS.colors.textPrimary)
                detail.receipts.forEach { receipt ->
                    Row(
                        Modifier.fillMaxWidth().clickable { onReceipt(receipt) }.padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm),
                    ) {
                        Icon(Icons.Outlined.Description, contentDescription = null, tint = DS.colors.primary)
                        Column(Modifier.weight(1f)) {
                            Text(formatSar(receipt.amount), style = DS.type.subhead, color = DS.colors.textPrimary)
                            Text(bookingString("receipt.status.${receipt.status}"), style = DS.type.caption, color = DS.colors.textSecondary)
                            receipt.rejectReason?.let { Text(it, style = DS.type.caption, color = DS.colors.textPrimary) }
                        }
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = DS.colors.textSecondary)
                    }
                }
            }
        }

        val trust = feature.trustViews
        if (b.status == BookingStatus.Completed && !b.isDemo && trust != null) trust.review(b.id, role)
        if (!b.isDemo && trust != null) {
            Row(Modifier.clickable(onClick = onHelp).heightIn(min = 44.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                Icon(Icons.Outlined.HelpOutline, contentDescription = null, tint = DS.colors.primary)
                Text(stringResource(R.string.booking_action_help), style = DS.type.subhead, color = DS.colors.primary)
            }
        }

        if (detail.events.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                Text(stringResource(R.string.booking_timeline_title), style = DS.type.headline, color = DS.colors.textPrimary)
                detail.events.forEach { event ->
                    Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
                        Box(Modifier.padding(top = 7.dp).size(8.dp).clip(CircleShape).background(DS.colors.premiumGold))
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(bookingString("status.${event.toStatus.rawValue}"), style = DS.type.subhead, color = DS.colors.textPrimary)
                            Text(event.createdAt?.let { DisplayDates.pattern(it, "yMMMdjmm") }.orEmpty(), style = DS.type.caption, color = DS.colors.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

// Payment and receipt (mockup 6)

/** Loads the full booking (its payment methods) before showing the payment form. */
@Composable
internal fun PaymentLoaderScreen(feature: BookingFeature, bookingId: String) {
    val navigator = LocalNavigator.current
    val scope = rememberCoroutineScope()
    var state: ViewState<BookingDetail?> by remember { mutableStateOf(ViewState.Loading) }
    LaunchedEffect(bookingId) { state = loadState { feature.repository.booking(bookingId) } }
    when (val s = state) {
        is ViewState.Loaded -> s.value?.let { PaymentScreen(feature, it) } ?: Column(Modifier.fillMaxSize().background(DS.colors.background)) {
            DSTopBar("", navigator.back, stringResource(R.string.booking_back))
            ErrorStateView(AppError.Unknown(null)) { scope.launch { state = loadState { feature.repository.booking(bookingId) } } }
        }
        is ViewState.Error -> Column(Modifier.fillMaxSize().background(DS.colors.background)) {
            DSTopBar("", navigator.back, stringResource(R.string.booking_back))
            ErrorStateView(s.error) { scope.launch { state = loadState { feature.repository.booking(bookingId) } } }
        }
        else -> Box(Modifier.fillMaxSize().background(DS.colors.background), contentAlignment = Alignment.Center) { Spinner() }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PaymentScreen(feature: BookingFeature, detail: BookingDetail) {
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var image by remember { mutableStateOf<ByteArray?>(null) }
    var amountText by remember { mutableStateOf(detail.summary.price.let { if (it % 1.0 == 0.0) it.toLong().toString() else it.toString() }) }
    var transferredAt by remember { mutableStateOf(Instant.now()) }
    var senderBank by remember { mutableStateOf("") }
    var isSending by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var pickingDate by remember { mutableStateOf(false) }
    var pickingTime by remember { mutableStateOf(false) }
    val amount = amountText.map { if (it in '٠'..'٩') '0' + (it - '٠') else it }.filter { it.isDigit() || it == '.' }.joinToString("").toDoubleOrNull()

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) scope.launch { image = withContext(Dispatchers.IO) { ImageCompressor.jpeg(context, uri, maxDimension = 2000, quality = 85) } }
    }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.booking_pay_title), navigator.back, stringResource(R.string.booking_back)) {
            TextButton(enabled = image != null && amount != null && !isSending, onClick = {
                val jpeg = image ?: return@TextButton
                val total = amount ?: return@TextButton
                isSending = true
                scope.launch {
                    try {
                        val path = feature.receipts.upload(jpeg, detail.summary.id)
                        val hash = MessageDigest.getInstance("SHA-256").digest(jpeg).joinToString("") { "%02x".format(it) }
                        when (val result = feature.repository.submitReceipt(detail.summary.id, path, total, transferredAt, senderBank.ifEmpty { null }, hash)) {
                            is ActionResult.Ok -> { feature.onBookingsChanged(); navigator.back() }
                            is ActionResult.Refused -> message = refusal(context, result.code)
                        }
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        message = context.getString(R.string.booking_error_upload)
                    } finally {
                        isSending = false
                    }
                }
            }) {
                Text(stringResource(R.string.booking_pay_submit), style = DS.type.headline,
                    color = if (image != null && amount != null) DS.colors.primary else DS.colors.disabled)
            }
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.lg)) {
            PaymentSummaryCard(detail.summary)
            DSFormSection(stringResource(R.string.booking_pay_methods)) {
                detail.paymentMethods.forEachIndexed { index, method ->
                    if (index > 0) DSFormDivider()
                    Row(Modifier.padding(horizontal = DSSpacing.md, vertical = DSSpacing.sm), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text("${bookingString("method.${method.kind}")} · ${method.label}", style = DS.type.caption, color = DS.colors.textSecondary)
                            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                                Text(method.value, style = DS.type.subhead.copy(fontFamily = FontFamily.Monospace), color = DS.colors.textPrimary)
                            }
                            Text(stringResource(R.string.booking_pay_beneficiary, method.accountName), style = DS.type.footnote, color = DS.colors.textPrimary)
                        }
                        CopyButton(method.value)
                    }
                }
            }
            DSFormSection(stringResource(R.string.booking_pay_receipt), footer = stringResource(R.string.booking_pay_disclaimer)) {
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Button) { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
                        .padding(horizontal = DSSpacing.md),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
                ) {
                    Icon(if (image != null) Icons.Filled.CheckCircle else Icons.Outlined.AddPhotoAlternate, contentDescription = null, tint = DS.colors.primary)
                    Text(stringResource(if (image != null) R.string.booking_pay_attached else R.string.booking_pay_attach), style = DS.type.body, color = DS.colors.primary)
                }
                image?.let { bytes ->
                    val bitmap = remember(bytes) { BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap() }
                    bitmap?.let { Image(it, contentDescription = stringResource(R.string.booking_pay_attached), contentScale = ContentScale.Fit, modifier = Modifier.fillMaxWidth().heightIn(max = 220.dp).padding(DSSpacing.sm)) }
                }
                DSFormDivider()
                DSTextFieldRow(amountText, { amountText = it }, stringResource(R.string.booking_pay_transferredAmount), keyboardType = KeyboardType.Decimal)
                DSFormDivider()
                DSNavRow(stringResource(R.string.booking_pay_transferTime), DisplayDates.pattern(transferredAt, "yMMMdjmm")) { pickingDate = true }
                DSFormDivider()
                DSTextFieldRow(senderBank, { senderBank = it }, stringResource(R.string.booking_pay_senderBank))
            }
        }
    }

    if (pickingDate) {
        val dateState = rememberDatePickerState(
            initialSelectedDateMillis = transferredAt.atZone(ZoneId.systemDefault()).toLocalDate().atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= System.currentTimeMillis()
            },
        )
        DatePickerDialog(
            onDismissRequest = { pickingDate = false },
            confirmButton = {
                TextButton(onClick = {
                    dateState.selectedDateMillis?.let { millis ->
                        val day = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
                        val time = transferredAt.atZone(ZoneId.systemDefault()).toLocalTime()
                        transferredAt = minOf(Instant.now(), day.atTime(time).atZone(ZoneId.systemDefault()).toInstant())
                    }
                    pickingDate = false
                    pickingTime = true
                }) { Text(stringResource(R.string.booking_common_ok)) }
            },
        ) { DatePicker(dateState) }
    }
    if (pickingTime) {
        TimeDialog(transferredAt.atZone(ZoneId.systemDefault()).toLocalTime(), onDismiss = { pickingTime = false }) { time ->
            val day = transferredAt.atZone(ZoneId.systemDefault()).toLocalDate()
            transferredAt = minOf(Instant.now(), day.atTime(time).atZone(ZoneId.systemDefault()).toInstant())
        }
    }
    MessageDialog(message) { message = null }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun TimeDialog(initial: LocalTime, onDismiss: () -> Unit, onPick: (LocalTime) -> Unit) {
    val state = rememberTimePickerState(initial.hour, initial.minute, is24Hour = false)
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.booking_pickTime)) },
        text = { TimePicker(state) },
        confirmButton = { TextButton(onClick = { onPick(LocalTime.of(state.hour, state.minute)); onDismiss() }) { Text(stringResource(R.string.booking_common_ok)) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.booking_common_cancel)) } },
    )
}

@Composable
private fun CopyButton(value: String) {
    val context = LocalContext.current
    var copied by remember { mutableStateOf(false) }
    Box(Modifier.size(44.dp).clickable(role = Role.Button) { context.copyToClipboard(value); copied = true }, contentAlignment = Alignment.Center) {
        Icon(if (copied) Icons.Filled.Check else Icons.Outlined.ContentCopy,
            contentDescription = stringResource(if (copied) R.string.booking_common_copied else R.string.booking_common_copy), tint = DS.colors.primary)
    }
}

/** The burgundy summary at the top of the payment screen (mockup 6). */
@Composable
private fun PaymentSummaryCard(summary: BookingSummary) {
    val context = LocalContext.current
    var copied by remember { mutableStateOf(false) }
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(DSRadius.card)).background(DSGradient.primary).padding(DSSpacing.lg),
        verticalArrangement = Arrangement.spacedBy(DSSpacing.md),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.booking_pay_amountFrom, summary.provider.name.orEmpty()), style = DS.type.footnote, color = Color.White.copy(alpha = 0.85f))
            Text(formatSar(summary.price), style = DS.type.largeTitle, color = Color.White)
        }
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.12f)).padding(DSSpacing.md),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm),
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stringResource(R.string.booking_pay_referenceHint), style = DS.type.footnote, color = Color.White.copy(alpha = 0.85f))
                // Gold is fine here: large text on burgundy, not small text on ivory.
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                    Text(summary.referenceCode, style = DS.type.title2.copy(fontFamily = FontFamily.Monospace), color = DS.colors.premiumGold)
                }
            }
            Text(
                stringResource(if (copied) R.string.booking_common_copied else R.string.booking_common_copy),
                style = DS.type.subhead.copy(fontWeight = FontWeight.SemiBold), color = DS.colors.primary,
                modifier = Modifier.clip(RoundedCornerShape(DSRadius.pill)).background(DS.colors.background)
                    .clickable(role = Role.Button) { context.copyToClipboard(summary.referenceCode); copied = true }
                    .heightIn(min = 44.dp).padding(horizontal = DSSpacing.md, vertical = DSSpacing.sm),
            )
        }
        summary.paymentDueAt?.let {
            Text(stringResource(R.string.booking_pay_deadline, bookingDateText(it)), style = DS.type.footnote, color = Color.White.copy(alpha = 0.85f))
        }
    }
}

@Composable
private fun ReceiptViewer(feature: BookingFeature, receipt: BookingReceipt, onDismiss: () -> Unit) {
    var bytes by remember { mutableStateOf<ByteArray?>(null) }
    var failed by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    suspend fun load() {
        val path = receipt.storagePath ?: return
        failed = false
        runCatching { feature.receipts.download(path) }.onSuccess { bytes = it }.onFailure { failed = true }
    }
    LaunchedEffect(receipt.id) { load() }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.booking_receipts_title)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
                val bitmap = bytes?.let { remember(it) { BitmapFactory.decodeByteArray(it, 0, it.size)?.asImageBitmap() } }
                when {
                    bitmap != null -> Image(bitmap, contentDescription = stringResource(R.string.booking_receipts_title), contentScale = ContentScale.Fit, modifier = Modifier.fillMaxWidth().heightIn(max = 360.dp))
                    receipt.storagePath == null -> Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                        // The demo booking's sample receipt.
                        Icon(Icons.Outlined.Description, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(64.dp))
                        Text(stringResource(R.string.booking_demo_receipt), style = DS.type.footnote, color = DS.colors.textPrimary)
                    }
                    failed -> ErrorStateView(AppError.Network(AppError.NetworkFailureReason.NoConnection)) { scope.launch { load() } }
                    else -> Spinner()
                }
                LabeledValue(stringResource(R.string.booking_pay_transferredAmount), formatSar(receipt.amount))
                receipt.senderBank?.takeIf { it.isNotEmpty() }?.let { LabeledValue(stringResource(R.string.booking_pay_senderBank), it) }
                receipt.transferredAt?.let { LabeledValue(stringResource(R.string.booking_pay_transferTime), DisplayDates.pattern(it, "yMMMdjmm")) }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.booking_common_done)) } },
    )
}

@Composable
private fun LabeledValue(label: String, value: String) {
    Row {
        Text(label, style = DS.type.subhead, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
        Text(value, style = DS.type.subhead, color = DS.colors.textSecondary)
    }
}

// Small action sheets

/** A bottom sheet with Cancel / title / Send, like the iOS form sheets. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ActionSheet(title: String, canSend: Boolean, isSending: Boolean, onDismiss: () -> Unit, onSend: () -> Unit, content: @Composable () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = DS.colors.background) {
        Column(Modifier.fillMaxWidth().padding(horizontal = DSSpacing.lg).padding(bottom = DSSpacing.xl), verticalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) { Text(stringResource(R.string.booking_common_cancel), color = DS.colors.primary) }
                Text(title, style = DS.type.headline, color = DS.colors.textPrimary, modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                TextButton(onClick = onSend, enabled = canSend && !isSending) {
                    Text(stringResource(R.string.booking_common_send), color = if (canSend) DS.colors.primary else DS.colors.disabled)
                }
            }
            content()
        }
    }
}

@Composable
private fun ProposeTimeSheet(onDismiss: () -> Unit, action: suspend (Instant, String?) -> ActionResult) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val zone = ZoneId.systemDefault()
    var date by remember { mutableStateOf(LocalDate.now(zone).plusDays(1)) }
    var time by remember { mutableStateOf(LocalTime.of(16, 0)) }
    var note by remember { mutableStateOf("") }
    var isSending by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var pickingDate by remember { mutableStateOf(false) }
    var pickingTime by remember { mutableStateOf(false) }
    val instant = date.atTime(time).atZone(zone).toInstant()
    // At least two hours ahead, like the iOS picker's range.
    val valid = instant.isAfter(Instant.now().plusSeconds(7200))

    ActionSheet(stringResource(R.string.booking_action_propose), valid, isSending, onDismiss, onSend = {
        isSending = true
        scope.launch {
            try {
                when (val result = action(instant, note.ifEmpty { null })) {
                    is ActionResult.Ok -> onDismiss()
                    is ActionResult.Refused -> message = refusal(context, result.code)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                message = context.getString(R.string.booking_error_generic)
            } finally {
                isSending = false
            }
        }
    }) {
        DSFormSection(stringResource(R.string.booking_proposal_newTime)) {
            DSNavRow(stringResource(R.string.booking_pickDate), DisplayDates.pattern(instant, "EEEEdMMMM")) { pickingDate = true }
            DSFormDivider()
            DSNavRow(stringResource(R.string.booking_pickTime), DisplayDates.pattern(instant, "jmm")) { pickingTime = true }
        }
        DSFormSection {
            DSTextFieldRow(note, { note = it }, stringResource(R.string.booking_proposal_note), minLines = 2)
        }
    }
    if (pickingDate) {
        val today = LocalDate.now(zone).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        val state = rememberDatePickerState(
            initialSelectedDateMillis = date.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates { override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis >= today },
        )
        DatePickerDialog(onDismissRequest = { pickingDate = false }, confirmButton = {
            TextButton(onClick = {
                state.selectedDateMillis?.let { date = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate() }
                pickingDate = false
            }) { Text(stringResource(R.string.booking_common_ok)) }
        }) { DatePicker(state) }
    }
    if (pickingTime) TimeDialog(time, onDismiss = { pickingTime = false }) { time = it }
    MessageDialog(message) { message = null }
}

@Composable
private fun ReasonSheet(title: Int, optional: Boolean, onDismiss: () -> Unit, action: suspend (String?) -> ActionResult) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var reason by remember { mutableStateOf("") }
    var isSending by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    ActionSheet(stringResource(title), optional || reason.isNotBlank(), isSending, onDismiss, onSend = {
        isSending = true
        scope.launch {
            try {
                action(reason.ifEmpty { null })
                onDismiss()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                message = context.getString(R.string.booking_error_generic)
            } finally {
                isSending = false
            }
        }
    }) {
        DSFormSection {
            DSTextFieldRow(reason, { reason = it }, stringResource(if (optional) R.string.booking_reason_optional else R.string.booking_reason_required), minLines = 3)
        }
    }
    MessageDialog(message) { message = null }
}

@Composable
private fun DisputeSheet(onDismiss: () -> Unit, action: suspend (DisputeReason, String?) -> ActionResult) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var reason by remember { mutableStateOf(DisputeReason.PaymentNotReceived) }
    var details by remember { mutableStateOf("") }
    var isSending by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    val labels = DisputeReason.entries.associateWith { bookingString("dispute.${it.rawValue}") }
    ActionSheet(stringResource(R.string.booking_action_dispute), true, isSending, onDismiss, onSend = {
        isSending = true
        scope.launch {
            try {
                action(reason, details.ifEmpty { null })
                onDismiss()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                message = context.getString(R.string.booking_error_generic)
            } finally {
                isSending = false
            }
        }
    }) {
        DSFormSection {
            DSPickerRow(stringResource(R.string.booking_dispute_reason), DisputeReason.entries, reason, label = { labels.getValue(it) }) { reason = it }
        }
        DSFormSection(footer = stringResource(R.string.booking_dispute_footer)) {
            DSTextFieldRow(details, { details = it }, stringResource(R.string.booking_dispute_details), minLines = 3)
        }
    }
    MessageDialog(message) { message = null }
}

/** Remembers, on this device, that the provider has read the demo explanation for a booking. */
private object DemoIntro {
    private fun prefs(context: android.content.Context) = context.getSharedPreferences("demo_intro", android.content.Context.MODE_PRIVATE)
    fun isSeen(context: android.content.Context, bookingId: String) = prefs(context).getBoolean(bookingId, false)
    fun markSeen(context: android.content.Context, bookingId: String) = prefs(context).edit().putBoolean(bookingId, true).apply()
}

/**
 * Shown the first time a new provider opens her practice booking: what it is, the three steps to
 * try, and that it comes only once and doesn't count. Same as iOS `DemoIntroSheet`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DemoIntroSheet(onStart: () -> Unit) {
    val steps = listOf(R.string.booking_demo_intro_step1, R.string.booking_demo_intro_step2, R.string.booking_demo_intro_step3)
    ModalBottomSheet(onDismissRequest = onStart, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = DS.colors.background) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = DSSpacing.lg).padding(bottom = DSSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.lg),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                Icon(Icons.Outlined.AutoAwesome, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(30.dp))
                Text(stringResource(R.string.booking_demo_intro_title), style = DS.type.title2, color = DS.colors.textPrimary)
                Text(stringResource(R.string.booking_demo_intro_subtitle), style = DS.type.body, color = DS.colors.textSecondary)
            }
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
                steps.forEachIndexed { index, step ->
                    Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm), verticalAlignment = Alignment.Top) {
                        Box(Modifier.size(26.dp).clip(CircleShape).background(DS.colors.primary), contentAlignment = Alignment.Center) {
                            Text(java.text.NumberFormat.getIntegerInstance().format(index + 1), style = DS.type.subhead.copy(fontWeight = FontWeight.SemiBold), color = DS.colors.background)
                        }
                        Text(stringResource(step), style = DS.type.body, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                    }
                }
            }
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(DSRadius.control)).background(DS.colors.primaryMuted).padding(DSSpacing.sm),
                horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs), verticalAlignment = Alignment.Top,
            ) {
                Icon(Icons.Outlined.Info, contentDescription = null, tint = DS.colors.textPrimary, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.booking_demo_intro_note), style = DS.type.footnote, color = DS.colors.textPrimary)
            }
            PrimaryButton(stringResource(R.string.booking_demo_intro_start)) { onStart() }
        }
    }
}

/** The bride's details on her booking, for the provider: date, city, venue, guests and notes. */
@Composable
private fun BrideDetailsCard(details: BookingBrideDetails, isRevealed: Boolean) {
    val arabic = java.util.Locale.getDefault().language == "ar"
    // "yyyy-MM-dd" → a long date, in the same calendar and language as every other booking date.
    val dateText = details.weddingDate?.let { day ->
        runCatching { LocalDate.parse(day).atTime(12, 0).atZone(Riyadh).toInstant() }.getOrNull()
            ?.let { DisplayDates.pattern(it, "dMMMMy") } ?: day
    }
    DSCard(Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
            Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.Badge, contentDescription = null, tint = DS.colors.textPrimary)
                Text(stringResource(R.string.booking_brideDetails_title), style = DS.type.headline, color = DS.colors.textPrimary)
            }
            BrideDetailRow(R.string.booking_brideDetails_name, Icons.Outlined.Person, details.fullName)
            BrideDetailRow(R.string.booking_brideDetails_age, Icons.Outlined.Tag, details.age?.let { java.text.NumberFormat.getIntegerInstance().format(it) })
            BrideDetailRow(R.string.booking_brideDetails_nationality, Icons.Outlined.Public, details.nationality)
            BrideDetailRow(R.string.booking_brideDetails_phone, Icons.Outlined.Phone, details.phone?.let { if (it.startsWith("+966")) "0" + it.drop(4) else it })
            if (!isRevealed) Text(stringResource(R.string.booking_brideDetails_hidden), style = DS.type.caption, color = DS.colors.textSecondary)
            BrideDetailRow(R.string.booking_brideDetails_skinType, Icons.Outlined.WaterDrop, details.skinType?.let { bookingString("brideDetails.skinType.$it") })
            BrideDetailRow(R.string.booking_brideDetails_skinTone, Icons.Outlined.Palette, details.skinTone?.let { bookingString("brideDetails.skinTone.$it") })
            BrideDetailRow(R.string.booking_brideDetails_hairType, Icons.Outlined.ContentCut, details.hairType?.let { bookingString("brideDetails.hairType.$it") })
            BrideDetailRow(R.string.booking_brideDetails_hairLength, Icons.Outlined.Straighten, details.hairLength?.let { bookingString("brideDetails.hairLength.$it") })
            if (!details.allergies.isNullOrEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xxs)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Outlined.WarningAmber, contentDescription = null, tint = DS.colors.warning, modifier = Modifier.size(16.dp))
                        Text(stringResource(R.string.booking_brideDetails_allergies), style = DS.type.caption, color = DS.colors.warning)
                    }
                    Text(details.allergies, style = DS.type.body, color = DS.colors.textPrimary)
                }
            }
            if (details.hasWedding) {
                if (details.hasPersonal || !isRevealed) HorizontalDivider(color = DS.colors.border)
                Text(stringResource(R.string.booking_brideDetails_section_wedding), style = DS.type.subhead.copy(fontWeight = FontWeight.SemiBold), color = DS.colors.textPrimary)
            }
            BrideDetailRow(R.string.booking_brideDetails_date, Icons.Outlined.CalendarMonth, dateText)
            BrideDetailRow(R.string.booking_brideDetails_city, Icons.Outlined.LocationOn, if (arabic) details.cityNameAr else details.cityNameEn)
            BrideDetailRow(R.string.booking_brideDetails_venue, Icons.Outlined.Apartment, details.venue)
            BrideDetailRow(R.string.booking_brideDetails_guests, Icons.Outlined.Groups, details.guestCount?.let { java.text.NumberFormat.getIntegerInstance().format(it) })
            if (!details.notes.isNullOrEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xxs)) {
                    Text(stringResource(R.string.booking_brideDetails_notes), style = DS.type.caption, color = DS.colors.textSecondary)
                    Text(details.notes, style = DS.type.body, color = DS.colors.textPrimary)
                }
            }
        }
    }
}

@Composable
private fun BrideDetailRow(label: Int, icon: ImageVector, value: String?) {
    if (value.isNullOrEmpty()) return
    Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(22.dp))
        Text(stringResource(label), style = DS.type.subhead, color = DS.colors.textSecondary)
        Spacer(Modifier.weight(1f))
        Text(value, style = DS.type.subhead, color = DS.colors.textPrimary)
    }
}
