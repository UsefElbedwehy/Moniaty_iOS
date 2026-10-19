package co.munyati.app.shell

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Download
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import co.munyati.app.R
import co.munyati.app.composition.AppEnvironment
import co.munyati.app.composition.AppSession
import co.munyati.app.composition.l10n
import co.munyati.authentication.domain.UserRole
import co.munyati.designsystem.brand.DSBrand
import co.munyati.designsystem.components.PrimaryButton
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.analytics.AnalyticsEvent
import kotlinx.coroutines.async
import kotlinx.coroutines.launch

/**
 * Picks what the whole window shows: splash while restoring, the landing (role choice) when signed
 * out, then the bride or provider tab shell. Also hosts the force-update gate and the sign-in sheet
 * a guest sees when she taps something that needs an account. Mirrors iOS `RootView`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RootView(environment: AppEnvironment) {
    val session = environment.session
    val config = environment.remoteConfig

    LaunchedEffect(Unit) {
        val loads = listOf(
            async { environment.loadRemoteConfig() },
            async { environment.loadRemoteStrings() },
            async { environment.loadCities() },
        )
        loads.forEach { it.await() }
        environment.restoreSession()
        environment.analytics(AnalyticsEvent.AppOpen)
    }

    if (config.forceUpdateRequired || config.isMaintenanceMode) {
        ForceUpdateScreen(config.config?.update?.updateMessage, config.config?.update?.storeUrl)
        return
    }

    when (val state = session.state) {
        AppSession.State.Checking -> SplashScreen()
        AppSession.State.SignedOut -> AuthHost(environment)
        is AppSession.State.SignedIn -> when {
            state.user.role == UserRole.Provider -> ProviderShell(environment)
            state.user.role == UserRole.Bride || state.user.isAnonymous -> BrideShell(environment)
            else -> SplashScreen() // role not known yet (profile still loading)
        }
    }

    if (session.isPresentingAuth) {
        ModalBottomSheet(
            onDismissRequest = { session.isPresentingAuth = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = DS.colors.background,
            dragHandle = null,
        ) {
            AuthHost(environment)
        }
    }
}

/** Owns one auth feature for as long as it is on screen, so its navigation survives recomposition. */
@Composable
private fun AuthHost(environment: AppEnvironment) {
    val scope = rememberCoroutineScope()
    val feature = remember { environment.makeAuthFeature { state -> scope.launch { environment.authFinished(state) } } }
    feature.Content()
}

/** Brief branded screen while the session is restored. */
@Composable
fun SplashScreen() {
    Column(
        modifier = Modifier.fillMaxSize().background(DS.colors.background),
        verticalArrangement = Arrangement.spacedBy(DSSpacing.lg, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        DSBrand.Wordmark(Modifier.height(160.dp), contentDescription = l10n(R.string.app_name))
        CircularProgressIndicator(color = DS.colors.primary, strokeWidth = 2.dp, modifier = Modifier.size(24.dp))
    }
}

/**
 * Full-screen, undismissable screen shown when the admin marks this build too old (or turns on
 * maintenance). The only action is opening the store listing.
 */
@Composable
private fun ForceUpdateScreen(message: String?, storeUrl: String?) {
    val context = LocalContext.current
    Column(
        modifier = Modifier.fillMaxSize().background(DS.colors.background).padding(DSSpacing.md),
        verticalArrangement = Arrangement.spacedBy(DSSpacing.lg, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.size(88.dp).clip(CircleShape).background(DS.colors.primaryMuted), contentAlignment = Alignment.Center) {
            Icon(Icons.Filled.Download, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(34.dp))
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DSSpacing.xxs)) {
            Text(l10n(R.string.forceUpdate_title), style = DS.type.title2, color = DS.colors.textPrimary, textAlign = TextAlign.Center)
            Text(message ?: l10n(R.string.forceUpdate_message), style = DS.type.subhead, color = DS.colors.textSecondary, textAlign = TextAlign.Center)
        }
        if (storeUrl != null) {
            PrimaryButton(l10n(R.string.forceUpdate_action), icon = Icons.Filled.Download) {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(storeUrl)))
            }
        }
    }
}
