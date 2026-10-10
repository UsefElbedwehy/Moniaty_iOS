import Foundation
import os

/// Protocol-based local cache abstraction. Features depend on this protocol, never on
/// a concrete storage mechanism — this is the seam that lets us swap JSON-on-disk for
/// something else later without touching call sites.
///
/// This is the mechanism the rest of the app uses to cache Configuration, Categories,
/// Regions/Cities, Home, Profile, Favorites, Recently Viewed, and My Places for offline use.
public protocol CacheStore<Value>: Sendable {
    associatedtype Value: Codable & Sendable

    func save(_ value: Value) async throws
    func load() async -> Value?
    func clear() async
}

/// JSON-on-disk implementation of `CacheStore`. Writes to
/// `<directory>/Munyati/<key>.json`.
///
/// All file I/O is isolated inside a private `actor` so concurrent callers are safe by
/// construction; `FileCacheStore` itself is a thin `Sendable` façade that forwards to it.
public final class FileCacheStore<Value: Codable & Sendable>: CacheStore, @unchecked Sendable {
    private let io: FileCacheIO

    public init(key: String, directory: FileManager.SearchPathDirectory = .cachesDirectory) {
        self.io = FileCacheIO(key: key, directory: directory)
    }

    public func save(_ value: Value) async throws {
        try await io.save(value)
    }

    public func load() async -> Value? {
        await io.load()
    }

    public func clear() async {
        await io.clear()
    }
}

/// Actor performing the actual file I/O for `FileCacheStore`. Kept generic so each
/// `FileCacheStore<Value>` gets a correctly-typed, isolated worker.
private actor FileCacheIO {
    private let key: String
    private let directory: FileManager.SearchPathDirectory
    private let logger = Logger(subsystem: "Munyati.Shared", category: "cache")

    init(key: String, directory: FileManager.SearchPathDirectory) {
        self.key = key
        self.directory = directory
    }

    func save<Value: Codable & Sendable>(_ value: Value) throws {
        let url = try fileURL(creatingDirectories: true)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }

    func load<Value: Codable & Sendable>() -> Value? {
        guard let url = try? fileURL(creatingDirectories: false),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            let description = error.localizedDescription
            logger.warning("Failed to decode cache for key \(self.key, privacy: .public): \(description, privacy: .public)")
            return nil
        }
    }

    func clear() {
        guard let url = try? fileURL(creatingDirectories: false) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func fileURL(creatingDirectories: Bool) throws -> URL {
        let baseURL = try FileManager.default.url(
            for: directory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folderURL = baseURL.appendingPathComponent("Munyati", isDirectory: true)
        if creatingDirectories {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        return folderURL.appendingPathComponent("\(key).json", isDirectory: false)
    }
}
