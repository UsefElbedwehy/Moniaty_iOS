import Foundation
import Testing
@testable import Shared

@Suite("MediaThumbnail")
struct MediaThumbnailTests {
    @Test func newPhotosHaveASmallCopyBesideThem() {
        let full = URL(string: "https://x.supabase.co/storage/v1/object/public/media/u1/services/AB12.full.jpg")!
        #expect(MediaThumbnail.url(for: full)?.absoluteString
                == "https://x.supabase.co/storage/v1/object/public/media/u1/services/AB12.thumb.jpg")
    }

    @Test func olderPhotosHaveNone() {
        #expect(MediaThumbnail.url(for: URL(string: "https://x.supabase.co/storage/v1/object/public/media/u1/services/AB12.jpg")!) == nil)
        #expect(MediaThumbnail.url(for: URL(string: "https://picsum.photos/seed/a/800/600")!) == nil)
    }
}
