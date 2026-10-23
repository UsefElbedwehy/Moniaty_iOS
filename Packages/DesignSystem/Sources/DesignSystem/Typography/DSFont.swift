import SwiftUI
import CoreText

/// Munyati's type scale. Display styles (large title, title 1) use **Amiri**, the calligraphic
/// Naskh face the منيتي wordmark is built on, so headings echo the logo. Everything else uses the
/// system font (SF Arabic / SF Pro), which reads best at small sizes. Every case is anchored to a
/// `Font.TextStyle`, so Dynamic Type scales all of them.
///
/// Amiri ships in `Resources/Fonts` (SIL Open Font License) and must be registered once at
/// launch with `DSFonts.register()`; until then SwiftUI falls back to the system font.
public extension Font {
    static let dsLargeTitle = Font.custom(DSFonts.displayBold, size: 30, relativeTo: .title)
    static let dsTitle1 = Font.custom(DSFonts.displayBold, size: 24, relativeTo: .title2)
    static let dsTitle2 = Font.system(.title3).weight(.bold)
    static let dsHeadline = Font.system(.headline).weight(.semibold)
    static let dsBody = Font.system(.body)
    static let dsSubhead = Font.system(.subheadline).weight(.medium)
    static let dsFootnote = Font.system(.footnote)
    static let dsCaption = Font.system(.caption).weight(.medium)
}

/// Registers the bundled brand fonts with Core Text.
public enum DSFonts {
    public static let displayRegular = "Amiri-Regular"
    public static let displayBold = "Amiri-Bold"

    /// Call once from the App's init. Safe to call more than once: already-registered fonts are
    /// skipped by Core Text and the error is ignored.
    public static func register() {
        let urls = (Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
