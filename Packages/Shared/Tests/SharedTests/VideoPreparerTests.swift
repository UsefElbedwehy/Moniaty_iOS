#if canImport(UIKit)
import AVFoundation
import Foundation
import Testing
import UIKit
@testable import Shared

/// Runs on the iOS simulator (`xcodebuild test -scheme Shared`); `swift test` on macOS skips it.
@Suite("VideoPreparer")
struct VideoPreparerTests {
    @Test func compressesTo720pWithPoster() async throws {
        let source = try await makeVideo(seconds: 3, size: CGSize(width: 1920, height: 1080))
        let prepared = try await VideoPreparer.prepare(source)
        defer { try? FileManager.default.removeItem(at: prepared.file) }

        #expect(prepared.durationSeconds == 3)
        #expect(prepared.poster.flatMap(UIImage.init(data:)) != nil)
        let track = try #require(try await AVURLAsset(url: prepared.file).loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)
        #expect(min(size.width, size.height) <= 720)
        #expect(prepared.file.pathExtension == "mp4")
    }

    @Test func outputSizeKeepsAspectAndEvenSides() {
        #expect(VideoEncoding.outputSize(for: CGSize(width: 1920, height: 1080)) == CGSize(width: 1280, height: 720))
        #expect(VideoEncoding.outputSize(for: CGSize(width: 1080, height: 1920)) == CGSize(width: 720, height: 1280))
        #expect(VideoEncoding.outputSize(for: CGSize(width: 640, height: 360)) == CGSize(width: 640, height: 360))
        #expect(VideoEncoding.outputSize(for: CGSize(width: 1441, height: 1081)) == CGSize(width: 958, height: 720))
    }

    @Test func bitRateIsCappedButNeverRaised() {
        #expect(VideoEncoding.videoBitRate(sourceRate: 18_000_000) == 2_500_000)
        #expect(VideoEncoding.videoBitRate(sourceRate: 1_200_000) == 1_200_000)
        #expect(VideoEncoding.videoBitRate(sourceRate: 0) == 2_500_000)
    }

    /// Pure random noise at 1080p is the worst case for any encoder (the old system preset went
    /// far past 7 Mbit/s on camera grain); it still lands near the target. Real clips measure ~2.3.
    @Test func noisyFullHDClipStaysNearTheTargetRate() async throws {
        let source = try await makeVideo(seconds: 4, size: CGSize(width: 1920, height: 1080), fps: 30, noisy: true)
        let prepared = try await VideoPreparer.prepare(source)
        defer { try? FileManager.default.removeItem(at: prepared.file) }
        let bytes = try #require(try prepared.file.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        let megabitsPerSecond = Double(bytes * 8) / 4 / 1_000_000
        #expect(megabitsPerSecond < 4.5, "came out at \(megabitsPerSecond) Mbit/s")
        let track = try #require(try await AVURLAsset(url: prepared.file).loadTracks(withMediaType: .video).first)
        #expect(try await track.load(.naturalSize) == CGSize(width: 1280, height: 720))
    }

    @Test func rejectsVideosOverTheLimit() async throws {
        let source = try await makeVideo(seconds: 5, size: CGSize(width: 640, height: 360))
        await #expect(throws: VideoPreparer.Failure.tooLong(maxSeconds: 3)) {
            _ = try await VideoPreparer.prepare(source, maxSeconds: 3)
        }
    }

    @Test func rejectsFilesThatAreNotVideos() async throws {
        let junk = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        try Data("not a video".utf8).write(to: junk)
        await #expect(throws: VideoPreparer.Failure.unreadable) {
            _ = try await VideoPreparer.prepare(junk)
        }
    }

    /// An H.264 clip written with AVAssetWriter: solid colour at 2 fps, or random noise (which
    /// compresses badly, like a real camera clip) at the given frame rate.
    private func makeVideo(seconds: Int, size: CGSize, fps: Int32 = 2, noisy: Bool = false) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: size.width, AVVideoHeightKey: size.height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width, kCVPixelBufferHeightKey as String: size.height,
        ])
        input.expectsMediaDataInRealTime = false
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<(seconds * Int(fps)) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            let pixels = try #require(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            let base = CVPixelBufferGetBaseAddress(pixels)!
            let count = CVPixelBufferGetDataSize(pixels)
            if noisy {
                arc4random_buf(base, count)
            } else {
                memset(base, Int32(40 + frame * 10 % 200), count)
            }
            CVPixelBufferUnlockBaseAddress(pixels, [])
            adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
        }
        input.markAsFinished()
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }
}
#endif
