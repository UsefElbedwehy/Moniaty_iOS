import Foundation
import Core
import Shared

/// Uploads picked images and videos to the public `media` bucket under the signed-in user's own
/// folder (`<uid>/<folder>/<uuid>.<ext>`), which the storage policies require.
struct SupabaseMediaUploader: MediaUploading {
    let baseURL: URL
    let anonKey: String
    let accessToken: @Sendable () async -> String?
    let currentUserId: @Sendable () async -> String?
    var session: URLSession = .shared

    func uploadJPEG(_ jpeg: Data, folder: String) async throws -> URL {
        try await upload(contentType: "image/jpeg", fileExtension: "jpg", folder: folder) { request in
            try await session.upload(for: request, from: jpeg)
        }
    }

    func uploadFile(_ file: URL, contentType: String, fileExtension: String, folder: String) async throws -> URL {
        try await upload(contentType: contentType, fileExtension: fileExtension, folder: folder) { request in
            try await session.upload(for: request, fromFile: file)
        }
    }

    /// The small copy goes first: a full photo is only ever saved with its thumbnail beside it.
    func uploadPhoto(_ photo: PreparedPhoto, folder: String) async throws -> URL {
        let name = UUID().uuidString
        _ = try await upload(contentType: "image/jpeg", fileExtension: "jpg", folder: folder,
                             name: name + String(MediaThumbnail.thumbnailSuffix.dropLast(4))) { request in
            try await session.upload(for: request, from: photo.thumbnail)
        }
        return try await upload(contentType: "image/jpeg", fileExtension: "jpg", folder: folder,
                                name: name + String(MediaThumbnail.fullSuffix.dropLast(4))) { request in
            try await session.upload(for: request, from: photo.full)
        }
    }

    private func upload(contentType: String, fileExtension: String, folder: String, name: String = UUID().uuidString,
                        send: (URLRequest) async throws -> (Data, URLResponse)) async throws -> URL {
        guard let uid = await currentUserId(), let token = await accessToken() else {
            throw AppError.authentication(.notAuthenticated)
        }
        let objectPath = "\(uid)/\(folder)/\(name).\(fileExtension)"
        var request = URLRequest(url: baseURL.appendingPathComponent("storage/v1/object/media/\(objectPath)"))
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        // Paths are never reused, so the bytes are immutable: cache for a year (cuts egress cost).
        request.setValue("public, max-age=31536000, immutable", forHTTPHeaderField: "Cache-Control")

        let response: URLResponse
        do {
            (_, response) = try await send(request)
        } catch {
            throw AppError.network(.noConnection)
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppError.server(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Upload failed.")
        }
        return baseURL.appendingPathComponent("storage/v1/object/public/media/\(objectPath)")
    }
}

/// Offline stand-in: pretends the upload worked. Photos come back as a placeholder image; files
/// are kept on the device so a picked video still plays back.
struct MockMediaUploader: MediaUploading {
    func uploadJPEG(_ jpeg: Data, folder: String) async throws -> URL {
        URL(string: "https://picsum.photos/seed/\(UUID().uuidString)/800/600")!
    }

    func uploadPhoto(_ photo: PreparedPhoto, folder: String) async throws -> URL {
        try await uploadJPEG(photo.full, folder: folder)
    }

    func uploadFile(_ file: URL, contentType: String, fileExtension: String, folder: String) async throws -> URL {
        let caches = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let kept = caches.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
        try FileManager.default.copyItem(at: file, to: kept)
        return kept
    }
}
