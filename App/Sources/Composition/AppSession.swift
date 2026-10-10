import SwiftUI
import Observation
import Authentication
import Booking

/// Who is using the app right now. Decides which shell `RootView` shows:
/// - `.checking`: launch only, restoring the Keychain session (splash).
/// - `.signedOut`: no session; show the landing screen (role choice).
/// - `.signedIn`: a session exists. An anonymous session is a guest browsing as a bride;
///   `role` comes from the server profile and is nil until it has loaded.
@MainActor
@Observable
final class AppSession {
    enum State: Equatable {
        case checking
        case signedOut
        case signedIn(SessionUser)
    }

    struct SessionUser: Equatable {
        let id: String
        var role: UserRole?
        var isAnonymous: Bool
        var displayName: String?
    }

    var state: State = .checking

    /// Set when a guest taps something that needs an account (book, favorite, review, report).
    var isPresentingAuth = false

    /// Set when a screen asks for the city picker (Home's city button).
    var isPickingCities = false

    /// The service a bride tapped "Book" on; presents the booking request sheet.
    var bookingRequest: BookableService?

    init() {
        // UI-test hooks: start signed in as a given role so automated runs skip OTP.
        let env = ProcessInfo.processInfo.environment
        if let raw = env["UITEST_START_ROLE"], let role = UserRole(rawValue: raw) {
            state = .signedIn(SessionUser(id: "uitest-user", role: role, isAnonymous: false, displayName: "Test"))
        }
    }

    var user: SessionUser? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    /// A real (non-anonymous) account.
    var hasAccount: Bool { user.map { !$0.isAnonymous } ?? false }

    var role: UserRole? { user?.role }
}
