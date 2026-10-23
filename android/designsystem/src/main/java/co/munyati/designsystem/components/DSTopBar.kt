package co.munyati.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSSpacing

/**
 * The inline bar on pushed screens: back arrow, a one-line title and trailing actions (the
 * equivalent of an iOS inline navigation bar with toolbar items).
 */
@Composable
fun DSTopBar(
    title: String,
    onBack: (() -> Unit)?,
    backDescription: String,
    modifier: Modifier = Modifier,
    actions: @Composable RowScope.() -> Unit = {},
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(DS.colors.background)
            .statusBarsPadding()
            .heightIn(min = 56.dp)
            .padding(horizontal = DSSpacing.xxs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onBack != null) TopBarIconButton(Icons.AutoMirrored.Filled.ArrowBack, backDescription, onClick = onBack)
        Text(
            title,
            style = DS.type.headline,
            color = DS.colors.textPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f).padding(horizontal = DSSpacing.xs).semantics { heading() },
        )
        actions()
    }
}

/** A 48dp icon action for [DSTopBar]. */
@Composable
fun TopBarIconButton(icon: ImageVector, contentDescription: String, tint: androidx.compose.ui.graphics.Color = DS.colors.primary, onClick: () -> Unit) {
    Box(Modifier.size(48.dp).clickable(role = Role.Button, onClick = onClick), contentAlignment = Alignment.Center) {
        Icon(icon, contentDescription = contentDescription, tint = tint)
    }
}
