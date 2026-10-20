package co.munyati.app.composition

import co.munyati.booking.domain.BookingRole
import co.munyati.booking.presentation.BookingFeature
import co.munyati.booking.presentation.BookingTrustViews
import co.munyati.catalog.presentation.CatalogContentRef
import co.munyati.catalog.presentation.CatalogFeature
import co.munyati.catalog.presentation.CatalogTrustViews
import co.munyati.trust.domain.ReportTarget
import co.munyati.trust.domain.ReviewRole
import co.munyati.trust.presentation.TrustFeature

/**
 * Hands Catalog and Booking their Trust views (reviews, the report/block menu, booking help), so
 * neither depends on the Trust module — the same hooks as iOS. Kept out of `AppEnvironment.init`:
 * composable lambdas built inside a class initializer trip the Compose compiler.
 */
internal fun connectTrustViews(trust: TrustFeature, catalog: CatalogFeature, booking: BookingFeature) {
    catalog.setTrustViews(CatalogTrustViews(
        reviews = { providerId -> trust.ReviewsSection(providerId) },
        moreMenu = { ref ->
            when (ref) {
                // A provider's id is also their account id, so it can be blocked directly.
                is CatalogContentRef.Provider -> trust.MoreMenu(ReportTarget.Provider(ref.id), blockUserId = ref.id)
                is CatalogContentRef.Service -> trust.MoreMenu(ReportTarget.Service(ref.id))
                is CatalogContentRef.Store -> trust.MoreMenu(ReportTarget.Store(ref.id))
            }
        },
    ))
    booking.setTrustViews(BookingTrustViews(
        review = { id, role -> trust.BookingReviewSection(id, if (role == BookingRole.Provider) ReviewRole.Provider else ReviewRole.Bride) },
        moreMenu = { id -> trust.MoreMenu(ReportTarget.Booking(id), blockBookingId = id) },
        helpSheet = { id, onDismiss -> trust.TicketSheet(id, onDismiss) },
    ))
}
