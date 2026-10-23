package co.munyati.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing

// Grouped form pieces, the Android counterpart of an iOS `Form` with `Section`s.

/** A titled group of rows on a surface card, with an optional footer note. */
@Composable
fun DSFormSection(title: String? = null, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
        if (title != null) Text(title, style = DS.type.footnote, color = DS.colors.textSecondary, modifier = Modifier.padding(horizontal = DSSpacing.xs))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(DSRadius.card / 2 + 4.dp)).background(DS.colors.surface), content = content)
        if (footer != null) Text(footer, style = DS.type.footnote, color = DS.colors.textSecondary, modifier = Modifier.padding(horizontal = DSSpacing.xs))
    }
}

/** A hairline between rows of a [DSFormSection]. */
@Composable
fun DSFormDivider() = HorizontalDivider(color = DS.colors.border, modifier = Modifier.padding(start = DSSpacing.md))

/** A text input row with a placeholder; multi-line when [minLines] > 1. */
@Composable
fun DSTextFieldRow(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    minLines: Int = 1,
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = minLines == 1,
        minLines = minLines,
        textStyle = DS.type.body.copy(color = DS.colors.textPrimary),
        cursorBrush = SolidColor(DS.colors.primary),
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        modifier = Modifier.fillMaxWidth(),
        decorationBox = { inner ->
            Box(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = DSSpacing.md, vertical = DSSpacing.sm), contentAlignment = Alignment.CenterStart) {
                if (value.isEmpty()) Text(placeholder, style = DS.type.body, color = DS.colors.textSecondary.copy(alpha = 0.6f))
                inner()
            }
        },
    )
}

/** A label with a switch. */
@Composable
fun DSToggleRow(title: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Switch) { onCheckedChange(!checked) }.padding(horizontal = DSSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = DS.type.body, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
        Switch(checked, onCheckedChange, colors = SwitchDefaults.colors(checkedTrackColor = DS.colors.primary))
    }
}

/** A label with the chosen value; tapping opens a menu of options (an iOS menu `Picker`). */
@Composable
fun <T> DSPickerRow(title: String, options: List<T>, selected: T, label: (T) -> String, onSelect: (T) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.DropdownList) { open = true }.padding(horizontal = DSSpacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
        ) {
            Text(title, style = DS.type.body, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
            Text(label(selected), style = DS.type.body, color = DS.colors.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Icon(Icons.Filled.UnfoldMore, contentDescription = null, tint = DS.colors.textSecondary)
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            options.forEach { option ->
                DropdownMenuItem(text = { Text(label(option)) }, onClick = {
                    open = false
                    onSelect(option)
                })
            }
        }
    }
}

/** A row that opens another screen or dialog, showing a trailing value. */
@Composable
fun DSNavRow(title: String, value: String? = null, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = DSSpacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs),
    ) {
        Text(title, style = DS.type.body, color = DS.colors.textPrimary)
        Text(value.orEmpty(), style = DS.type.body, color = DS.colors.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = DS.colors.textSecondary)
    }
}
