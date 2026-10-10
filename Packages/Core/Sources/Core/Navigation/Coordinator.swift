import SwiftUI

/// A coordinator owns navigation state for one feature (or the app root) and is the
/// only thing allowed to push/present/dismiss. Views describe *intent* (call a method
/// on the coordinator); they never construct or push another view directly.
@MainActor
public protocol Coordinator: AnyObject, Observable {
    associatedtype Route: Hashable

    var path: NavigationPath { get set }
    var presentedSheet: Route? { get set }
    var presentedFullScreenCover: Route? { get set }

    func push(_ route: Route)
    func pop()
    func popToRoot()
    func present(sheet route: Route)
    func present(fullScreenCover route: Route)
    func dismissPresented()
}

/// Default, storage-agnostic implementations so conforming coordinators only need to
/// declare their `Route` type and hold the `path`/`presentedSheet` storage.
extension Coordinator {
    public func push(_ route: Route) {
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func popToRoot() {
        path.removeLast(path.count)
    }

    public func present(sheet route: Route) {
        presentedSheet = route
    }

    public func present(fullScreenCover route: Route) {
        presentedFullScreenCover = route
    }

    public func dismissPresented() {
        presentedSheet = nil
        presentedFullScreenCover = nil
    }
}

/// A factory builds the SwiftUI view for a given route. Keeping this separate from the
/// coordinator means the coordinator stays pure navigation state — no view construction —
/// and the factory can be unit tested (or swapped for previews) independently.
@MainActor
public protocol ViewFactory {
    associatedtype Route: Hashable
    associatedtype Content: View

    @ViewBuilder
    func makeView(for route: Route) -> Content
}
