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

    /// A solid-colour H.264 clip at 2 fps, written with AVAssetWriter.
    private func makeVideo(seconds: Int, size: CGSize) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: size.width, AVVideoHeightKey: size.height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width, kCVPixelBufferHeightKey as String: size.height,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        let fps: Int32 = 2
        for frame in 0..<(seconds * Int(fps)) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            let pixels = try #require(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            memset(CVPixelBufferGetBaseAddress(pixels), Int32(40 + frame * 10 % 200), CVPixelBufferGetDataSize(pixels))
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
