package co.munyati.designsystem.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.munyati.designsystem.R
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSGradient
import co.munyati.designsystem.theme.DSRadius

/** Shared label for every DS button: swaps the title for a spinner while loading. */
@Composable
private fun DSButtonLabel(title: String, isLoading: Boolean, style: TextStyle, color: Color, icon: ImageVector? = null) {
    AnimatedContent(targetState = isLoading, label = "buttonLoading") { loading ->
        if (loading) {
            CircularProgressIndicator(color = color, strokeWidth = 2.dp, modifier = Modifier.size(22.dp))
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                if (icon != null) Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
                Text(title, style = style, color = color)
            }
        }
    }
}

@Composable
private fun Modifier.dsButton(enabled: Boolean, isLoading: Boolean, onClick: () -> Unit): Modifier {
    val loading = stringResource(R.string.ds_common_loading)
    return this
        .clickable(enabled = enabled && !isLoading, role = Role.Button, onClick = onClick)
        .semantics { if (isLoading) stateDescription = loading }
}

/** Filled primary call-to-action. Burgundy gradient, white text, 50dp tall. */
@Composable
fun PrimaryButton(
    title: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    isLoading: Boolean = false,
    isEnabled: Boolean = true,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(DSRadius.button)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(50.dp)
            .clip(shape)
            .then(if (isEnabled) Modifier.background(DSGradient.primary) else Modifier.background(DS.colors.disabled))
            .dsButton(isEnabled, isLoading, onClick),
        contentAlignment = Alignment.Center,
    ) {
        DSButtonLabel(title, isLoading, DS.type.headline, Color.White, icon)
    }
}

/** Pale filled button with primary text, for secondary but still prominent actions. */
@Composable
fun SecondaryButton(
    title: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    isLoading: Boolean = false,
    isEnabled: Boolean = true,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(50.dp)
            .clip(RoundedCornerShape(DSRadius.button))
            .background(if (isEnabled) DS.colors.primaryMuted else DS.colors.surface)
            .dsButton(isEnabled, isLoading, onClick),
        contentAlignment = Alignment.Center,
    ) {
        DSButtonLabel(title, isLoading, DS.type.headline, if (isEnabled) DS.colors.primary else DS.colors.disabled, icon)
    }
}

/** Outline button, primary text color, 1.5dp border stroke. */
@Composable
fun TertiaryButton(
    title: String,
    modifier: Modifier = Modifier,
    isLoading: Boolean = false,
    isEnabled: Boolean = true,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(DSRadius.button)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(50.dp)
            .clip(shape)
            .background(DS.colors.background)
            .border(1.5.dp, if (isEnabled) DS.colors.border else DS.colors.disabled, shape)
            .dsButton(isEnabled, isLoading, onClick),
        contentAlignment = Alignment.Center,
    ) {
        DSButtonLabel(title, isLoading, DS.type.headline, if (isEnabled) DS.colors.textPrimary else DS.colors.disabled)
    }
}

/** Filled destructive action. Error fill, white text, 44dp min height. */
@Composable
fun DestructiveButton(
    title: String,
    modifier: Modifier = Modifier,
    isLoading: Boolean = false,
    isEnabled: Boolean = true,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 44.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(if (isEnabled) DS.colors.error else DS.colors.disabled)
            .dsButton(isEnabled, isLoading, onClick),
        contentAlignment = Alignment.Center,
    ) {
        DSButtonLabel(title, isLoading, DS.type.body.copy(fontWeight = FontWeight.SemiBold), Color.White)
    }
}
