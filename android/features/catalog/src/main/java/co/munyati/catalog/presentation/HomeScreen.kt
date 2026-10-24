package co.munyati.catalog.presentation

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForwardIos
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.EditCalendar
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.munyati.catalog.R
import co.munyati.catalog.domain.CatalogCategory
import co.munyati.catalog.domain.HomeBanner
import co.munyati.catalog.domain.HomeContent
import co.munyati.catalog.domain.ServiceFilter
import co.munyati.core.error.AppError
import co.munyati.core.state.ViewState
import co.munyati.designsystem.brand.DSBrand
import co.munyati.designsystem.brand.DSBrandHero
import co.munyati.designsystem.brand.DSSparkle
import co.munyati.designsystem.brand.LightStatusBarIcons
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSGradient
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSShadow
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.analytics.AnalyticsEvent
import co.munyati.shared.analytics.LocalAnalytics
import co.munyati.shared.images.RemoteImage
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.time.LocalTime
import androidx.compose.ui.draw.shadow

// Home (Home v2: brand hero, carousel, picks, trust strip, provider invite). Mirrors iOS HomeScreen.

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun HomeScreen(feature: CatalogFeature) {
    val context = feature.context
    val analytics = LocalAnalytics.current
    val navigator = LocalNavigator.current
    val scope = rememberCoroutineScope()
    var state: ViewState<HomeContent> by remember { mutableStateOf(ViewState.Loading) }
    var refreshing by remember { mutableStateOf(false) }
    var showBudget by remember { mutableStateOf(false) }
    val budget = feature.budget.budget

    suspend fun load() {
        if (state.value == null) state = ViewState.Loading
        try {
            state = ViewState.Loaded(feature.repository.home(context.cityIds, feature.budget.maxPrice))
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            if (state.value == null) state = ViewState.Error(AppError.from(e))
        }
    }

    LaunchedEffect(context.cityIds, feature.budget.maxPrice, context.isGuest) { load() }
    LaunchedEffect(context.isGuest) { feature.budget.load(context.isGuest) }
    LaunchedEffect(Unit) { analytics.screen("bride_home") }
    LightStatusBarIcons()

    Box(Modifier.fillMaxSize().background(DS.colors.background)) {
        PullToRefreshBox(
            isRefreshing = refreshing,
            onRefresh = { scope.launch { refreshing = true; load(); refreshing = false } },
            modifier = Modifier.fillMaxSize(),
        ) {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                HomeHero(feature)
                SearchEntry(Modifier.padding(horizontal = DSSpacing.lg).offset(y = (-28).dp)) {
                    navigator.navigate(ServicesRoute(title = null))
                }
                Column(
                    Modifier.padding(start = DSSpacing.lg, end = DSSpacing.lg, bottom = DSSpacing.xl).offset(y = (-28 + 20).dp),
                    verticalArrangement = Arrangement.spacedBy(DSSpacing.xl),
                ) {
                    if (!context.isGuest) {
                        WeddingRow(feature) { showBudget = true }
                    }
                    LoadableContent(state, retry = { scope.launch { load() } }) { home ->
                        Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xl)) {
                            HomeCarousel(home.banners.map { HomeSlide.Banner(it) } + listOf(HomeSlide.Budget, HomeSlide.Discover)) { slide ->
                                when (slide) {
                                    is HomeSlide.Banner -> {
                                        analytics(AnalyticsEvent.BannerClick, slide.banner.id)
                                        slide.banner.linkUrl?.let { feature.openLink?.invoke(it) }
                                    }
                                    HomeSlide.Budget -> if (context.isGuest) feature.requireSignIn() else showBudget = true
                                    HomeSlide.Discover -> navigator.navigate(ServicesRoute(title = null))
                                }
                            }
                            Categories(home.categories) { analytics(AnalyticsEvent.CategoryOpen, it.id) }
                            val withinBudgetTitle = stringResource(R.string.catalog_home_withinBudget)
                            ServiceCarousel(
                                title = stringResource(if (budget == null) R.string.catalog_home_featured else R.string.catalog_home_withinBudget),
                                cards = home.featured,
                                feature = feature,
                                seeAll = ServicesRoute(title = withinBudgetTitle, withinBudget = budget != null),
                            )
                            WhyMunyatiStrip()
                            val newestTitle = stringResource(R.string.catalog_home_newest)
                            ServiceCarousel(
                                title = newestTitle,
                                cards = home.newest,
                                feature = feature,
                                seeAll = ServicesRoute(title = newestTitle, sort = ServiceFilter.Sort.Newest.rawValue),
                            )
                            ProviderInviteCard { feature.openProviderInvite?.invoke() }
                        }
                    }
                }
            }
        }
        // The status bar in the hero's burgundy, so scrolled content never runs under the clock.
        Box(Modifier.fillMaxWidth().windowInsetsTopHeight(WindowInsets.statusBars).background(DSGradient.primaryStart))
    }

    if (showBudget) BudgetSheet(feature.budget) { showBudget = false }
}

@Composable
private fun HomeHero(feature: CatalogFeature) {
    val context = feature.context
    val navigator = LocalNavigator.current
    val greeting = stringResource(if (LocalTime.now().hour < 12) R.string.catalog_home_greeting_morning else R.string.catalog_home_greeting_evening)
    DSBrandHero(Modifier.fillMaxWidth()) {
        Column(
            Modifier.statusBarsPadding().padding(start = DSSpacing.lg, end = DSSpacing.lg, top = DSSpacing.sm, bottom = DSSpacing.xxl + 28.dp),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.md),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                DSBrand.WordmarkReversed(Modifier.height(40.dp), contentDescription = stringResource(R.string.catalog_home_brand))
                Spacer(Modifier.weight(1f))
                Box(
                    Modifier.size(44.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.14f))
                        .clickable(role = Role.Button) { navigator.navigate(FavoritesRoute) },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Outlined.FavoriteBorder, contentDescription = stringResource(R.string.catalog_favorites_title), tint = Color.White)
                }
                val pill = RoundedCornerShape(DSRadius.pill)
                Row(
                    Modifier.heightIn(min = 44.dp).clip(pill).background(Color.White.copy(alpha = 0.14f))
                        .border(1.dp, DS.colors.premiumGold.copy(alpha = 0.6f), pill)
                        .clickable(role = Role.Button, onClickLabel = stringResource(R.string.catalog_cities_hint), onClick = feature.openCityPicker)
                        .padding(horizontal = DSSpacing.sm),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(Icons.Outlined.LocationOn, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                    Text(context.citySummary, style = DS.type.subhead, color = Color.White, maxLines = 1)
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(greeting, style = DS.type.subhead, color = Color.White.copy(alpha = 0.85f))
                Text(context.displayName ?: stringResource(R.string.catalog_home_guestName), style = DS.type.largeTitle, color = Color.White, maxLines = 2)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    DSSparkle(10.dp)
                    Text(stringResource(R.string.catalog_home_tagline), style = DS.type.footnote.copy(fontWeight = FontWeight.Medium), color = DS.colors.premiumGold)
                }
            }
        }
    }
}

@Composable
private fun SearchEntry(modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(DSRadius.card)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .shadow(DSShadow.level2, shape)
            .clip(shape)
            .background(DS.colors.surface)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(start = DSSpacing.md, end = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm),
    ) {
        Icon(Icons.Outlined.Search, contentDescription = null, tint = DS.colors.primary)
        Text(
            stringResource(R.string.catalog_search_placeholder), style = DS.type.body, color = DS.colors.textSecondary,
            maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f),
        )
        Box(Modifier.size(36.dp).clip(CircleShape).background(DS.colors.primary), contentAlignment = Alignment.Center) {
            Icon(Icons.Outlined.Tune, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
private fun WeddingRow(feature: CatalogFeature, onEdit: () -> Unit) {
    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
        if (!isLargeText()) {
            WeddingCountdownCard(feature.daysUntilWedding, Modifier.width(128.dp).fillMaxHeight(), onEdit)
        }
        Box(Modifier.weight(1f).fillMaxHeight()) { BudgetCardView(feature.budget.budget, onEdit) }
    }
}

// Pieces

/** A section title with the gold sparkle from the logo. */
@Composable
internal fun HomeSectionTitle(title: String, modifier: Modifier = Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        DSSparkle(11.dp)
        Text(title, style = DS.type.title2, color = DS.colors.textPrimary, modifier = Modifier.semantics { heading() })
    }
}

/** One carousel page: a dashboard banner or a built-in brand slide. */
internal sealed interface HomeSlide {
    data class Banner(val banner: HomeBanner) : HomeSlide
    data object Budget : HomeSlide
    data object Discover : HomeSlide
}

/** The auto-advancing, looping Home carousel with page dots under it. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun HomeCarousel(slides: List<HomeSlide>, onTap: (HomeSlide) -> Unit) {
    val count = slides.size
    // A long virtual strip starting in the middle, so swiping either way loops.
    val start = if (count > 1) (Int.MAX_VALUE / 2).let { it - it % count } else 0
    val pager = rememberPagerState(initialPage = start) { if (count > 1) Int.MAX_VALUE else count }
    if (count > 1) {
        LaunchedEffect(pager.settledPage, count) {
            delay(5_000)
            pager.animateScrollToPage(pager.currentPage + 1)
        }
    }
    val height = (200 * LocalConfiguration.current.fontScale).coerceAtMost(270f).dp
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
        HorizontalPager(pager, Modifier.fillMaxWidth().height(height), pageSpacing = DSSpacing.xs) { page ->
            val slide = slides[page % count]
            HomeSlideCard(slide) { onTap(slide) }
        }
        if (count > 1) {
            val index = pager.currentPage % count
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                repeat(count) { i ->
                    Box(
                        Modifier.height(5.dp).width(if (i == index) 16.dp else 5.dp).clip(CircleShape)
                            .background(if (i == index) DS.colors.primary else DS.colors.primary.copy(alpha = 0.35f)),
                    )
                }
            }
        }
    }
}

@Composable
private fun HomeSlideCard(slide: HomeSlide, onClick: () -> Unit) {
    val banner = (slide as? HomeSlide.Banner)?.banner
    if (banner != null && banner.isImageOnly) {
        // A designed banner: shown exactly as uploaded.
        val label = banner.subtitle ?: stringResource(R.string.catalog_home_slide_banner_image)
        RemoteImage(
            banner.imageUrl,
            Modifier.fillMaxSize().clip(RoundedCornerShape(DSRadius.card))
                .clickable(role = Role.Button, onClick = onClick)
                .semantics { contentDescription = label },
            contentScale = ContentScale.Crop,
        )
        return
    }
    val isGold = slide == HomeSlide.Budget
    val ink = if (isGold) DS.colors.primaryPress else Color.White
    val badge = if (isGold) stringResource(R.string.catalog_home_slide_budget_badge) else null
    val title = when (slide) {
        is HomeSlide.Banner -> slide.banner.title.orEmpty()
        HomeSlide.Budget -> stringResource(R.string.catalog_home_slide_budget_title)
        HomeSlide.Discover -> stringResource(R.string.catalog_home_slide_discover_title)
    }
    val subtitle = when (slide) {
        is HomeSlide.Banner -> slide.banner.subtitle
        HomeSlide.Budget -> stringResource(R.string.catalog_home_slide_budget_subtitle)
        HomeSlide.Discover -> stringResource(R.string.catalog_home_slide_discover_subtitle)
    }
    val cta = when (slide) {
        is HomeSlide.Banner -> if (slide.banner.linkUrl == null) null else slide.banner.cta
        HomeSlide.Budget -> stringResource(R.string.catalog_home_slide_budget_cta)
        HomeSlide.Discover -> stringResource(R.string.catalog_home_slide_discover_cta)
    }
    val shape = RoundedCornerShape(DSRadius.card)
    val imageUrl = (slide as? HomeSlide.Banner)?.banner?.imageUrl
    Box(Modifier.fillMaxSize().clip(shape).clickable(role = Role.Button, onClick = onClick)) {
        if (imageUrl != null) {
            RemoteImage(imageUrl, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            // Darkens the text side so white text stays readable on any photo.
            Box(Modifier.fillMaxSize().background(Brush.horizontalGradient(listOf(Color.Black.copy(alpha = 0.6f), Color.Transparent))))
        } else {
            Box(Modifier.fillMaxSize().background(if (isGold) DSGradient.gold else DSGradient.primary))
            Image(
                painterResource(co.munyati.designsystem.R.drawable.brand_ring),
                contentDescription = null,
                colorFilter = ColorFilter.tint(if (isGold) DS.colors.primary.copy(alpha = 0.14f) else DS.colors.premiumGold.copy(alpha = 0.22f)),
                modifier = Modifier.align(Alignment.CenterEnd).offset(x = 30.dp).size(170.dp),
            )
            if (!isGold) DSSparkle(14.dp, Modifier.align(Alignment.TopEnd).padding(DSSpacing.lg))
        }
        Column(
            Modifier.fillMaxHeight().widthIn(max = 300.dp).padding(DSSpacing.lg),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.xs),
        ) {
            if (badge != null) {
                Text(
                    badge, style = DS.type.caption, color = ink,
                    modifier = Modifier.clip(RoundedCornerShape(DSRadius.pill)).background(Color.White.copy(alpha = 0.45f)).padding(horizontal = 10.dp, vertical = 4.dp),
                )
            }
            // Amiri's tall default line height would push the button out of the card on two lines.
            Text(title, style = DS.type.title1.copy(fontSize = 22.sp, lineHeight = 30.sp), color = ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (subtitle != null) {
                Text(subtitle, style = DS.type.footnote, color = ink.copy(alpha = 0.88f), maxLines = if (badge != null) 1 else 2, overflow = TextOverflow.Ellipsis)
            }
            Spacer(Modifier.weight(1f))
            if (cta != null) {
                Box(
                    Modifier.heightIn(min = 36.dp).clip(RoundedCornerShape(DSRadius.pill))
                        .then(if (isGold) Modifier.background(DS.colors.primary) else Modifier.background(DSGradient.gold))
                        .padding(horizontal = DSSpacing.md),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(cta, style = DS.type.subhead.copy(fontWeight = FontWeight.SemiBold), color = if (isGold) Color.White else DS.colors.primaryPress)
                }
            }
        }
    }
}

/** Days to the wedding in a gold ring; without a date, a prompt to set one. */
@Composable
private fun WeddingCountdownCard(days: Int?, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(DSRadius.card)
    val track = DS.colors.primaryMuted
    val gold = DSGradient.gold
    val fraction = days?.let { (1f - it.coerceAtMost(365) / 365f).coerceAtLeast(0.04f) } ?: 0f
    Column(
        modifier.clip(shape).background(DS.colors.surface).border(1.dp, DS.colors.border, shape)
            .clickable(role = Role.Button, onClick = onClick).padding(DSSpacing.sm),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(DSSpacing.xs, Alignment.CenterVertically),
    ) {
        Text(stringResource(R.string.catalog_home_countdown_title), style = DS.type.caption, color = DS.colors.textSecondary, maxLines = 1)
        Box(Modifier.size(76.dp), contentAlignment = Alignment.Center) {
            Canvas(Modifier.fillMaxSize().padding(3.dp)) {
                drawArc(track, 0f, 360f, false, style = Stroke(6.dp.toPx()))
                drawArc(gold, -90f, 360f * fraction, false, style = Stroke(6.dp.toPx(), cap = StrokeCap.Round))
            }
            if (days != null) {
                Text(NumberFormat.getIntegerInstance().format(days), style = DS.type.title1, color = DS.colors.primary, maxLines = 1)
            } else {
                Icon(Icons.Outlined.EditCalendar, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(26.dp))
            }
        }
        Text(
            stringResource(
                when {
                    days == null -> R.string.catalog_home_countdown_setDate
                    days == 0 -> R.string.catalog_home_countdown_today
                    else -> R.string.catalog_home_countdown_subtitle
                },
            ),
            style = DS.type.caption, color = DS.colors.textPrimary, textAlign = TextAlign.Center, maxLines = 2,
        )
    }
}

/** "Why Munyati": the three promises, as a quiet strip between the lists. */
@Composable
private fun WhyMunyatiStrip() {
    val shape = RoundedCornerShape(DSRadius.card)
    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
        HomeSectionTitle(stringResource(R.string.catalog_home_why_title))
        Row(
            Modifier.fillMaxWidth().clip(shape).background(DS.colors.surface).border(1.dp, DS.colors.border, shape).padding(DSSpacing.md),
            horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
        ) {
            listOf(
                Icons.Filled.Verified to R.string.catalog_home_why_verified,
                Icons.Filled.Payments to R.string.catalog_home_why_direct,
                Icons.Filled.Star to R.string.catalog_home_why_reviews,
            ).forEach { (icon, text) ->
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                    Box(Modifier.size(44.dp).clip(CircleShape).background(DS.colors.primaryMuted), contentAlignment = Alignment.Center) {
                        Icon(icon, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(20.dp))
                    }
                    Text(stringResource(text), style = DS.type.caption, color = DS.colors.textPrimary, textAlign = TextAlign.Center)
                }
            }
        }
    }
}

/** Invites service providers to join (the website explains plans and how to sign up). */
@Composable
private fun ProviderInviteCard(onClick: () -> Unit) {
    val shape = RoundedCornerShape(DSRadius.card)
    Row(
        Modifier.fillMaxWidth().clip(shape).background(DS.colors.primaryMuted)
            .border(1.dp, DS.colors.premiumGold.copy(alpha = 0.5f), shape)
            .clickable(role = Role.Button, onClick = onClick).padding(DSSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm),
    ) {
        DSBrand.Ring(Modifier.size(48.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.catalog_home_join_title), style = DS.type.headline, color = DS.colors.textPrimary)
            Text(stringResource(R.string.catalog_home_join_subtitle), style = DS.type.footnote, color = DS.colors.textSecondary)
        }
        Icon(Icons.AutoMirrored.Filled.ArrowForwardIos, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(14.dp))
    }
}

@Composable
private fun Categories(list: List<CatalogCategory>, onOpen: (CatalogCategory) -> Unit) {
    val columns = if (isLargeText()) 2 else 4
    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
        HomeSectionTitle(stringResource(R.string.catalog_home_categories))
        Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.md)) {
            list.chunked(columns).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                    row.forEach { CategoryTile(it, Modifier.weight(1f)) { onOpen(it) } }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}
