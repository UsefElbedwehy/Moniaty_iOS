import SwiftUI
import Observation
import Core
import Shared

/// What the catalog needs from the App, kept observable so screens reload when it changes
/// (e.g. the bride picks other cities).
@MainActor
@Observable
public final class CatalogContext {
    /// nil = all cities.
    public var cityIds: [String]?
    /// Short label for the city button, e.g. "الدمام، الخبر".
    public var citySummary: String
    public var displayName: String?
    /// Guests (no account) are asked to sign in before favoriting or setting a budget.
    public var isGuest: Bool

    public init(cityIds: [String]? = nil, citySummary: String = "", displayName: String? = nil, isGuest: Bool = true) {
        self.cityIds = cityIds
        self.citySummary = citySummary
        self.displayName = displayName
        self.isGuest = isGuest
    }
}

/// Public entry point of the Catalog feature (bride discovery: Home, search, details, map,
/// favorites, budget). The App builds one, mounts its screens in the tab shell and registers
/// `destination(for:)` on each NavigationStack.
@MainActor
public final class CatalogFeature {
    public let context: CatalogContext
    let repository: CatalogRepository
    let favorites: FavoritesStore
    let budget: BudgetStore
    let openCityPicker: () -> Void
    let requireSignIn: () -> Void
    /// The "Book" action on a service. Phase 3 wires the booking flow; nil shows "coming soon".
    var onBook: ((ServiceCard) -> Void)?

    public init(
        repository: CatalogRepository,
        context: CatalogContext,
        openCityPicker: @escaping () -> Void,
        requireSignIn: @escaping () -> Void
    ) {
        self.repository = repository
        self.context = context
        self.openCityPicker = openCityPicker
        self.requireSignIn = requireSignIn
        self.favorites = FavoritesStore(repository: repository)
        self.budget = BudgetStore(repository: repository)
    }

    /// Reloads per-account state after sign-in / sign-out.
    public func accountChanged() {
        favorites.reset()
        Task { await budget.load(isGuest: context.isGuest) }
    }

    public func homeScreen() -> some View {
        HomeScreen(feature: self)
    }

    public func exploreScreen() -> some View {
        ExploreScreen(feature: self)
    }

    /// The budget editor, for presenting from outside Home (e.g. Profile).
    public func budgetEditor() -> some View {
        BudgetSheet(store: budget)
    }

    @ViewBuilder
    public func destination(for route: CatalogRoute) -> some View {
        switch route {
        case .services(let filter): ServiceListScreen(feature: self, initialFilter: filter)
        case .service(let id): ServiceDetailScreen(feature: self, serviceId: id)
        case .provider(let id): ProviderScreen(feature: self, providerId: id)
        case .store(let id): StoreScreen(feature: self, storeId: id)
        case .favorites: FavoritesScreen(feature: self)
        }
    }

    /// Sets the booking entry point (Phase 3).
    public func setBookingHandler(_ handler: @escaping (ServiceCard) -> Void) {
        onBook = handler
    }

    func toggleFavorite(_ card: ServiceCard) {
        guard !context.isGuest else { requireSignIn(); return }
        Task { await favorites.toggle(card) }
    }
}

/// Favorite state shared by every card on screen, so a heart tapped in one list updates the
/// others immediately (optimistic, rolled back on failure).
@MainActor
@Observable
final class FavoritesStore {
    private var overrides: [String: Bool] = [:]
    private let repository: CatalogRepository

    init(repository: CatalogRepository) {
        self.repository = repository
    }

    func isFavorite(_ card: ServiceCard) -> Bool {
        overrides[card.id] ?? card.isFavorite
    }

    func toggle(_ card: ServiceCard) async {
        let wanted = !isFavorite(card)
        overrides[card.id] = wanted
        do {
            overrides[card.id] = try await repository.toggleFavorite(serviceId: card.id)
        } catch {
            overrides[card.id] = !wanted
        }
    }

    func reset() {
        overrides.removeAll()
    }
}

/// The bride's budget (requirement 13): loaded once, edited from Home or Profile.
@MainActor
@Observable
public final class BudgetStore {
    public private(set) var budget: Budget?
    private let repository: CatalogRepository

    init(repository: CatalogRepository) {
        self.repository = repository
    }

    /// The cap for "within my budget" filters, or nil when no budget is set.
    var maxPrice: Decimal? { budget?.remaining }

    func load(isGuest: Bool) async {
        guard !isGuest else { budget = nil; return }
        if let loaded = try? await repository.budget() { budget = loaded }
    }

    func save(total: Decimal, weddingDate: String?) async throws {
        budget = try await repository.setBudget(total: total, weddingDate: weddingDate)
    }
}

/// Maps any thrown error to an `AppError` for `ViewState`.
func appError(_ error: Error) -> AppError {
    (error as? AppError) ?? .unknown(message: error.localizedDescription)
}
