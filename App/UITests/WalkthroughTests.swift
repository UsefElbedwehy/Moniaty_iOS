import XCTest

/// End-to-end walkthrough of both roles on the in-memory mocks. Screenshots go to
/// `WALKTHROUGH_SHOTS` (a host directory) when set, and are attached to the test result.
final class WalkthroughTests: XCTestCase {
    let app = XCUIApplication()
    private var shot = 0

    override func setUp() {
        continueAfterFailure = false
        app.launchEnvironment["UITEST_MOCK_BACKEND"] = "1"
        let lang = ProcessInfo.processInfo.environment["WALKTHROUGH_LANG"] ?? "en"
        app.launchArguments += ["-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "ar" ? "ar_SA" : "en_US"]
        addUIInterruptionMonitor(withDescription: "alerts") { alert in
            for label in ["Allow", "السماح", "OK", "حسنًا"] where alert.buttons[label].exists {
                alert.buttons[label].tap(); return true
            }
            return false
        }
    }

    func snap(_ name: String, tree: Bool = true) {
        sleep(1)
        shot += 1
        let file = String(format: "%02d-%@", shot, name)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = file
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["WALKTHROUGH_SHOTS"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(file).png"))
        }
        print("STEP \(file)")
        if tree { print("TREE>>> \(file)\n" + app.debugDescription + "\n<<<TREE") }
    }

    func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 8), "missing \(element)", file: file, line: line)
        element.tap()
    }

    func button(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
    }

    func signIn(role: String, phone: String, name: String) {
        tap(button(role))
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(phone)
        snap("phone-\(name)", tree: false)
        tap(button("Send code"))
        sleep(1)
        app.typeText("123456")
        snap("otp-\(name)")
    }

    func signOut(_ name: String) {
        tap(app.tabBars.buttons["Profile"])
        app.swipeUp(); app.swipeUp()
        snap("profile-bottom-\(name)", tree: false)
        tap(button("Sign out"))
        snap("signout-confirm-\(name)")
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Sign out'"))
        if confirm.count > 1 { confirm.element(boundBy: confirm.count - 1).tap() }
        sleep(1)
    }

    func testWalkthrough() throws {
        app.launch()
        signIn(role: "a bride", phone: "512345678", name: "bride")
        sleep(3)
        snap("home-bride", tree: false)
        tap(button("مكياج العروس"))
        snap("service-detail")
        app.swipeUp()
        snap("service-detail-scrolled", tree: false)
        tap(button("Request booking"))
        snap("request-sheet", tree: false)
        tap(button("Mon, 12"))
        tap(button("10:00"))
        snap("request-filled", tree: false)
        tap(button("Send booking request"))
        snap("request-sent", tree: false)
        tap(app.tabBars.buttons["Profile"])
        snap("profile-bride", tree: false)
        signOut("bride")
        signIn(role: "service provider", phone: "598765432", name: "provider")
        app.swipeUp()
        snap("studio-scrolled", tree: false)
        tap(app.tabBars.buttons["Bookings"])
        snap("provider-inbox", tree: false)
        tap(button("Awaiting approval"))
        snap("provider-request", tree: false)
        tap(button("Approve"))
        snap("provider-approved")
        signOut("provider")
        signIn(role: "a bride", phone: "512345678", name: "bride-2")
        tap(app.tabBars.buttons["My bookings"])
        snap("bride-bookings", tree: false)
        tap(button("MN-"))
        snap("bride-awaiting-payment", tree: false)
        tap(button("Pay and upload receipt"))
        snap("pay-sheet")
        tap(button("Attach receipt photo"))
        sleep(2)
        snap("photo-picker", tree: false)
        // The picker's grid cells report "not hittable"; tap by coordinate.
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 8))
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(2)
        snap("pay-filled", tree: false)
        app.swipeUp()
        snap("pay-filled-bottom", tree: false)
        tap(button("Send receipt"))
        snap("receipt-sent", tree: false)

        signOut("bride-2")
        signIn(role: "service provider", phone: "598765432", name: "provider-2")
        tap(app.tabBars.buttons["Bookings"])
        tap(button("MN-"))
        snap("provider-receipt")
        tap(button("Confirm payment received"))
        snap("provider-confirmed")
        tap(button("Service done"))
        snap("provider-completed")

        signOut("provider-2")
        signIn(role: "a bride", phone: "512345678", name: "bride-3")
        tap(app.tabBars.buttons["My bookings"])
        tap(app.buttons["Past"])
        snap("bride-past", tree: false)
        tap(button("MN-"))
        snap("bride-completed", tree: false)
        tap(button("Write a review"))
        tap(button("5 out of 5"))
        let reviewText = app.textFields.firstMatch
        reviewText.tap()
        reviewText.typeText("Lovely makeup, on time and very professional.")
        snap("review-filled", tree: false)
        tap(button("Send"))
        snap("review-sent", tree: false)
        app.swipeUp()
        snap("review-sent-scrolled", tree: false)

        signOut("bride-3")
        signIn(role: "service provider", phone: "598765432", name: "provider-3")
        tap(app.tabBars.buttons["Bookings"])
        tap(app.buttons["Past"])
        tap(button("MN-"))
        snap("provider-completed-review", tree: false)
    }

    /// The bride's main screens in Arabic (run with WALKTHROUGH_LANG=ar).
    func testArabicScreens() throws {
        app.launch()
        tap(button("أنا عروس"))
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("512345678")
        tap(button("إرسال الرمز"))
        sleep(1)
        app.typeText("123456")
        sleep(3)
        snap("ar-home", tree: false)
        tap(button("مكياج العروس"))
        snap("ar-detail", tree: false)
        tap(button("طلب حجز"))
        snap("ar-request", tree: false)
    }
}
