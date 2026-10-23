import Foundation

/// A concrete, resolved API endpoint: a path, an HTTP method, and optional query items.
///
/// The rest of the app never hardcodes a URL path or knows about REST/Supabase details —
/// it only ever writes something like `APIEndpoint.catalog.cities` and hands that to an
/// `APIClient`. This is the single module that encodes how the backend is shaped; if the
/// backend changes later, only this file and each feature's repository implementation change —
/// Presentation and Domain never do.
///
/// Current backend: **Supabase**. The base URL is the project root; each path carries its
/// service prefix (`/rest/v1`, `/auth/v1`, `/storage/v1`). Data access goes through Postgres
/// RPC functions (see `supabase/migrations/*_rpc.sql`) whose JSON output matches the feature
/// DTOs exactly — so the app "mainly renders data" and business logic stays in the backend.
public struct APIEndpoint: Sendable, Equatable {
    public enum HTTPMethod: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    public let path: String
    public let method: HTTPMethod
    public let queryItems: [URLQueryItem]

    public init(path: String, method: HTTPMethod, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
    }

    /// Convenience for a Supabase Postgres RPC call (always POST `/rest/v1/rpc/<name>`,
    /// arguments supplied as the JSON body).
    public static func rpc(_ name: String) -> APIEndpoint {
        APIEndpoint(path: "/rest/v1/rpc/\(name)", method: .post)
    }

    /// Convenience for a Supabase Edge Function call (always POST `/functions/v1/<name>`).
    /// Public functions carry only the anon apikey/bearer via the default headers.
    public static func function(_ name: String) -> APIEndpoint {
        APIEndpoint(path: "/functions/v1/\(name)", method: .post)
    }
}

// MARK: - Endpoint namespaces

extension APIEndpoint {
    /// Supabase Auth (GoTrue). These carry the anon apikey via the default headers; the bearer
    /// is the anon key until a session exists, at which point the token provider overrides it.
    public enum authentication {
        /// Anonymous sign-in — returns a real session so "guest" users can still own places.
        public static let signUpAnonymous = APIEndpoint(path: "/auth/v1/signup", method: .post)
        /// Request a phone OTP. Delivered by our own `send-otp` Edge Function (which sends the
        /// SMS via OurSMS), not GoTrue's native phone provider — OurSMS isn't a built-in provider.
        public static let sendOTP = APIEndpoint.function("send-otp")
        /// Verify a phone OTP, returning a session. Handled by the `verify-otp` Edge Function,
        /// which checks the code and mints a Supabase session.
        public static let verifyOTP = APIEndpoint.function("verify-otp")
        /// Exchange an OIDC id-token (e.g. Sign in with Apple) for a session.
        public static let signInWithIdToken = APIEndpoint(
            path: "/auth/v1/token",
            method: .post,
            queryItems: [URLQueryItem(name: "grant_type", value: "id_token")]
        )
        /// Exchange a still-valid refresh token for a new session — used to renew an expired
        /// access token without asking the user to sign in again, and to validate a session
        /// restored from Keychain at app launch.
        public static let refreshToken = APIEndpoint(
            path: "/auth/v1/token",
            method: .post,
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")]
        )
    }

    public enum configuration {
        public static let get = APIEndpoint.rpc("get_config")
        /// Remote string overrides changed since a given timestamp (`app_strings`).
        public static let strings = APIEndpoint.rpc("get_app_strings")
    }

    public enum catalog {
        public static let cities = APIEndpoint.rpc("get_cities")
        public static let categories = APIEndpoint.rpc("get_categories")
    }

    public enum analytics {
        public static let record = APIEndpoint.rpc("record_analytics_event")
        public static let logError = APIEndpoint.rpc("log_client_error")
    }

    public enum profile {
        public static let get = APIEndpoint.rpc("get_my_profile")
        public static let update = APIEndpoint.rpc("update_my_profile")
        public static let setCities = APIEndpoint.rpc("set_my_cities")
    }

    public enum notifications {
        public static let list = APIEndpoint.rpc("get_notifications")
        public static let markRead = APIEndpoint.rpc("mark_notification_read")
        public static let markOpened = APIEndpoint.rpc("mark_notification_opened")
        public static let markAllRead = APIEndpoint.rpc("mark_all_notifications_read")
        public static let delete = APIEndpoint.rpc("delete_notification")
        public static let deleteAll = APIEndpoint.rpc("delete_all_notifications")
        public static let registerDeviceToken = APIEndpoint.rpc("register_device_token")
        public static let unregisterDeviceToken = APIEndpoint.rpc("unregister_device_token")
    }

    public enum cms {
        public static let getPage = APIEndpoint.rpc("get_cms_page")
    }
}
