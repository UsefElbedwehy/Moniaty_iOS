import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Uploads an image the user picked (service photos, logos) and returns its public URL.
/// Implemented in the App against Supabase Storage; features stay storage-agnostic.
public protocol MediaUploading: Sendable {
    /// `jpeg` is already resized/compressed by the caller. `folder` is a short label such as
    /// "services" or "logos"; the implementation prefixes the user's own folder.
    func uploadJPEG(_ jpeg: Data, folder: String) async throws -> URL
    /// Uploads a photo with its small list copy side by side (`<id>.full.jpg`, `<id>.thumb.jpg`)
    /// and returns the full photo's URL; `MediaThumbnail.url(for:)` derives the other.
    func uploadPhoto(_ photo: PreparedPhoto, folder: String) async throws -> URL
    /// Uploads a file already on disk (a prepared video), streamed rather than read into memory.
    func uploadFile(_ file: URL, contentType: String, fileExtension: String, folder: String) async throws -> URL
}

/// A picked photo ready to upload: the full photo and the small copy shown in lists and grids.
public struct PreparedPhoto: Sendable {
    public let full: Data
    public let thumbnail: Data

    public init(full: Data, thumbnail: Data) {
        self.full = full
        self.thumbnail = thumbnail
    }
}

/// Where a photo's small copy lives. Photos uploaded since thumbnails exist end in `.full.jpg`
/// and have a `.thumb.jpg` beside them; older photos have none, so they are shown as they are.
public enum MediaThumbnail {
    public static let fullSuffix = ".full.jpg"
    public static let thumbnailSuffix = ".thumb.jpg"
    /// Longest side of the small copy: a two-column card at 3x.
    public static let maxDimension: CGFloat = 600

    /// The small copy's URL, or nil when the photo has none.
    public static func url(for url: URL) -> URL? {
        let text = url.absoluteString
        guard text.hasSuffix(fullSuffix) else { return nil }
        return URL(string: String(text.dropLast(fullSuffix.count)) + thumbnailSuffix)
    }
}

/// Downscales and JPEG-encodes picked photos before upload (keeps uploads small and avoids
/// paid server-side image transformations, see docs/research/backend-stack-and-cost.md §8.5).
#if canImport(UIKit)
public enum ImageCompressor {
    public static func jpeg(from data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    /// The full photo (1600 px) and its list copy (600 px), both from the picked original.
    public static func photo(from data: Data) -> PreparedPhoto? {
        guard let full = jpeg(from: data),
              let thumbnail = jpeg(from: data, maxDimension: MediaThumbnail.maxDimension, quality: 0.75) else { return nil }
        return PreparedPhoto(full: full, thumbnail: thumbnail)
    }
}
#endif
