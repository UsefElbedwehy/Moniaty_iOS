package co.munyati.app.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import co.munyati.app.R
import co.munyati.app.backend.CmsPage
import co.munyati.app.backend.CmsPageRepository
import co.munyati.app.composition.l10n
import co.munyati.designsystem.components.DSTopBar
import co.munyati.designsystem.components.EmptyStateView
import co.munyati.designsystem.theme.DS
import co.munyati.designsystem.theme.DSSpacing
import co.munyati.shared.navigation.LocalNavigator
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.util.Locale

/** A CMS page (terms, privacy, about) from the dashboard-managed `cms_pages` table. */
@Serializable data class CmsPageRoute(val slug: String)

@Composable
fun CmsPageScreen(slug: String, repository: CmsPageRepository) {
    val navigator = LocalNavigator.current
    val scope = rememberCoroutineScope()
    var page by remember { mutableStateOf<CmsPage?>(null) }
    var failed by remember { mutableStateOf(false) }

    suspend fun load() {
        failed = false
        val locale = if (Locale.getDefault().language == "en") "en" else "ar"
        page = runCatching { repository.fetchPage(slug, locale) }.getOrNull()
        failed = page == null
    }
    LaunchedEffect(slug) { load() }

    Column(Modifier.fillMaxSize().background(DS.colors.background)) {
        DSTopBar(page?.title.orEmpty(), navigator.back, l10n(R.string.common_done))
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            val p = page
            when {
                p != null -> MarkdownView(p.bodyMarkdown, Modifier.padding(DSSpacing.lg))
                failed -> Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    EmptyStateView(Icons.Outlined.WifiOff, l10n(R.string.common_errorTitle), l10n(R.string.common_errorMessage))
                    TextButton(onClick = { scope.launch { load() } }) { Text(l10n(R.string.common_retry), style = DS.type.headline, color = DS.colors.primary) }
                }
                else -> Box(Modifier.fillMaxWidth().padding(top = DSSpacing.xxl), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = DS.colors.primary, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
                }
            }
        }
    }
}

/**
 * Renders CMS markdown as blocks — paragraphs, headings, bullet/numbered lists and rules — with
 * inline **bold** and *italic*. The same grouping rules as the iOS `CMSMarkdownView`.
 */
@Composable
private fun MarkdownView(markdown: String, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(DSSpacing.sm)) {
        parseBlocks(markdown).forEach { block ->
            when (block) {
                is Block.Heading -> Text(
                    inline(block.text),
                    style = when (block.level) { 1 -> DS.type.title1; 2 -> DS.type.title2; else -> DS.type.headline },
                    color = DS.colors.textPrimary,
                    modifier = Modifier.padding(top = if (block.level <= 2) DSSpacing.xs else 0.dp),
                )
                is Block.Paragraph -> Text(inline(block.text), style = DS.type.body, color = DS.colors.textPrimary)
                is Block.ListBlock -> Column(verticalArrangement = Arrangement.spacedBy(DSSpacing.xxs)) {
                    block.items.forEach { (marker, text) ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(marker, style = DS.type.body, color = DS.colors.textSecondary)
                            Text(inline(text), style = DS.type.body, color = DS.colors.textPrimary, modifier = Modifier.weight(1f))
                        }
                    }
                }
                Block.Rule -> HorizontalDivider(color = DS.colors.border, modifier = Modifier.padding(vertical = DSSpacing.xxs))
            }
        }
    }
}

private sealed interface Block {
    data class Heading(val level: Int, val text: String) : Block
    data class Paragraph(val text: String) : Block
    data class ListBlock(val items: List<Pair<String, String>>) : Block
    data object Rule : Block
}

/**
 * Line-by-line grouping: blank lines break blocks; consecutive bullet/number lines group into a
 * list; consecutive plain lines join (with a space) into a paragraph.
 */
private fun parseBlocks(markdown: String): List<Block> {
    val result = mutableListOf<Block>()
    val paragraph = mutableListOf<String>()
    val bullets = mutableListOf<Pair<String, String>>()
    val ordered = mutableListOf<Pair<String, String>>()
    fun flushParagraph() { if (paragraph.isNotEmpty()) { result += Block.Paragraph(paragraph.joinToString(" ")); paragraph.clear() } }
    fun flushBullets() { if (bullets.isNotEmpty()) { result += Block.ListBlock(bullets.toList()); bullets.clear() } }
    fun flushOrdered() { if (ordered.isNotEmpty()) { result += Block.ListBlock(ordered.toList()); ordered.clear() } }
    fun flushAll() { flushParagraph(); flushBullets(); flushOrdered() }

    for (raw in markdown.replace("\r\n", "\n").split("\n")) {
        val line = raw.trim()
        val heading = Regex("^(#{1,6}) (.+)$").find(line)
        val number = Regex("^(\\d+)\\. (.+)$").find(line)
        val compact = line.replace(" ", "")
        when {
            line.isEmpty() -> flushAll()
            compact.length >= 3 && (compact.all { it == '-' } || compact.all { it == '*' } || compact.all { it == '_' }) -> { flushAll(); result += Block.Rule }
            heading != null -> { flushAll(); result += Block.Heading(heading.groupValues[1].length, heading.groupValues[2].trim()) }
            line.startsWith("- ") || line.startsWith("* ") || line.startsWith("+ ") -> { flushParagraph(); flushOrdered(); bullets += "•" to line.drop(2).trim() }
            number != null -> { flushParagraph(); flushBullets(); ordered += "${number.groupValues[1]}." to number.groupValues[2].trim() }
            else -> { flushBullets(); flushOrdered(); paragraph += line }
        }
    }
    flushAll()
    return result
}

/** Inline **bold** and *italic* (links show as their text). */
private fun inline(text: String): AnnotatedString = buildAnnotatedString {
    val pattern = Regex("\\*\\*(.+?)\\*\\*|\\*(.+?)\\*|\\[(.+?)]\\((.+?)\\)")
    var index = 0
    for (match in pattern.findAll(text)) {
        append(text.substring(index, match.range.first))
        val (bold, italic, linkText) = Triple(match.groups[1]?.value, match.groups[2]?.value, match.groups[3]?.value)
        when {
            bold != null -> withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(bold) }
            italic != null -> withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(italic) }
            linkText != null -> withStyle(SpanStyle(color = androidx.compose.ui.graphics.Color(0xFF8A0D3A))) { append(linkText) }
        }
        index = match.range.last + 1
    }
    append(text.substring(index))
}
