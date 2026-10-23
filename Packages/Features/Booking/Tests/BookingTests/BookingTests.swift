import Testing
import Foundation
@testable import Booking

@Suite("Booking models and the mock lifecycle")
struct BookingTests {
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    @Test("status raw values match the Postgres enum, and only open statuses are active")
    func statuses() {
        #expect(BookingStatus(rawValue: "reschedule_proposed") == .rescheduleProposed)
        #expect(BookingStatus(rawValue: "cancelled_by_provider") == .cancelledByProvider)
        #expect(BookingStatus.paymentConfirmed.isActive)
        #expect(BookingStatus.disputed.isActive)
        #expect(!BookingStatus.completed.isActive)
        #expect(!BookingStatus.expired.isActive)
        #expect(BookingStatus.completed.step == 5)
        #expect(BookingStatus.declined.step == 0)
    }

    @Test("a booking detail decodes from get_booking's flat JSON")
    func detailDecoding() throws {
        let json = """
        {"id":"b1","reference_code":"MN-7K2Q9","status":"awaiting_payment","is_demo":false,
         "service_id":"s1","service_title":"مكياج العروس","category_id":"makeup","price":2800,
         "starts_at":"2026-11-11T13:00:00Z","ends_at":"2026-11-11T16:00:00Z","note":null,
         "payment_due_at":"2026-11-01T10:00:00Z","status_changed_at":"2026-10-30T10:00:00Z",
         "provider":{"id":"p1","name":"لمسة جمال","logo_url":null,"is_verified":true},"bride_name":"ن***",
         "payment_methods":[{"kind":"iban","label":"الراجحي","account_name":"لمسة","value":"SA0380000000608010167519"}],
         "receipts":[],"events":[{"to_status":"requested","actor_role":"bride","note":null,"created_at":"2026-10-30T09:00:00Z"}]}
        """
        let detail = try decoder().decode(BookingDetail.self, from: Data(json.utf8))
        #expect(detail.summary.status == .awaitingPayment)
        #expect(detail.summary.price == 2800)
        #expect(detail.paymentMethods.first?.kind == "iban")
        #expect(detail.proposal == nil)
        #expect(detail.events.count == 1)
    }

    @Test("payment method drafts need a label, a name and a value")
    func draftValidation() {
        var draft = PaymentMethodDraft()
        #expect(!draft.isValid)
        draft.label = "الراجحي"
        draft.accountName = "لمسة جمال"
        draft.value = "SA0380000000608010167519"
        #expect(draft.isValid)
    }

    @Test("the mock walks a booking from request to completion")
    func mockLifecycle() async throws {
        let repo = MockBookingRepository()
        let created = try await repo.createBooking(serviceId: "s1", startsAt: .now.addingTimeInterval(86400 * 3), note: nil)
        guard case .ok(let id?) = created else { Issue.record("no id"); return }

        #expect(try await repo.booking(id: id)?.summary.status == .requested)
        #expect(try await repo.booking(id: id)?.paymentMethods.isEmpty == true)

        _ = try await repo.approve(bookingId: id)
        let approved = try #require(try await repo.booking(id: id))
        #expect(approved.summary.status == .awaitingPayment)
        #expect(!approved.paymentMethods.isEmpty)
        #expect(approved.summary.paymentDueAt != nil)

        _ = try await repo.submitReceipt(bookingId: id, storagePath: "\(id)/r.jpg", amount: 2800,
                                         transferredAt: .now, senderBank: nil, sha256: "abc")
        #expect(try await repo.booking(id: id)?.receipts.count == 1)
        _ = try await repo.confirmPayment(bookingId: id)
        _ = try await repo.complete(bookingId: id)

        #expect(try await repo.bookings(active: true).isEmpty)
        #expect(try await repo.bookings(active: false).first?.status == .completed)
    }

    @Test("the mock refuses a non-Saudi IBAN")
    func mockIban() async throws {
        let repo = MockBookingRepository()
        var draft = PaymentMethodDraft()
        draft.label = "Bank"
        draft.accountName = "Name"
        draft.value = "GB29NWBK60161331926819"
        #expect(try await repo.savePaymentMethod(draft) == .refused("invalid_iban"))
    }
}
