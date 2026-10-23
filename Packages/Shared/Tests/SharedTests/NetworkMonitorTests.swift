import Testing
@testable import Shared

@Suite("NetworkMonitor")
@MainActor
struct NetworkMonitorTests {
    @Test("initializes without crashing and has a sane default state")
    func initializesWithDefaultState() {
        let monitor = NetworkMonitor()
        // NWPathMonitor hasn't necessarily delivered its first update yet, but the
        // monitor must start in a well-defined, non-crashing state biased toward
        // "connected" so UI doesn't flash an offline state on launch.
        #expect(monitor.isConnected == true)
    }
}
