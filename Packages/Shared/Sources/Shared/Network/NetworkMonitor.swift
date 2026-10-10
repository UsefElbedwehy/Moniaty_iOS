import Foundation
import Network

/// Wraps `NWPathMonitor` and publishes connectivity on the main actor so SwiftUI views
/// can observe `isConnected` directly and feed `Core`'s `ViewState<T>.offline` case.
@Observable
@MainActor
public final class NetworkMonitor {
    public private(set) var isConnected: Bool = true

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "Munyati.Shared.NetworkMonitor")

    public init(monitorProvider: () -> NWPathMonitor = { NWPathMonitor() }) {
        let monitor = monitorProvider()
        self.monitor = monitor

        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
