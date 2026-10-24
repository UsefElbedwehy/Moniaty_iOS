import Foundation
import SwiftUI
import DesignSystem
import ImageIO
import os

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Explicit load state for a single remote image. Mirrors the spirit of `Core`'s
/// generic `ViewState<T>`, but a single image doesn't need that machinery — a local
/// three-case enum keeps this self-contained.
public enum ImagePhase: Sendable {
    case loading
    case loaded(Image)
    case failed
}

/// Shared `URLCache`-backed session used for remote image loading across the app.
/// 50MB in-memory / 400MB on-disk budget. The on-disk figure is deliberately larger than the
/// whole published photo catalog: a cached photo that gets evicted has to be re-downloaded, and
/// bandwidth is the scarce resource here, not disk (this lives in `Caches`, so the OS reclaims it
/// under storage pressure). Uploaded paths carry a fresh UUID and are never overwritten, so a
/// long-lived cache entry can never go stale.
public enum RemoteImageLoading {
    public static let cache: URLCache = URLCache(
        memoryCapacity: 50 * 1024 * 1024,
        diskCapacity: 400 * 1024 * 1024,
        diskPath: "MunyatiRemoteImageCache"
    )

    public static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }()
}

/// A small decoded-image cache shared across every `RemoteImageView` instance, keyed by URL.
/// `RemoteImageLoading.cache` above only caches the raw HTTP response bytes — this avoids
/// re-decoding `UIImage(data:)` every time the same photo reappears in a fresh view instance
/// (e.g. scrolling a gallery carousel back and forth). `NSCache` is thread-safe and evicts under
/// memory pressure on its own, so no manual size limit is needed.
enum RemoteImageDecodeCache {
    // NSCache is documented as thread-safe by Apple, but isn't itself `Sendable` — `unsafe` here
    // just opts out of a check the type's own concurrency guarantees already satisfy.
    #if canImport(UIKit)
    nonisolated(unsafe) static let shared = NSCache<NSURL, UIImage>()
    #elseif canImport(AppKit)
    nonisolated(unsafe) static let shared = NSCache<NSURL, NSImage>()
    #endif
}

#if canImport(UIKit)
extension RemoteImageLoading {
    /// The decoded photo for `url`, through the same caches as `RemoteImageView` (used by the
    /// full-screen viewer, which zooms a `UIImage`).
    public static func uiImage(for url: URL) async -> UIImage? {
        // Full resolution for zooming; kept apart from the screen-size copies `RemoteImageView` caches.
        let key = url.appendingPathComponent("#full") as NSURL
        if let cached = RemoteImageDecodeCache.shared.object(forKey: key) { return cached }
        guard let (data, response) = try? await session.data(from: url) else { return nil }
        if !url.isFileURL {
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        }
        guard let image = await decodeOffMain(data) else { return nil }
        RemoteImageDecodeCache.shared.setObject(image, forKey: key)
        return image
    }

    nonisolated private static func decodeOffMain(_ data: Data) async -> UIImage? {
        decodeDownsampled(data, maxPixelSize: nil)
    }

    /// Longest side of an image shown inside the app (cards, galleries, banners): a full phone
    /// width at 3x. Uploads are 1600 px, so this alone saves about 45% memory per photo.
    public static let displayMaxPixelSize: CGFloat = 1200

    /// Decodes with ImageIO: shrunk to `maxPixelSize` while decoding (never holding the full bitmap)
    /// and decoded right here, off the main thread. `UIImage(data:)` would instead decode the full
    /// size lazily on the main thread the first time the image is drawn, which stutters scrolling.
    nonisolated static func decodeDownsampled(_ data: Data, maxPixelSize: CGFloat?) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        if let maxPixelSize {
            options[kCGImageSourceThumbnailMaxPixelSize] = maxPixelSize
        } else if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
                  let height = properties[kCGImagePropertyPixelHeight] as? CGFloat {
            options[kCGImageSourceThumbnailMaxPixelSize] = max(width, height)
        }
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)   // formats ImageIO can't thumbnail
        }
        return UIImage(cgImage: image)
    }
}
#endif

/// Drives the fetch/cache/retry lifecycle for a single `RemoteImageView`.
@Observable
@MainActor
final class RemoteImageLoader {
    private(set) var phase: ImagePhase = .loading
    private let logger = Logger(subsystem: "Munyati.Shared", category: "RemoteImage")
    private var currentTask: Task<Void, Never>?

    func load(url: URL?) {
        currentTask?.cancel()
        guard let url else {
            phase = .failed
            return
        }
        phase = .loading
        currentTask = Task { [weak self] in
            await self?.fetch(url: url)
        }
    }

    func cancel() {
        currentTask?.cancel()
    }

    private func fetch(url: URL) async {
        #if canImport(UIKit)
        if let cached = RemoteImageDecodeCache.shared.object(forKey: url as NSURL) {
            phase = .loaded(Image(uiImage: cached))
            return
        }
        #elseif canImport(AppKit)
        if let cached = RemoteImageDecodeCache.shared.object(forKey: url as NSURL) {
            phase = .loaded(Image(nsImage: cached))
            return
        }
        #endif
        do {
            let (data, response) = try await RemoteImageLoading.session.data(from: url)
            // A `file://` URL (used for bundled placeholder photos, e.g. mock hero banners)
            // never comes back as an `HTTPURLResponse` — there's no HTTP status to check, so a
            // successful read is success by definition.
            if !url.isFileURL {
                guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                    phase = .failed
                    return
                }
            }
            guard !Task.isCancelled else { return }
            #if canImport(UIKit)
            guard let uiImage = await Self.decode(data: data) else {
                phase = .failed
                return
            }
            RemoteImageDecodeCache.shared.setObject(uiImage, forKey: url as NSURL)
            phase = .loaded(Image(uiImage: uiImage))
            #elseif canImport(AppKit)
            guard let nsImage = await Self.decode(data: data) else {
                phase = .failed
                return
            }
            RemoteImageDecodeCache.shared.setObject(nsImage, forKey: url as NSURL)
            phase = .loaded(Image(nsImage: nsImage))
            #endif
        } catch is CancellationError {
            // Superseded by a newer load; leave state untouched.
        } catch {
            guard !Task.isCancelled else { return }
            let description = error.localizedDescription
            logger.warning("Remote image load failed for \(url.absoluteString, privacy: .public): \(description, privacy: .public)")
            phase = .failed
        }
    }

    // Nonisolated so this CPU-bound decode runs off the main actor instead of blocking it —
    // `nonisolated func ... async` hops to the background cooperative pool rather than staying
    // pinned to whichever actor called it.
    #if canImport(UIKit)
    nonisolated private static func decode(data: Data) async -> UIImage? {
        RemoteImageLoading.decodeDownsampled(data, maxPixelSize: RemoteImageLoading.displayMaxPixelSize)
    }
    #elseif canImport(AppKit)
    nonisolated private static func decode(data: Data) async -> NSImage? { NSImage(data: data) }
    #endif
}

/// A SwiftUI view that loads a remote place/listing photo with caching, a neutral
/// placeholder, retry-on-failure, and a progressive fade-in once the image loads.
public struct RemoteImageView: View {
    private let url: URL?
    private let contentMode: ContentMode

    @State private var loader = RemoteImageLoader()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }

    public var body: some View {
        ZStack {
            switch loader.phase {
            case .loading:
                placeholder

            case .loaded(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(reduceMotion ? .identity : .opacity.animation(.easeOut(duration: 0.25)))

            case .failed where url == nil:
                placeholder

            case .failed:
                failureView
            }
        }
        .clipped()
        .task(id: url) {
            loader.load(url: url)
        }
        .onDisappear {
            loader.cancel()
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.dsBorder.opacity(0.6))
    }

    private var failureView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.dsBorder.opacity(0.45))

            Button {
                loader.load(url: url)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(12)
                    .background(Circle().fill(Color.dsSurface.opacity(0.9)))
            }
            .accessibilityLabel(SharedStrings.retry)
        }
    }
}
