import SwiftUI

/// A cross-cutting hook for feature views to gate identity-requiring actions (e.g. posting a
/// review) behind a real sign-in, without every feature having to know about the app's session
/// model. The composition root injects it once via `.environment(\.authGate, …)`; a feature reads
/// `@Environment(\.authGate)` and, when `isGuest` is true, calls `requireSignIn()` to raise the
/// sign-in flow instead of performing the action.
///
/// "Guest" here means *not a real account* — both a not-yet-authenticated user and an anonymous
/// "Browse as guest" session count as guests, since neither should be able to review.
public struct AuthGate: Sendable {
    public let isGuest: Bool
    /// MainActor-isolated so it can safely capture the app's (MainActor) session state, and
    /// `@Sendable` so `AuthGate` itself is `Sendable` (required for the environment default).
    public let requireSignIn: @MainActor @Sendable () -> Void

    public init(isGuest: Bool, requireSignIn: @escaping @MainActor @Sendable () -> Void) {
        self.isGuest = isGuest
        self.requireSignIn = requireSignIn
    }

    /// Default: treat the user as a real account and do nothing on `requireSignIn` — so previews
    /// and any view rendered without an injected gate behave as before (no accidental gating).
    public static let allowAll = AuthGate(isGuest: false, requireSignIn: {})
}

public extension EnvironmentValues {
    var authGate: AuthGate {
        get { self[AuthGateKey.self] }
        set { self[AuthGateKey.self] = newValue }
    }
}

private struct AuthGateKey: EnvironmentKey {
    static let defaultValue = AuthGate.allowAll
}
