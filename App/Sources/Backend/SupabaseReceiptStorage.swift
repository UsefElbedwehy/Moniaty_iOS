import Foundation
import Core
import Booking

/// Payment receipts live in the private `receipts` bucket under `<bookingId>/`; the storage
/// policies let only the booking's bride, its provider and admins read them.
struct SupabaseReceiptStorage: ReceiptStorage {
    let baseURL: URL
    let anonKey: String
    let accessToken: @Sendable () async -> String?
    var session: URLSession = .shared

    func upload(jpeg: Data, bookingId: String) async throws -> String {
        let path = "\(bookingId)/\(UUID().uuidString).jpg"
        var request = try await authorizedRequest("storage/v1/object/receipts/\(path)")
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let response: URLResponse
        do {
            (_, response) = try await session.upload(for: request, from: jpeg)
        } catch {
            throw AppError.network(.noConnection)
        }
        try check(response, message: "Receipt upload failed.")
        return path
    }

    func download(path: String) async throws -> Data {
        let request = try await authorizedRequest("storage/v1/object/authenticated/receipts/\(path)")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AppError.network(.noConnection)
        }
        try check(response, message: "Receipt download failed.")
        return data
    }

    private func authorizedRequest(_ path: String) async throws -> URLRequest {
        guard let token = await accessToken() else { throw AppError.authentication(.notAuthenticated) }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func check(_ response: URLResponse, message: String) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppError.server(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: message)
        }
    }
}

/// Offline stand-in: keeps receipts in memory so the viewer can show what was uploaded.
actor MockReceiptStorage: ReceiptStorage {
    private var files: [String: Data] = [:]

    func upload(jpeg: Data, bookingId: String) async throws -> String {
        let path = "\(bookingId)/\(UUID().uuidString).jpg"
        files[path] = jpeg
        return path
    }

    func download(path: String) async throws -> Data {
        guard let data = files[path] else { throw AppError.unknown(message: "Receipt not found.") }
        return data
    }
}
