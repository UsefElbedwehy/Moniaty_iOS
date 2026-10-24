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

    /// Re-encodes at a fixed bitrate (see `VideoEncoding`); if that path fails on an unusual file,
    /// falls back to the system 720p preset, whose bitrate is higher but which reads almost anything.
    private static func export(_ asset: AVURLAsset, to output: URL) async throws {
        if (try? await transcode(asset, to: output)) == true { return }
        try? FileManager.default.removeItem(at: output)
        try await exportWithPreset(asset, to: output)
    }

    private static func transcode(_ asset: AVURLAsset, to output: URL) async throws -> Bool {
        guard let video = try await asset.loadTracks(withMediaType: .video).first else { return false }
        let (natural, transform, frameRate, dataRate) = try await video.load(.naturalSize, .preferredTransform,
                                                                             .nominalFrameRate, .estimatedDataRate)
        let audio = try await asset.loadTracks(withMediaType: .audio).first
        var channels = 2
        if let audio, let format = try await audio.load(.formatDescriptions).first,
           let description = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee {
            channels = max(1, min(2, Int(description.mChannelsPerFrame)))
        }

        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true   // index first, so playback starts before the download ends

        let size = VideoEncoding.outputSize(for: natural)
        let videoOut = AVAssetReaderTrackOutput(track: video, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        ])
        videoOut.alwaysCopiesSampleData = false
        let videoIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: VideoEncoding.videoBitRate(sourceRate: dataRate),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalDurationKey: 2,
                AVVideoExpectedSourceFrameRateKey: frameRate > 0 ? Int(frameRate.rounded()) : 30,
            ],
        ])
        videoIn.transform = transform   // keep portrait clips portrait
        videoIn.expectsMediaDataInRealTime = false
        guard reader.canAdd(videoOut), writer.canAdd(videoIn) else { return false }
        reader.add(videoOut)
        writer.add(videoIn)
        var pumps = [TrackPump(output: videoOut, input: videoIn, writer: writer, label: "video")]

        if let audio {
            let audioOut = AVAssetReaderTrackOutput(track: audio, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ])
            let audioIn = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: VideoEncoding.audioBitRate(channels: channels),
            ])
            audioIn.expectsMediaDataInRealTime = false
            if reader.canAdd(audioOut), writer.canAdd(audioIn) {
                reader.add(audioOut)
                writer.add(audioIn)
                pumps.append(TrackPump(output: audioOut, input: audioIn, writer: writer, label: "audio"))
            }
        }

        let job = TranscodeJob(reader: reader, writer: writer, pumps: pumps)
        return await job.run()
    }

    private static func exportWithPreset(_ asset: AVURLAsset, to output: URL) async throws {
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
/// The numbers behind every uploaded video, shared by the tests.
enum VideoEncoding {
    /// Short side at most 720 px, even dimensions (H.264 needs them), aspect kept.
    static func outputSize(for natural: CGSize) -> CGSize {
        let width = abs(natural.width), height = abs(natural.height)
        let scale = min(1, 720 / max(1, min(width, height)))
        let even = { (value: CGFloat) in max(2, (value * scale / 2).rounded(.down) * 2) }
        return CGSize(width: even(width), height: even(height))
    }

    /// 2.5 Mbit/s: clear 720p on a phone, about 19 MB a minute with sound. A source that is
    /// already lighter keeps its own rate (re-encoding never makes a file bigger).
    static let targetVideoBitRate = 2_500_000

    static func videoBitRate(sourceRate: Float) -> Int {
        guard sourceRate > 0 else { return targetVideoBitRate }
        return max(500_000, min(targetVideoBitRate, Int(sourceRate)))
    }

    static func audioBitRate(channels: Int) -> Int { channels > 1 ? 128_000 : 96_000 }
}

/// Feeds one track from the reader to the writer on its own queue until it runs out.
private final class TrackPump: @unchecked Sendable {
    private let output: AVAssetReaderOutput
    private let input: AVAssetWriterInput
    private let writer: AVAssetWriter
    private let queue: DispatchQueue
    private var finished = false   // touched only on `queue`

    init(output: AVAssetReaderOutput, input: AVAssetWriterInput, writer: AVAssetWriter, label: String) {
        self.output = output
        self.input = input
        self.writer = writer
        self.queue = DispatchQueue(label: "co.munyati.video.\(label)")
    }

    func run() async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            input.requestMediaDataWhenReady(on: queue) { [self] in
                while input.isReadyForMoreMediaData, !finished {
                    if writer.status == .writing, let buffer = output.copyNextSampleBuffer(), input.append(buffer) { continue }
                    finished = true
                    input.markAsFinished()
                    done.resume()
                }
            }
        }
    }
}

/// Reads, re-encodes and writes every track, then reports whether the file is complete.
private final class TranscodeJob: @unchecked Sendable {
    private let reader: AVAssetReader
    private let writer: AVAssetWriter
    private let pumps: [TrackPump]

    init(reader: AVAssetReader, writer: AVAssetWriter, pumps: [TrackPump]) {
        self.reader = reader
        self.writer = writer
        self.pumps = pumps
    }

    func run() async -> Bool {
        guard writer.startWriting() else { return false }
        guard reader.startReading() else {
            writer.cancelWriting()
            return false
        }
        writer.startSession(atSourceTime: .zero)
        await withTaskGroup(of: Void.self) { group in
            for pump in pumps { group.addTask { await pump.run() } }
        }
        guard reader.status == .completed, writer.status == .writing else {
            reader.cancelReading()
            writer.cancelWriting()
            return false
        }
        await writer.finishWriting()
        return writer.status == .completed
    }
}
#endif
