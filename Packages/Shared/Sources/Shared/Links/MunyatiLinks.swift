import Foundation

/// Shareable universal links on munyati.co (`docs/PLAN.md` §4.12). The App's `DeepLink` parses
/// the same paths back, so a shared link opens the right screen in the app.
public enum MunyatiLinks {
    public static let base = URL(string: "https://munyati.co")!

    public static func provider(_ id: String) -> URL { base.appendingPathComponent("p/\(id)") }
    public static func service(_ id: String) -> URL { base.appendingPathComponent("s/\(id)") }
    public static func store(_ id: String) -> URL { base.appendingPathComponent("store/\(id)") }
    public static func category(_ id: String) -> URL { base.appendingPathComponent("c/\(id)") }
}
