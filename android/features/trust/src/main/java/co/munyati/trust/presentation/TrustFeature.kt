@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package co.munyati.trust.presentation

import co.munyati.shared.R as SharedR
import co.munyati.shared.media.GalleryItem
import co.munyati.shared.media.MediaViewer
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material.icons.outlined.Call
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.HelpOutline
import androidx.compose.material.icons.outlined.MailOutline
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.outlined.AddPhotoAlternate
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import co.munyati.core.dates.DisplayDates
import co.munyati.core.error.AppError
import co.munyati.core.state.ViewState
import co.munyati.designsystem.components.DSFormDivider
import co.munyati.designsystem.components.DSFormSection
import co.munyati.designsystem.components.DSPickerRow
import co.munyati.designsystem.components.DSTextFieldRow
import co.munyati.designsystem.components.DSTopBar
import co.munyati.designsystem.components.EmptyStateView
import co.munyati.designsystem.components.ErrorStateView
import co.munyati.designsystem.components.PrimaryButton
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.analytics.AnalyticsEvent
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.images.RemoteImage
import co.munyati.shared.media.ImageCompressor
import co.munyati.shared.media.MediaUploading
import co.munyati.shared.navigation.LocalNavigator
import co.munyati.trust.R
import co.munyati.trust.data.TrustRepository
import co.munyati.trust.domain.BlockedUser
import co.munyati.trust.domain.ReportReason
import co.munyati.trust.domain.ReportTarget
import co.munyati.trust.domain.Review
import co.munyati.trust.domain.ReviewRole
import co.munyati.trust.domain.ReviewsPage
import co.munyati.trust.domain.SupportContact
import co.munyati.trust.domain.SupportTicket
import co.munyati.trust.domain.TrustResult
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import java.util.Locale

// Trust destinations, registered on the App's NavHosts.
@Serializable data class ReviewsListRoute(val providerId: String)
@Serializable data object SupportRoute
@Serializable data object BlockedUsersRoute

/**
 * Public entry point of the Trust feature: reviews, report, block and support. Other features don't
 * depend on this module: the App hands them these views as hooks (same as iOS).
 */
class TrustFeature(
    internal val repository: TrustRepository,
    internal val uploader: MediaUploading,
    /** Guests (no account) are asked to sign in before writing anything. */
    internal val isSignedIn: () -> Boolean,
    internal val requireSignIn: () -> Unit,
    /** Contact channels and the FAQ link from remote config. */
    internal val supportInfo: () -> Pair<List<SupportContact>, String?>,
) {
    /** Rating summary and the latest reviews on a provider page, with "See all". */
    @Composable
    fun ReviewsSection(providerId: String) = ReviewsSectionView(this, providerId)

    /** "Rate your experience" on a completed booking, or the review already written. */
    @Composable
    fun BookingReviewSection(bookingId: String, role: ReviewRole) = BookingReviewView(this, bookingId, role)

    /** The "…" menu: report, and optionally block (a user id, or the other side of a booking). */
    @Composable
    fun MoreMenu(target: ReportTarget, blockUserId: String? = null, blockBookingId: String? = null, onBlocked: (() -> Unit)? = null) =
        MoreMenuView(this, target, blockUserId, blockBookingId, onBlocked)

    /** A help request about one booking. */
    @Composable
    fun TicketSheet(bookingId: String?, onDismiss: () -> Unit) = TicketComposer(this, bookingId, onSent = {}, onDismiss = onDismiss)

    fun NavGraphBuilder.destinations() {
        composable<ReviewsListRoute> { ReviewsListScreen(this@TrustFeature, it.toRoute<ReviewsListRoute>().providerId) }
        composable<SupportRoute> { SupportScreen(this@TrustFeature) }
        composable<BlockedUsersRoute> { BlockedUsersScreen(this@TrustFeature) }
    }
}

/** A Trust string by its iOS key (keys built at run time, like "report.reason.\(raw)"). */
@Composable
internal fun trustString(key: String, vararg args: Any): String = trustKeys[key]?.let { stringResource(it, *args) } ?: key

internal fun refusal(context: Context, code: String): String =
    context.getString(trustKeys["error.$code"] ?: R.string.trust_error_generic)

private suspend fun <T> loadState(empty: (T) -> Boolean = { false }, fetch: suspend () -> T): ViewState<T> = try {
    fetch().let { if (empty(it)) ViewState.Empty else ViewState.Loaded(it) }
} catch (e: CancellationException) {
    throw e
} catch (e: Exception) {
    ViewState.Error(AppError.from(e))
}

@Composable
private fun Spinner(modifier: Modifier = Modifier) = Box(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
    CircularProgressIndicator(color = DS.colors.primary, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
}

@Composable
private fun MessageDialog(message: String?, onDismiss: () -> Unit) {
    if (message == null) return
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(message) },
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.trust_common_ok)) } },
    )
}

/** A bottom sheet with Cancel / title / Send, like the iOS form sheets. */
@Composable
private fun ComposeSheet(title: String, canSend: Boolean, isSending: Boolean, onDismiss: () -> Unit, onSend: () -> Unit, content: @Composable () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = DS.colors.background) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = DSSpacing.lg).padding(bottom = DSSpacing.xl),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.md),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) { Text(stringResource(R.string.trust_common_cancel), color = DS.colors.primary) }
                Text(title, style = DS.type.headline, color = DS.colors.textPrimary, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
                TextButton(onClick = onSend, enabled = canSend && !isSending) {
                    Text(stringResource(R.string.trust_common_send), color = if (canSend) DS.colors.primary else DS.colors.disabled)
                }
            }
            content()
        }
    }
}

// Stars

@Composable
internal fun StarsView(rating: Double, size: Int = 12) {
    val label = stringResource(R.string.trust_reviews_stars, Math.round(rating).toInt())
    Row(Modifier.semantics(mergeDescendants = true) { contentDescription = label }, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        (1..5).forEach { star ->
            Icon(if (star <= Math.round(rating)) Icons.Filled.Star else Icons.Outlined.StarOutline, contentDescription = null,
                tint = DS.colors.premiumGold, modifier = Modifier.size(size.dp))
        }
    }
}

@Composable
private fun StarPicker(rating: Int, onChange: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = DSSpacing.sm), horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm, Alignment.CenterHorizontally)) {
        (1..5).forEach { star ->
            val label = stringResource(R.string.trust_reviews_stars, star)
            Icon(
                if (star <= rating) Icons.Filled.Star else Icons.Outlined.StarOutline, contentDescription = label, tint = DS.colors.premiumGold,
                modifier = Modifier.size(40.dp).clickable(role = Role.RadioButton) { onChange(star) }.semantics { selected = star == rating },
            )
        }
    }
}

// Provider reviews

@Composable
private fun ReviewsSectionView(feature: TrustFeature, providerId: String) {
    val navigator = LocalNavigator.current
    var page by remember { mutableStateOf<ReviewsPage?>(null) }
    LaunchedEffect(providerId) { page = runCatching { feature.repository.providerReviews(providerId, 3, 0) }.getOrNull() }
    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.trust_reviews_title), style = DS.type.title2, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
            if ((page?.ratingCount ?: 0) > 3) {
                Text(stringResource(R.string.trust_reviews_seeAll), style = DS.type.subhead, color = DS.colors.primary,
                    modifier = Modifier.clickable(role = Role.Button) { navigator.navigate(ReviewsListRoute(providerId)) }.padding(DSSpacing.xxs))
            }
        }
        val p = page
        when {
            p == null -> Spinner()
            p.ratingCount == 0 -> Text(stringResource(R.string.trust_reviews_none), style = DS.type.footnote, color = DS.colors.textSecondary)
            else -> {
                RatingSummary(p)
                p.items.take(3).forEach { ReviewRow(feature, it) }
            }
        }
    }
}

@Composable
private fun RatingSummary(page: ReviewsPage) {
    val avg = page.ratingAvg ?: 0.0
    Row(Modifier.semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.lg)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(String.format(Locale.getDefault(), "%.1f", avg), style = DS.type.largeTitle, color = DS.colors.textPrimary)
            StarsView(avg)
            Text(stringResource(R.string.trust_reviews_count, page.ratingCount), style = DS.type.caption, color = DS.colors.textSecondary)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            (5 downTo 1).forEach { star ->
                val n = page.distribution[star.toString()] ?: 0
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(String.format(Locale.getDefault(), "%d", star), style = DS.type.caption, color = DS.colors.textPrimary, modifier = Modifier.width(12.dp))
                    Box(Modifier.weight(1f).height(6.dp).clip(RoundedCornerShape(DSRadius.pill)).background(DS.colors.primaryMuted)) {
                        val fraction = if (page.ratingCount > 0) n.toFloat() / page.ratingCount else 0f
                        Box(Modifier.fillMaxWidth(fraction).height(6.dp).clip(RoundedCornerShape(DSRadius.pill)).background(DS.colors.premiumGold))
                    }
                }
            }
        }
    }
}

@Composable
private fun ReviewRow(feature: TrustFeature, review: Review) {
    val shape = RoundedCornerShape(DSRadius.card)
    var viewerStart by remember { mutableStateOf<Int?>(null) }
    Column(
        Modifier.fillMaxWidth().clip(shape).background(DS.colors.surface).border(1.dp, DS.colors.border, shape).padding(DSSpacing.md),
        verticalArrangement = Arrangement.spacedBy(DSSpacing.xs),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(review.authorName, style = DS.type.headline, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
            MoreMenuView(feature, ReportTarget.Review(review.id), null, null, null)
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
            StarsView(review.rating.toDouble())
            review.createdAt?.let { Text(DisplayDates.pattern(it, "yMMMd"), style = DS.type.caption, color = DS.colors.textSecondary) }
            review.serviceTitle?.let { Text("· $it", style = DS.type.caption, color = DS.colors.textSecondary, maxLines = 1) }
        }
        if (!review.body.isNullOrEmpty()) Text(review.body, style = DS.type.body, color = DS.colors.textPrimary)
        if (review.photoUrls.isNotEmpty()) {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                review.photoUrls.forEachIndexed { index, url ->
                    val label = stringResource(SharedR.string.shared_media_photo, index + 1, review.photoUrls.size)
                    val hint = stringResource(SharedR.string.shared_media_openHint)
                    RemoteImage(
                        url,
                        Modifier.size(72.dp).clip(RoundedCornerShape(12.dp))
                            .clickable(onClickLabel = hint, role = Role.Button) { viewerStart = index }
                            .semantics { contentDescription = label },
                        placeholder = DS.colors.primaryMuted,
                    )
                }
            }
        }
        viewerStart?.let { start ->
            MediaViewer(review.photoUrls.map { GalleryItem.Image(it) }, start, onDismiss = { viewerStart = null })
        }
        review.providerReply?.let { reply ->
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(DS.colors.primaryMuted).padding(DSSpacing.sm),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(stringResource(R.string.trust_reviews_reply), style = DS.type.caption, color = DS.colors.primary)
                Text(reply, style = DS.type.footnote, color = DS.colors.textPrimary)
            }
        }
    }
}

@Composable
private fun ReviewsListScreen(feature: TrustFeature, providerId: String) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var state: ViewState<ReviewsPage> by remember { mutableStateOf(ViewState.Loading) }
    var items by remember { mutableStateOf(emptyList<Review>()) }
    var hasMore by remember { mutableStateOf(true) }

    suspend fun load(reset: Boolean) {
        try {
            val page = feature.repository.providerReviews(providerId, 20, if (reset) 0 else items.size)
            items = if (reset) page.items else items + page.items
            hasMore = page.items.size == 20
            state = ViewState.Loaded(page)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            if (state.value == null) state = ViewState.Error(AppError.from(e))
        }
    }
    LaunchedEffect(Unit) {
        analytics.screen("reviews")
        load(reset = true)
    }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.trust_reviews_title), navigator.back, stringResource(R.string.trust_back))
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
            when (val s = state) {
                ViewState.Loading -> Spinner(Modifier.padding(top = DSSpacing.xxl))
                is ViewState.Error -> ErrorStateView(s.error) { scope.launch { load(reset = true) } }
                else -> {
                    s.value?.let { RatingSummary(it) }
                    items.forEach { ReviewRow(feature, it) }
                    if (hasMore && items.isNotEmpty()) {
                        Spinner()
                        LaunchedEffect(items.size) { load(reset = false) }
                    }
                }
            }
        }
    }
}

// Booking review

@Composable
private fun BookingReviewView(feature: TrustFeature, bookingId: String, role: ReviewRole) {
    var reviewState by remember { mutableStateOf<co.munyati.trust.domain.MyReviewState?>(null) }
    var composing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(bookingId) { reviewState = runCatching { feature.repository.myReview(bookingId) }.getOrNull() }

    val review = reviewState?.review
    when {
        review != null -> Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
            Text(stringResource(if (role == ReviewRole.Bride) R.string.trust_review_mine_bride else R.string.trust_review_mine_provider),
                style = DS.type.headline, color = DS.colors.textPrimary)
            StarsView(review.rating.toDouble(), size = 16)
            review.body?.let { Text(it, style = DS.type.subhead, color = DS.colors.textPrimary) }
            if (review.status == "pending") Text(stringResource(R.string.trust_review_pending), style = DS.type.footnote, color = DS.colors.textSecondary)
        }
        reviewState?.canReview == true -> Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
            Text(stringResource(if (role == ReviewRole.Bride) R.string.trust_review_prompt_bride else R.string.trust_review_prompt_provider),
                style = DS.type.headline, color = DS.colors.textPrimary)
            PrimaryButton(stringResource(R.string.trust_review_write), icon = Icons.Outlined.StarOutline) { composing = true }
        }
    }
    if (composing) {
        ReviewComposer(feature, bookingId, role, onDismiss = { composing = false }) {
            scope.launch { reviewState = runCatching { feature.repository.myReview(bookingId) }.getOrNull() }
        }
    }
}

@Composable
private fun ReviewComposer(feature: TrustFeature, bookingId: String, role: ReviewRole, onDismiss: () -> Unit, onSent: () -> Unit) {
    val context = LocalContext.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var rating by remember { mutableStateOf(0) }
    var text by remember { mutableStateOf("") }
    var photos by remember { mutableStateOf(emptyList<String>()) }
    var isUploading by remember { mutableStateOf(false) }
    var isSending by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(4)) { uris ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        isUploading = true
        scope.launch {
            var failed = false
            for (uri in uris.take(4 - photos.size)) {
                val jpeg = withContext(Dispatchers.IO) { ImageCompressor.jpeg(context, uri) }
                val url = jpeg?.let { runCatching { feature.uploader.uploadJpeg(it, "reviews") }.getOrNull() }
                if (url != null) photos = photos + url else failed = true
            }
            isUploading = false
            if (failed) message = context.getString(R.string.trust_error_invalid_photo)
        }
    }

    ComposeSheet(stringResource(R.string.trust_review_title), rating > 0 && !isUploading, isSending, onDismiss, onSend = {
        isSending = true
        scope.launch {
            try {
                when (val result = feature.repository.submitReview(bookingId, rating, text.trim().ifEmpty { null }, photos)) {
                    TrustResult.Ok -> {
                        analytics(AnalyticsEvent.ReviewSubmitted, bookingId, role.rawValue)
                        onSent()
                        onDismiss()
                    }
                    is TrustResult.Refused -> message = refusal(context, result.code)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                message = context.getString(R.string.trust_error_generic)
            } finally {
                isSending = false
            }
        }
    }) {
        StarPicker(rating) { rating = it }
        DSFormSection(footer = stringResource(if (role == ReviewRole.Bride) R.string.trust_review_footer_bride else R.string.trust_review_footer_provider)) {
            DSTextFieldRow(text, { text = it },
                stringResource(if (role == ReviewRole.Bride) R.string.trust_review_text_bride else R.string.trust_review_text_provider), minLines = 4)
        }
        if (role == ReviewRole.Bride) {
            DSFormSection(stringResource(R.string.trust_review_photos)) {
                if (photos.isNotEmpty()) {
                    Row(Modifier.horizontalScroll(rememberScrollState()).padding(DSSpacing.sm), horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                        photos.forEach { RemoteImage(it, Modifier.size(64.dp).clip(RoundedCornerShape(10.dp)), placeholder = DS.colors.primaryMuted) }
                    }
                }
                if (photos.size < 4) {
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(enabled = !isUploading, role = Role.Button) {
                            picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                        }.padding(horizontal = DSSpacing.md),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
                    ) {
                        if (isUploading) CircularProgressIndicator(color = DS.colors.primary, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
                        else Icon(Icons.Outlined.AddPhotoAlternate, contentDescription = null, tint = DS.colors.primary)
                        Text(stringResource(R.string.trust_review_addPhotos), style = DS.type.body, color = DS.colors.primary)
                    }
                }
            }
        }
    }
    MessageDialog(message) { message = null }
}

// Report and block

@Composable
private fun MoreMenuView(feature: TrustFeature, target: ReportTarget, blockUserId: String?, blockBookingId: String?, onBlocked: (() -> Unit)?) {
    val analytics = LocalAnalytics.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var open by remember { mutableStateOf(false) }
    var reporting by remember { mutableStateOf(false) }
    var confirmBlock by remember { mutableStateOf(false) }
    var notice by remember { mutableStateOf<String?>(null) }
    val canBlock = blockUserId != null || blockBookingId != null

    Box {
        Box(Modifier.size(44.dp).clickable(role = Role.Button) { open = true }, contentAlignment = Alignment.Center) {
            Icon(Icons.Filled.MoreVert, contentDescription = stringResource(R.string.trust_more), tint = DS.colors.primary)
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            DropdownMenuItem(
                text = { Text(stringResource(R.string.trust_report_action), color = DS.colors.error) },
                leadingIcon = { Icon(Icons.Outlined.Flag, contentDescription = null, tint = DS.colors.error) },
                onClick = {
                    open = false
                    if (feature.isSignedIn()) reporting = true else feature.requireSignIn()
                },
            )
            if (canBlock) {
                DropdownMenuItem(
                    text = { Text(stringResource(R.string.trust_block_action), color = DS.colors.error) },
                    leadingIcon = { Icon(Icons.Outlined.Block, contentDescription = null, tint = DS.colors.error) },
                    onClick = {
                        open = false
                        if (feature.isSignedIn()) confirmBlock = true else feature.requireSignIn()
                    },
                )
            }
        }
    }

    if (reporting) ReportSheet(feature, target, onDismiss = { reporting = false }) { notice = context.getString(R.string.trust_report_thanks) }
    if (confirmBlock) {
        AlertDialog(
            onDismissRequest = { confirmBlock = false },
            title = { Text(stringResource(R.string.trust_block_confirm_title)) },
            text = { Text(stringResource(R.string.trust_block_confirm_message)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmBlock = false
                    scope.launch {
                        notice = try {
                            if (blockUserId != null) feature.repository.block(blockUserId) else if (blockBookingId != null) feature.repository.blockBookingParty(blockBookingId)
                            analytics(AnalyticsEvent.UserBlocked, blockUserId ?: blockBookingId)
                            onBlocked?.invoke()
                            context.getString(R.string.trust_block_done)
                        } catch (e: CancellationException) {
                            throw e
                        } catch (e: Exception) {
                            context.getString(R.string.trust_error_generic)
                        }
                    }
                }) { Text(stringResource(R.string.trust_block_action), color = DS.colors.error) }
            },
            dismissButton = { TextButton(onClick = { confirmBlock = false }) { Text(stringResource(R.string.trust_common_cancel)) } },
        )
    }
    MessageDialog(notice) { notice = null }
}

@Composable
private fun ReportSheet(feature: TrustFeature, target: ReportTarget, onDismiss: () -> Unit, onSent: () -> Unit) {
    val context = LocalContext.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var reason by remember { mutableStateOf(ReportReason.Inappropriate) }
    var details by remember { mutableStateOf("") }
    var isSending by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    val labels = ReportReason.entries.associateWith { trustString("report.reason.${it.rawValue}") }

    ComposeSheet(stringResource(R.string.trust_report_title), true, isSending, onDismiss, onSend = {
        isSending = true
        scope.launch {
            try {
                when (val result = feature.repository.report(target, reason, details.trim().ifEmpty { null })) {
                    TrustResult.Ok -> {
                        analytics(AnalyticsEvent.ReportSubmitted, target.id, target.type)
                        onDismiss()
                        onSent()
                    }
                    is TrustResult.Refused -> message = refusal(context, result.code)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                message = context.getString(R.string.trust_error_generic)
            } finally {
                isSending = false
            }
        }
    }) {
        DSFormSection {
            DSPickerRow(stringResource(R.string.trust_report_reason), ReportReason.entries, reason, label = { labels.getValue(it) }) { reason = it }
        }
        DSFormSection(footer = stringResource(R.string.trust_report_footer)) {
            DSTextFieldRow(details, { details = it }, stringResource(R.string.trust_report_details), minLines = 3)
        }
    }
    MessageDialog(message) { message = null }
}

@Composable
private fun BlockedUsersScreen(feature: TrustFeature) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var state: ViewState<List<BlockedUser>> by remember { mutableStateOf(ViewState.Loading) }
    var failed by remember { mutableStateOf(false) }
    suspend fun load() {
        val fresh = loadState({ it.isEmpty() }) { feature.repository.blockedUsers() }
        if (fresh is ViewState.Error && state.value != null) return
        state = fresh
    }
    LaunchedEffect(Unit) {
        analytics.screen("blocked_users")
        load()
    }
    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.trust_block_list_title), navigator.back, stringResource(R.string.trust_back))
        when (val s = state) {
            ViewState.Loading -> Spinner(Modifier.padding(top = 120.dp))
            is ViewState.Error -> ErrorStateView(s.error) { scope.launch { load() } }
            ViewState.Empty, ViewState.Offline -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                EmptyStateView(Icons.Outlined.Block, stringResource(R.string.trust_block_empty_title), stringResource(R.string.trust_block_empty_message))
            }
            else -> Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg)) {
                DSFormSection {
                    s.value.orEmpty().forEachIndexed { index, user ->
                        if (index > 0) DSFormDivider()
                        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = DSSpacing.md), verticalAlignment = Alignment.CenterVertically) {
                            Text(user.name, style = DS.type.body, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                            TextButton(onClick = {
                                scope.launch {
                                    runCatching { feature.repository.unblock(user.userId) }.onFailure { failed = true }
                                    load()
                                }
                            }) { Text(stringResource(R.string.trust_block_unblock), color = DS.colors.primary) }
                        }
                    }
                }
            }
        }
    }
    MessageDialog(if (failed) stringResource(R.string.trust_error_generic) else null) { failed = false }
}

// Support

@Composable
private fun SupportScreen(feature: TrustFeature) {
    val navigator = LocalNavigator.current
    val analytics = LocalAnalytics.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val (contacts, faqUrl) = remember { feature.supportInfo() }
    var tickets by remember { mutableStateOf(emptyList<SupportTicket>()) }
    var composing by remember { mutableStateOf(false) }
    suspend fun load() {
        if (!feature.isSignedIn()) return
        runCatching { feature.repository.tickets() }.getOrNull()?.let { tickets = it }
    }
    LaunchedEffect(Unit) {
        analytics.screen("support")
        load()
    }
    fun open(url: String) = runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(stringResource(R.string.trust_support_title), navigator.back, stringResource(R.string.trust_back))
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.lg)) {
            DSFormSection(footer = stringResource(R.string.trust_support_footer)) {
                if (faqUrl != null) {
                    SupportRow(Icons.Outlined.HelpOutline, stringResource(R.string.trust_support_faq), null) { open(faqUrl) }
                    if (contacts.isNotEmpty()) DSFormDivider()
                }
                contacts.forEachIndexed { index, contact ->
                    if (index > 0) DSFormDivider()
                    val icon = when (contact.kind) {
                        SupportContact.Kind.Email -> Icons.Outlined.MailOutline
                        SupportContact.Kind.Phone -> Icons.Outlined.Call
                        SupportContact.Kind.Whatsapp -> Icons.Outlined.ChatBubbleOutline
                    }
                    SupportRow(icon, trustString("support.contact.${contact.kind.rawValue}"), contact.value) { open(contact.url) }
                }
            }
            DSFormSection(stringResource(R.string.trust_support_tickets)) {
                SupportRow(Icons.Outlined.EditNote, stringResource(R.string.trust_support_newTicket), null, tint = DS.colors.primary) {
                    if (feature.isSignedIn()) composing = true else feature.requireSignIn()
                }
                tickets.forEach { ticket ->
                    DSFormDivider()
                    Column(Modifier.fillMaxWidth().padding(horizontal = DSSpacing.md, vertical = DSSpacing.sm), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row {
                            Text(ticket.subject, style = DS.type.headline, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                            Text(trustString("support.status.${ticket.status}"), style = DS.type.caption,
                                color = if (ticket.status == "answered") DS.colors.success else DS.colors.textSecondary)
                        }
                        Text(ticket.message, style = DS.type.footnote, color = DS.colors.textSecondary, maxLines = 2)
                        ticket.adminReply?.let {
                            Text(it, style = DS.type.subhead, color = DS.colors.textPrimary,
                                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(DS.colors.primaryMuted).padding(DSSpacing.sm))
                        }
                    }
                }
            }
        }
    }
    if (composing) TicketComposer(feature, null, onSent = { scope.launch { load() } }, onDismiss = { composing = false })
}

@Composable
private fun SupportRow(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, subtitle: String?, tint: androidx.compose.ui.graphics.Color = DS.colors.textPrimary, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = DSSpacing.md, vertical = DSSpacing.xs),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm),
    ) {
        Icon(icon, contentDescription = null, tint = DS.colors.primary)
        Column {
            Text(title, style = DS.type.body, color = tint)
            if (subtitle != null) {
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                    Text(subtitle, style = DS.type.footnote, color = DS.colors.textSecondary)
                }
            }
        }
    }
}

@Composable
private fun TicketComposer(feature: TrustFeature, bookingId: String?, onSent: () -> Unit, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val analytics = LocalAnalytics.current
    val scope = rememberCoroutineScope()
    var subject by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var isSending by remember { mutableStateOf(false) }
    var alert by remember { mutableStateOf<String?>(null) }
    val isValid = subject.trim().length >= 3 && message.trim().length >= 3

    ComposeSheet(stringResource(R.string.trust_support_newTicket), isValid, isSending, onDismiss, onSend = {
        isSending = true
        scope.launch {
            try {
                when (val result = feature.repository.createTicket(subject, message, bookingId)) {
                    TrustResult.Ok -> {
                        analytics(AnalyticsEvent.SupportTicketCreated, bookingId)
                        onSent()
                        onDismiss()
                    }
                    is TrustResult.Refused -> alert = refusal(context, result.code)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                alert = context.getString(R.string.trust_error_generic)
            } finally {
                isSending = false
            }
        }
    }) {
        DSFormSection(footer = if (bookingId != null) stringResource(R.string.trust_support_aboutBooking) else null) {
            DSTextFieldRow(subject, { subject = it }, stringResource(R.string.trust_support_subject))
            DSFormDivider()
            DSTextFieldRow(message, { message = it }, stringResource(R.string.trust_support_message), minLines = 5)
        }
    }
    MessageDialog(alert) { alert = null }
}
