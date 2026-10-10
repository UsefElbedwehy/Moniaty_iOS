import Foundation
import Networking

/// Supabase-backed `CMSPageRepository`: reads via `get_cms_page`, which already scopes to
/// `status = 'published'` server-side — no draft/unpublished content ever reaches the client.
struct SupabaseCMSPageRepository: CMSPageRepository {
    let client: APIClient

    func fetchPage(slug: String, locale: String) async throws -> CMSPage? {
        let dto: CMSPageDTO? = try await client.send(.cms.getPage, body: GetPageArgs(pSlug: slug, pLocale: locale))
        return dto?.toDomain()
    }
}

private struct GetPageArgs: Encodable, Sendable { let pSlug: String; let pLocale: String }

private struct CMSPageDTO: Decodable, Sendable {
    let slug: String
    let title: String
    let bodyMarkdown: String

    func toDomain() -> CMSPage {
        CMSPage(slug: slug, title: title, bodyMarkdown: bodyMarkdown)
    }
}
