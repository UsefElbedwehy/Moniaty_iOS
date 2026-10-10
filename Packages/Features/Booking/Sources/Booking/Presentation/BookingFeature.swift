import SwiftUI
import Observation
import Core
import DesignSystem
import Shared
import Catalog

/// Destinations inside the booking feature (registered on the App's NavigationStacks).
public enum BookingRoute: Hashable, Sendable {
    case detail(id: String)
    case availability
    case paymentMethods
}

/// What a booking request needs to know about the service (from the catalog card).
public struct BookableService: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let price: Decimal
    public let providerName: String?

    public init(id: String, title: String, price: Decimal, providerName: String?) {
        self.id = id
        self.title = title
        self.price = price
        self.providerName = providerName
    }
}

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

    public init(repository: BookingRepository, receipts: ReceiptStorage,
                remainingBudget: @escaping () -> Decimal?, onBookingsChanged: @escaping () -> Void) {
        self.repository = repository
        self.receipts = receipts
        self.remainingBudget = remainingBudget
        self.onBookingsChanged = onBookingsChanged
    }

    /// The bride's "My bookings" or the provider's bookings inbox.
    public func bookingsScreen(role: BookingRole) -> some View {
        BookingsListScreen(feature: self, role: role)
    }

    /// The request sheet's content; `onCreated` receives the new booking id.
    public func requestScreen(for service: BookableService, onCreated: @escaping (String) -> Void) -> some View {
        BookingRequestScreen(feature: self, service: service, onCreated: onCreated)
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
        String(format: string(key), arguments: args)
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
    let day = date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.current))
    let time = date.formatted(.dateTime.hour().minute().locale(.current))
    return "\(day) · \(time)"
}

// MARK: - Request (mockup 4)

struct BookingRequestScreen: View {
    let feature: BookingFeature
    let service: BookableService
    let onCreated: (String) -> Void

    @State private var day = Calendar.current.startOfDay(for: .now)
    @State private var slots: ViewState<[Date]> = .loading
    @State private var selected: Date?
    @State private var note = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analytics) private var analytics

    private var days: [Date] {
        (0..<21).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: .now)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                DSCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: service.title).font(.dsHeadline)
                            Text(verbatim: service.providerName ?? "").font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                        }
                        Spacer()
                        Text(verbatim: formatSAR(service.price)).font(.dsHeadline).foregroundStyle(Color.dsPrimary)
                    }
                }

                BookingL10n.text("request.day").font(.dsHeadline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSSpacing.xs) {
                        ForEach(days, id: \.self) { d in
                            let isOn = Calendar.current.isDate(d, inSameDayAs: day)
                            Button { day = d; selected = nil } label: {
                                VStack(spacing: 2) {
                                    Text(verbatim: d.formatted(.dateTime.weekday(.abbreviated))).font(.dsCaption)
                                    Text(verbatim: d.formatted(.dateTime.day())).font(.dsTitle2)
                                }
                                .frame(width: 56, height: 64)
                                .foregroundStyle(isOn ? Color.dsBackground : Color.dsTextPrimary)
                                .background(RoundedRectangle(cornerRadius: 16).fill(isOn ? Color.dsPrimary : Color.dsSurface))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isOn ? Color.clear : Color.dsBorder))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                }

                BookingL10n.text("request.time").font(.dsHeadline)
                switch slots {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity)
                case .loaded(let list) where !list.isEmpty:
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DSSpacing.xs), count: 4), spacing: DSSpacing.xs) {
                        ForEach(list, id: \.self) { slot in
                            let isOn = selected == slot
                            Button { selected = slot } label: {
                                Text(verbatim: slot.formatted(.dateTime.hour().minute()))
                                    .font(.dsSubhead)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(isOn ? Color.dsBackground : Color.dsTextPrimary)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(isOn ? Color.dsTextPrimary : Color.dsSurface))
                                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isOn ? Color.clear : Color.dsBorder))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                case .error(let error):
                    ErrorStateView(error: error) { Task { await loadSlots() } }
                default:
                    BookingL10n.text("request.noSlots").font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                }

                TextField(BookingL10n.string("request.note"), text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(DSSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.dsSurface))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.dsBorder))

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    if let remaining = feature.remainingBudget() {
                        Text(verbatim: BookingL10n.format("request.budgetAfter", formatSAR(remaining - service.price)))
                            .font(.dsSubhead)
                    }
                    BookingL10n.text("request.paymentInfo").font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                }
                .padding(DSSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsPrimaryMuted))
            }
            .padding(DSSpacing.lg)
        }
        .dsScreenBackground()
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(BookingL10n.key("request.send"), isLoading: isSending, isEnabled: selected != nil) { send() }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.vertical, DSSpacing.sm)
                .background(.bar)
        }
        .navigationTitle(BookingL10n.string("request.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(BookingL10n.string("common.cancel")) { dismiss() }
            }
        }
        .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(BookingL10n.string("common.ok"), role: .cancel) {}
        }
        .task(id: day) { await loadSlots() }
        .trackScreen("booking_request")
    }

    private func loadSlots() async {
        slots = .loading
        do {
            let list = try await feature.repository.availableSlots(serviceId: service.id, day: DateFormatter.day.string(from: day))
            slots = list.isEmpty ? .empty : .loaded(list)
        } catch {
            slots = .error(appError(error))
        }
    }

    private func send() {
        guard let selected else { return }
        isSending = true
        Task {
            defer { isSending = false }
            do {
                switch try await feature.repository.createBooking(serviceId: service.id, startsAt: selected,
                                                                  note: note.isEmpty ? nil : note) {
                case .ok(let id):
                    analytics(.bookingSubmitted, service.id)
                    feature.onBookingsChanged()
                    dismiss()
                    if let id { onCreated(id) }
                case .refused(let code):
                    errorMessage = BookingL10n.refusal(code)
                    if code == "slot_unavailable" { await loadSlots() }
                }
            } catch {
                errorMessage = BookingL10n.string("error.generic")
            }
        }
    }
}
