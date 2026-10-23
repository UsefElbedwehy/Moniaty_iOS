package co.munyati.authentication.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import co.munyati.authentication.R
import co.munyati.designsystem.components.PrimaryButton
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSRadius
import co.munyati.designsystem.theme.DSSpacing

/**
 * New-user name capture: first + last name, both required, right after the code is verified for a
 * brand-new number. Submitting creates the account. Matches the iOS `NameEntryView`.
 */
@Composable
internal fun NameEntryScreen(viewModel: NameEntryViewModel, coordinator: AuthCoordinator) {
    // Hide the keyboard rather than clearing focus (see PhoneEntryScreen).
    val keyboard = LocalSoftwareKeyboardController.current
    val firstFocus = remember { FocusRequester() }
    val lastFocus = remember { FocusRequester() }
    LaunchedEffect(Unit) { firstFocus.requestFocus() }

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
                Text(stringResource(R.string.auth_name_title), style = DS.type.title1, color = DS.colors.textPrimary)
                Text(stringResource(R.string.auth_name_subtitle), style = DS.type.body, color = DS.colors.textSecondary)
            }
            Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
                NameField(
                    value = viewModel.firstName,
                    placeholder = stringResource(R.string.auth_name_first),
                    imeAction = ImeAction.Next,
                    onAction = { lastFocus.requestFocus() },
                    onValueChange = { viewModel.firstName = it },
                    modifier = Modifier.focusRequester(firstFocus),
                )
                NameField(
                    value = viewModel.lastName,
                    placeholder = stringResource(R.string.auth_name_last),
                    imeAction = ImeAction.Done,
                    onAction = { keyboard?.hide() },
                    onValueChange = { viewModel.lastName = it },
                    modifier = Modifier.focusRequester(lastFocus),
                )
            }
            viewModel.fieldError?.let {
                Text(it.authMessage(), style = DS.type.footnote, color = DS.colors.error)
            }
        }
        PrimaryButton(
            title = stringResource(R.string.auth_name_submit),
            isLoading = viewModel.isSubmitting,
            isEnabled = viewModel.canSubmit,
            modifier = Modifier.padding(horizontal = DSSpacing.lg, vertical = DSSpacing.sm),
        ) {
            keyboard?.hide()
            viewModel.submit(coordinator::didAuthenticate)
        }
    }
}

@Composable
private fun NameField(
    value: String,
    placeholder: String,
    imeAction: ImeAction,
    onAction: () -> Unit,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(DSRadius.control)
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        textStyle = DS.type.body.copy(color = DS.colors.textPrimary),
        cursorBrush = SolidColor(DS.colors.primary),
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, autoCorrectEnabled = false, imeAction = imeAction),
        keyboardActions = KeyboardActions(onNext = { onAction() }, onDone = { onAction() }),
        modifier = modifier.onFocusChanged { focused = it.isFocused },
        decorationBox = { inner ->
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .clip(shape)
                    .background(DS.colors.surface)
                    .border(if (focused) 2.dp else 1.dp, if (focused) DS.colors.primary else DS.colors.border, shape)
                    .padding(horizontal = DSSpacing.md),
                contentAlignment = Alignment.CenterStart,
            ) {
                if (value.isEmpty()) Text(placeholder, style = DS.type.body, color = DS.colors.textSecondary.copy(alpha = 0.5f))
                inner()
            }
        },
    )
}
