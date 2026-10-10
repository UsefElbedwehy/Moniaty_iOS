import Foundation

/// Configuration for the networking layer: where to send requests, what headers
/// to attach to every request by default, and how long to wait before timing out.
public struct NetworkConfiguration: Sendable {
    public let baseURL: URL
    public let defaultHeaders: [String: String]
    public let timeoutInterval: TimeInterval

    public init(
        baseURL: URL,
        defaultHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval = 30
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.timeoutInterval = timeoutInterval
    }
}
