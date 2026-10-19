package co.munyati.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material.icons.outlined.WifiOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import co.munyati.core.error.AppError
import co.munyati.designsystem.R
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSSpacing

/** Centered empty-state placeholder: icon, title, message and an optional primary action. */
@Composable
fun EmptyStateView(
    icon: ImageVector,
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    actionTitle: String? = null,
    onAction: (() -> Unit)? = null,
) {
    CenteredStack(modifier) {
        Box(
            modifier = Modifier.size(88.dp).clip(CircleShape).background(DS.colors.elevated),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = DS.colors.textSecondary, modifier = Modifier.size(34.dp))
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DSSpacing.xxs)) {
            Text(title, style = DS.type.title2, color = DS.colors.textPrimary, textAlign = TextAlign.Center)
            Text(message, style = DS.type.subhead, color = DS.colors.textSecondary, textAlign = TextAlign.Center)
        }
        if (actionTitle != null && onAction != null) {
            PrimaryButton(actionTitle, modifier = Modifier.padding(top = DSSpacing.xs), onClick = onAction)
        }
    }
}

/** Centered error placeholder driven by an [AppError], with an optional retry action. */
@Composable
fun ErrorStateView(error: AppError, modifier: Modifier = Modifier, onRetry: (() -> Unit)? = null) {
    val offline = error.isOffline
    CenteredStack(modifier) {
        Box(
            modifier = Modifier.size(88.dp).clip(CircleShape).background(DS.colors.error.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                if (offline) Icons.Outlined.WifiOff else Icons.Outlined.WarningAmber,
                contentDescription = null,
                tint = DS.colors.error,
                modifier = Modifier.size(34.dp),
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(DSSpacing.xxs)) {
            Text(
                stringResource(if (offline) R.string.ds_common_error_offline_title else R.string.ds_common_error_generic_title),
                style = DS.type.title2,
                color = DS.colors.textPrimary,
                textAlign = TextAlign.Center,
            )
            Text(error.description(LocalContext.current), style = DS.type.subhead, color = DS.colors.textSecondary, textAlign = TextAlign.Center)
        }
        if (onRetry != null) {
            PrimaryButton(
                stringResource(R.string.ds_common_tryAgain),
                icon = Icons.Outlined.Refresh,
                modifier = Modifier.padding(top = DSSpacing.xs).wrapContentWidth(),
                onClick = onRetry,
            )
        }
    }
}
