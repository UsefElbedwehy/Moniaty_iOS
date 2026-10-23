import Testing
@testable import Core

@Suite("ViewState")
struct ViewStateTests {
    @Test("value(for:) returns the payload only for loaded/refreshing")
    func valueExtraction() {
        #expect(ViewState<Int>.loaded(42).value == 42)
        #expect(ViewState<Int>.refreshing(7).value == 7)
        #expect(ViewState<Int>.loading.value == nil)
        #expect(ViewState<Int>.empty.value == nil)
        #expect(ViewState<Int>.offline.value == nil)
        #expect(ViewState<Int>.error(.offline).value == nil)
    }

    @Test("isLoading is true only for .loading")
    func loadingFlag() {
        #expect(ViewState<Int>.loading.isLoading)
        #expect(!ViewState<Int>.refreshing(1).isLoading)
        #expect(!ViewState<Int>.loaded(1).isLoading)
    }

    @Test("map transforms the payload and preserves every other case")
    func mapping() {
        #expect(ViewState<Int>.loaded(2).map { $0 * 10 } == .loaded(20))
        #expect(ViewState<Int>.refreshing(2).map { $0 * 10 } == .refreshing(20))
        #expect(ViewState<Int>.loading.map { $0 * 10 } == .loading)
        #expect(ViewState<Int>.empty.map { $0 * 10 } == .empty)
        #expect(ViewState<Int>.offline.map { $0 * 10 } == .offline)
        #expect(ViewState<Int>.error(.offline).map { $0 * 10 } == .error(.offline))
    }
}
