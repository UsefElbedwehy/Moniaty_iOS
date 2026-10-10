import Foundation

/// Centralized error type for the whole app. Every layer (Networking, Data, Domain)
/// maps its own failures into this type before they cross into Presentation, so a
/// ViewModel only ever has to switch over one error type with localized, user-facing copy.
public enum AppError: Error, Equatable, Sendable {
    case network(NetworkFailureReason)
    case validation(field: String?, message: String)
    case authentication(AuthFailureReason)
    case server(statusCode: Int, message: String?)
    case offline
    case unknown(message: String?)

    public enum NetworkFailureReason: Sendable, Equatable {
        case timedOut
        case noConnection
        case cancelled
        case decodingFailed
        case invalidResponse
    }

    public enum AuthFailureReason: Sendable, Equatable {
        case invalidCredentials
        case sessionExpired
        case otpExpired
        case otpIncorrect
        case notAuthenticated
    }
}

extension AppError: LocalizedError {
    /// User-facing, localized message. Keys resolve through the app's string catalog;
    /// this package ships an English fallback so `Core` has no dependency on `Shared`.
    public var errorDescription: String? {
        switch self {
        case .network(.timedOut):
            return String(localized: "error.network.timedOut", defaultValue: "The request timed out. Please try again.")
        case .network(.noConnection):
            return String(localized: "error.network.noConnection", defaultValue: "You're offline. Check your connection and try again.")
        case .network(.cancelled):
            return String(localized: "error.network.cancelled", defaultValue: "The request was cancelled.")
        case .network(.decodingFailed), .network(.invalidResponse):
            return String(localized: "error.network.invalidResponse", defaultValue: "Something went wrong on our end. Please try again.")
        case .validation(_, let message):
            return message
        case .authentication(.invalidCredentials):
            return String(localized: "error.auth.invalidCredentials", defaultValue: "Those credentials don't look right.")
        case .authentication(.sessionExpired):
            return String(localized: "error.auth.sessionExpired", defaultValue: "Your session expired. Please sign in again.")
        case .authentication(.otpExpired):
            return String(localized: "error.auth.otpExpired", defaultValue: "That code expired. Request a new one.")
        case .authentication(.otpIncorrect):
            return String(localized: "error.auth.otpIncorrect", defaultValue: "That code isn't correct.")
        case .authentication(.notAuthenticated):
            return String(localized: "error.auth.notAuthenticated", defaultValue: "Please sign in to continue.")
        case .server(_, let message):
            return message ?? String(localized: "error.server.generic", defaultValue: "Our servers had a problem. Please try again shortly.")
        case .offline:
            return String(localized: "error.offline", defaultValue: "You're offline. Some content may be out of date.")
        case .unknown(let message):
            return message ?? String(localized: "error.unknown", defaultValue: "Something unexpected happened.")
        }
    }
}
