import Foundation
import Security

/// Keychain-backed storage for the Supabase auth session. Before this, `SupabaseAuthRepository`
/// held its session as a plain in-memory `var` — killing the app (or even backgrounding it long
/// enough for the process to be evicted) wiped it completely, forcing a fresh sign-in on every
/// launch. The access token, refresh token, and expiry now survive relaunches the same way any
/// production app's session does.
struct KeychainSessionStore: Sendable {
    struct PersistedSession: Codable, Sendable {
        let accessToken: String
        let refreshToken: String?
        let userId: String
        let phone: String?
        let expiresAt: Date
    }

    private let service = "com.munyati.app.session"
    private let account = "supabase"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() -> PersistedSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(PersistedSession.self, from: data)
    }

    func save(_ session: PersistedSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }

        // Delete-then-add rather than update: simplest way to be idempotent regardless of
        // whether an item already exists, and this runs at most once per sign-in/refresh.
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        // Available as soon as the device is unlocked once after boot, and remains available
        // while locked thereafter — appropriate for a background token refresh, unlike
        // `.whenUnlocked` which would block that.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
