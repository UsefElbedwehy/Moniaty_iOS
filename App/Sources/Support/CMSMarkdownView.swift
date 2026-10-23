import SwiftUI
import DesignSystem

/// Renders CMS / Help markdown as proper blocks — paragraphs (blank-line separated, with real
/// spacing), headings, and bullet/numbered lists. SwiftUI's `Text(AttributedString(markdown:))`
/// collapses every newline and all block structure into one run, which is why the pages looked
/// like one wall of text. Inline styling (**bold**, *italic*, [links](…)) still works per line.
struct CMSMarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Rendering

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case let .heading(level, text):
            inlineText(text)
                .font(headingFont(level))
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.top, level <= 2 ? DSSpacing.xs : 0)
        case let .paragraph(text):
            inlineText(text)
                .font(.dsBody)
                .foregroundStyle(Color.dsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        case let .bullets(items):
            listView(items.map { (marker: "•", text: $0) })
        case let .ordered(items):
            listView(items.map { (marker: "\($0.number).", text: $0.text) })
        case .rule:
            Divider().overlay(Color.dsBorder).padding(.vertical, DSSpacing.xxs)
        }
    }

    private func listView(_ items: [(marker: String, text: String)]) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Text(item.marker)
                        .font(.dsBody)
                        .foregroundStyle(Color.dsTextSecondary)
                    inlineText(item.text)
                        .font(.dsBody)
                        .foregroundStyle(Color.dsTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Inline markdown for a single logical line (bold/italic/links), preserving whitespace.
    private func inlineText(_ string: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(string)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .dsTitle1
        case 2: return .dsTitle2
        default: return .dsHeadline
        }
    }

    // MARK: - Parsing

    private struct OrderedItem { let number: Int; let text: String }

    private enum Block {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullets([String])
        case ordered([OrderedItem])
        case rule
    }

    /// Line-by-line grouping: blank lines break blocks; consecutive bullet/number lines group into
    /// a list; consecutive plain lines join (with a space, standard soft-wrap) into a paragraph.
    private var blocks: [Block] {
        var result: [Block] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var ordered: [OrderedItem] = []

        func flushParagraph() {
            if !paragraph.isEmpty { result.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
        }
        func flushBullets() { if !bullets.isEmpty { result.append(.bullets(bullets)); bullets = [] } }
        func flushOrdered() { if !ordered.isEmpty { result.append(.ordered(ordered)); ordered = [] } }
        func flushAll() { flushParagraph(); flushBullets(); flushOrdered() }

        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        for raw in normalized.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flushAll(); continue }
            if isHorizontalRule(line) { flushAll(); result.append(.rule); continue }
            if let heading = parseHeading(line) { flushAll(); result.append(heading); continue }
            if isBullet(line) { flushParagraph(); flushOrdered(); bullets.append(strip(line, 2)); continue }
            if let (number, text) = parseOrdered(line) {
                flushParagraph(); flushBullets(); ordered.append(OrderedItem(number: number, text: text)); continue
            }
            flushBullets(); flushOrdered(); paragraph.append(line)
        }
        flushAll()
        return result
    }

    private func parseHeading(_ line: String) -> Block? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        var index = line.startIndex
        while index < line.endIndex, line[index] == "#", level < 6 {
            level += 1
            index = line.index(after: index)
        }
        guard index < line.endIndex, line[index] == " " else { return nil }
        let text = String(line[line.index(after: index)...]).trimmingCharacters(in: .whitespaces)
        return .heading(level: level, text: text)
    }

    private func isBullet(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    /// A thematic break: a line of 3+ identical `-`, `*`, or `_` (e.g. "---").
    private func isHorizontalRule(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        guard stripped.count >= 3 else { return false }
        return stripped.allSatisfy { $0 == "-" } || stripped.allSatisfy { $0 == "*" } || stripped.allSatisfy { $0 == "_" }
    }

    private func parseOrdered(_ line: String) -> (number: Int, text: String)? {
        // "12. text" → (12, "text")
        guard let dot = line.firstIndex(of: "."),
              let number = Int(line[line.startIndex..<dot]),
              line.index(after: dot) < line.endIndex, line[line.index(after: dot)] == " " else { return nil }
        let text = String(line[line.index(dot, offsetBy: 2)...]).trimmingCharacters(in: .whitespaces)
        return (number, text)
    }

    private func strip(_ line: String, _ count: Int) -> String {
        String(line.dropFirst(count)).trimmingCharacters(in: .whitespaces)
    }
}
