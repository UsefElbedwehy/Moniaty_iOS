package co.munyati.catalog.presentation

import co.munyati.designsystem.theme.DSGradient
import androidx.compose.material.icons.outlined.Payments
import android.icu.text.MeasureFormat
import android.icu.util.Measure
import android.icu.util.MeasureUnit
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.AccountBalance
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Brush
import androidx.compose.material.icons.outlined.Cake
import androidx.compose.material.icons.outlined.Checkroom
import androidx.compose.material.icons.outlined.ContentCut
import androidx.compose.material.icons.outlined.Coffee
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.PanTool
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material.icons.outlined.CardGiftcard
import androidx.compose.material.icons.outlined.MusicNote
import androidx.compose.material.icons.outlined.Spa
import androidx.compose.material.icons.outlined.Videocam
import androidx.compose.material.icons.outlined.Celebration
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.munyati.catalog.R
import co.munyati.catalog.domain.Budget
import co.munyati.catalog.domain.CatalogCategory
import co.munyati.catalog.domain.ProviderSummary
import co.munyati.catalog.domain.ServiceCard
import co.munyati.catalog.domain.formatAmount
import co.munyati.core.error.AppError
import co.munyati.core.state.ViewState
import co.munyati.designsystem.components.EmptyStateView
import co.munyati.designsystem.components.ErrorStateView
import co.munyati.designsystem.components.StatusBadge
import co.munyati.designsystem.components.StatusBadgeKind
import co.munyati.designsystem.theme.Amiri
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.images.RemoteImage
import co.munyati.shared.navigation.LocalNavigator
import java.util.Locale

/** "٢٬٨٠٠ ر.س" / "SAR 2,800". */
@Composable
internal fun formatSar(amount: Double): String = stringResource(R.string.catalog_price_sar, formatAmount(amount))

/** True at the largest font sizes, where layouts drop to fewer columns (iOS accessibility sizes). */
@Composable
internal fun isLargeText(): Boolean = LocalConfiguration.current.fontScale >= 1.6f

/** Shows a `ViewState`: spinner, content, empty, or error with retry. */
@Composable
internal fun <T> LoadableContent(
    state: ViewState<T>,
    retry: () -> Unit,
    emptyTitle: Int = R.string.catalog_common_empty_title,
    emptyMessage: Int = R.string.catalog_common_empty_message,
    content: @Composable (T) -> Unit,
) {
    val boxed = Modifier.fillMaxWidth().heightIn(min = 240.dp)
    when (state) {
        ViewState.Loading -> Box(boxed, contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = DS.colors.primary, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
        }
        is ViewState.Loaded -> content(state.value)
        is ViewState.Refreshing -> content(state.value)
        ViewState.Empty -> Box(boxed, contentAlignment = Alignment.Center) {
            EmptyStateView(Icons.Outlined.AutoAwesome, stringResource(emptyTitle), stringResource(emptyMessage))
        }
        is ViewState.Error -> Box(boxed, contentAlignment = Alignment.Center) { ErrorStateView(state.error, onRetry = retry) }
        ViewState.Offline -> Box(boxed, contentAlignment = Alignment.Center) { ErrorStateView(AppError.Offline, onRetry = retry) }
    }
}

/** The service card used in grids and carousels (mockup 2). */
@Composable
internal fun ServiceCardView(card: ServiceCard, feature: CatalogFeature, modifier: Modifier = Modifier) {
    val navigator = LocalNavigator.current
    Column(
        modifier = modifier.clickable { navigator.navigate(ServiceRoute(card.id)) },
        verticalArrangement = Arrangement.spacedBy(DSSpacing.xs),
    ) {
        Box(Modifier.fillMaxWidth().height(120.dp)) {
            RemoteImage(
                card.imageUrl,
                modifier = Modifier.fillMaxWidth().height(120.dp).clip(RoundedCornerShape(18.dp)),
                placeholder = DS.colors.primaryMuted,
            )
            FavoriteButton(card, feature, Modifier.align(Alignment.TopEnd).padding(2.dp))
            if (card.isFeatured == true) {
                StatusBadge(StatusBadgeKind.Featured, stringResource(R.string.catalog_badge_featured), Modifier.align(Alignment.BottomStart).padding(6.dp))
            }
        }
        Text(card.title, style = DS.type.headline, color = DS.colors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(card.providerName.orEmpty(), style = DS.type.footnote, color = DS.colors.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
            if (card.isVerified) VerifiedMark()
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(formatSar(card.price), style = DS.type.subhead, color = DS.colors.primary)
            Spacer(Modifier.weight(1f))
            val avg = card.ratingAvg
            if (avg != null && (card.ratingCount ?: 0) > 0) RatingLabel(avg, null)
        }
    }
}

@Composable
internal fun VerifiedMark(size: Dp = 14.dp) {
    Icon(Icons.Filled.Verified, contentDescription = stringResource(R.string.catalog_badge_verified), tint = DS.colors.primary, modifier = Modifier.size(size))
}

@Composable
internal fun FavoriteButton(card: ServiceCard, feature: CatalogFeature, modifier: Modifier = Modifier) {
    val isOn = feature.favorites.isFavorite(card)
    val description = stringResource(if (isOn) R.string.catalog_favorite_remove else R.string.catalog_favorite_add)
    Box(
        modifier = modifier.size(44.dp).clickable(role = Role.Button) { feature.toggleFavorite(card) }.semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(36.dp).clip(CircleShape).background(DS.colors.background.copy(alpha = 0.92f)), contentAlignment = Alignment.Center) {
            Icon(if (isOn) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(18.dp))
        }
    }
}

/** Material icons for the SF Symbol names the dashboard stores (`categories.icon_symbol`). */
internal fun categoryIcon(symbol: String?): ImageVector = when (symbol) {
    "paintbrush.pointed" -> Icons.Outlined.Brush
    "comb" -> Icons.Outlined.ContentCut
    "hand.raised" -> Icons.Outlined.PanTool
    "camera" -> Icons.Outlined.PhotoCamera
    "building.columns" -> Icons.Outlined.AccountBalance
    "sparkles.rectangle.stack" -> Icons.Outlined.Celebration
    "tshirt" -> Icons.Outlined.Checkroom
    "birthday.cake" -> Icons.Outlined.Cake
    "cup.and.saucer" -> Icons.Outlined.Coffee
    "music.note" -> Icons.Outlined.MusicNote
    "leaf" -> Icons.Outlined.Spa
    "gift" -> Icons.Outlined.CardGiftcard
    "video" -> Icons.Outlined.Videocam
    else -> Icons.Outlined.AutoAwesome
}

/** Category icon: the dashboard-uploaded image when present, else the symbol fallback. */
@Composable
internal fun CategoryTile(category: CatalogCategory, modifier: Modifier = Modifier, onOpen: () -> Unit = {}) {
    val navigator = LocalNavigator.current
    Column(
        modifier = modifier.clickable {
            onOpen()
            navigator.navigate(ServicesRoute(categoryId = category.id, title = category.name))
        },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(
            Modifier.size(64.dp).clip(CircleShape).background(DS.colors.primaryMuted)
                .border(1.dp, DS.colors.premiumGold.copy(alpha = 0.55f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (category.iconUrl != null) {
                RemoteImage(category.iconUrl, Modifier.size(30.dp), contentScale = ContentScale.Fit)
            } else {
                Icon(categoryIcon(category.iconSymbol), contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(26.dp))
            }
        }
        // Two lines reserved so every tile in a row is the same height.
        Text(
            category.name,
            style = DS.type.caption,
            color = DS.colors.textPrimary,
            textAlign = TextAlign.Center,
            maxLines = 2,
            minLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/**
 * The bride's budget card (Home v2): remaining amount and a gold progress bar on the surface color,
 * so it stands apart from the burgundy hero above it. Tapping it opens the editor.
 */
@Composable
internal fun BudgetCardView(budget: Budget?, onClick: () -> Unit) {
    val shape = RoundedCornerShape(DSRadius.card)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .fillMaxHeight()
            .clip(shape)
            .background(DS.colors.surface)
            .border(1.dp, DS.colors.border, shape)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(DSSpacing.md),
        verticalArrangement = Arrangement.spacedBy(DSSpacing.xs),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(Icons.Outlined.Payments, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(20.dp))
            Text(stringResource(R.string.catalog_budget_title), style = DS.type.subhead, color = DS.colors.textSecondary, modifier = Modifier.weight(1f))
            Text(
                stringResource(if (budget == null) R.string.catalog_budget_set else R.string.catalog_budget_edit),
                style = DS.type.caption,
                color = DS.colors.primary,
                modifier = Modifier.clip(RoundedCornerShape(DSRadius.pill)).background(DS.colors.primaryMuted).padding(horizontal = 10.dp, vertical = 4.dp),
            )
        }
        if (budget != null) {
            Text(formatSar(budget.remaining), style = DS.type.title1, color = DS.colors.primary, maxLines = 1)
            Text(stringResource(R.string.catalog_budget_remainingOf, formatSar(budget.total)), style = DS.type.footnote, color = DS.colors.textSecondary)
            Spacer(Modifier.weight(1f))
            Box(Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(DSRadius.pill)).background(DS.colors.primaryMuted)) {
                Box(Modifier.fillMaxWidth(budget.usedFraction).fillMaxHeight().clip(RoundedCornerShape(DSRadius.pill)).background(DSGradient.gold))
            }
            Text(stringResource(R.string.catalog_budget_reserved, formatSar(budget.reserved)), style = DS.type.caption, color = DS.colors.textSecondary)
        } else {
            Text(stringResource(R.string.catalog_budget_prompt), style = DS.type.footnote, color = DS.colors.textPrimary)
        }
    }
}

/** A titled horizontal carousel of service cards, with an optional "See all". */
@Composable
internal fun ServiceCarousel(title: String, cards: List<ServiceCard>, feature: CatalogFeature, seeAll: Any? = null) {
    if (cards.isEmpty()) return
    val navigator = LocalNavigator.current
    // Grows with the text size so titles aren't cut to a word at large sizes.
    val cardWidth = (170 * LocalConfiguration.current.fontScale).coerceAtMost(300f).dp
    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            HomeSectionTitle(title, Modifier.weight(1f))
            if (seeAll != null) {
                Text(
                    stringResource(R.string.catalog_common_seeAll),
                    style = DS.type.subhead,
                    color = DS.colors.primary,
                    modifier = Modifier.clickable(role = Role.Button) { navigator.navigate(seeAll) }.padding(DSSpacing.xxs),
                )
            }
        }
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
            cards.forEach { ServiceCardView(it, feature, Modifier.width(cardWidth)) }
        }
    }
}

/** Grid of service cards: two columns, one at the largest text sizes. Lives inside a scroll. */
@Composable
internal fun ServiceGrid(cards: List<ServiceCard>, feature: CatalogFeature) {
    val columns = if (isLargeText()) 1 else 2
    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
        cards.chunked(columns).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
                row.forEach { ServiceCardView(it, feature, Modifier.weight(1f)) }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** "★ 4.8 (12)" from approved bride reviews. */
@Composable
internal fun RatingLabel(avg: Double, count: Int?) {
    val value = String.format(Locale.getDefault(), "%.1f", avg)
    val description = stringResource(R.string.catalog_rating_a11y, value)
    Row(
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.semantics(mergeDescendants = true) { contentDescription = description },
    ) {
        Icon(Icons.Filled.Star, contentDescription = null, tint = DS.colors.premiumGold, modifier = Modifier.size(13.dp))
        Text(if (count != null) "$value ($count)" else value, style = DS.type.caption, color = DS.colors.textSecondary)
    }
}

@Composable
internal fun ProviderAvatar(url: String?, name: String?, size: Dp) {
    Box(
        Modifier.size(size).clip(CircleShape).border(3.dp, DS.colors.background, CircleShape).background(DS.colors.primary),
        contentAlignment = Alignment.Center,
    ) {
        if (url != null) {
            RemoteImage(url, Modifier.size(size))
        } else {
            Text(
                (name?.firstOrNull() ?: 'م').toString(),
                style = TextStyle(fontFamily = Amiri, fontSize = (size.value * 0.42f).sp),
                color = DS.colors.premiumGold,
            )
        }
    }
}

@Composable
internal fun ProviderRow(provider: ProviderSummary, showsChevron: Boolean = true, onClick: (() -> Unit)? = null) {
    val shape = RoundedCornerShape(18.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(DS.colors.surface)
            .border(1.dp, DS.colors.border, shape)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(DSSpacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm),
    ) {
        ProviderAvatar(provider.logoUrl, provider.name, 44.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(provider.name.orEmpty(), style = DS.type.headline, color = DS.colors.textPrimary)
                if (provider.isVerified) VerifiedMark(16.dp)
            }
            val avg = provider.ratingAvg
            val count = provider.ratingCount
            if (avg != null && count != null && count > 0) RatingLabel(avg, count)
            if (provider.femaleStaffOnly) {
                Text(stringResource(R.string.catalog_detail_femaleOnly), style = DS.type.caption, color = DS.colors.textSecondary)
            }
        }
        if (showsChevron) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = DS.colors.textSecondary)
    }
}

@Composable
internal fun InfoRow(icon: ImageVector, title: String, subtitle: String?, onClick: (() -> Unit)? = null) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(vertical = 4.dp)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm),
    ) {
        Box(Modifier.widthIn(min = 28.dp), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = DS.colors.primary)
        }
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = DS.type.subhead, color = DS.colors.textPrimary)
            if (!subtitle.isNullOrEmpty()) Text(subtitle, style = DS.type.footnote, color = DS.colors.textSecondary)
        }
    }
}

/** "3 hours" / "٣ ساعات", "1 hour, 30 minutes" — full unit names in the current language. */
internal fun durationText(minutes: Int, locale: Locale = Locale.getDefault()): String {
    val format = MeasureFormat.getInstance(locale, MeasureFormat.FormatWidth.WIDE)
    val hours = minutes / 60
    val rest = minutes % 60
    return when {
        hours == 0 -> format.formatMeasures(Measure(rest, MeasureUnit.MINUTE))
        rest == 0 -> format.formatMeasures(Measure(hours, MeasureUnit.HOUR))
        else -> format.formatMeasures(Measure(hours, MeasureUnit.HOUR), Measure(rest, MeasureUnit.MINUTE))
    }
}

