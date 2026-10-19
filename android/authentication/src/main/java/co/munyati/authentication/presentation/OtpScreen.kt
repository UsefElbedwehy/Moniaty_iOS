package co.munyati.authentication.presentation

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import co.munyati.authentication.R
import co.munyati.authentication.domain.OTP_CODE_LENGTH
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing

/**
 * OTP entry: back chevron, title, "Sent to <phone>. Edit", six code boxes with a ring on the active
 * box, and a resend countdown that becomes a button at zero. One invisible text field owns the real
 * input; the boxes only render its text. Matches the iOS `OTPView`.
 */
@Composable
internal fun OtpScreen(viewModel: OtpViewModel, coordinator: AuthCoordinator) {
    val focusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    var focused by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        viewModel.startCountdown()
        focusRequester.requestFocus()
    }
    LaunchedEffect(viewModel.isComplete) {
        if (viewModel.isComplete) {
            focusManager.clearFocus()
            viewModel.verify(onUser = coordinator::didAuthenticate, onNeedsName = coordinator::needsName)
        }
    }

    Column(Modifier.fillMaxSize().background(DS.colors.background).safeDrawingPadding().imePadding()) {
        BackChevronButton(coordinator::pop)
        Column(
            modifier = Modifier.padding(horizontal = DSSpacing.lg).padding(top = DSSpacing.sm),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.lg),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                Text(stringResource(R.string.auth_otp_title), style = DS.type.title1, color = DS.colors.textPrimary)
                Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.xxs), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        stringResource(R.string.auth_otp_sentTo, ltr(viewModel.challenge.phoneE164)),
                        style = DS.type.body,
                        color = DS.colors.textSecondary,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    Text(
                        stringResource(R.string.auth_otp_edit),
                        style = DS.type.body.copy(fontWeight = FontWeight.SemiBold),
                        color = DS.colors.primary,
                        modifier = Modifier.clickable(role = Role.Button, onClick = coordinator::editPhoneNumber),
                    )
                }
            }

            CodeBoxes(
                code = viewModel.code,
                focused = focused,
                isComplete = viewModel.isComplete,
                onCodeChange = viewModel::onCodeChange,
                modifier = Modifier
                    .focusRequester(focusRequester)
                    .onFocusChanged { focused = it.isFocused },
            )

            viewModel.errorMessage?.let {
                Text(it.authMessage(), style = DS.type.footnote, color = DS.colors.error, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            }

            ResendRow(viewModel)
        }
    }
}

@Composable
private fun CodeBoxes(
    code: String,
    focused: Boolean,
    isComplete: Boolean,
    onCodeChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val description = stringResource(R.string.auth_otp_codeAccessibility)
    // A code is a number, and numbers read left to right in Arabic too: the first digit typed
    // lands in the leftmost box, matching the SMS the user is copying from.
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        BasicTextField(
            value = code,
            onValueChange = onCodeChange,
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
            textStyle = TextStyle(color = Color.Transparent),
            cursorBrush = SolidColor(Color.Transparent),
            modifier = modifier.fillMaxWidth().semantics { contentDescription = description },
            decorationBox = { inner ->
                Box {
                    Box(Modifier.size(1.dp)) { inner() } // the real field stays invisible
                    Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                        repeat(OTP_CODE_LENGTH) { index ->
                            val hasDigit = index < code.length
                            val isActive = focused && index == code.length && !isComplete
                            CodeBox(code.getOrNull(index)?.toString().orEmpty(), hasDigit, isActive, Modifier.weight(1f))
                        }
                    }
                }
            },
        )
    }
}

@Composable
private fun CodeBox(digit: String, hasDigit: Boolean, isActive: Boolean, modifier: Modifier) {
    val shape = RoundedCornerShape(DSRadius.control)
    val ring by animateColorAsState(if (isActive || hasDigit) DS.colors.primary else DS.colors.border, label = "otpRing")
    Box(
        modifier = modifier
            .height(60.dp)
            .clip(shape)
            .background(if (hasDigit || isActive) DS.colors.surface else DS.colors.elevated)
            .border(if (isActive || hasDigit) 2.dp else 1.dp, ring, shape),
        contentAlignment = Alignment.Center,
    ) {
        Text(digit, style = DS.type.title2.copy(fontWeight = FontWeight.Bold), color = DS.colors.textPrimary)
    }
}

@Composable
private fun ResendRow(viewModel: OtpViewModel) {
    Box(Modifier.fillMaxWidth().heightIn(min = 44.dp), contentAlignment = Alignment.Center) {
        if (viewModel.canResend) {
            Text(
                stringResource(R.string.auth_otp_resend),
                style = DS.type.subhead.copy(fontWeight = FontWeight.SemiBold),
                color = DS.colors.primary,
                modifier = Modifier.clickable(role = Role.Button, onClick = viewModel::resend).padding(DSSpacing.xs),
            )
        } else {
            Text(
                stringResource(R.string.auth_otp_resendIn, ltr(viewModel.resendCountdownText)),
                style = DS.type.subhead,
                color = DS.colors.textSecondary,
            )
        }
        if (viewModel.isVerifying) {
            CircularProgressIndicator(
                color = DS.colors.primary,
                strokeWidth = 2.dp,
                modifier = Modifier.align(Alignment.CenterEnd).padding(end = DSSpacing.md).size(20.dp),
            )
        }
    }
}
