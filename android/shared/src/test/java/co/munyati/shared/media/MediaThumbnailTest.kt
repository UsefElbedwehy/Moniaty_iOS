package co.munyati.shared.media

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MediaThumbnailTest {
    @Test fun newPhotosHaveASmallCopyBesideThem() {
        assertEquals(
            "https://x.supabase.co/storage/v1/object/public/media/u1/services/AB12.thumb.jpg",
            MediaThumbnail.url("https://x.supabase.co/storage/v1/object/public/media/u1/services/AB12.full.jpg"),
        )
    }

    @Test fun olderPhotosHaveNone() {
        assertNull(MediaThumbnail.url("https://x.supabase.co/storage/v1/object/public/media/u1/services/AB12.jpg"))
        assertNull(MediaThumbnail.url(null))
    }
}
