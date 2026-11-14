package co.munyati.authentication.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import co.munyati.authentication.R
import co.munyati.designsystem.components.PrimaryButton
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSSpacing
import kotlinx.coroutines.launch

private class Slide(val icon: ImageVector, val title: Int, val body: Int)

private val slides = listOf(
    Slide(Icons.Outlined.AutoAwesome, R.string.auth_slides_discover_title, R.string.auth_slides_discover_body),
    Slide(Icons.Outlined.CalendarMonth, R.string.auth_slides_book_title, R.string.auth_slides_book_body),
    Slide(Icons.Outlined.Payments, R.string.auth_slides_pay_title, R.string.auth_slides_pay_body),
)

/**
 * The three intro slides shown once, before the role choice: discover, book, pay. Matches the iOS
 * `OnboardingSlidesView`. "Skip" and the last slide's button both call [onFinish].
 */
@Composable
internal fun OnboardingSlidesScreen(onFinish: () -> Unit) {
    val pager = rememberPagerState { slides.size }
    val scope = rememberCoroutineScope()
    val isLast = pager.currentPage == slides.lastIndex

    Column(Modifier.fillMaxSize().background(DS.colors.background).safeDrawingPadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = DSSpacing.xl).padding(top = DSSpacing.sm), horizontalArrangement = Arrangement.End) {
            if (!isLast) {
                Box(
                    Modifier.heightIn(min = 44.dp).widthIn(min = 44.dp).clickable(role = Role.Button, onClick = onFinish),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(stringResource(R.string.auth_slides_skip), style = DS.type.headline, color = DS.colors.primary)
                }
            } else {
                Spacer(Modifier.height(44.dp))
            }
        }

        HorizontalPager(pager, Modifier.weight(1f).fillMaxWidth()) { index ->
            val slide = slides[index]
            Column(
                Modifier.fillMaxSize().padding(horizontal = DSSpacing.xl),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Box(
                    Modifier.size(220.dp).clip(CircleShape).background(DS.colors.primaryMuted)
                        .border(1.dp, DS.colors.premiumGold, CircleShape).padding(10.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(slide.icon, contentDescription = null, tint = DS.colors.primary, modifier = Modifier.size(84.dp))
                }
                Spacer(Modifier.height(DSSpacing.lg))
                Text(stringResource(slide.title), style = DS.type.title1, color = DS.colors.textPrimary, textAlign = TextAlign.Center)
                Spacer(Modifier.height(DSSpacing.sm))
                Text(stringResource(slide.body), style = DS.type.body, color = DS.colors.textSecondary, textAlign = TextAlign.Center)
            }
        }

        Row(
            Modifier.fillMaxWidth().padding(bottom = DSSpacing.lg),
            horizontalArrangement = Arrangement.spacedBy(DSSpacing.xs, Alignment.CenterHorizontally),
        ) {
            slides.indices.forEach { index ->
                val selected = index == pager.currentPage
                Box(
                    Modifier.height(8.dp).size(width = if (selected) 24.dp else 8.dp, height = 8.dp).clip(CircleShape)
                        .background(if (selected) DS.colors.primary else DS.colors.border),
                )
            }
        }

        PrimaryButton(
            title = stringResource(if (isLast) R.string.auth_slides_start else R.string.auth_slides_next),
            modifier = Modifier.padding(horizontal = DSSpacing.xl).padding(bottom = DSSpacing.lg),
        ) {
            if (isLast) onFinish() else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
        }
    }
}
