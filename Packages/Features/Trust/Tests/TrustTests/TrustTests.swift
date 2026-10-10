import Testing
import Foundation
@testable import Trust

@Suite("Trust models and mock")
struct TrustTests {
    @Test("a reviews page decodes the server's masked names and distribution")
    func decodePage() throws {
        let json = """
        {"rating_avg":4.5,"rating_count":2,"distribution":{"1":0,"2":0,"3":0,"4":1,"5":1},
         "items":[{"id":"r1","rating":5,"body":"رائعة","photo_urls":[],"author_name":"نو**** مح****","is_mine":false,
                   "service_title":"مكياج","provider_reply":null,"status":"approved","created_at":"2026-10-01T10:00:00Z"}]}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let page = try decoder.decode(ReviewsPage.self, from: Data(json.utf8))
        #expect(page.ratingCount == 2)
        #expect(page.distribution["5"] == 1)
        #expect(page.items.first?.authorName == "نو**** مح****")
    }

    @Test("report targets map to the SQL enum")
    func targets() {
        #expect(ReportTarget.provider("p").type == "provider")
        #expect(ReportTarget.review("r").id == "r")
    }

    @Test("the mock allows one review per booking and lists blocks")
    func mockFlow() async throws {
        let repo = MockTrustRepository()
        #expect(try await repo.myReview(bookingId: "b1")?.canReview == true)
        #expect(try await repo.submitReview(bookingId: "b1", rating: 5, body: nil, photoUrls: []) == .ok)
        #expect(try await repo.submitReview(bookingId: "b1", rating: 4, body: nil, photoUrls: []) == .refused("already_reviewed"))
        try await repo.block(userId: "u1")
        #expect(try await repo.blockedUsers().count == 1)
        try await repo.unblock(userId: "u1")
        #expect(try await repo.blockedUsers().isEmpty)
    }
}
