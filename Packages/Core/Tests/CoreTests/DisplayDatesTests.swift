import Foundation
import Testing
@testable import Core

@Suite("Display dates")
struct DisplayDatesTests {
    private let date = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: .gmt,
                                      year: 2026, month: 10, day: 10, hour: 12).date!

    @Test("the display calendar is Gregorian")
    func gregorian() {
        #expect(Calendar.display.identifier == .gregorian)
    }

    @Test("Saudi Arabic formatting shows the Gregorian year, not the Umm al-Qura one")
    func saudiArabicYear() {
        let text = date.displayFormatted(.dateTime.year().locale(Locale(identifier: "ar_SA")))
        #expect(text.contains("٢٠٢٦"))
        #expect(!text.contains("١٤٤٨"))
    }
}
