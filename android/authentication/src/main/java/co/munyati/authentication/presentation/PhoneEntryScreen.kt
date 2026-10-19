package co.munyati.authentication.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
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
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import co.munyati.authentication.R
import co.munyati.designsystem.components.PrimaryButton
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing

/**
 * Phone entry: back chevron, title, subtitle, the SA +966 chip beside the number field, a terms
 * footnote, and "Send code" docked above the keyboard. Matches the iOS `PhoneEntryView`.
 */
@Composable
internal fun PhoneEntryScreen(viewModel: PhoneEntryViewModel, coordinator: AuthCoordinator) {
    // Hide the keyboard rather than clearing focus: on a hardware keyboard, clearing focus on
    // Enter hands focus to the back button, and the same key press then pops the screen.
    val keyboard = LocalSoftwareKeyboardController.current
    val focusRequester = remember { FocusRequester() }
    var focused by remember { mutableStateOf(false) }
    val send = {
        keyboard?.hide()
        viewModel.sendCode(coordinator::didSendOtp)
    }
    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    Column(Modifier.fillMaxSize().background(DS.colors.background).safeDrawingPadding().imePadding()) {
        BackChevronButton(coordinator::pop)
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = DSSpacing.lg)
                .padding(top = DSSpacing.sm),
            verticalArrangement = Arrangement.spacedBy(DSSpacing.lg),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xs)) {
                Text(stringResource(R.string.auth_phone_title), style = DS.type.title1, color = DS.colors.textPrimary)
                Text(stringResource(R.string.auth_phone_subtitle), style = DS.type.body, color = DS.colors.textSecondary)
            }
            // Numbers read left to right in Arabic too: keep the dial code before the number.
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                Row(horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs), verticalAlignment = Alignment.CenterVertically) {
                    CountryCodeChip(viewModel.selectedCountry)
                    NumberField(
                        value = viewModel.nationalNumber,
                        placeholder = viewModel.selectedCountry.example,
                        focused = focused,
                        onValueChange = viewModel::onNumberChange,
                        onDone = { if (viewModel.canSubmit) send() },
                        modifier = Modifier
                            .weight(1f)
                            .focusRequester(focusRequester)
                            .onFocusChanged { focused = it.isFocused },
                    )
                }
            }
            viewModel.fieldError?.let {
                Text(it.authMessage(), style = DS.type.footnote, color = DS.colors.error)
            }
            Text(stringResource(R.string.auth_phone_terms), style = DS.type.footnote, color = DS.colors.textSecondary)
        }
        PrimaryButton(
            title = stringResource(R.string.auth_phone_sendCode),
            isLoading = viewModel.isSending,
            isEnabled = viewModel.canSubmit,
            modifier = Modifier.padding(horizontal = DSSpacing.lg, vertical = DSSpacing.sm),
            onClick = send,
        )
    }
}

/** The SA +966 chip. With a single selectable country it's a plain, non-interactive label. */
@Composable
private fun CountryCodeChip(country: PhoneCountry) {
    val description = stringResource(R.string.auth_phone_countryAccessibility)
    Row(
        modifier = Modifier
            .heightIn(min = 56.dp)
            .clip(RoundedCornerShape(DSRadius.control))
            .background(DS.colors.elevated)
            .padding(horizontal = DSSpacing.sm)
            .semantics { contentDescription = description },
        horizontalArrangement = Arrangement.spacedBy(DSSpacing.xxs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            country.id,
            style = DS.type.caption.copy(fontWeight = FontWeight.Bold),
            color = Color.White,
            modifier = Modifier
                .clip(RoundedCornerShape(DSRadius.control / 2))
                .background(DS.colors.primary)
                .padding(horizontal = DSSpacing.xxs, vertical = 2.dp),
        )
        Text(country.dialCode, style = DS.type.body, color = DS.colors.textPrimary)
    }
}

@Composable
private fun NumberField(
    value: String,
    placeholder: String,
    focused: Boolean,
    onValueChange: (String) -> Unit,
    onDone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(DSRadius.control)
    val description = stringResource(R.string.auth_phone_numberAccessibility)
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        textStyle = DS.type.body.copy(color = DS.colors.textPrimary),
        cursorBrush = SolidColor(DS.colors.primary),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Done),
        keyboardActions = KeyboardActions(onDone = { onDone() }),
        modifier = modifier.semantics { contentDescription = description },
        decorationBox = { inner ->
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 56.dp)
                    .clip(shape)
                    .background(DS.colors.surface)
                    .border(if (focused) 2.dp else 1.dp, if (focused) DS.colors.primary else DS.colors.border, shape)
                    .padding(horizontal = DSSpacing.md),
                contentAlignment = Alignment.CenterStart,
            ) {
                if (value.isEmpty()) {
                    Text(placeholder, style = DS.type.body, color = DS.colors.textSecondary.copy(alpha = 0.5f))
                }
                inner()
            }
        },
    )
}
