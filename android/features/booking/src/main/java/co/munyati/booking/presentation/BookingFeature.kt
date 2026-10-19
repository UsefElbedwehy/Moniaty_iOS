package co.munyati.booking.presentation

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import co.munyati.booking.R
import co.munyati.booking.data.BookingRepository
import co.munyati.booking.data.ReceiptStorage
import co.munyati.booking.domain.BookableService
import co.munyati.booking.domain.BookingRole
import co.munyati.catalog.domain.formatAmount
import co.munyati.core.dates.DisplayDates
import kotlinx.serialization.Serializable
import java.time.Instant

// Destinations inside the booking feature, registered on the App's NavHosts (iOS `BookingRoute`
// plus the screens iOS presents as sheets).
@Serializable data class BookingDetailRoute(val id: String, val role: String)
@Serializable data class BookingRequestRoute(val serviceId: String, val title: String, val price: Double, val providerName: String? = null)
@Serializable data class BookingPaymentRoute(val id: String)
@Serializable data object AvailabilityRoute
@Serializable data object PaymentMethodsRoute
@Serializable data class PaymentMethodEditRoute(val id: String? = null)

/** Views supplied by the App from the Trust feature, so Booking doesn't depend on it. */
class BookingTrustViews(
    val review: @Composable (bookingId: String, role: BookingRole) -> Unit,
    val moreMenu: @Composable (bookingId: String) -> Unit,
    val helpSheet: @Composable (bookingId: String, onDismiss: () -> Unit) -> Unit,
)

/**
 * Public entry point of the Booking feature: requests, the booking lifecycle for both roles,
 * receipts, disputes, and the provider's availability and payment methods.
 */
class BookingFeature(
    internal val repository: BookingRepository,
    internal val receipts: ReceiptStorage,
    /** The bride's remaining budget, for the "after this booking" hint. */
    internal val remainingBudget: () -> Double?,
    /** Called after anything that changes the budget (approval, cancellation…). */
    internal val onBookingsChanged: () -> Unit,
    /** A new request was sent: the App opens it in the Bookings tab. */
    internal val onBookingCreated: (String) -> Unit,
) {
    internal var trustViews: BookingTrustViews? = null

    fun setTrustViews(views: BookingTrustViews) {
        trustViews = views
    }

    /** The bride's "My bookings" or the provider's bookings inbox. */
    @Composable
    fun BookingsScreen(role: BookingRole) = BookingsListScreen(this, role)

    fun requestRoute(service: BookableService) = BookingRequestRoute(service.id, service.title, service.price, service.providerName)

    fun detailRoute(id: String, role: BookingRole) = BookingDetailRoute(id, role.rawValue)

    /** Registers the booking screens on a tab's NavHost. */
    fun NavGraphBuilder.destinations() {
        composable<BookingDetailRoute> {
            val route = it.toRoute<BookingDetailRoute>()
            BookingDetailScreen(this@BookingFeature, route.id, if (route.role == "provider") BookingRole.Provider else BookingRole.Bride)
        }
        composable<BookingRequestRoute> {
            val r = it.toRoute<BookingRequestRoute>()
            BookingRequestScreen(this@BookingFeature, BookableService(r.serviceId, r.title, r.price, r.providerName))
        }
        composable<BookingPaymentRoute> { PaymentLoaderScreen(this@BookingFeature, it.toRoute<BookingPaymentRoute>().id) }
        composable<AvailabilityRoute> { AvailabilityScreen(this@BookingFeature) }
        composable<PaymentMethodsRoute> { PaymentMethodsScreen(this@BookingFeature) }
        composable<PaymentMethodEditRoute> { PaymentMethodEditor(this@BookingFeature, it.toRoute<PaymentMethodEditRoute>().id) }
    }
}

/** A Booking string by its iOS key (keys built at run time, like "status.\(raw)"). */
@Composable
internal fun bookingString(key: String, vararg args: Any): String {
    val id = bookingKeys[key] ?: return key
    return stringResource(id, *args)
}

/** Server refusal codes → user-facing text (falls back to the generic error). */
internal fun refusal(context: Context, code: String): String =
    context.getString(bookingKeys["error.$code"] ?: R.string.booking_error_generic)

/** "SAR 2,800" with the catalog's price format. */
@Composable
internal fun formatSar(amount: Double) = stringResource(co.munyati.catalog.R.string.catalog_price_sar, formatAmount(amount))

/** "الثلاثاء ١١ نوفمبر · ٤:٠٠ م" in the user's language and the display calendar. */
internal fun bookingDateText(instant: Instant): String =
    DisplayDates.pattern(instant, "EEEEdMMMM") + " · " + DisplayDates.pattern(instant, "jmm")

internal fun Context.copyToClipboard(text: String) {
    (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText(text, text))
}
