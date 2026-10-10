import Foundation
import SwiftUI
import DesignSystem

/// A single in-app notification (place approved/rejected, a new review, a promotion decision,
/// or a logged payment) — written server-side by database triggers, never by the client. Lives
/// in `Shared` (not a single Feature package) since both Home and Account push the same
/// `NotificationsView` onto their own navigation stack.
public struct AppNotification: Identifiable, Sendable {
    public enum Kind: String, Sendable {
        case placeApproved = "place_approved"
        case placeRejected = "place_rejected"
        case reviewReceived = "review_received"
        case promotionApproved = "promotion_approved"
        case promotionRejected = "promotion_rejected"
        case paymentLogged = "payment_logged"
        // User-facing confirmations for the events the admin is also alerted about, plus admin
        // broadcasts. (The admin-audience kinds — ad_submitted etc. — never reach the app inbox,
        // so they're intentionally absent here; the DTO drops any unknown kind anyway.)
        case adReceived = "ad_received"
        case businessReceived = "business_received"
        case welcome
        case adminMessage = "admin_message"
        /// The owner's business was just verified by an admin.
        case businessVerified = "business_verified"
        // Admin-audience kinds — only ever surfaced to a signed-in admin (get_notifications returns
        // them when the caller is an admin), so an admin using the same app sees them in-app too.
        case adSubmitted = "ad_submitted"
        case businessSubmitted = "business_submitted"
        case userRegistered = "user_registered"
        case reviewSubmitted = "review_submitted"

        var icon: String {
            switch self {
            case .placeApproved: return "checkmark.seal.fill"
            case .placeRejected: return "xmark.seal.fill"
            case .reviewReceived, .reviewSubmitted: return "star.fill"
            case .promotionApproved, .promotionRejected: return "megaphone.fill"
            case .paymentLogged: return "creditcard.fill"
            case .adReceived, .adSubmitted: return "paperplane.fill"
            case .businessReceived, .businessSubmitted: return "building.2.fill"
            case .welcome: return "hand.wave.fill"
            case .adminMessage: return "bell.badge.fill"
            case .businessVerified: return "checkmark.seal.fill"
            case .userRegistered: return "person.crop.circle.badge.plus"
            }
        }

        var tint: Color {
            switch self {
            case .placeApproved, .promotionApproved, .paymentLogged, .adReceived, .businessReceived, .welcome, .adminMessage, .businessVerified, .adSubmitted, .businessSubmitted, .userRegistered:
                return .dsPrimary
            case .placeRejected, .promotionRejected: return .dsError
            case .reviewReceived, .reviewSubmitted: return .dsPremiumGold
            }
        }
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let subtitle: String?
    public let body: String
    public let imageURL: URL?
    public let placeId: String?
    /// A linked business, when the notification is about one (business created/verified) — lets a
    /// tap open the business profile, the counterpart to `placeId` for place notifications.
    public let businessId: String?
    public let isRead: Bool
    public let createdAt: Date

    public init(id: String, kind: Kind, title: String, subtitle: String? = nil, body: String, imageURL: URL? = nil, placeId: String?, businessId: String? = nil, isRead: Bool, createdAt: Date) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.imageURL = imageURL
        self.placeId = placeId
        self.businessId = businessId
        self.isRead = isRead
        self.createdAt = createdAt
    }
}

/// Boundary for the in-app notification inbox. Reading/marking-read only — rows are written
/// server-side by database triggers on place/review/promotion/payment changes, never by the
/// client, so there's no "create" method here.
public protocol NotificationsRepository: Sendable {
    func fetchNotifications() async throws -> [AppNotification]
    func markRead(id: String) async throws
    /// Records that the notification itself was opened — a push tap, or a tap on the inbox row.
    /// Separate from `markRead`, which `markAllRead` also satisfies without anyone reading
    /// anything.
    func markOpened(id: String) async throws
    func markAllRead() async throws
    /// Removes one notification from the inbox (user's own row, or any admin-audience row for an
    /// admin). Deletion is permanent — the row is gone, not just hidden.
    func deleteNotification(id: String) async throws
    /// Clears the whole inbox for the signed-in user (and the shared admin inbox for an admin).
    func deleteAllNotifications() async throws
    /// Associates this device's push token with the signed-in user, so server-side events can
    /// target it. Safe to call repeatedly — the backend upserts by token.
    func registerDeviceToken(_ token: String, platform: String) async throws
    /// Detaches this device's token (called on sign-out) so a future notification for the
    /// now-signed-out user doesn't keep pushing to this device.
    func unregisterDeviceToken(_ token: String) async throws
}

/// In-memory `NotificationsRepository` for offline UI work and UI tests (`UITEST_MOCK_BACKEND`).
public actor MockNotificationsRepository: NotificationsRepository {
    private var items: [AppNotification]

    public init(seed: [AppNotification] = MockNotificationsRepository.samples) {
        self.items = seed
    }

    public func fetchNotifications() async throws -> [AppNotification] { items }

    public func markRead(id: String) async throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items[index]
        items[index] = AppNotification(id: item.id, kind: item.kind, title: item.title, body: item.body, placeId: item.placeId, isRead: true, createdAt: item.createdAt)
    }

    /// The mock inbox has nowhere to put this — it exists so previews and UI tests satisfy the
    /// protocol without a network call.
    public func markOpened(id: String) async throws {}

    public func markAllRead() async throws {
        items = items.map { AppNotification(id: $0.id, kind: $0.kind, title: $0.title, body: $0.body, placeId: $0.placeId, isRead: true, createdAt: $0.createdAt) }
    }

    public func deleteNotification(id: String) async throws {
        items.removeAll { $0.id == id }
    }

    public func deleteAllNotifications() async throws {
        items.removeAll()
    }

    public func registerDeviceToken(_ token: String, platform: String) async throws {}
    public func unregisterDeviceToken(_ token: String) async throws {}

    public static let samples: [AppNotification] = [
        AppNotification(id: "1", kind: .placeApproved, title: "Your listing is live", body: "\"Al Ghadeer Rest House\" was approved and is now live.", placeId: nil, isRead: false, createdAt: Date().addingTimeInterval(-2 * 3600)),
        AppNotification(id: "2", kind: .reviewReceived, title: "New review", body: "Someone rated \"Sip — mobile café\" 5/5.", placeId: nil, isRead: false, createdAt: Date().addingTimeInterval(-86_400)),
        AppNotification(id: "3", kind: .promotionApproved, title: "Promotion approved", body: "Your promotion request for \"Palm Yard Chalet\" was approved.", placeId: nil, isRead: true, createdAt: Date().addingTimeInterval(-2 * 86_400))
    ]
}
