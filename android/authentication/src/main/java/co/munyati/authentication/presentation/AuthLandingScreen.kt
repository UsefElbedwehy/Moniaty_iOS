package co.munyati.authentication.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import co.munyati.authentication.R
import co.munyati.designsystem.brand.DSBrand
import co.munyati.designsystem.brand.DSSparkle
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing

/**
 * The first screen: the منيتي wordmark, the tagline, and the role choice — "I'm a bride" or "I'm a
 * service provider" — plus "Browse as guest". Matches mockup 1 and the iOS `AuthLandingView`.
 */
@Composable
internal fun AuthLandingScreen(viewModel: OnboardingViewModel, coordinator: AuthCoordinator) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DS.colors.background)
            .safeDrawingPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = DSSpacing.xl)
            .padding(bottom = DSSpacing.lg),
    ) {
        Brand(Modifier.padding(top = DSSpacing.xxl))

        Column(
            modifier = Modifier.padding(top = DSSpacing.xxl),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.sm),
        ) {
            Text(stringResource(R.string.auth_landing_prompt), style = DS.type.subhead, color = DS.colors.textSecondary)
            RoleCard(
                title = stringResource(R.string.auth_role_bride_title),
                subtitle = stringResource(R.string.auth_role_bride_subtitle),
                icon = Icons.Outlined.AutoAwesome,
                isProminent = true,
                enabled = !viewModel.isBusy,
            ) { coordinator.startPhoneSignIn(co.munyati.authentication.domain.UserRole.Bride) }
            RoleCard(
                title = stringResource(R.string.auth_role_provider_title),
                subtitle = stringResource(R.string.auth_role_provider_subtitle),
                icon = Icons.Outlined.Storefront,
                isProminent = false,
                enabled = !viewModel.isBusy,
            ) { coordinator.startPhoneSignIn(co.munyati.authentication.domain.UserRole.Provider) }
        }

        Spacer(Modifier.weight(1f).heightIn(min = DSSpacing.xl))

        GuestButton(viewModel, coordinator)
    }
}

@Composable
private fun Brand(modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
        DSBrand.Wordmark(Modifier.height(150.dp), contentDescription = stringResource(R.string.auth_brand_name))
        Text(
            stringResource(R.string.auth_landing_tagline),
            style = DS.type.title1,
            color = DS.colors.primary,
            textAlign = TextAlign.Center,
        )
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
            Box(Modifier.width(48.dp).height(1.dp).background(DS.colors.premiumGold))
            DSSparkle()
            Box(Modifier.width(48.dp).height(1.dp).background(DS.colors.premiumGold))
        }
    }
}

@Composable
private fun GuestButton(viewModel: OnboardingViewModel, coordinator: AuthCoordinator) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 44.dp)
                .clickable(enabled = !viewModel.isBusy, role = Role.Button) {
                    viewModel.browseAsGuest(coordinator::didContinueAsGuest)
                },
            contentAlignment = Alignment.Center,
        ) {
            if (viewModel.isBusy) {
                CircularProgressIndicator(color = DS.colors.primary, strokeWidth = 2.dp, modifier = Modifier.size(22.dp))
            } else {
                Text(stringResource(R.string.auth_onboarding_browseGuest), style = DS.type.headline, color = DS.colors.primary)
            }
        }
        viewModel.errorMessage?.let {
            Text(it.authMessage(), style = DS.type.footnote, color = DS.colors.error, textAlign = TextAlign.Center)
        }
    }
}

/** One of the two big role buttons on the landing screen. */
@Composable
private fun RoleCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    isProminent: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(DSRadius.card)
    val foreground = if (isProminent) DS.colors.background else DS.colors.textPrimary
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(if (isProminent) DS.colors.primary else DS.colors.surface)
            .border(1.dp, if (isProminent) Color.Transparent else DS.colors.border, shape)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics(mergeDescendants = true) {}
            .padding(DSSpacing.lg),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.md),
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(if (isProminent) Color.White.copy(alpha = 0.12f) else DS.colors.primaryMuted),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = if (isProminent) DS.colors.premiumGold else DS.colors.primary, modifier = Modifier.size(28.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = DS.type.title2, color = foreground)
            Text(
                subtitle,
                style = DS.type.footnote,
                color = if (isProminent) DS.colors.background.copy(alpha = 0.85f) else DS.colors.textSecondary,
            )
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = foreground)
    }
}
