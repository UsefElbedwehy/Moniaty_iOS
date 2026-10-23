import Foundation
import Observation

/// Every place the app can be opened to from outside: a notification tap, a universal link on
/// `munyati.co`, or the `munyati://` scheme (`docs/PLAN.md` §4.12). One parser serves all three.
///
/// URL shapes (web and scheme use the same paths):
///   https://munyati.co/p/<id>      provider profile      munyati://p/<id>
///   https://munyati.co/s/<id>      service
///   https://munyati.co/store/<id>  store
///   https://munyati.co/c/<id>      category
///   https://munyati.co/b/<id>      booking (signed-in parties only)
///   https://munyati.co/plans       provider plans
///   https://munyati.co/notifications
enum DeepLink: Equatable, Sendable {
    case provider(id: String)
    case service(id: String)
    case store(id: String)
    case category(id: String)
    case booking(id: String)
    case plans
    case notifications

    static let webHosts: Set<String> = ["munyati.co", "www.munyati.co"]
    static let scheme = "munyati"

    init?(url: URL) {
        var parts: [String]
        if url.scheme == Self.scheme {
            // munyati://p/123 → host "p", path "/123"
            parts = [url.host].compactMap { $0 } + url.pathComponents.filter { $0 != "/" }
        } else if url.scheme == "https", let host = url.host?.lowercased(), Self.webHosts.contains(host) {
            parts = url.pathComponents.filter { $0 != "/" }
        } else {
            return nil
        }
        guard let head = parts.first?.lowercased() else { return nil }
        parts.removeFirst()
        let id = parts.first.flatMap { $0.isEmpty ? nil : $0 }

        switch (head, id) {
        case ("p", let id?): self = .provider(id: id)
        case ("s", let id?): self = .service(id: id)
        case ("store", let id?): self = .store(id: id)
        case ("c", let id?): self = .category(id: id)
        case ("b", let id?): self = .booking(id: id)
        case ("plans", _): self = .plans
        case ("notifications", _): self = .notifications
        default: return nil
        }
    }

    init?(string: String?) {
        guard let string, let url = URL(string: string) else { return nil }
        self.init(url: url)
    }

    /// The shareable universal link for this destination.
    var webURL: URL {
        let path: String
        switch self {
        case .provider(let id): path = "p/\(id)"
        case .service(let id): path = "s/\(id)"
        case .store(let id): path = "store/\(id)"
        case .category(let id): path = "c/\(id)"
        case .booking(let id): path = "b/\(id)"
        case .plans: path = "plans"
        case .notifications: path = "notifications"
        }
        return URL(string: "https://munyati.co/\(path)")!
    }
}

/// Holds the deep link waiting to be shown. Set by push taps and `onOpenURL`; the tab shells
/// consume it (switch tab, then open the screen) and clear it.
@MainActor
@Observable
final class DeepLinkStore {
    var pending: DeepLink?
}
