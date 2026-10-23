import Core
import Foundation

/// Generic transport abstraction. Feature Data-layer repositories depend on this protocol
/// (never on `URLSession` or Supabase directly) so they can be tested against a fake and so
/// the concrete transport can be swapped without touching call sites.
public protocol APIClient: Sendable {
    func send<Response: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws(AppError) -> Response
    func send<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        body: Body
    ) async throws(AppError) -> Response
}
