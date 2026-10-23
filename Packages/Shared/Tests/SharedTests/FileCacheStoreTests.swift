import Testing
import Foundation
@testable import Shared

@Suite("FileCacheStore")
struct FileCacheStoreTests {
    private struct Fixture: Codable, Sendable, Equatable {
        let id: Int
        let name: String
    }

    private func uniqueKey(_ label: String = #function) -> String {
        "test-\(label)-\(UUID().uuidString)"
    }

    @Test("loading before any save returns nil")
    func loadBeforeSaveReturnsNil() async {
        let store = FileCacheStore<Fixture>(key: uniqueKey())
        let loaded = await store.load()
        #expect(loaded == nil)
    }

    @Test("save then load round-trips the value")
    func saveThenLoadRoundTrips() async throws {
        let store = FileCacheStore<Fixture>(key: uniqueKey())
        let value = Fixture(id: 42, name: "Bridal Salon")

        try await store.save(value)
        let loaded = await store.load()

        #expect(loaded == value)
    }

    @Test("save overwrites a previously saved value")
    func saveOverwritesPreviousValue() async throws {
        let store = FileCacheStore<Fixture>(key: uniqueKey())

        try await store.save(Fixture(id: 1, name: "First"))
        try await store.save(Fixture(id: 2, name: "Second"))
        let loaded = await store.load()

        #expect(loaded == Fixture(id: 2, name: "Second"))
    }

    @Test("clear removes the saved value")
    func clearRemovesValue() async throws {
        let store = FileCacheStore<Fixture>(key: uniqueKey())

        try await store.save(Fixture(id: 7, name: "To be cleared"))
        await store.clear()
        let loaded = await store.load()

        #expect(loaded == nil)
    }

    @Test("clearing an empty store does not throw or crash")
    func clearWithoutPriorSaveIsSafe() async {
        let store = FileCacheStore<Fixture>(key: uniqueKey())
        await store.clear()
        let loaded = await store.load()
        #expect(loaded == nil)
    }

    @Test("distinct keys do not collide")
    func distinctKeysDoNotCollide() async throws {
        let storeA = FileCacheStore<Fixture>(key: uniqueKey("a"))
        let storeB = FileCacheStore<Fixture>(key: uniqueKey("b"))

        try await storeA.save(Fixture(id: 1, name: "A"))
        try await storeB.save(Fixture(id: 2, name: "B"))

        let loadedA = await storeA.load()
        let loadedB = await storeB.load()

        #expect(loadedA == Fixture(id: 1, name: "A"))
        #expect(loadedB == Fixture(id: 2, name: "B"))
    }
}
