package co.munyati.networking

/**
 * A concrete, resolved API endpoint: a path, an HTTP method, and optional query items.
 *
 * The rest of the app never hardcodes a URL path or knows about REST/Supabase details — it only
 * ever writes something like `ApiEndpoint.Catalog.cities` and hands that to an [ApiClient]. This is
 * the single module that encodes how the backend is shaped.
 *
 * Current backend: **Supabase**. The base URL is the project root; each path carries its service
 * prefix (`/rest/v1`, `/auth/v1`, `/storage/v1`, `/functions/v1`). Mirrors the iOS `APIEndpoint`.
 */
data class ApiEndpoint(
    val path: String,
    val method: HttpMethod,
    val queryItems: List<Pair<String, String>> = emptyList(),
) {
    enum class HttpMethod { GET, POST, PUT, PATCH, DELETE }

    companion object {
        /** A Supabase Postgres RPC call (always POST `/rest/v1/rpc/<name>`, arguments as the JSON body). */
        fun rpc(name: String) = ApiEndpoint("/rest/v1/rpc/$name", HttpMethod.POST)

        /** A Supabase Edge Function call (always POST `/functions/v1/<name>`). */
        fun function(name: String) = ApiEndpoint("/functions/v1/$name", HttpMethod.POST)
    }

    /** Supabase Auth (GoTrue) and the OTP edge functions. */
    object Authentication {
        /** Anonymous sign-in — returns a real session so guests have a stable identity. */
        val signUpAnonymous = ApiEndpoint("/auth/v1/signup", HttpMethod.POST)
        /** Request a phone OTP, delivered by the `send-otp` edge function (OurSMS). */
        val sendOtp = function("send-otp")
        /** Verify a phone OTP (or register a new number), returning a session. */
        val verifyOtp = function("verify-otp")
        /** Exchange a still-valid refresh token for a new session. */
        val refreshToken = ApiEndpoint("/auth/v1/token", HttpMethod.POST, listOf("grant_type" to "refresh_token"))
    }

    object Configuration {
        val get = rpc("get_config")
        /** Remote string overrides (`app_strings`). */
        val strings = rpc("get_app_strings")
    }

    object Catalog {
        val cities = rpc("get_cities")
        val categories = rpc("get_categories")
    }

    object Analytics {
        val record = rpc("record_analytics_event")
        val logError = rpc("log_client_error")
    }

    object Profile {
        val get = rpc("get_my_profile")
        val update = rpc("update_my_profile")
        val setCities = rpc("set_my_cities")
        val setAudience = rpc("set_my_audience")
    }

    object Notifications {
        val list = rpc("get_notifications")
        val markRead = rpc("mark_notification_read")
        val markOpened = rpc("mark_notification_opened")
        val markAllRead = rpc("mark_all_notifications_read")
        val delete = rpc("delete_notification")
        val deleteAll = rpc("delete_all_notifications")
        val registerDeviceToken = rpc("register_device_token")
        val unregisterDeviceToken = rpc("unregister_device_token")
    }

    object Cms {
        val getPage = rpc("get_cms_page")
    }
}
