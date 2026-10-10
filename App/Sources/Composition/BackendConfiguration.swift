import Foundation
import Networking

/// Loads the Supabase client configuration from `BackendConfig.plist` and turns it into a
/// transport-level `NetworkConfiguration`. The app never imports the Supabase SDK — it just
/// points its own `URLSessionAPIClient` at Supabase's PostgREST base URL and attaches the
/// public anon key headers, so Supabase is only ever an HTTP detail behind the Networking layer.
enum BackendConfiguration {
    struct Values: Sendable {
        let baseURL: URL
        let anonKey: String
    }

    /// The raw Supabase URL + anon key from `BackendConfig.plist`, for callers (auth, storage)
    /// that need them directly rather than as a `NetworkConfiguration`.
    static func load() -> Values? {
        guard
            let url = Bundle.main.url(forResource: "BackendConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let baseString = dict["SUPABASE_URL"] as? String,
            let base = URL(string: baseString),
            let anonKey = dict["SUPABASE_ANON_KEY"] as? String, !anonKey.isEmpty
        else {
            return nil
        }
        return Values(baseURL: base, anonKey: anonKey)
    }

    /// Networking config. Base URL is the Supabase **project root**; each `APIEndpoint` carries
    /// its own service prefix (`/rest/v1`, `/auth/v1`, `/storage/v1`).
    static func makeNetworkConfiguration() -> NetworkConfiguration? {
        guard let values = load() else { return nil }
        // Supabase requires the anon key on every request (`apikey`), plus a bearer token that
        // defaults to the anon key for unauthenticated access. Once a user signs in, the
        // per-request bearer is swapped for their access token via the client's token provider.
        return NetworkConfiguration(
            baseURL: values.baseURL,
            defaultHeaders: [
                "apikey": values.anonKey,
                "Authorization": "Bearer \(values.anonKey)"
            ]
        )
    }
}
