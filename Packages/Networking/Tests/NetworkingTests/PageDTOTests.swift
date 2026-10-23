import Foundation
import Testing
@testable import Networking

private struct FixtureItem: Decodable, Sendable, Equatable {
    let id: String
    let name: String
}

@Suite("PageDTO")
struct PageDTOTests {
    @Test("decodes a JSON fixture with items, nextCursor, and hasMore")
    func decodesFixture() throws {
        let json = """
        {
            "items": [
                { "id": "1", "name": "First" },
                { "id": "2", "name": "Second" }
            ],
            "next_cursor": "cursor-123",
            "has_more": true
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let page = try decoder.decode(PageDTO<FixtureItem>.self, from: json)

        #expect(page.items == [FixtureItem(id: "1", name: "First"), FixtureItem(id: "2", name: "Second")])
        #expect(page.nextCursor == "cursor-123")
        #expect(page.hasMore == true)
    }

    @Test("decodes a fixture with a null nextCursor and no more pages")
    func decodesLastPage() throws {
        let json = """
        {
            "items": [],
            "next_cursor": null,
            "has_more": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let page = try decoder.decode(PageDTO<FixtureItem>.self, from: json)

        #expect(page.items.isEmpty)
        #expect(page.nextCursor == nil)
        #expect(page.hasMore == false)
    }
}
