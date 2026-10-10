import Foundation

/// A concrete, resolved API endpoint: a path, an HTTP method, and optional query items.
///
/// The rest of the app never hardcodes a URL path or knows about REST/Supabase details —
/// it only ever writes something like `APIEndpoint.places.detail` and hands that to an
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
    }

    public enum categories {
        public static let list = APIEndpoint.rpc("get_categories")
        /// Body: `{ "p_category_id": "<id>" }`.
        public static let formSchema = APIEndpoint.rpc("get_category_form_schema")
    }

    public enum home {
        public static let sections = APIEndpoint.rpc("get_home_sections")
    }

    public enum places {
        /// Body: `{ "p_status": <string?>, "p_cursor": <string?>, "p_limit": <int>, …,
        /// "p_featured": <bool?> }`.
        public static let list = APIEndpoint.rpc("get_places")
        /// No args → `{ "featured": [PlaceDTO], "recent": [PlaceDTO] }`. Home's Featured/Recent
        /// rails — counts are admin-configured server-side (`app_config.home_featured_count`/
        /// `home_recent_count`).
        public static let home = APIEndpoint.rpc("get_home_places")
        /// Body: `{ "p_id": "<uuid>" }`.
        public static let detail = APIEndpoint.rpc("get_place_detail")
        /// Body: `{ "payload": { … } }`.
        public static let submit = APIEndpoint.rpc("submit_place")
        /// Body: `{ "p_id": "<uuid>", "payload": { … } }`.
        public static let resubmit = APIEndpoint.rpc("resubmit_place")
        /// Body: `{ "p_status": <string?> }`.
        public static let myPlaces = APIEndpoint.rpc("get_my_places")
        /// Body: `{ "p_id": "<uuid>" }`. Fire-and-forget — increments the place's view counter.
        public static let recordView = APIEndpoint.rpc("record_place_view")
    }

    /// Engagement events (button taps, banner impressions) behind the dashboard's insights
    /// screen. Fire-and-forget — a dropped event is never worth failing a user action over.
    public enum analytics {
        /// Body: `{ "p_event_type": "<analytics_event_type>", "p_entity_id": <string?>,
        /// "p_context_id": <string?> }`.
        public static let record = APIEndpoint.rpc("record_analytics_event")
    }

    /// Server-side logging of what people actually search for, so the admin dashboard can
    /// surface trending terms/categories/cities. Fire-and-forget from the client's perspective.
    public enum search {
        /// Body: `{ "p_term": <string?>, "p_category_id": <string?>, "p_city": <string?>,
        /// "p_availability": <string?> }`. The RPC itself no-ops when every field is empty.
        public static let log = APIEndpoint.rpc("log_search")
        /// Body: `{ "p_limit": <int> }` → array of the most-searched terms (last 90 days).
        public static let popular = APIEndpoint.rpc("popular_searches")
    }

    public enum favorites {
        /// Body: `{ "p_place_id": "<uuid>" }` → `{ "is_favorited": <bool> }`.
        public static let toggle = APIEndpoint.rpc("toggle_favorite")
        /// No args → `PageDTO<PlaceDTO>` of the user's favorited places.
        public static let list = APIEndpoint.rpc("get_favorites")
    }

    public enum reviews {
        /// Body: `{ "p_place_id", "p_rating", "p_comment" }` → array of reviews.
        public static let add = APIEndpoint.rpc("add_review")
        /// Body: `{ "p_place_id" }` → array of reviews. Every review the place has; prefer
        /// `page` for anything user-facing.
        public static let list = APIEndpoint.rpc("get_reviews")
        /// Body: `{ "p_place_id", "p_limit", "p_offset", "p_sort" }` →
        /// `{ "items": [Review], "total": Int, "has_more": Bool }`.
        public static let page = APIEndpoint.rpc("get_reviews_page")
        /// Body: `{ "p_place_id" }` → deletes the caller's own review, returns the refreshed array.
        public static let delete = APIEndpoint.rpc("delete_my_review")
        /// Body: `{ "p_business_id" }` → array of reviews across the business's live places.
        public static let businessList = APIEndpoint.rpc("get_business_reviews")
        /// Body: `{ "p_review_id", "p_reaction" }` → `{ "review_id", "like_count", "dislike_count", "my_reaction" }`.
        public static let react = APIEndpoint.rpc("toggle_review_reaction")
    }

    public enum promotion {
        /// Body: `{ "p_place_id", "p_days" }` → the created request.
        public static let request = APIEndpoint.rpc("request_promotion")
    }

    public enum profile {
        /// No args → the signed-in user's profile.
        public static let get = APIEndpoint.rpc("get_profile")
        /// Body: `{ "p_display_name", "p_city", "p_avatar_url" }` → the updated profile.
        public static let update = APIEndpoint.rpc("update_profile")
    }

    public enum business {
        /// Body: `{ "p_id": "<uuid>" }` → a business profile + its live places.
        public static let get = APIEndpoint.rpc("get_business")
        /// No args → the caller's business (or null).
        public static let mine = APIEndpoint.rpc("get_my_business")
        /// Body: `{ "payload": { … } }` → the created/updated business.
        public static let upsert = APIEndpoint.rpc("upsert_business")
    }

    public enum notifications {
        /// Body: `{ "p_limit": <int> }` → array of the signed-in user's notifications, newest first.
        public static let list = APIEndpoint.rpc("get_notifications")
        /// Body: `{ "p_id": "<uuid>" }` → no content.
        public static let markRead = APIEndpoint.rpc("mark_notification_read")
        /// Body: `{ "p_id": "<uuid>" }` → no content. Records that the push itself was *tapped*,
        /// which `markRead` doesn't distinguish from opening the inbox list.
        public static let markOpened = APIEndpoint.rpc("mark_notification_opened")
        /// No args → no content.
        public static let markAllRead = APIEndpoint.rpc("mark_all_notifications_read")
        /// Body: `{ "p_id": "<uuid>" }` → no content. Removes one notification from the inbox.
        public static let delete = APIEndpoint.rpc("delete_notification")
        /// No args → no content. Clears the whole inbox.
        public static let deleteAll = APIEndpoint.rpc("delete_all_notifications")
        /// Body: `{ "p_token": "<fcm token>", "p_platform": "ios" }` → no content. Upserts by
        /// token, so re-registering an already-known token is a harmless no-op.
        public static let registerDeviceToken = APIEndpoint.rpc("register_device_token")
        /// Body: `{ "p_token": "<fcm token>" }` → no content. Called on sign-out.
        public static let unregisterDeviceToken = APIEndpoint.rpc("unregister_device_token")
    }

    public enum cms {
        /// Body: `{ "p_slug": "<string>", "p_locale": "en"|"ar" }` → the published page's json
        /// (server falls back to the English pair if the Arabic one isn't filled in yet), or
        /// SQL null if the slug doesn't exist or isn't published at all.
        public static let getPage = APIEndpoint.rpc("get_cms_page")
    }

    /// Supabase Storage. Object paths are namespaced by the uploader's user id.
    public enum storage {
        public static let placeImagesBucket = "place-images"

        /// Upload (create) an object. `objectPath` is `<uid>/<place>/<file>.jpg`.
        public static func uploadPlaceImage(objectPath: String) -> APIEndpoint {
            APIEndpoint(path: "/storage/v1/object/\(placeImagesBucket)/\(objectPath)", method: .post)
        }

        /// The public URL path for a stored object (bucket is public-read).
        public static func publicURLPath(objectPath: String) -> String {
            "/storage/v1/object/public/\(placeImagesBucket)/\(objectPath)"
        }
    }
}
