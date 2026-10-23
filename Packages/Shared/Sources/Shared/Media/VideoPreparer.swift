#if canImport(UIKit)
import AVFoundation
import CoreTransferable
import UIKit
import UniformTypeIdentifiers

/// A movie picked with `PhotosPicker`, copied out of the picker's temporary location.
public struct PickedMovie: Transferable, Sendable {
    public let url: URL

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}

/// Turns a picked video into what gets uploaded: a 720p H.264 MP4 (small enough to stream
/// over mobile data and to stay under the storage upload limit), a JPEG poster frame and the
/// length in seconds. Done on the phone so the backend never has to transcode (cost).
public enum VideoPreparer {
    public struct Prepared: Sendable {
        public let file: URL
        public let poster: Data?
        public let durationSeconds: Int
    }

    public enum Failure: Error, Equatable, Sendable {
        case tooLong(maxSeconds: Int)
        case tooLarge
        case unreadable
    }

    public static func prepare(_ source: URL, maxSeconds: Int = VideoLimits.maxSeconds,
                               maxBytes: Int = VideoLimits.maxBytes) async throws -> Prepared {
        // The picked copy is temporary, whatever happens next.
        defer { try? FileManager.default.removeItem(at: source) }
        let asset = AVURLAsset(url: source)
        guard let duration = try? await asset.load(.duration), duration.isNumeric, duration.seconds > 0 else {
            throw Failure.unreadable
        }
        // A little slack: phones round a 60-second recording to 60.4 and so on.
        guard duration.seconds <= Double(maxSeconds) + 0.9 else { throw Failure.tooLong(maxSeconds: maxSeconds) }

        let poster = await posterJPEG(asset: asset, duration: duration)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        try await export(asset, to: output)

        let size = (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0 else { throw Failure.unreadable }
        guard size <= maxBytes else {
            try? FileManager.default.removeItem(at: output)
            throw Failure.tooLarge
        }
        return Prepared(file: output, poster: poster, durationSeconds: Int(duration.seconds.rounded()))
    }

    private static func export(_ asset: AVURLAsset, to output: URL) async throws {
        let preset = await AVAssetExportSession.compatibility(ofExportPreset: AVAssetExportPreset1280x720, with: asset, outputFileType: .mp4)
            ? AVAssetExportPreset1280x720 : AVAssetExportPresetMediumQuality
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { throw Failure.unreadable }
        session.shouldOptimizeForNetworkUse = true
        if #available(iOS 18, *) {
            do {
                try await session.export(to: output, as: .mp4)
            } catch {
                throw Failure.unreadable
            }
        } else {
            session.outputURL = output
            session.outputFileType = .mp4
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                session.exportAsynchronously { done.resume() }
            }
            guard session.status == .completed else { throw Failure.unreadable }
        }
    }

    private static func posterJPEG(asset: AVURLAsset, duration: CMTime) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        let at = CMTime(seconds: min(1, duration.seconds / 2), preferredTimescale: 600)
        guard let (image, _) = try? await generator.image(at: at) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.8)
    }
}
#endif
