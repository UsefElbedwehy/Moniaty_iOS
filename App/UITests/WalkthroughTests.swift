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
        confirmSignOut("Sign out")
    }

    /// Sign out asks for confirmation: tap the dialog's button (the list's own is covered).
    func confirmSignOut(_ label: String) {
        let buttons = app.buttons.matching(NSPredicate(format: "label == %@", label))
        let dialog = (0..<buttons.count).map { buttons.element(boundBy: $0) }.first { $0.isHittable }
        dialog?.tap()
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

    // MARK: - Screen tour (polish pass)

    private var isArabic: Bool { (ProcessInfo.processInfo.environment["WALKTHROUGH_LANG"] ?? "en") == "ar" }
    private func t(_ en: String, _ ar: String) -> String { isArabic ? ar : en }

    /// Taps the first button containing `label` if it shows up; logs and carries on otherwise.
    @discardableResult
    func go(_ label: String, in query: XCUIElementQuery? = nil) -> Bool {
        let element = (query ?? app.buttons).matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        // At large text sizes the target is often below the fold: scroll a little before giving up.
        for _ in 0..<3 where !(element.waitForExistence(timeout: 2) && element.isHittable) { app.swipeUp() }
        guard element.waitForExistence(timeout: 3) else {
            print("TOUR missing: \(label) among \(app.buttons.allElementsBoundByIndex.prefix(30).map(\.label))")
            return false
        }
        if element.isHittable { element.tap() } else { element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        return true
    }

    func back() {
        let button = app.navigationBars.buttons.firstMatch
        if button.waitForExistence(timeout: 3) { button.tap() }
        sleep(1)
    }

    func dismissSheet() {
        let close = app.buttons.matching(NSPredicate(format: "label IN %@",
            [t("Cancel", "إلغاء"), t("Done", "تم"), t("Close", "إغلاق")])).firstMatch
        if close.waitForExistence(timeout: 2) { close.tap() } else { app.swipeDown(velocity: .fast) }
        sleep(1)
    }

    func tab(_ symbol: String) {
        let button = app.tabBars.buttons[symbol]
        if button.waitForExistence(timeout: 5) { button.tap() } else { print("TOUR missing tab: \(symbol)") }
        sleep(1)
    }

    func tourSignIn(bride: Bool) {
        go(bride ? t("a bride", "أنا عروس") : t("service provider", "أنا مقدّمة خدمة"))
        let field = app.textFields.firstMatch
        _ = field.waitForExistence(timeout: 5)
        snap("auth-phone-empty", tree: false)
        field.typeText(bride ? "512345678" : "598765432")
        go(t("Send code", "إرسال الرمز"))
        sleep(1)
        snap("auth-otp", tree: false)
        app.typeText("123456")
        sleep(3)
    }

    /// Every screen reachable on the mocks, for both roles. Variant comes from the environment
    /// (WALKTHROUGH_LANG, WALKTHROUGH_TYPE); dark mode is the simulator's appearance setting.
    func testScreenTour() throws {
        continueAfterFailure = true
        if let size = ProcessInfo.processInfo.environment["WALKTHROUGH_TYPE"] {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
        }
        app.launch()
        snap("landing")
        tourSignIn(bride: true)

        // Bride: empty states first, before anything is booked or saved.
        tab("calendar"); snap("bride-bookings-empty", tree: false)
        tab("map"); sleep(2); snap("bride-explore", tree: false)
        tab("person"); snap("bride-profile", tree: false)
        go(t("Favorites", "المفضلة")); snap("bride-favorites-empty", tree: false); back()
        go(t("Wedding budget", "ميزانية الزفاف")); snap("bride-budget", tree: false); dismissSheet(); back()
        go(t("Cities", "المدن")); snap("bride-cities", tree: false); dismissSheet()
        go(t("Help and support", "الدعم والمساعدة")); snap("bride-support", tree: false); back()
        go(t("Blocked accounts", "الحسابات المحظورة")); snap("bride-blocked-empty", tree: false); back()
        go(t("Terms", "الشروط والأحكام")); sleep(1); snap("bride-terms", tree: false); back()

        tab("house"); snap("bride-home", tree: false)
        app.swipeUp(); snap("bride-home-scrolled", tree: false); app.swipeDown()
        go(t("Search services or providers", "ابحثي عن خدمة أو مقدّمة خدمة")); sleep(1); snap("bride-search", tree: false)
        let searchField = app.searchFields.count > 0 ? app.searchFields.firstMatch : app.textFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap(); searchField.typeText(t("zzz", "ززز")); sleep(2)
            snap("bride-search-no-results", tree: false)
        }
        dismissSheet(); back()
        tab("house")
        go(t("Makeup artist", "خبيرة مكياج")); sleep(1); snap("bride-category", tree: false); back()
        go("مكياج العروس"); snap("bride-service", tree: false)
        go("لمسة جمال"); sleep(1); snap("bride-provider", tree: false)
        app.swipeUp(); snap("bride-provider-scrolled", tree: false); back()
        go(t("Request booking", "طلب حجز")); snap("bride-request", tree: false)
        let day = app.scrollViews.buttons.element(boundBy: 2)
        if day.waitForExistence(timeout: 3) { day.tap() }
        sleep(1)
        let slot = app.buttons.matching(NSPredicate(format: "label CONTAINS ':'")).firstMatch
        if slot.waitForExistence(timeout: 3) { slot.tap() }
        go(t("Send booking request", "إرسال طلب الحجز")); sleep(1)
        snap("bride-booking-requested", tree: false)
        tab("calendar"); snap("bride-bookings-list", tree: false)

        // Provider: studio, editors, plans, inbox.
        tab("person"); app.swipeUp(); app.swipeUp()
        go(t("Sign out", "تسجيل الخروج")); sleep(1)
        snap("profile-signout-confirm", tree: false)
        confirmSignOut(t("Sign out", "تسجيل الخروج"))
        tourSignIn(bride: false)
        snap("provider-studio", tree: false)
        app.swipeUp(); snap("provider-studio-scrolled", tree: false); app.swipeDown()
        go(t("Business profile", "ملف النشاط")); sleep(1); snap("provider-business", tree: false)
        app.swipeUp(); snap("provider-business-scrolled", tree: false); app.swipeDown(); app.swipeDown()
        // Saving a name approves the mock provider, which unlocks plans and insights.
        let name = app.textFields[t("Business name", "اسم النشاط")]
        if name.waitForExistence(timeout: 3) { name.tap(); name.typeText(t("Lamsa Beauty", "لمسة جمال")) }
        go(t("Save", "حفظ")); sleep(2)
        if app.navigationBars.buttons[t("Save", "حفظ")].exists { back() }
        go(t("My services", "خدماتي")); sleep(1); snap("provider-services-empty", tree: false)
        if go(t("Add", "إضافة")) { sleep(1); snap("provider-service-editor", tree: false); dismissSheet() }
        back()
        go(t("My stores", "متاجري")); sleep(1); snap("provider-stores-empty", tree: false); back()
        app.swipeUp()
        go(t("Working hours", "أوقات العمل")); sleep(1); snap("provider-hours", tree: false); back()
        go(t("Payout methods", "طرق استلام المبالغ")); sleep(1); snap("provider-payout-empty", tree: false); back()
        go(t("Plan and subscription", "الباقة والاشتراك")); sleep(1); snap("provider-plans", tree: false); back()
        go(t("Insights", "الإحصائيات")); sleep(1); snap("provider-insights", tree: false); back()
        tab("calendar"); snap("provider-inbox", tree: false)
        go("MN-"); sleep(1); snap("provider-booking", tree: false)
    }
}
