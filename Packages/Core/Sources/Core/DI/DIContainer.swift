import Foundation

/// A minimal, protocol-based service locator used only at each feature's composition
/// root (its `DI/` folder). Features register their own concrete dependencies against
/// protocols here; nothing below the DI layer ever imports this type directly —
/// ViewModels receive their dependencies through plain initializer injection.
public protocol DIContainer: AnyObject {
    func register<Service>(_ type: Service.Type, factory: @escaping @Sendable (any DIContainer) -> Service)
    func resolve<Service>(_ type: Service.Type) -> Service
}

/// Default container implementation. Not a singleton — the `App` composition root
/// creates one root container per app launch and feature-level containers wrap it.
public final class AppDIContainer: DIContainer, @unchecked Sendable {
    private var factories: [ObjectIdentifier: @Sendable (any DIContainer) -> Any] = [:]
    private let lock = NSLock()

    public init() {}

    public func register<Service>(_ type: Service.Type, factory: @escaping @Sendable (any DIContainer) -> Service) {
        lock.lock()
        defer { lock.unlock() }
        factories[ObjectIdentifier(type)] = factory
    }

    public func resolve<Service>(_ type: Service.Type) -> Service {
        lock.lock()
        let factory = factories[ObjectIdentifier(type)]
        lock.unlock()
        guard let factory, let service = factory(self) as? Service else {
            preconditionFailure("No registration found for \(String(describing: type)). Register it in the owning feature's DI container before resolving.")
        }
        return service
    }
}
