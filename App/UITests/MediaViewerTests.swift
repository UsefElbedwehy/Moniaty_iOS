import XCTest

/// The service gallery and the full-screen photo/video viewer, on the in-memory mocks
/// (mock service s1 has three photos and one sample video). Screenshots go to `WALKTHROUGH_SHOTS`
/// when set.
final class MediaViewerTests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchEnvironment["UITEST_MOCK_BACKEND"] = "1"
        app.launchEnvironment["UITEST_START_ROLE"] = "bride"
        app.launchEnvironment["UITEST_NO_PUSH"] = "1"
        app.launchEnvironment["UITEST_OPEN_URL"] = "munyati://s/s1"
        let lang = ProcessInfo.processInfo.environment["WALKTHROUGH_LANG"] ?? "en"
        app.launchArguments += ["-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "ar" ? "ar_SA" : "en_US"]
    }

    private func snap(_ name: String) {
        sleep(1)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["WALKTHROUGH_SHOTS"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/media-\(name).png"))
        }
    }

    private func element(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
    }

    func testGalleryOpensViewerAndPlaysVideo() {
        app.launch()
        let rtl = (ProcessInfo.processInfo.environment["WALKTHROUGH_LANG"] ?? "en") == "ar"
        let firstPhoto = element(rtl ? "صورة" : "Photo 1 of")
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 10))
        snap("1-gallery")

        // Tap the big page (the thumbnail below carries the same label).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28)).tap()
        let close = app.buttons[rtl ? "إغلاق" : "Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "viewer did not open")
        snap("2-viewer-photo")

        // Double-tap zooms in; double-tap again zooms back out.
        app.doubleTap()
        snap("3-viewer-zoomed")
        app.doubleTap()

        // Swipe to the video (the last item). Arabic pages the other way.
        for _ in 0..<3 { rtl ? app.swipeRight() : app.swipeLeft(); usleep(600_000) }
        sleep(3)
        snap("4-viewer-video")

        // Drag down closes the viewer.
        rtl ? app.swipeLeft() : app.swipeRight()
        sleep(1)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        sleep(1)
        XCTAssertFalse(close.exists, "drag down did not close the viewer")
        snap("5-closed")
    }
}
