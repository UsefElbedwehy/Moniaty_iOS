import Foundation

/// In-memory bookings for running without a backend. One instance is shared by the bride and
/// provider shells, so a request made as a bride shows up in the provider inbox and vice versa.
/// It follows the same state machine as the server, without its permission checks.
public actor MockBookingRepository: BookingRepository {
    private struct Row {
        var summary: [String: Any]
        var status: BookingStatus
        var paymentMethods: [[String: Any]] = []
        var proposal: [String: Any]?
        var receipts: [[String: Any]] = []
        var events: [[String: Any]] = []
    }

    private var rows: [String: Row] = [:]
    private var methods: [String: PaymentMethodDraft] = [:]
    private var hours = Availability(
        rules: (0...6).map { Availability.Rule(weekday: $0, startTime: "10:00", endTime: "22:00") },
        daysOff: []
    )

    public init() {}

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    nonisolated(unsafe) private static let iso = ISO8601DateFormatter()

    private func json(_ row: Row) -> [String: Any] {
        var object = row.summary
        object["status"] = row.status.rawValue
        object["payment_methods"] = row.status == .requested || row.status == .rescheduleProposed ? [] : row.paymentMethods
        if let proposal = row.proposal { object["proposal"] = proposal }
        object["receipts"] = row.receipts
        object["events"] = row.events
        return object
    }

    private func decode<T: Decodable>(_ object: Any) throws -> T {
        try Self.decoder.decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func move(_ id: String, to status: BookingStatus, by role: String) {
        rows[id]?.status = status
        rows[id]?.summary["status_changed_at"] = Self.iso.string(from: .now)
        rows[id]?.events.append(["to_status": status.rawValue, "actor_role": role, "created_at": Self.iso.string(from: .now)])
    }

    public func availableSlots(serviceId: String, day: String) async throws -> [Date] {
        guard let date = DateFormatter.day.date(from: day) else { return [] }
        let calendar = Calendar(identifier: .gregorian)
        return stride(from: 10, through: 20, by: 2).compactMap {
            calendar.date(bySettingHour: $0, minute: 0, second: 0, of: date)
        }.filter { $0 > .now }
    }

    public func createBooking(serviceId: String, startsAt: Date, note: String?) async throws -> ActionResult {
        let id = UUID().uuidString
        let code = "MN-" + String(UUID().uuidString.prefix(5)).uppercased()
        rows[id] = Row(summary: [
            "id": id, "reference_code": code, "is_demo": false, "service_id": serviceId,
            "service_title": "مكياج العروس", "price": 2800,
            "starts_at": Self.iso.string(from: startsAt), "ends_at": Self.iso.string(from: startsAt.addingTimeInterval(3 * 3600)),
            "note": note ?? "", "status_changed_at": Self.iso.string(from: .now),
            "provider": ["id": "p-lamsa", "name": "لمسة جمال", "is_verified": true] as [String: Any], "bride_name": "نورة"
        ], status: .requested, events: [["to_status": "requested", "actor_role": "bride", "created_at": Self.iso.string(from: .now)]])
        return .ok(id: id)
    }

    public func respondToProposal(bookingId: String, accept: Bool) async throws -> ActionResult {
        if accept, let starts = rows[bookingId]?.proposal?["starts_at"] { rows[bookingId]?.summary["starts_at"] = starts }
        rows[bookingId]?.proposal = nil
        move(bookingId, to: accept ? .awaitingPayment : .cancelledByBride, by: "bride")
        if accept { snapshotMethods(bookingId) }
        return .ok(id: bookingId)
    }

    public func submitReceipt(bookingId: String, storagePath: String, amount: Decimal, transferredAt: Date,
                              senderBank: String?, sha256: String) async throws -> ActionResult {
        rows[bookingId]?.receipts.insert(["id": UUID().uuidString, "storage_path": storagePath,
                                          "amount": NSDecimalNumber(decimal: amount), "status": "pending",
                                          "sender_bank": senderBank ?? "", "created_at": Self.iso.string(from: .now)], at: 0)
        move(bookingId, to: .paymentSubmitted, by: "bride")
        return .ok(id: bookingId)
    }

    private func snapshotMethods(_ id: String) {
        rows[id]?.paymentMethods = methods.values.filter(\.isActive).map {
            ["kind": $0.kind, "label": $0.label, "account_name": $0.accountName, "value": $0.value]
        }
        if rows[id]?.paymentMethods.isEmpty == true {
            rows[id]?.paymentMethods = [["kind": "iban", "label": "مصرف الراجحي", "account_name": "لمسة جمال",
                                         "value": "SA0380000000608010167519"]]
        }
        rows[id]?.summary["payment_due_at"] = Self.iso.string(from: .now.addingTimeInterval(48 * 3600))
    }

    public func approve(bookingId: String) async throws -> ActionResult {
        move(bookingId, to: .awaitingPayment, by: "provider")
        snapshotMethods(bookingId)
        return .ok(id: bookingId)
    }

    public func decline(bookingId: String, reason: String?) async throws -> ActionResult {
        move(bookingId, to: .declined, by: "provider")
        return .ok(id: bookingId)
    }

    public func proposeReschedule(bookingId: String, startsAt: Date, note: String?) async throws -> ActionResult {
        rows[bookingId]?.proposal = ["id": UUID().uuidString, "starts_at": Self.iso.string(from: startsAt),
                                     "ends_at": Self.iso.string(from: startsAt.addingTimeInterval(3 * 3600)),
                                     "note": note ?? "", "expires_at": Self.iso.string(from: .now.addingTimeInterval(86400))]
        move(bookingId, to: .rescheduleProposed, by: "provider")
        return .ok(id: bookingId)
    }

    public func confirmPayment(bookingId: String) async throws -> ActionResult {
        move(bookingId, to: .paymentConfirmed, by: "provider")
        return .ok(id: bookingId)
    }

    public func rejectPayment(bookingId: String, reason: String) async throws -> ActionResult {
        move(bookingId, to: .awaitingPayment, by: "provider")
        return .ok(id: bookingId)
    }

    public func complete(bookingId: String) async throws -> ActionResult {
        move(bookingId, to: .completed, by: "provider")
        return .ok(id: bookingId)
    }

    public func cancel(bookingId: String, reason: String?) async throws -> ActionResult {
        move(bookingId, to: .cancelledByBride, by: "bride")
        return .ok(id: bookingId)
    }

    public func openDispute(bookingId: String, reason: DisputeReason, details: String?) async throws -> ActionResult {
        move(bookingId, to: .disputed, by: "bride")
        return .ok(id: bookingId)
    }

    public func bookings(active: Bool) async throws -> [BookingSummary] {
        try decode(rows.values.filter { $0.status.isActive == active }.map(json))
    }

    public func booking(id: String) async throws -> BookingDetail? {
        guard let row = rows[id] else { return nil }
        return try decode(json(row))
    }

    public func availability() async throws -> Availability { hours }

    public func saveAvailability(_ availability: Availability) async throws { hours = availability }

    public func paymentMethods() async throws -> [PaymentMethod] {
        try decode(methods.values.map { ["id": $0.id ?? "", "kind": $0.kind, "label": $0.label,
                                         "account_name": $0.accountName, "value": $0.value, "is_active": $0.isActive] })
    }

    public func savePaymentMethod(_ draft: PaymentMethodDraft) async throws -> ActionResult {
        if draft.kind == "iban", !draft.value.uppercased().hasPrefix("SA") { return .refused("invalid_iban") }
        var d = draft
        let id = d.id ?? UUID().uuidString
        d.id = id
        methods[id] = d
        return .ok(id: id)
    }

    public func deletePaymentMethod(id: String) async throws { methods[id] = nil }
}

extension DateFormatter {
    /// "yyyy-MM-dd" in the Gregorian calendar (what the slot RPC expects for a day).
    static var day: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Riyadh")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}
