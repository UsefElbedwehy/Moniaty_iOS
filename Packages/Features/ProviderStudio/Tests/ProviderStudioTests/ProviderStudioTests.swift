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
}
