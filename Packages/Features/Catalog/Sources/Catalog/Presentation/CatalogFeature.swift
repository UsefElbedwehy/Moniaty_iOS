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
    /// Whom a customer browses for. The server filters Home, search and the map by the saved
    /// value; it is mirrored here only so those screens reload when she changes it.
    public var audience: Audience?
    /// Short label for the city button, e.g. "الدمام، الخبر".
    public var citySummary: String
    public var displayName: String?
    /// The account's phone, to pre-fill Bride details.
    public var phone: String?
    /// Guests (no account) are asked to sign in before favoriting or setting a budget.
    public var isGuest: Bool
    /// False for provider accounts: bookings are made from a bride account (which can be created
    /// on the same number), so the service page shows a note instead of the Book button.
    public var canBook = true
    /// The built-in Home slides (budget, discover); the dashboard can hide them to leave the
    /// carousel to paid banners.
    public var showsBudgetSlide = true
    public var showsDiscoverSlide = true
    /// Every city the app serves, for the bride's wedding city in "Bride details".
    public var cities: [City] = []

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
    let preparations: PreparationsStore
    let brideDetails: BrideDetailsStore
    let openCityPicker: () -> Void
    let requireSignIn: () -> Void
    /// The "Book" action on a service. Phase 3 wires the booking flow; nil shows "coming soon".
    var onBook: ((ServiceCard) -> Void)?
    /// Reviews and report/block menus from the Trust feature (Phase 5).
    var trustViews: CatalogTrustViews?
    /// Opens a Home banner's link: app links go through the App's deep-link router, other
    /// pages open in the browser. Set by the App.
    var openLink: ((URL) -> Void)?

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
        self.preparations = PreparationsStore(repository: repository)
        self.brideDetails = BrideDetailsStore(repository: repository)
        budget.afterSave = { [brideDetails, context] in
            Task { await brideDetails.load(isGuest: context.isGuest) }
        }
    }

    /// Reloads per-account state after sign-in / sign-out.
    public func accountChanged() {
        favorites.reset()
        Task { await budget.load(isGuest: context.isGuest) }
        Task { await preparations.load(isGuest: context.isGuest) }
        Task { await brideDetails.load(isGuest: context.isGuest) }
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
        case .preparations: PreparationsScreen(feature: self)
        case .brideDetails: BrideDetailsScreen(feature: self)
        case .dresses: DressesScreen(feature: self)
        }
    }

    /// What is left of the bride's budget (nil without one), for the booking request.
    public var remainingBudget: Decimal? { budget.budget?.remaining }

    /// Reloads the budget after bookings change what is reserved.
    public func refreshBudget() {
        Task { await budget.load(isGuest: context.isGuest) }
    }

    /// Sets the reviews section and the report/block menu (Phase 5).
    public func setTrustViews(_ views: CatalogTrustViews) {
        trustViews = views
    }

    /// Sets how a banner's link opens (the App's deep-link router).
    public func setLinkHandler(_ handler: @escaping (URL) -> Void) {
        openLink = handler
    }

    /// The bride's budget, for Profile.
    public var currentBudget: Budget? { budget.budget }

    /// "My preparations" progress for Profile: done and total (nil before it has loaded).
    public var preparationsProgress: (done: Int, total: Int)? {
        guard preparations.hasLoaded else { return nil }
        return (preparations.items.filter(\.isDone).count, preparations.items.count)
    }

    /// Days until the wedding (nil without a date or once it has passed), for Home and Profile.
    public var daysUntilWedding: Int? { Budget.daysUntil(weddingDate) }

    /// The wedding date, "yyyy-MM-dd": from Bride details, else the budget (they are kept equal).
    public var weddingDate: String? { brideDetails.details?.weddingDate ?? budget.budget?.weddingDate }

    /// The bride's details, for Profile.
    public var currentBrideDetails: BrideDetails? { brideDetails.details }

    /// How many services the bride saved, for Profile.
    public func favoritesCount() async -> Int? {
        guard !context.isGuest else { return nil }
        return try? await repository.favorites().count
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

    /// Runs after a save (the wedding date it holds is shared with Bride details).
    var afterSave: (() -> Void)?

    func save(total: Decimal, weddingDate: String?) async throws {
        budget = try await repository.setBudget(total: total, weddingDate: weddingDate)
        afterSave?()
    }
}

/// The bride's details (تفاصيل العروس), loaded with her account and edited from Profile.
@MainActor
@Observable
public final class BrideDetailsStore {
    public private(set) var details: BrideDetails?
    private let repository: CatalogRepository

    init(repository: CatalogRepository) {
        self.repository = repository
    }

    func load(isGuest: Bool) async {
        guard !isGuest else { details = nil; return }
        if let loaded = try? await repository.brideDetails() { details = loaded }
    }

    func save(_ new: BrideDetails) async throws {
        details = try await repository.setBrideDetails(new)
    }
}

/// The bride's "My preparations" checklist (تجهيزاتي). Ticking an item shows at once and is
/// undone if the server refuses; every other change shows the list the server sends back.
@MainActor
@Observable
public final class PreparationsStore {
    public private(set) var items: [Preparation] = []
    public private(set) var hasLoaded = false
    private let repository: CatalogRepository

    init(repository: CatalogRepository) {
        self.repository = repository
    }

    var open: [Preparation] { items.filter { !$0.isDone } }
    var done: [Preparation] { items.filter(\.isDone) }

    func load(isGuest: Bool) async {
        guard !isGuest else { items = []; hasLoaded = false; return }
        if let loaded = try? await repository.preparations() {
            items = loaded
            hasLoaded = true
        }
    }

    /// Loads, throwing, for the screen's first load and pull to refresh.
    func reload() async throws {
        items = try await repository.preparations()
        hasLoaded = true
    }

    func save(id: String?, title: String, note: String?) async throws {
        items = try await repository.savePreparation(id: id, title: title, note: note)
    }

    func toggle(_ item: Preparation) async throws {
        let before = items
        if let index = items.firstIndex(where: { $0.id == item.id }) { items[index].isDone.toggle() }
        do {
            items = try await repository.setPreparationDone(id: item.id, done: !item.isDone)
        } catch {
            items = before
            throw error
        }
    }

    func delete(_ item: Preparation) async throws {
        items = try await repository.deletePreparation(id: item.id)
    }
}

/// Maps any thrown error to an `AppError` for `ViewState`.
func appError(_ error: Error) -> AppError {
    (error as? AppError) ?? .unknown(message: error.localizedDescription)
}

/// Content a catalog screen can report.
public enum CatalogContentRef: Hashable, Sendable {
    case provider(String), service(String), store(String)
}

/// Views supplied by the App from the Trust feature, so Catalog doesn't depend on it.
public struct CatalogTrustViews {
    let reviews: (String) -> AnyView
    let moreMenu: (CatalogContentRef) -> AnyView

    public init(reviews: @escaping (String) -> AnyView, moreMenu: @escaping (CatalogContentRef) -> AnyView) {
        self.reviews = reviews
        self.moreMenu = moreMenu
    }
}
