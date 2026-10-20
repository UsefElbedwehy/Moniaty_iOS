package co.munyati.app.shell

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForwardIos
import androidx.compose.material.icons.automirrored.outlined.Logout
import androidx.compose.material.icons.automirrored.outlined.OpenInNew
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.AlternateEmail
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.Chat
import androidx.compose.material.icons.outlined.DarkMode
import androidx.compose.material.icons.outlined.DeleteForever
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Forum
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.MusicNote
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material.icons.outlined.PlayCircle
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.CenterFocusWeak
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.VerticalDivider
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.munyati.app.R
import co.munyati.app.composition.Appearance
import co.munyati.app.composition.AppEnvironment
import co.munyati.app.composition.l10n
import co.munyati.authentication.domain.UserRole
import co.munyati.catalog.presentation.FavoritesRoute
import co.munyati.designsystem.brand.DSBrand
import co.munyati.designsystem.brand.DSBrandHero
import co.munyati.designsystem.brand.DSSparkle
import co.munyati.designsystem.brand.LightStatusBarIcons
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSGradient
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSShadow
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.navigation.LocalNavigator
import co.munyati.trust.presentation.BlockedUsersRoute
import co.munyati.trust.presentation.SupportRoute
import kotlinx.coroutines.launch
import java.text.NumberFormat

/**
 * Profile & settings, shared by both roles (Profile v2, modeled on Kolna Al-Khafji and Lamha): a
 * burgundy identity hero, stats, a share card, grouped rows with colored icon tiles, follow-us links
 * from remote config, sign out and in-app account deletion (App Store 5.1.1(v), Google Play's
 * account deletion policy), and a brand footer. Mirrors iOS `ProfileScreen`.
 */
@Composable
fun ProfileScreen(environment: AppEnvironment) {
    val session = environment.session
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var confirmSignOut by remember { mutableStateOf(false) }
    var showCities by remember { mutableStateOf(false) }
    var showBudget by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    var isDeleting by remember { mutableStateOf(false) }
    var deleteFailed by remember { mutableStateOf(false) }
    var showAppearance by remember { mutableStateOf(false) }
    var bookingsCount by remember { mutableStateOf<Int?>(null) }
    var favoritesCount by remember { mutableStateOf<Int?>(null) }
    val navigator = LocalNavigator.current
    val isBride = session.role != UserRole.Provider
    val showsStats = session.hasAccount && isBride

    LaunchedEffect(session.user?.id) {
        if (showsStats) {
            bookingsCount = environment.booking.activeBookingsCount()
            favoritesCount = environment.catalog.favoritesCount()
        }
    }
    LightStatusBarIcons()

    Box(Modifier.fillMaxSize().background(DS.colors.background)) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = DSSpacing.xl),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.lg),
        ) {
            Box {
                ProfileHero(environment, Modifier.padding(bottom = if (showsStats) STATS_OVERHANG else 0.dp))
                if (showsStats) {
                    StatsCard(
                        bookings = bookingsCount,
                        favorites = favoritesCount,
                        days = environment.catalog.daysUntilWedding,
                        onFavorites = { navigator.navigate(FavoritesRoute) },
                        onSetDate = { showBudget = true },
                        modifier = Modifier.align(Alignment.BottomCenter).padding(horizontal = DSSpacing.lg),
                    )
                }
            }
            Column(Modifier.padding(horizontal = DSSpacing.lg), verticalArrangement = Arrangement.spacedBy(DSSpacing.lg)) {
                val shareMessage = l10n(R.string.profile_share_message)
                ShareCard(l10n(if (isBride) R.string.profile_share_title else R.string.profile_share_titleProvider)) {
                    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, "$shareMessage\nhttps://munyati.co")
                    context.startActivity(Intent.createChooser(send, null))
                }
                if (isBride) {
                    Section(l10n(R.string.profile_section_wedding)) {
                        ProfileRow(l10n(R.string.profile_favorites), Icons.Filled.Favorite, DS.colors.accentRose) { navigator.navigate(FavoritesRoute) }
                        RowDivider()
                        val remaining = environment.catalog.budget.budget?.remaining
                        ProfileRow(
                            l10n(R.string.profile_budget), Icons.Outlined.Payments, DS.colors.accentGold,
                            value = remaining?.let { NumberFormat.getIntegerInstance().format(it) },
                        ) { if (session.hasAccount) showBudget = true else session.isPresentingAuth = true }
                        RowDivider()
                        ProfileRow(
                            l10n(R.string.profile_cities), Icons.Outlined.LocationOn, DS.colors.primary,
                            value = environment.cities.summary(l10n(R.string.cities_all)),
                        ) { showCities = true }
                    }
                }
                Section(l10n(R.string.profile_section_app)) {
                    ProfileRow(
                        l10n(R.string.profile_language), Icons.Outlined.Language, DS.colors.accentBlue,
                        value = l10n(R.string.profile_language_current), trailing = Icons.AutoMirrored.Outlined.OpenInNew,
                    ) {
                        // The app's language page in system settings (Android 13+), like iOS Settings.
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            Intent(Settings.ACTION_APP_LOCALE_SETTINGS, Uri.fromParts("package", context.packageName, null))
                        } else {
                            Intent(Settings.ACTION_LOCALE_SETTINGS)
                        }
                        context.startActivity(intent)
                    }
                    RowDivider()
                    Box {
                        ProfileRow(
                            l10n(R.string.profile_appearance), Icons.Outlined.DarkMode, DS.colors.accentPurple,
                            value = appearanceTitle(environment.appearance.value),
                        ) { showAppearance = true }
                        DropdownMenu(showAppearance, onDismissRequest = { showAppearance = false }) {
                            Appearance.entries.forEach { option ->
                                DropdownMenuItem(
                                    text = { Text(appearanceTitle(option)) },
                                    onClick = { environment.appearance.set(option); showAppearance = false },
                                )
                            }
                        }
                    }
                }
                Section(l10n(R.string.profile_section_help)) {
                    ProfileRow(l10n(R.string.profile_support), Icons.Outlined.Forum, DS.colors.success) { navigator.navigate(SupportRoute) }
                    RowDivider()
                    ProfileRow(l10n(R.string.profile_about), null, DS.colors.primary) { navigator.navigate(CmsPageRoute("about")) }
                    RowDivider()
                    ProfileRow(l10n(R.string.profile_terms), Icons.Outlined.Description, DS.colors.textSecondary) { navigator.navigate(CmsPageRoute("terms")) }
                    RowDivider()
                    ProfileRow(l10n(R.string.profile_privacy), Icons.Outlined.Shield, DS.colors.textSecondary) { navigator.navigate(CmsPageRoute("privacy")) }
                    RowDivider()
                    ProfileRow(l10n(R.string.profile_rate), Icons.Filled.Star, DS.colors.accentGold, showsChevron = false) {
                        environment.openExternal("https://play.google.com/store/apps/details?id=${context.packageName}")
                    }
                }
                FollowUs(environment)
                if (session.hasAccount) {
                    Section(null) {
                        ProfileRow(l10n(R.string.profile_blocked), Icons.Outlined.Block, DS.colors.textSecondary) { navigator.navigate(BlockedUsersRoute) }
                        RowDivider()
                        ProfileRow(l10n(R.string.profile_signOut), Icons.AutoMirrored.Outlined.Logout, DS.colors.primary, showsChevron = false) { confirmSignOut = true }
                        RowDivider()
                        ProfileRow(
                            l10n(R.string.profile_deleteAccount), Icons.Outlined.DeleteForever, DS.colors.error,
                            showsChevron = false, destructive = true,
                        ) { if (!isDeleting) confirmDelete = true }
                    }
                }
                Footer(environment)
            }
        }
        // The status bar in the hero's burgundy, so scrolled content never runs under the clock.
        Box(Modifier.fillMaxWidth().windowInsetsTopHeight(WindowInsets.statusBars).background(DSGradient.primaryStart))
    }

    if (confirmSignOut) {
        AlertDialog(
            onDismissRequest = { confirmSignOut = false },
            title = { Text(l10n(R.string.profile_signOut_confirmTitle)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmSignOut = false
                    scope.launch { environment.signOut() }
                }) { Text(l10n(R.string.profile_signOut), color = DS.colors.error) }
            },
            dismissButton = { TextButton(onClick = { confirmSignOut = false }) { Text(l10n(R.string.common_done)) } },
        )
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text(l10n(R.string.profile_deleteAccount_confirmTitle)) },
            text = { Text(l10n(R.string.profile_deleteAccount_message)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    isDeleting = true
                    scope.launch {
                        runCatching { environment.deleteAccount() }.onFailure { deleteFailed = true }
                        isDeleting = false
                    }
                }) { Text(l10n(R.string.profile_deleteAccount_confirm), color = DS.colors.error) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(stringResource(android.R.string.cancel)) } },
        )
    }
    if (deleteFailed) {
        AlertDialog(
            onDismissRequest = { deleteFailed = false },
            title = { Text(l10n(R.string.profile_deleteAccount_failed)) },
            confirmButton = { TextButton(onClick = { deleteFailed = false }) { Text(l10n(R.string.common_ok)) } },
        )
    }

    if (showCities) CityPickerDialog(environment) { showCities = false }
    if (showBudget) environment.catalog.BudgetEditor { showBudget = false }
}


/** How far the stats card hangs below the hero. */
private val STATS_OVERHANG = 52.dp

@Composable
private fun appearanceTitle(appearance: Appearance): String = l10n(
    when (appearance) {
        Appearance.System -> R.string.profile_appearance_system
        Appearance.Light -> R.string.profile_appearance_light
        Appearance.Dark -> R.string.profile_appearance_dark
    },
)

/** "+966 55 111 1111" from the stored "+966551111111". */
internal fun formatPhone(phone: String): String {
    if (!phone.startsWith("+966") || phone.length != 13) return phone
    val d = phone.drop(4)
    return "+966 ${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5)}"
}

@Composable
private fun ProfileHero(environment: AppEnvironment, modifier: Modifier) {
    val session = environment.session
    val user = session.user
    val hasStats = session.hasAccount && session.role != UserRole.Provider
    DSBrandHero(modifier.fillMaxWidth()) {
        Column(
            Modifier.fillMaxWidth().statusBarsPadding()
                .padding(start = DSSpacing.lg, end = DSSpacing.lg, top = DSSpacing.sm, bottom = if (hasStats) 72.dp else DSSpacing.xxl),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(DSSpacing.xs),
        ) {
            Text(
                l10n(R.string.tab_profile), style = DS.type.title1, color = Color.White,
                modifier = Modifier.fillMaxWidth().padding(bottom = DSSpacing.xs).semantics { heading() },
            )
            val initial = user?.displayName?.trim()?.firstOrNull()?.takeIf { session.hasAccount }
            Box(
                Modifier.size(96.dp).clip(CircleShape).background(DS.colors.primaryMuted).border(3.dp, DS.colors.premiumGold, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                if (initial != null) {
                    Text(initial.toString(), style = DS.type.largeTitle.copy(fontSize = 42.sp, lineHeight = 52.sp), color = DS.colors.primary)
                } else {
                    Icon(Icons.Filled.Person, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(44.dp))
                }
            }
            if (session.hasAccount && user != null) {
                Text(user.displayName.orEmpty(), style = DS.type.largeTitle, color = Color.White, textAlign = TextAlign.Center)
                user.phone?.let {
                    // Isolated left-to-right so the "+" stays in front in Arabic.
                    Text("\u2066${formatPhone(it)}\u2069", style = DS.type.subhead, color = Color.White.copy(alpha = 0.8f))
                }
                Row(
                    Modifier.heightIn(min = 28.dp).border(1.dp, DS.colors.premiumGold, RoundedCornerShape(DSRadius.pill)).padding(horizontal = DSSpacing.sm),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    DSSparkle(10.dp)
                    Text(
                        l10n(if (user.role == UserRole.Provider) R.string.profile_role_provider else R.string.profile_role_bride),
                        style = DS.type.caption, color = DS.colors.premiumGold,
                    )
                }
            } else {
                Text(l10n(R.string.profile_guest_title), style = DS.type.title1, color = Color.White)
                Text(l10n(R.string.profile_guest_message), style = DS.type.footnote, color = Color.White.copy(alpha = 0.85f), textAlign = TextAlign.Center)
                Box(
                    Modifier.padding(top = DSSpacing.xs).heightIn(min = 44.dp).clip(RoundedCornerShape(DSRadius.pill)).background(DSGradient.gold)
                        .clickable(role = Role.Button) { session.isPresentingAuth = true }.padding(horizontal = DSSpacing.xl),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(l10n(R.string.auth_signIn), style = DS.type.headline, color = DS.colors.primaryPress)
                }
            }
        }
    }
}

@Composable
private fun StatsCard(
    bookings: Int?,
    favorites: Int?,
    days: Int?,
    onFavorites: () -> Unit,
    onSetDate: () -> Unit,
    modifier: Modifier,
) {
    val shape = RoundedCornerShape(DSRadius.card + 2.dp)
    Row(
        modifier.fillMaxWidth().shadow(DSShadow.level2, shape).clip(shape).background(DS.colors.surface).padding(vertical = DSSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Stat(bookings, l10n(R.string.profile_stats_bookings), Modifier.weight(1f))
        VerticalDivider(Modifier.height(36.dp), color = DS.colors.border)
        Stat(favorites, l10n(R.string.profile_stats_favorites), Modifier.weight(1f).clickable(role = Role.Button, onClick = onFavorites))
        VerticalDivider(Modifier.height(36.dp), color = DS.colors.border)
        if (days != null) {
            Stat(days, l10n(R.string.profile_stats_days), Modifier.weight(1f))
        } else {
            Stat(null, l10n(R.string.profile_stats_setDate), Modifier.weight(1f).clickable(role = Role.Button, onClick = onSetDate))
        }
    }
}

@Composable
private fun Stat(value: Int?, label: String, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(value?.let { NumberFormat.getIntegerInstance().format(it) } ?: "—", style = DS.type.title1, color = DS.colors.primary)
        Text(label, style = DS.type.caption, color = DS.colors.textSecondary, textAlign = TextAlign.Center, maxLines = 2)
    }
}

@Composable
private fun ShareCard(title: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(DSRadius.card + 2.dp)
    Box(Modifier.fillMaxWidth().clip(shape).background(DSGradient.gold).clickable(role = Role.Button, onClick = onClick)) {
        // matchParentSize: the watermark never makes the card taller than its text.
        Box(Modifier.matchParentSize()) {
            androidx.compose.foundation.Image(
                androidx.compose.ui.res.painterResource(co.munyati.designsystem.R.drawable.brand_ring),
                contentDescription = null,
                colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(DS.colors.primary.copy(alpha = 0.14f)),
                modifier = Modifier.align(Alignment.BottomEnd).offset(x = 18.dp, y = 26.dp).requiredSize(110.dp),
            )
        }
        Row(Modifier.padding(DSSpacing.md), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
            Box(Modifier.size(44.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.55f)), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.CardGiftcard, contentDescription = null, tint = DS.colors.primaryPress)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, style = DS.type.headline, color = DS.colors.primaryPress)
                Text(l10n(R.string.profile_share_subtitle), style = DS.type.footnote, color = DS.colors.primaryPress.copy(alpha = 0.85f))
            }
        }
    }
}

/** A titled group of rows on a surface card. */
@Composable
private fun Section(title: String?, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
        if (title != null) {
            Text(
                title, style = DS.type.footnote.copy(fontWeight = FontWeight.SemiBold), color = DS.colors.textSecondary,
                modifier = Modifier.padding(horizontal = 6.dp).semantics { heading() },
            )
        }
        val shape = RoundedCornerShape(DSRadius.card)
        Column(Modifier.fillMaxWidth().clip(shape).background(DS.colors.surface).border(1.dp, DS.colors.border, shape)) { content() }
    }
}

@Composable
private fun RowDivider() = HorizontalDivider(Modifier.padding(start = 62.dp), color = DS.colors.border)

/** A row with a colored icon tile; a null icon shows the brand ring. */
@Composable
private fun ProfileRow(
    title: String,
    icon: ImageVector?,
    tint: Color,
    value: String? = null,
    trailing: ImageVector? = null,
    showsChevron: Boolean = true,
    destructive: Boolean = false,
    onClick: () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm),
    ) {
        Box(Modifier.size(36.dp).clip(RoundedCornerShape(11.dp)).background(tint.copy(alpha = 0.13f)), contentAlignment = Alignment.Center) {
            if (icon != null) Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(19.dp))
            else DSBrand.Ring(Modifier.size(22.dp))
        }
        Text(
            title, style = DS.type.body.copy(fontWeight = if (destructive) FontWeight.SemiBold else FontWeight.Medium),
            color = if (destructive) DS.colors.error else DS.colors.textPrimary, modifier = Modifier.weight(1f),
        )
        if (value != null) Text(value, style = DS.type.footnote, color = DS.colors.textSecondary, maxLines = 1)
        when {
            trailing != null -> Icon(trailing, contentDescription = null, tint = DS.colors.textSecondary, modifier = Modifier.size(16.dp))
            showsChevron -> Icon(Icons.AutoMirrored.Filled.ArrowForwardIos, contentDescription = null, tint = DS.colors.disabled, modifier = Modifier.size(14.dp))
        }
    }
}

/** Social accounts from remote config (`social_links`), as round icon buttons. */
@Composable
private fun FollowUs(environment: AppEnvironment) {
    val order = listOf("instagram", "tiktok", "snapchat", "x", "twitter", "whatsapp", "youtube")
    val links = (environment.remoteConfig.config?.socialLinks ?: emptyMap()).entries
        .sortedBy { order.indexOf(it.key.lowercase()).let { i -> if (i < 0) order.size else i } }
    if (links.isEmpty()) return
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
        Text(l10n(R.string.profile_followUs), style = DS.type.footnote.copy(fontWeight = FontWeight.SemiBold), color = DS.colors.textSecondary)
        Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
            links.forEach { (key, url) ->
                val icon = when (key.lowercase()) {
                    "instagram" -> Icons.Outlined.CameraAlt
                    "tiktok" -> Icons.Outlined.MusicNote
                    "snapchat" -> Icons.Outlined.CenterFocusWeak
                    "x", "twitter" -> Icons.Outlined.AlternateEmail
                    "whatsapp" -> Icons.Outlined.Chat
                    "youtube" -> Icons.Outlined.PlayCircle
                    else -> Icons.Outlined.Link
                }
                Box(
                    Modifier.size(48.dp).clip(CircleShape).background(DS.colors.surface).border(1.dp, DS.colors.border, CircleShape)
                        .clickable(role = Role.Button) { environment.openExternal(url) }
                        .semantics { contentDescription = key.replaceFirstChar { it.uppercase() } },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(icon, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(21.dp))
                }
            }
        }
    }
}

@Composable
private fun Footer(environment: AppEnvironment) {
    Column(Modifier.fillMaxWidth().padding(top = DSSpacing.xs), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DSSpacing.xxs)) {
        DSBrand.Ring(Modifier.size(44.dp))
        Text(l10n(R.string.profile_brand), style = DS.type.title2, color = DS.colors.primary)
        Text(
            "${l10n(R.string.profile_tagline)} · ${l10n(R.string.profile_version)} ${environment.appVersionString}",
            style = DS.type.caption, color = DS.colors.textSecondary, textAlign = TextAlign.Center,
        )
    }
}

/** The bride's cities (`docs/PLAN.md` §4.9): «الكل» or any of the active cities. */
@Composable
internal fun CityPickerDialog(environment: AppEnvironment, onDismiss: () -> Unit) {
    val cities = environment.cities
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l10n(R.string.cities_title)) },
        text = {
            Column {
                Text(l10n(R.string.cities_pickerHint), style = DS.type.footnote, color = DS.colors.textSecondary)
                CityRow(l10n(R.string.cities_all), cities.isAll) { cities.selectAll() }
                cities.available.forEach { city ->
                    CityRow(city.name(), city.id in cities.selected) { cities.toggle(city.id) }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                environment.saveCities()
                onDismiss()
            }) { Text(l10n(R.string.common_done)) }
        },
    )
}

@Composable
private fun CityRow(title: String, checked: Boolean, onToggle: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(role = Role.Checkbox, onClick = onToggle),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Checkbox(checked = checked, onCheckedChange = { onToggle() })
        Text(title, style = DS.type.body, color = DS.colors.textPrimary)
    }
}
