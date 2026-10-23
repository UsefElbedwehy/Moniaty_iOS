import XCTest

/// Signs up and browses against the **live** Supabase project with a test number from
/// `DEV_PHONES` (fixed code `DEV_OTP_CODE`). Skipped unless `LIVE_PHONE` is set, e.g.
/// `TEST_RUNNER_LIVE_PHONE=500000104 TEST_RUNNER_LIVE_CODE=000000 xcodebuild test … -only-testing:MunyatiUITests/LiveSmokeTests`.
/// Screenshots go to `WALKTHROUGH_SHOTS`.
final class LiveSmokeTests: XCTestCase {
    private let env = ProcessInfo.processInfo.environment
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        try XCTSkipIf(env["LIVE_PHONE"] == nil, "LIVE_PHONE not set")
        continueAfterFailure = false
        app.launchEnvironment["UITEST_NO_PUSH"] = "1"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        addUIInterruptionMonitor(withDescription: "alerts") { alert in
            for label in ["Allow", "OK", "Don’t Allow"] where alert.buttons[label].exists {
                alert.buttons[label].tap(); return true
            }
            return false
        }
    }

    private func snap(_ name: String) {
        sleep(2)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = env["WALKTHROUGH_SHOTS"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/live-\(name).png"))
        }
    }

    private func tap(_ element: XCUIElement, _ what: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 15), "missing \(what)")
        element.tap()
    }

    private func button(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
    }

    func testBrideSignUpAndBrowse() throws {
        app.launch()
        snap("01-start")
        tap(button("I'm a bride"), "role card")
        let phone = app.textFields.firstMatch
        XCTAssertTrue(phone.waitForExistence(timeout: 10))
        phone.tap()
        phone.typeText(env["LIVE_PHONE"]!)
        tap(button("Send code"), "send code")
        sleep(3)
        snap("02-otp")
        app.typeText(env["LIVE_CODE"] ?? "000000")
        sleep(4)

        // A new number is asked for a name; an existing one goes straight in.
        let first = app.textFields["First name"]
        if first.waitForExistence(timeout: 6) {
            first.tap(); first.typeText("Test")
            let last = app.textFields["Last name"]
            last.tap(); last.typeText("Bride")
            snap("03-name")
            tap(button("Create account"), "create account")
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20), "did not reach the tabs")
        sleep(4)
        snap("04-home")
        tap(app.tabBars.buttons["My bookings"], "bookings tab")
        snap("05-bookings")
        tap(app.tabBars.buttons["Profile"], "profile tab")
        snap("06-profile")
    }
}
