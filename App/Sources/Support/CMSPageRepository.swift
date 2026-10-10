import Foundation

/// A CMS page the admin dashboard manages (Help/Terms/Privacy body copy) — server-written only,
/// read here so `InfoSheet` can show live content instead of copy baked into the app bundle.
struct CMSPage: Sendable {
    let slug: String
    let title: String
    let bodyMarkdown: String
}

/// Boundary for fetching CMS page content. Read-only — pages are authored in the admin dashboard.
protocol CMSPageRepository: Sendable {
    /// Returns `nil` when the slug doesn't exist or isn't published yet — callers fall back to
    /// bundled copy in that case rather than showing an empty sheet. `locale` is `"en"`/`"ar"`
    /// (matches `AppLanguage.rawValue`); the backend falls back to English if the Arabic pair
    /// for a page hasn't been filled in yet.
    func fetchPage(slug: String, locale: String) async throws -> CMSPage?
}

/// In-memory `CMSPageRepository` for offline UI work and UI tests (`UITEST_MOCK_BACKEND`).
struct MockCMSPageRepository: CMSPageRepository {
    func fetchPage(slug: String, locale: String) async throws -> CMSPage? {
        let isArabic = locale == "ar"
        switch slug {
        case "help":
            return CMSPage(
                slug: slug,
                title: isArabic ? "المساعدة" : "Help",
                bodyMarkdown: isArabic
                    ? "هذا محتوى مساعدة تجريبي — النص الحقيقي يأتي من محرر الصفحات في لوحة التحكم."
                    : "This is mock Help content — the real copy comes from the admin dashboard's Settings → Pages editor."
            )
        case "terms-of-service":
            return CMSPage(
                slug: slug,
                title: isArabic ? "الشروط والأحكام" : "Terms of Service",
                bodyMarkdown: isArabic
                    ? "هذا محتوى شروط تجريبي — النص الحقيقي يأتي من محرر الصفحات في لوحة التحكم."
                    : "This is mock Terms content — the real copy comes from the admin dashboard's Settings → Pages editor."
            )
        case "privacy-policy":
            return CMSPage(
                slug: slug,
                title: isArabic ? "سياسة الخصوصية" : "Privacy Policy",
                bodyMarkdown: isArabic
                    ? "هذا محتوى خصوصية تجريبي — النص الحقيقي يأتي من محرر الصفحات في لوحة التحكم."
                    : "This is mock Privacy content — the real copy comes from the admin dashboard's Settings → Pages editor."
            )
        case "about":
            return CMSPage(
                slug: slug,
                title: isArabic ? "عن منيتي" : "About Munyati",
                bodyMarkdown: isArabic
                    ? "هذا محتوى تجريبي — النص الحقيقي يأتي من محرر الصفحات في لوحة التحكم."
                    : "This is mock About content — the real copy comes from the admin dashboard's Settings → Pages editor."
            )
        default:
            return nil
        }
    }
}
