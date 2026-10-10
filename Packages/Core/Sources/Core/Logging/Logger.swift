import Foundation
import os

/// Thin abstraction over `os.Logger` so call sites depend on a protocol, not a concrete
/// logging framework — keeps `Core` swappable and unit tests silent by default.
public protocol AppLogging: Sendable {
    func debug(_ message: @autoclosure () -> String, category: LogCategory)
    func info(_ message: @autoclosure () -> String, category: LogCategory)
    func warning(_ message: @autoclosure () -> String, category: LogCategory)
    func error(_ message: @autoclosure () -> String, category: LogCategory)
}

public enum LogCategory: String, Sendable {
    case network, navigation, cache, auth, lifecycle
}

public struct OSAppLogger: AppLogging {
    private let subsystem: String

    public init(subsystem: String = Bundle.main.bundleIdentifier ?? "Munyati") {
        self.subsystem = subsystem
    }

    public func debug(_ message: @autoclosure () -> String, category: LogCategory) {
        let resolved = message()
        Logger(subsystem: subsystem, category: category.rawValue).debug("\(resolved, privacy: .public)")
    }

    public func info(_ message: @autoclosure () -> String, category: LogCategory) {
        let resolved = message()
        Logger(subsystem: subsystem, category: category.rawValue).info("\(resolved, privacy: .public)")
    }

    public func warning(_ message: @autoclosure () -> String, category: LogCategory) {
        let resolved = message()
        Logger(subsystem: subsystem, category: category.rawValue).warning("\(resolved, privacy: .public)")
    }

    public func error(_ message: @autoclosure () -> String, category: LogCategory) {
        let resolved = message()
        Logger(subsystem: subsystem, category: category.rawValue).error("\(resolved, privacy: .public)")
    }
}
