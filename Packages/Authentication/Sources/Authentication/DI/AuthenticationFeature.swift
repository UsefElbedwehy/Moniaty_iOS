import SwiftUI
import Core

/// Public entry point for the Authentication feature. The App composition root builds one of
/// these with a chosen `AuthRepository` (mock today, remote once a backend exists) and an
/// `onFinished` callback, then mounts `rootView()`. Nothing outside this type needs to know about
/// the feature's view models, coordinator, or factory.
///
/// `onFinished` fires exactly once with the terminal `AuthState` — `.authenticated(user)` after a
/// verified code, or `.guest` after "Browse as guest". The feature does not decide what happens
/// next; the App does.
@MainActor
public struct AuthenticationFeature {
    private let coordinator: AuthCoordinator
    private let factory: AuthFactory

    public init(repository: AuthRepository, onFinished: @escaping (AuthState) -> Void) {
        let coordinator = AuthCoordinator(onFinished: onFinished)
        self.coordinator = coordinator
        self.factory = AuthFactory(useCases: AuthUseCases(repository: repository), coordinator: coordinator)
    }

    /// The feature's navigable root: a `NavigationStack` rooted at Onboarding, bound to the
    /// coordinator's path. Mount this as the app's root while unauthenticated.
    public func rootView() -> some View {
        AuthRootView(coordinator: coordinator, factory: factory)
    }

    /// Convenience: a mock-backed instance so the App can mount auth with one call today, before
    /// a backend exists.
    public static func makeDefault(onFinished: @escaping (AuthState) -> Void) -> AuthenticationFeature {
        AuthenticationFeature(repository: MockAuthRepository(), onFinished: onFinished)
    }
}

/// Hosts the navigation stack and binds it to the coordinator's path so every push/pop the
/// coordinator performs drives SwiftUI navigation.
private struct AuthRootView: View {
    @State var coordinator: AuthCoordinator
    let factory: AuthFactory

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            factory.makeRoot()
                .navigationDestination(for: AuthRoute.self) { route in
                    factory.makeView(for: route)
                }
        }
    }
}
