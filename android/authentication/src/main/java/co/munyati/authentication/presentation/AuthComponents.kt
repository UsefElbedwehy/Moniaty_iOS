package co.munyati.authentication.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import co.munyati.authentication.R
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSSpacing

/** The circular back chevron at the top of the phone, OTP and name screens. */
@Composable
internal fun BackChevronButton(onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(start = DSSpacing.sm, end = DSSpacing.sm, top = DSSpacing.sm)) {
        Box(
            modifier = Modifier.size(44.dp).clickable(role = Role.Button, onClick = onClick),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                Modifier.size(40.dp).clip(CircleShape).background(DS.colors.elevated),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                    contentDescription = stringResource(R.string.auth_common_back),
                    tint = DS.colors.primary,
                    modifier = Modifier.size(28.dp),
                )
            }
        }
        Spacer(Modifier.weight(1f))
    }
}
