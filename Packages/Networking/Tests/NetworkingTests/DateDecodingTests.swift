import Foundation
import Testing
@testable import Networking

@Suite("Postgres timestamp decoding")
struct DateDecodingTests {
    private struct Box: Decodable { let at: Date }

    private func decode(_ value: String) throws -> Date {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(URLSessionAPIClient.decodePostgresDate)
        return try decoder.decode(Box.self, from: Data("{\"at\":\"\(value)\"}".utf8)).at
    }

    @Test("accepts timestamps with and without fractional seconds")
    func acceptsBoth() throws {
        let whole = try decode("2026-10-13T15:00:00+00:00")
        let fractional = try decode("2026-10-13T15:00:00.123456+00:00")
        #expect(abs(fractional.timeIntervalSince(whole) - 0.123) < 0.001)
    }
}
