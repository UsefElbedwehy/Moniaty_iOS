import XCTest

/// App Store screenshots on the in-memory mocks: one launch per screen, saved to
/// `WALKTHROUGH_SHOTS` as `store-<lang>-<nn>-<name>.png`. Run on the iPhone 6.9" simulator
/// (iPhone 16 Pro Max) with `WALKTHROUGH_LANG=ar` and again with `en`. Retake with real
/// providers' photos before launch.
final class StoreScreenshotsTests: XCTestCase {
    private var lang: String { ProcessInfo.processInfo.environment["WALKTHROUGH_LANG"] ?? "ar" }

    override func setUp() { continueAfterFailure = true }

    private func launch(role: String = "bride", tab: String? = nil, url: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_MOCK_BACKEND"] = "1"
        app.launchEnvironment["UITEST_NO_PUSH"] = "1"
        app.launchEnvironment["UITEST_START_ROLE"] = role
        app.launchEnvironment["UITEST_DISPLAY_NAME"] = lang == "ar" ? (role == "bride" ? "نورة" : "لمسة جمال") : (role == "bride" ? "Noura" : "Lamsa Beauty")
        app.launchEnvironment["UITEST_PHONE"] = "+966551234567"
        app.launchEnvironment["UITEST_SAMPLE_BOOKINGS"] = "1"
        if let tab { app.launchEnvironment["UITEST_START_TAB"] = tab }
        if let url { app.launchEnvironment["UITEST_OPEN_URL"] = url }
        app.launchArguments += ["-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "ar" ? "ar_SA" : "en_US"]
        app.launch()
        return app
    }

    private func save(_ name: String, wait: UInt32 = 12) {
        sleep(wait)   // remote photos load
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["WALKTHROUGH_SHOTS"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/store-\(lang)-\(name).png"))
        }
    }

    func test01Home() { _ = launch(tab: "home"); save("01-home") }
    func test02Service() { _ = launch(url: "munyati://s/s1"); save("02-service") }
    func test03Viewer() {
        let app = launch(url: "munyati://s/s1")
        sleep(10)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28)).tap()
        sleep(8)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()   // hide the controls
        save("03-viewer", wait: 3)
    }
    func test04Provider() { _ = launch(url: "munyati://p/p-lamsa"); save("04-provider") }
    func test05Explore() { _ = launch(tab: "explore"); save("05-explore", wait: 8) }
    func test06Bookings() { _ = launch(tab: "bookings"); save("06-bookings") }
    func test07Profile() { _ = launch(tab: "profile"); save("07-profile") }
    func test08Studio() { _ = launch(role: "provider", tab: "home"); save("08-studio") }
}
