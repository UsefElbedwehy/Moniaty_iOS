package co.munyati.shared.media

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class VideoPreparerTest {
    @Test fun heavyClipsAreCappedAtTheTarget() {
        assertEquals(VideoPreparer.TARGET_VIDEO_BITRATE, VideoPreparer.targetVideoBitrate(shortSide = 1080, sourceBitrate = 18_000_000))
        assertEquals(VideoPreparer.TARGET_VIDEO_BITRATE, VideoPreparer.targetVideoBitrate(shortSide = 720, sourceBitrate = 12_000_000))
    }

    @Test fun lightSourcesAreNeverRaised() {
        assertEquals(1_200_000, VideoPreparer.targetVideoBitrate(shortSide = 1080, sourceBitrate = 1_200_000))
    }

    @Test fun small_light_clipsKeepTheirStream() {
        assertNull(VideoPreparer.targetVideoBitrate(shortSide = 480, sourceBitrate = 1_500_000))
    }

    @Test fun unknownBitrateUsesTheTarget() {
        assertEquals(VideoPreparer.TARGET_VIDEO_BITRATE, VideoPreparer.targetVideoBitrate(shortSide = 720, sourceBitrate = 0))
    }
}
