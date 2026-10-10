import Foundation

/// Generic pagination envelope for list endpoints. This is a transport-level shape only —
/// it knows nothing about any feature's domain model. Each feature decodes its own
/// `PageDTO<FeatureDTO>` and maps it to a domain-level paginated result.
public struct PageDTO<Element: Decodable & Sendable>: Decodable, Sendable {
    public let items: [Element]
    public let nextCursor: String?
    public let hasMore: Bool
}
