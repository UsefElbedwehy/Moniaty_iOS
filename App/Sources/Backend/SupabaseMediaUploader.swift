import Foundation
import Core
import Shared

/// Uploads picked images to the public `media` bucket under the signed-in user's own folder
/// (`<uid>/<folder>/<uuid>.jpg`), which the storage policies require.
struct SupabaseMediaUploader: MediaUploading {
    let baseURL: URL
    let anonKey: String
    let accessToken: @Sendable () async -> String?
    let currentUserId: @Sendable () async -> String?
    var session: URLSession = .shared

    func uploadJPEG(_ jpeg: Data, folder: String) async throws -> URL {
        guard let uid = await currentUserId(), let token = await accessToken() else {
            throw AppError.authentication(.notAuthenticated)
        }
        let objectPath = "\(uid)/\(folder)/\(UUID().uuidString).jpg"
        var request = URLRequest(url: baseURL.appendingPathComponent("storage/v1/object/media/\(objectPath)"))
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        // Paths are never reused, so the bytes are immutable: cache for a year (cuts egress cost).
        request.setValue("public, max-age=31536000, immutable", forHTTPHeaderField: "Cache-Control")

        let response: URLResponse
        do {
            (_, response) = try await session.upload(for: request, from: jpeg)
        } catch {
            throw AppError.network(.noConnection)
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppError.server(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Image upload failed.")
        }
        return baseURL.appendingPathComponent("storage/v1/object/public/media/\(objectPath)")
    }
}

/// Offline stand-in: pretends the upload worked and returns a placeholder image URL.
struct MockMediaUploader: MediaUploading {
    func uploadJPEG(_ jpeg: Data, folder: String) async throws -> URL {
        URL(string: "https://picsum.photos/seed/\(UUID().uuidString)/800/600")!
    }
}
