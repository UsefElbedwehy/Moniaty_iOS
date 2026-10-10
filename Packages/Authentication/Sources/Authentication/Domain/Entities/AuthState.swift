import Foundation

/// The two terminal outcomes of the auth flow. "Auth is never a wall" — `guest` is a
/// first-class state the App can run the whole app on, not an error or a stub.
public enum AuthState: Equatable, Sendable {
    case guest
    case authenticated(User)
}
