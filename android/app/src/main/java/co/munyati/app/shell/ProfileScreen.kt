package co.munyati.app.shell

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Logout
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.LocationCity
import androidx.compose.material.icons.outlined.PersonAddAlt
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import co.munyati.app.R
import co.munyati.app.composition.AppEnvironment
import co.munyati.app.composition.l10n
import co.munyati.authentication.domain.UserRole
import co.munyati.designsystem.components.DSCard
import co.munyati.designsystem.components.LargeHeaderBar
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSSpacing
import kotlinx.coroutines.launch

/**
 * Profile & settings, shared by both roles. Foundation version: identity, cities, language, sign
 * out and version. Legal pages, support, favorites, budget and account deletion arrive with their
 * features (Catalog, Trust).
 */
@Composable
fun ProfileScreen(environment: AppEnvironment) {
    val session = environment.session
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var confirmSignOut by remember { mutableStateOf(false) }
    var showCities by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        LargeHeaderBar(l10n(R.string.tab_profile))
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(DSSpacing.md),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.md),
        ) {
            DSCard(Modifier.fillMaxWidth()) {
                val user = session.user
                if (session.hasAccount && user != null) {
                    Text(user.displayName.orEmpty(), style = DS.type.title2, color = DS.colors.textPrimary)
                    Text(
                        l10n(if (user.role == UserRole.Provider) R.string.profile_role_provider else R.string.profile_role_bride),
                        style = DS.type.footnote,
                        color = DS.colors.textSecondary,
                    )
                } else {
                    ProfileRow(l10n(R.string.auth_signIn), Icons.Outlined.PersonAddAlt) { session.isPresentingAuth = true }
                }
            }

            if (session.role != UserRole.Provider) {
                Section(l10n(R.string.profile_section_preferences)) {
                    ProfileRow(
                        l10n(R.string.profile_cities),
                        Icons.Outlined.LocationCity,
                        trailing = environment.cities.summary(l10n(R.string.cities_all)),
                    ) { showCities = true }
                }
            }

            Section(l10n(R.string.profile_section_app)) {
                ProfileRow(l10n(R.string.profile_language), Icons.Outlined.Language) {
                    // The app's language page in system settings (Android 13+), like iOS Settings.
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        Intent(Settings.ACTION_APP_LOCALE_SETTINGS, Uri.fromParts("package", context.packageName, null))
                    } else {
                        Intent(Settings.ACTION_LOCALE_SETTINGS)
                    }
                    context.startActivity(intent)
                }
                if (session.hasAccount) {
                    HorizontalDivider(color = DS.colors.border)
                    ProfileRow(l10n(R.string.profile_signOut), Icons.AutoMirrored.Outlined.Logout, tint = DS.colors.error) {
                        confirmSignOut = true
                    }
                }
            }

            Text(
                "${l10n(R.string.profile_version)} ${environment.appVersionString}",
                style = DS.type.footnote,
                color = DS.colors.textSecondary,
                modifier = Modifier.fillMaxWidth().padding(top = DSSpacing.xs),
            )
        }
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

    if (showCities) CityPickerDialog(environment) { showCities = false }
}

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
        Text(title, style = DS.type.footnote, color = DS.colors.textSecondary, modifier = Modifier.padding(horizontal = DSSpacing.xs))
        DSCard(Modifier.fillMaxWidth(), padding = 0.dp) { content() }
    }
}

@Composable
private fun ProfileRow(
    title: String,
    icon: ImageVector,
    trailing: String? = null,
    tint: Color = DS.colors.textPrimary,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 52.dp)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = DSSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.sm),
    ) {
        Icon(icon, contentDescription = null, tint = if (tint == DS.colors.textPrimary) DS.colors.primary else tint)
        Text(title, style = DS.type.body, color = tint, modifier = Modifier.weight(1f))
        if (trailing != null) Text(trailing, style = DS.type.subhead, color = DS.colors.textSecondary)
    }
}

/** The bride's cities (`docs/PLAN.md` §4.9): «الكل» or any of the active cities. */
@Composable
private fun CityPickerDialog(environment: AppEnvironment, onDismiss: () -> Unit) {
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
