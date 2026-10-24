#if canImport(UIKit)
import Foundation
import Testing
import UIKit
@testable import Shared

/// Runs on the iOS simulator (`xcodebuild test -scheme Shared`).
@Suite("RemoteImage decoding")
struct RemoteImageDecodeTests {
    private func jpeg(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 0.8)!
    }

    @Test func shrinksToTheDisplaySizeKeepingAspect() throws {
        let image = try #require(RemoteImageLoading.decodeDownsampled(jpeg(width: 1600, height: 1200), maxPixelSize: 1200))
        #expect(image.size == CGSize(width: 1200, height: 900))
    }

    @Test func neverEnlargesSmallImages() throws {
        let image = try #require(RemoteImageLoading.decodeDownsampled(jpeg(width: 400, height: 300), maxPixelSize: 1200))
        #expect(image.size == CGSize(width: 400, height: 300))
    }

    @Test func fullResolutionForTheViewer() throws {
        let image = try #require(RemoteImageLoading.decodeDownsampled(jpeg(width: 1600, height: 1200), maxPixelSize: nil))
        #expect(image.size == CGSize(width: 1600, height: 1200))
    }

    @Test func junkIsNotAnImage() {
        #expect(RemoteImageLoading.decodeDownsampled(Data("nope".utf8), maxPixelSize: 1200) == nil)
    }
}
#endif
