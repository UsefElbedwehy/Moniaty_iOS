import Foundation

/// Whom a customer browses for, and whom a provider serves: the bride herself (e.g. bridal
/// makeup), the wedding guests «المعازيم» (e.g. guests' makeup, food), or both. Customers see
/// only providers that serve their audience; `both` on either side matches everyone. Stored as
/// `profiles.audience` / `providers.audience`.
public enum Audience: String, Codable, Sendable, CaseIterable, Hashable {
    case bride
    case guests
    case both
}
