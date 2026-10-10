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
}
#endif
