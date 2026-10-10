import Testing
import Foundation
@testable import ProviderStudio

@Suite("Provider studio drafts and limits")
struct ProviderStudioTests {
    @Test("price accepts Arabic and Latin digits and the Arabic decimal separator")
    func priceParsing() {
        var draft = ServiceDraft()
        draft.priceText = "٢٨٠٠"
        #expect(draft.price == 2800)
        draft.priceText = "1500.5"
        #expect(draft.price == Decimal(string: "1500.5"))
        draft.priceText = "٩٩٫٥"
        #expect(draft.price == Decimal(string: "99.5"))
        draft.priceText = ""
        #expect(draft.price == nil)
    }

    @Test("a service draft needs a title, a category and a price")
    func serviceValidation() {
        var draft = ServiceDraft()
        #expect(!draft.isValid)
        draft.title = "مكياج العروس"
        draft.categoryId = "makeup"
        draft.priceText = "2800"
        #expect(draft.isValid)
    }

    @Test("the mock refuses an active service above the limit, but accepts it paused")
    func serviceLimit() async throws {
        let repo = MockStudioRepository()
        var draft = ServiceDraft()
        draft.title = "خدمة"
        draft.categoryId = "makeup"
        draft.priceText = "100"
        for _ in 0..<10 {
            draft.id = nil
            guard case .saved = try await repo.saveService(draft) else { Issue.record("expected save"); return }
        }
        draft.id = nil
        #expect(try await repo.saveService(draft) == .limitReached(max: 10))
        draft.isActive = false
        guard case .saved = try await repo.saveService(draft) else { Issue.record("paused should save"); return }
        let business = try await repo.business()
        #expect(business.services.count == 11)
        #expect(business.activeServiceCount == 10)
    }

    @Test("the subscription overview decodes from get_my_subscription's JSON")
    func subscriptionDecoding() throws {
        let json = """
        {"entitlement":{"state":"trial","plan_id":"diamond","source":null,"trial_ends_at":"2026-12-09T10:00:00.123+00:00",
          "period_ends_at":null,"paid_until":"2027-01-09T10:00:00+00:00","next_plan_id":"plus",
          "next_starts_at":"2026-12-09T10:00:00+00:00","is_listed":true},
         "limits":{"plan_id":"diamond","max_services":10,"max_stores":3,"max_photos":30},
         "usage":{"active_services":2,"active_stores":0},
         "plans":[{"id":"plus","name_ar":"بلس","name_en":"Plus","description_ar":null,"description_en":null,
           "features_ar":["٣ خدمات"],"features_en":["3 services"],"price_sar":249,"period_months":1,"max_services":3,
           "max_stores":1,"max_photos":15,"is_featured":false,"insights_level":"full","rank":2,"is_recommended":true}],
         "payments":[]}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: text) ?? .distantPast
        }
        let overview = try decoder.decode(SubscriptionOverview.self, from: Data(json.utf8))
        #expect(overview.entitlement.state == .trial)
        #expect(overview.nextPlan?.id == "plus")
        // On trial with a plan queued, the listing runs until the paid time ends.
        #expect(overview.entitlement.listedUntil == overview.entitlement.paidUntil)
        #expect(overview.plans.first?.priceSar == 249)
    }

    @Test("a mock payment for a smaller plan pauses the services above its limit")
    func mockDowngradePauses() async throws {
        let repo = MockStudioRepository()
        var draft = ServiceDraft()
        draft.title = "خدمة"
        draft.categoryId = "makeup"
        draft.priceText = "100"
        for _ in 0..<3 {
            draft.id = nil
            _ = try await repo.saveService(draft)
        }
        let checkout = MockPlanCheckout(repository: repo)
        guard case .completed(let paymentId) = try await checkout.start(planId: "normal") else {
            Issue.record("expected an immediate mock payment"); return
        }
        #expect(try await checkout.status(paymentId: paymentId) == .captured)
        let business = try await repo.business()
        #expect(business.activeServiceCount == 1)
        #expect(business.limits.maxServices == 1)
        let overview = try await repo.subscription()
        #expect(overview.payments.count == 1)
        #expect(overview.limits.planId == "normal")
    }
}
