import SwiftUI
import Observation
import Core
import DesignSystem
import Shared
import Catalog

/// Public entry point of the Booking feature (Phase 3): requests, the booking lifecycle for both
/// roles, receipts, disputes, and the provider's availability and payment methods.
@MainActor
public final class BookingFeature {
    let repository: BookingRepository
    let receipts: ReceiptStorage
    /// The bride's remaining budget, for the "after this booking" hint.
    let remainingBudget: () -> Decimal?
    /// Called after anything that changes the budget (approval, cancellation…).
    let onBookingsChanged: () -> Void
    /// Review, report/block and help from the Trust feature (Phase 5).
    var trustViews: BookingTrustViews?

    public init(repository: BookingRepository, receipts: ReceiptStorage,
                remainingBudget: @escaping () -> Decimal?, onBookingsChanged: @escaping () -> Void) {
        self.repository = repository
        self.receipts = receipts
        self.remainingBudget = remainingBudget
        self.onBookingsChanged = onBookingsChanged
    }

    /// How many bookings are in progress, for Profile's stats (nil when it can't load).
    public func activeBookingsCount() async -> Int? {
        try? await repository.bookings(active: true).count
    }

    public func setTrustViews(_ views: BookingTrustViews) {
        trustViews = views
    }

    /// The bride's "My bookings" or the provider's bookings inbox.
    public func bookingsScreen(role: BookingRole) -> some View {
        BookingsListScreen(feature: self, role: role)
    }

    /// The request sheet's content; `onCreated` receives the new booking id.
    public func requestScreen(for service: BookableService, onCreated: @escaping (String) -> Void) -> some View {
        BookingRequestScreenView(feature: self, service: service, onCreated: onCreated)
    }

    @ViewBuilder
    public func destination(for route: BookingRoute, role: BookingRole) -> some View {
        switch route {
        case .detail(let id): BookingDetailScreen(feature: self, bookingId: id, role: role)
        case .availability: AvailabilityScreen(feature: self)
        case .paymentMethods: PaymentMethodsScreen(feature: self)
        }
    }
}

/// Localization for the Booking module.
enum BookingL10n {
    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }

    static func text(_ key: String) -> Text { Text(verbatim: string(key)) }

    static func key(_ key: String) -> LocalizedStringKey { LocalizedStringKey("\(string(key))") }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        // The current locale: Arabic-Indic digits in Arabic, and plural rules from .stringsdict.
        String(format: string(key), locale: .current, arguments: args)
    }

    /// Server refusal codes → user-facing text.
    static func refusal(_ code: String) -> String {
        let key = "error.\(code)"
        let value = string(key)
        return value == key ? string("error.generic") : value
    }
}

func appError(_ error: Error) -> AppError {
    (error as? AppError) ?? .unknown(message: error.localizedDescription)
}

/// "الثلاثاء ١١ نوفمبر · ٤:٠٠ م" in the user's language, Riyadh time.
func bookingDateText(_ date: Date) -> String {
    let day = date.displayFormatted(.dateTime.weekday(.wide).day().month(.wide).locale(.current))
    let time = date.displayFormatted(.dateTime.hour().minute().locale(.current))
    return "\(day) · \(time)"
}
