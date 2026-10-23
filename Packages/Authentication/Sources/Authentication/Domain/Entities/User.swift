import Foundation

/// Which side of the marketplace an account is on. Chosen once at sign-up and stored on the
/// server profile; it decides which tab shell the App shows.
public enum UserRole: String, Codable, Sendable, CaseIterable {
    case bride
    case provider
}

/// A signed-in person. `phoneNumber` is the E.164 value we verified; `displayName` is optional
/// because a freshly phone-verified user has no profile yet. `role` is nil only for anonymous
/// guests and for legacy sessions whose profile has not been fetched yet.
public struct User: Identifiable, Equatable, Sendable {
    public let id: String
    public let phoneNumber: String?
    public let displayName: String?
    public let role: UserRole?

    public init(id: String, phoneNumber: String? = nil, displayName: String? = nil, role: UserRole? = nil) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.role = role
    }
}
