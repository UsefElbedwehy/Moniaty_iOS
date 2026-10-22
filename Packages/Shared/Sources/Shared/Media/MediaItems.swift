import Foundation

/// A video on a service: the file, a poster frame made at upload, and its length.
/// Encodes to the backend shape `{url, poster_url, duration_seconds}` (the API client converts
/// key case).
public struct VideoAsset: Hashable, Sendable, Codable {
    public let url: URL
    public let posterUrl: URL?
    public let durationSeconds: Int?

    public init(url: URL, posterUrl: URL?, durationSeconds: Int?) {
        self.url = url
        self.posterUrl = posterUrl
        self.durationSeconds = durationSeconds
    }

    /// "0:42"-style length for badges.
    public var durationText: String? {
        guard let durationSeconds, durationSeconds > 0 else { return nil }
        return String(format: "%d:%02d", durationSeconds / 60, durationSeconds % 60)
    }
}

/// One page of a media gallery: a photo or a video.
public enum GalleryItem: Hashable, Sendable, Identifiable {
    case image(URL)
    case video(VideoAsset)

    public var id: String {
        switch self {
        case .image(let url): "i:" + url.absoluteString
        case .video(let video): "v:" + video.url.absoluteString
        }
    }

    /// Photos first, then videos (the order the provider added them in each group).
    public static func items(images: [URL], videos: [VideoAsset]) -> [GalleryItem] {
        images.map(GalleryItem.image) + videos.map(GalleryItem.video)
    }
}

/// Limits for videos a provider adds to a service (the backend allows at most 3 per service).
public enum VideoLimits {
    public static let perService = 3
    public static let maxSeconds = 60
    /// Supabase Storage's upload limit on the current plan.
    public static let maxBytes = 50 * 1024 * 1024
}
