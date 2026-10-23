import Testing
@testable import Shared

@Suite("RemoteStrings")
struct RemoteStringsTests {
    @Test("falls back to the bundled value when there is no override")
    func fallsBack() {
        let strings = RemoteStrings()
        #expect(strings.string("tab.home", fallback: "Home") == "Home")
    }

    @Test("an installed override wins; an empty override is ignored")
    func overrideWins() {
        let strings = RemoteStrings()
        strings.install(["tab.home": "الرئيسية", "tab.explore": ""])
        #expect(strings.string("tab.home", fallback: "Home") == "الرئيسية")
        #expect(strings.string("tab.explore", fallback: "Explore") == "Explore")
    }
}
