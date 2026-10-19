package co.munyati.app.composition

import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * Every place the app can be opened to from outside: a notification tap, an App Link on
 * `munyati.co`, or the `munyati://` scheme (`docs/PLAN.md` §4.12). One parser serves all three,
 * with the same URL shapes as iOS `DeepLink`:
 *   https://munyati.co/p/<id>  provider      munyati://p/<id>
 *   https://munyati.co/s/<id>  service
 *   https://munyati.co/store/<id>  store
 *   https://munyati.co/c/<id>  category
 *   https://munyati.co/b/<id>  booking (signed-in parties only)
 *   https://munyati.co/plans   provider plans
 *   https://munyati.co/notifications
 */
sealed interface DeepLink {
    data class Provider(val id: String) : DeepLink
    data class Service(val id: String) : DeepLink
    data class Store(val id: String) : DeepLink
    data class Category(val id: String) : DeepLink
    data class Booking(val id: String) : DeepLink
    data object Plans : DeepLink
    data object Notifications : DeepLink

    /** The shareable web link for this destination. */
    val webUrl: String
        get() = "https://munyati.co/" + when (this) {
            is Provider -> "p/$id"
            is Service -> "s/$id"
            is Store -> "store/$id"
            is Category -> "c/$id"
            is Booking -> "b/$id"
            Plans -> "plans"
            Notifications -> "notifications"
        }

    companion object {
        val webHosts = setOf("munyati.co", "www.munyati.co")
        const val SCHEME = "munyati"

        /** Parses a link from its parts (scheme, host, path segments); pure, so it's unit-testable. */
        fun parse(scheme: String?, host: String?, pathSegments: List<String>): DeepLink? {
            val parts: List<String> = when {
                scheme == SCHEME -> listOfNotNull(host) + pathSegments // munyati://p/123 → host "p"
                scheme == "https" && host?.lowercase() in webHosts -> pathSegments
                else -> return null
            }.filter { it.isNotEmpty() }
            val head = parts.firstOrNull()?.lowercase() ?: return null
            val id = parts.getOrNull(1)
            return when {
                head == "p" && id != null -> Provider(id)
                head == "s" && id != null -> Service(id)
                head == "store" && id != null -> Store(id)
                head == "c" && id != null -> Category(id)
                head == "b" && id != null -> Booking(id)
                head == "plans" -> Plans
                head == "notifications" -> Notifications
                else -> null
            }
        }

        fun from(uri: Uri?): DeepLink? = uri?.let { parse(it.scheme, it.host, it.pathSegments) }

        fun from(string: String?): DeepLink? = string?.let { from(Uri.parse(it)) }
    }
}

/** Holds the deep link waiting to be shown. The tab shells consume it and clear it. */
class DeepLinkStore {
    var pending: DeepLink? by mutableStateOf(null)
}
