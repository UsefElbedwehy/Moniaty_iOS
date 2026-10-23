import os

/// App-target logging categories. Feature packages have their own loggers; this covers the
/// composition-root concerns (push, DI wiring) that live only in the App target.
enum AppLog {
    static let push = Logger(subsystem: "com.munyati.app", category: "push")
    static let composition = Logger(subsystem: "com.munyati.app", category: "composition")
}
