package co.munyati.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSGradient

/** The kind of status a [StatusBadge] represents, driving its colors and optional icon. */
enum class StatusBadgeKind { Pending, Live, Rejected, Featured, Verified, Action }

/** Small label for listing/booking status (pending, live, rejected) or promotion (featured, verified). */
@Composable
fun StatusBadge(kind: StatusBadgeKind, text: String, modifier: Modifier = Modifier) {
    val c = DS.colors
    val background = when (kind) {
        StatusBadgeKind.Pending -> Modifier.background(c.pendingBackground)
        StatusBadgeKind.Live -> Modifier.background(c.liveBackground)
        StatusBadgeKind.Rejected -> Modifier.background(c.rejectedBackground)
        StatusBadgeKind.Featured -> Modifier.background(DSGradient.gold)
        StatusBadgeKind.Verified -> Modifier.background(DSGradient.primary)
        StatusBadgeKind.Action -> Modifier.background(c.primary)
    }
    val foreground = when (kind) {
        StatusBadgeKind.Pending -> c.pendingForeground
        StatusBadgeKind.Live -> c.liveForeground
        StatusBadgeKind.Rejected -> c.rejectedForeground
        else -> Color.White
    }
    val icon = when (kind) {
        StatusBadgeKind.Featured -> Icons.Filled.Star
        StatusBadgeKind.Verified -> Icons.Filled.Verified
        else -> null
    }
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .then(background)
            .padding(vertical = 6.dp, horizontal = 11.dp)
            .clearAndSetSemantics { contentDescription = text },
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) Icon(icon, contentDescription = null, tint = foreground, modifier = Modifier.size(11.dp))
        Text(text, style = DS.type.caption.copy(fontWeight = FontWeight.Bold), color = foreground)
    }
}
