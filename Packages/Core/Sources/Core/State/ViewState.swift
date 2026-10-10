import Foundation

/// The single source of truth for what a screen renders. Every ViewModel exposes
/// exactly one `ViewState<T>` — never a cluster of booleans (`isLoading`, `hasError`, ...).
public enum ViewState<Value: Sendable>: Sendable {
    case loading
    case refreshing(Value)
    case loaded(Value)
    case empty
    case error(AppError)
    case offline

    public var value: Value? {
        switch self {
        case .loaded(let value), .refreshing(let value):
            return value
        case .loading, .empty, .error, .offline:
            return nil
        }
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var error: AppError? {
        if case .error(let error) = self { return error }
        return nil
    }

    /// Maps the loaded/refreshing payload, preserving every other case as-is.
    public func map<NewValue: Sendable>(_ transform: (Value) -> NewValue) -> ViewState<NewValue> {
        switch self {
        case .loading: return .loading
        case .refreshing(let value): return .refreshing(transform(value))
        case .loaded(let value): return .loaded(transform(value))
        case .empty: return .empty
        case .error(let error): return .error(error)
        case .offline: return .offline
        }
    }
}

extension ViewState: Equatable where Value: Equatable {}
