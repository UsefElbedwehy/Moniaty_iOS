import Foundation

/// Text the admin can change from the dashboard without an app release (`app_strings` table,
/// see `docs/PLAN.md` §4.13). The App fetches overrides on launch, caches them, and installs
/// them here; lookups fall back to the bundled `Localizable.strings` value when a key has no
/// override, so the app always works offline and on first launch.
///
/// Thread-safe: overrides are swapped atomically under a lock, so any isolation can read them.
public final class RemoteStrings: @unchecked Sendable {
    public static let shared = RemoteStrings()

    private let lock = NSLock()
    private var overrides: [String: String] = [:]

    public init() {}

    /// Replaces all overrides for the current language (key → text).
    public func install(_ newOverrides: [String: String]) {
        lock.lock()
        overrides = newOverrides
        lock.unlock()
    }

    /// The override for `key`, or `fallback` (normally the bundled localized value).
    public func string(_ key: String, fallback: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        if let value = overrides[key], !value.isEmpty { return value }
        return fallback
    }
}
