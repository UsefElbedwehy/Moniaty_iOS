import Foundation
import Core
import Networking

public protocol BookingRepository: Sendable {
    // Bride
    func availableSlots(serviceId: String, day: String) async throws -> [Date]
    func createBooking(serviceId: String, startsAt: Date, note: String?) async throws -> ActionResult
    func respondToProposal(bookingId: String, accept: Bool) async throws -> ActionResult
    func submitReceipt(bookingId: String, storagePath: String, amount: Decimal, transferredAt: Date,
                       senderBank: String?, sha256: String) async throws -> ActionResult
    // Provider
    func approve(bookingId: String) async throws -> ActionResult
    func decline(bookingId: String, reason: String?) async throws -> ActionResult
    func proposeReschedule(bookingId: String, startsAt: Date, note: String?) async throws -> ActionResult
    func confirmPayment(bookingId: String) async throws -> ActionResult
    func rejectPayment(bookingId: String, reason: String) async throws -> ActionResult
    func complete(bookingId: String) async throws -> ActionResult
    // Either
    func cancel(bookingId: String, reason: String?) async throws -> ActionResult
    func openDispute(bookingId: String, reason: DisputeReason, details: String?) async throws -> ActionResult
    func bookings(active: Bool) async throws -> [BookingSummary]
    func booking(id: String) async throws -> BookingDetail?
    // Provider settings
    func availability() async throws -> Availability
    func saveAvailability(_ availability: Availability) async throws
    func paymentMethods() async throws -> [PaymentMethod]
    func savePaymentMethod(_ draft: PaymentMethodDraft) async throws -> ActionResult
    func deletePaymentMethod(id: String) async throws
}

/// Where receipt images live (private storage, readable only by the two parties and admins).
public protocol ReceiptStorage: Sendable {
    /// Uploads under `<bookingId>/` and returns the storage path for `submit_receipt`.
    func upload(jpeg: Data, bookingId: String) async throws -> String
    func download(path: String) async throws -> Data
}

/// Supabase RPCs from `supabase/migrations/20261012000000_booking.sql`.
public struct RemoteBookingRepository: BookingRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    private func act<Body: Encodable & Sendable>(_ rpc: String, _ body: Body) async throws -> ActionResult {
        let result: ResultDTO = try await client.send(.rpc(rpc), body: body)
        return result.ok ? .ok(id: result.id) : .refused(result.error ?? "unknown")
    }

    public func availableSlots(serviceId: String, day: String) async throws -> [Date] {
        try await client.send(.rpc("get_available_slots"), body: SlotsArgs(pServiceId: serviceId, pDay: day))
    }

    public func createBooking(serviceId: String, startsAt: Date, note: String?) async throws -> ActionResult {
        try await act("create_booking", CreateArgs(pServiceId: serviceId, pStartsAt: startsAt, pNote: note))
    }

    public func respondToProposal(bookingId: String, accept: Bool) async throws -> ActionResult {
        try await act("respond_to_proposal", RespondArgs(pBooking: bookingId, pAccept: accept))
    }

    public func submitReceipt(bookingId: String, storagePath: String, amount: Decimal, transferredAt: Date,
                              senderBank: String?, sha256: String) async throws -> ActionResult {
        try await act("submit_receipt", ReceiptArgs(pBooking: bookingId, pStoragePath: storagePath, pAmount: amount,
                                                    pTransferredAt: transferredAt, pSenderBank: senderBank, pSha256: sha256))
    }

    public func approve(bookingId: String) async throws -> ActionResult {
        try await act("approve_booking", BookingArgs(pBooking: bookingId))
    }

    public func decline(bookingId: String, reason: String?) async throws -> ActionResult {
        try await act("decline_booking", ReasonArgs(pBooking: bookingId, pReason: reason))
    }

    public func proposeReschedule(bookingId: String, startsAt: Date, note: String?) async throws -> ActionResult {
        try await act("propose_reschedule", ProposeArgs(pBooking: bookingId, pStartsAt: startsAt, pNote: note))
    }

    public func confirmPayment(bookingId: String) async throws -> ActionResult {
        try await act("confirm_payment", BookingArgs(pBooking: bookingId))
    }

    public func rejectPayment(bookingId: String, reason: String) async throws -> ActionResult {
        try await act("reject_payment", ReasonArgs(pBooking: bookingId, pReason: reason))
    }

    public func complete(bookingId: String) async throws -> ActionResult {
        try await act("complete_booking", BookingArgs(pBooking: bookingId))
    }

    public func cancel(bookingId: String, reason: String?) async throws -> ActionResult {
        try await act("cancel_booking", ReasonArgs(pBooking: bookingId, pReason: reason))
    }

    public func openDispute(bookingId: String, reason: DisputeReason, details: String?) async throws -> ActionResult {
        try await act("open_dispute", DisputeArgs(pBooking: bookingId, pReason: reason.rawValue, pDetails: details))
    }

    public func bookings(active: Bool) async throws -> [BookingSummary] {
        try await client.send(.rpc("get_my_bookings"), body: ScopeArgs(pScope: active ? "active" : "past"))
    }

    public func booking(id: String) async throws -> BookingDetail? {
        try await client.send(.rpc("get_booking"), body: BookingArgs(pBooking: id))
    }

    public func availability() async throws -> Availability {
        try await client.send(.rpc("get_my_availability"), body: NoArgs())
    }

    public func saveAvailability(_ availability: Availability) async throws {
        let _: Availability = try await client.send(.rpc("set_my_availability"),
                                                    body: AvailabilityArgs(pRules: availability.rules, pDaysOff: availability.daysOff))
    }

    public func paymentMethods() async throws -> [PaymentMethod] {
        try await client.send(.rpc("get_my_payment_methods"), body: NoArgs())
    }

    public func savePaymentMethod(_ d: PaymentMethodDraft) async throws -> ActionResult {
        try await act("upsert_my_payment_method", PaymentMethodArgs(
            pId: d.id, pKind: d.kind, pLabel: d.label, pAccountName: d.accountName, pValue: d.value, pIsActive: d.isActive))
    }

    public func deletePaymentMethod(id: String) async throws {
        let _: ResultDTO = try await client.send(.rpc("delete_my_payment_method"), body: IdArgs(pId: id))
    }
}

private struct ResultDTO: Decodable, Sendable {
    let ok: Bool
    let id: String?
    let error: String?
}

private struct NoArgs: Encodable, Sendable {}
private struct IdArgs: Encodable, Sendable { let pId: String }
private struct BookingArgs: Encodable, Sendable { let pBooking: String }
private struct ScopeArgs: Encodable, Sendable { let pScope: String }
private struct SlotsArgs: Encodable, Sendable { let pServiceId: String; let pDay: String }
private struct CreateArgs: Encodable, Sendable { let pServiceId: String; let pStartsAt: Date; let pNote: String? }
private struct RespondArgs: Encodable, Sendable { let pBooking: String; let pAccept: Bool }
private struct ReasonArgs: Encodable, Sendable { let pBooking: String; let pReason: String? }
private struct ProposeArgs: Encodable, Sendable { let pBooking: String; let pStartsAt: Date; let pNote: String? }
private struct DisputeArgs: Encodable, Sendable { let pBooking: String; let pReason: String; let pDetails: String? }
private struct ReceiptArgs: Encodable, Sendable {
    let pBooking: String
    let pStoragePath: String
    let pAmount: Decimal
    let pTransferredAt: Date
    let pSenderBank: String?
    let pSha256: String
}
private struct AvailabilityArgs: Encodable, Sendable { let pRules: [Availability.Rule]; let pDaysOff: [String] }
private struct PaymentMethodArgs: Encodable, Sendable {
    let pId: String?
    let pKind: String
    let pLabel: String
    let pAccountName: String
    let pValue: String
    let pIsActive: Bool

    // p_id has no SQL default, so send it even when nil (a new method).
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pId, forKey: .pId)
        try c.encode(pKind, forKey: .pKind)
        try c.encode(pLabel, forKey: .pLabel)
        try c.encode(pAccountName, forKey: .pAccountName)
        try c.encode(pValue, forKey: .pValue)
        try c.encode(pIsActive, forKey: .pIsActive)
    }

    private enum CodingKeys: String, CodingKey { case pId, pKind, pLabel, pAccountName, pValue, pIsActive }
}
