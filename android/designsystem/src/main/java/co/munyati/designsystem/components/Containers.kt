package co.munyati.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSGradient
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSShadow
import co.munyati.designsystem.theme.DSSpacing

/** Generic elevated container: elevated fill, card corners, level-1 shadow. */
@Composable
fun DSCard(
    modifier: Modifier = Modifier,
    padding: Dp = DSSpacing.md,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(DSRadius.card)
    Column(
        modifier = modifier
            .shadow(DSShadow.level1, shape, clip = false)
            .clip(shape)
            .background(DS.colors.elevated)
            .padding(padding),
        content = content,
    )
}

/** Tappable pill filter chip with a selected/unselected state. */
@Composable
fun Chip(title: String, isSelected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(DSRadius.pill)
    Box(
        modifier = modifier
            .heightIn(min = 44.dp)
            .clip(shape)
            .then(if (isSelected) Modifier.background(DSGradient.primary) else Modifier.background(DS.colors.elevated))
            .clickable(role = Role.Button, onClick = onClick)
            .padding(vertical = DSSpacing.xs, horizontal = DSSpacing.md - 1.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            title,
            style = DS.type.subhead.copy(fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium),
            color = if (isSelected) androidx.compose.ui.graphics.Color.White else DS.colors.textPrimary,
        )
    }
}

/** Section title with an optional trailing text action (e.g. "See all"). */
@Composable
fun SectionHeader(title: String, modifier: Modifier = Modifier, actionTitle: String? = null, onAction: (() -> Unit)? = null) {
    Row(modifier = modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = DS.type.headline, color = DS.colors.textPrimary, modifier = Modifier.semantics { heading() })
        Spacer(Modifier.weight(1f))
        if (actionTitle != null && onAction != null) {
            Box(
                modifier = Modifier.heightIn(min = 44.dp).clickable(role = Role.Button, onClick = onAction),
                contentAlignment = Alignment.Center,
            ) {
                Text(actionTitle, style = DS.type.subhead, color = DS.colors.primary)
            }
        }
    }
}

/** A fixed screen header: bold title at the start and an optional trailing accessory. */
@Composable
fun LargeHeaderBar(title: String, modifier: Modifier = Modifier, trailing: @Composable () -> Unit = {}) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(DS.colors.background)
            .padding(PaddingValues(start = DSSpacing.md, end = DSSpacing.md, top = DSSpacing.xs, bottom = DSSpacing.sm)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            title,
            style = DS.type.title1.copy(fontWeight = FontWeight.Bold),
            color = DS.colors.textPrimary,
            modifier = Modifier.weight(1f).semantics { heading() },
        )
        trailing()
    }
}

/** Circular icon button for header accessories (notifications, add, edit). */
@Composable
fun HeaderIconButton(icon: ImageVector, contentDescription: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clickable(role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(DS.colors.surface)
                .border(1.dp, DS.colors.border, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = contentDescription, tint = DS.colors.textPrimary, modifier = Modifier.size(20.dp))
        }
    }
}

/** A vertical stack with DS spacing; small helper used by the state views. */
@Composable
internal fun CenteredStack(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = modifier.padding(DSSpacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(DSSpacing.md),
        content = content,
    )
}
