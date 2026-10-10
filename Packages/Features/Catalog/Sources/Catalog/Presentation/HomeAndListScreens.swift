import SwiftUI
import Core
import DesignSystem
import Shared

// MARK: - Home (mockup 2)

struct HomeScreen: View {
    let feature: CatalogFeature
    @State private var state: ViewState<HomeContent> = .loading
    @State private var showBudget = false
    @Environment(\.analytics) private var analytics

    private var context: CatalogContext { feature.context }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                header
                if !context.isGuest {
                    BudgetCardView(budget: feature.budget.budget) { showBudget = true }
                }
                NavigationLink(value: CatalogRoute.services(ServiceFilter(title: CatalogL10n.string("search.title")))) {
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                        CatalogL10n.text("search.placeholder")
                        Spacer()
                    }
                    .font(.dsBody)
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.horizontal, DSSpacing.md)
                    .frame(minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.dsSurface))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.dsBorder))
                }
                .buttonStyle(.plain)

                LoadableContent(state: state, retry: reload) { home in
                    VStack(alignment: .leading, spacing: DSSpacing.xl) {
                        categories(home.categories)
                        ServiceCarousel(
                            title: CatalogL10n.string(feature.budget.budget == nil ? "home.featured" : "home.withinBudget"),
                            cards: home.featured,
                            feature: feature,
                            seeAll: .services(ServiceFilter(title: CatalogL10n.string("home.withinBudget"),
                                                             withinBudget: feature.budget.budget != nil))
                        )
                        ServiceCarousel(
                            title: CatalogL10n.string("home.newest"),
                            cards: home.newest,
                            feature: feature,
                            seeAll: .services(ServiceFilter(title: CatalogL10n.string("home.newest"), sort: .newest))
                        )
                    }
                }
            }
            .padding(DSSpacing.lg)
        }
        .dsScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await load() }
        .task(id: TaskKey(cities: context.cityIds, maxPrice: feature.budget.maxPrice, guest: context.isGuest)) {
            await load()
        }
        .task(id: context.isGuest) { await feature.budget.load(isGuest: context.isGuest) }
        .sheet(isPresented: $showBudget) {
            BudgetSheet(store: feature.budget)
        }
        .trackScreen("bride_home")
    }

    private struct TaskKey: Equatable { let cities: [String]?; let maxPrice: Decimal?; let guest: Bool }

    private var header: some View {
        HStack(alignment: .center, spacing: DSSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                CatalogL10n.text("home.greeting")
                    .font(.dsFootnote)
                    .foregroundStyle(Color.dsTextSecondary)
                Text(verbatim: context.displayName ?? CatalogL10n.string("home.guestName"))
                    .font(.dsTitle1)
                    .foregroundStyle(Color.dsTextPrimary)
            }
            Spacer()
            Button(action: feature.openCityPicker) {
                Label(context.citySummary, systemImage: "mappin.and.ellipse")
                    .font(.dsSubhead)
                    .foregroundStyle(Color.dsTextPrimary)
                    .padding(.horizontal, DSSpacing.sm)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Color.dsSurface))
                    .overlay(Capsule().strokeBorder(Color.dsBorder))
            }
            .buttonStyle(.plain)
            .accessibilityHint(CatalogL10n.string("cities.hint"))
        }
    }

    private func categories(_ list: [CatalogCategory]) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            CatalogL10n.text("home.categories").font(.dsTitle2)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DSSpacing.xs), count: 4),
                      spacing: DSSpacing.md) {
                ForEach(list) { category in
                    CategoryTile(category: category)
                        .simultaneousGesture(TapGesture().onEnded {
                            analytics(.categoryOpen, category.id)
                        })
                }
            }
        }
    }

    private func reload() {
        Task { await load() }
    }

    private func load() async {
        if state.value == nil { state = .loading }
        do {
            let home = try await feature.repository.home(cityIds: context.cityIds, maxPrice: feature.budget.maxPrice)
            state = .loaded(home)
        } catch {
            if state.value == nil { state = .error(appError(error)) }
        }
    }
}

// MARK: - Services list (category, search, "within budget")

struct ServiceListScreen: View {
    let feature: CatalogFeature
    @State private var filter: ServiceFilter
    @State private var state: ViewState<[ServiceCard]> = .loading
    @State private var canLoadMore = true
    @Environment(\.analytics) private var analytics

    init(feature: CatalogFeature, initialFilter: ServiceFilter) {
        self.feature = feature
        _filter = State(initialValue: initialFilter)
    }

    private var isSearch: Bool { filter.categoryId == nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                filterBar
                LoadableContent(state: state, emptyTitle: "list.empty.title", emptyMessage: "list.empty.message", retry: { Task { await load(reset: true) } }) { cards in
                    VStack(spacing: DSSpacing.md) {
                        ServiceGrid(cards: cards, feature: feature)
                        if canLoadMore {
                            ProgressView()
                                .onAppear { Task { await load(reset: false) } }
                        }
                    }
                }
            }
            .padding(DSSpacing.lg)
        }
        .dsScreenBackground()
        .navigationTitle(filter.title ?? CatalogL10n.string("search.title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $filter.query, prompt: CatalogL10n.string("search.placeholder"))
        .onSubmit(of: .search) {
            analytics(.search, nil, props: ["query": filter.query])
        }
        .task(id: TaskKey(filter: filter, cities: feature.context.cityIds)) {
            // Debounce typing.
            try? await Task.sleep(for: .milliseconds(isSearch && !filter.query.isEmpty ? 350 : 0))
            guard !Task.isCancelled else { return }
            await load(reset: true)
        }
        .trackScreen(isSearch ? "search" : "category")
    }

    private struct TaskKey: Equatable { let filter: ServiceFilter; let cities: [String]? }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSSpacing.xs) {
                if feature.budget.budget != nil {
                    Chip(CatalogL10n.key("filter.withinBudget"), isSelected: filter.withinBudget) {
                        filter.withinBudget.toggle()
                    }
                }
                Chip(CatalogL10n.key("filter.femaleOnly"), isSelected: filter.femaleOnly) {
                    filter.femaleOnly.toggle()
                }
                Menu {
                    Picker(CatalogL10n.string("sort.title"), selection: $filter.sort) {
                        ForEach(ServiceFilter.Sort.allCases, id: \.self) { sort in
                            Text(verbatim: CatalogL10n.string("sort.\(sort.rawValue)")).tag(sort)
                        }
                    }
                } label: {
                    Label(CatalogL10n.string("sort.\(filter.sort.rawValue)"), systemImage: "arrow.up.arrow.down")
                        .font(.dsSubhead)
                        .padding(.horizontal, DSSpacing.sm)
                        .frame(minHeight: 36)
                        .background(Capsule().strokeBorder(Color.dsBorder))
                }
            }
        }
    }

    private func load(reset: Bool) async {
        let current = reset ? [] : (state.value ?? [])
        if reset { state = .loading }
        do {
            let page = try await feature.repository.search(filter, cityIds: feature.context.cityIds,
                                                           maxPrice: feature.budget.maxPrice, offset: current.count)
            let all = current + page
            canLoadMore = page.count >= 30
            state = all.isEmpty ? .empty : .loaded(all)
        } catch {
            canLoadMore = false
            if current.isEmpty { state = .error(appError(error)) }
        }
    }
}

// MARK: - Favorites

struct FavoritesScreen: View {
    let feature: CatalogFeature
    @State private var state: ViewState<[ServiceCard]> = .loading

    var body: some View {
        ScrollView {
            LoadableContent(state: state, emptyTitle: "favorites.empty.title", emptyMessage: "favorites.empty.message",
                            retry: { Task { await load() } }) { cards in
                ServiceGrid(cards: cards, feature: feature)
            }
            .padding(DSSpacing.lg)
        }
        .dsScreenBackground()
        .navigationTitle(CatalogL10n.string("favorites.title"))
        .task { await load() }
        .refreshable { await load() }
        .trackScreen("favorites")
    }

    private func load() async {
        guard !feature.context.isGuest else { state = .empty; return }
        do {
            let cards = try await feature.repository.favorites()
            state = cards.isEmpty ? .empty : .loaded(cards)
        } catch {
            state = .error(appError(error))
        }
    }
}

// MARK: - Budget editor

struct BudgetSheet: View {
    let store: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analytics) private var analytics
    @State private var amountText = ""
    @State private var hasDate = false
    @State private var weddingDate = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    @State private var isSaving = false
    @State private var failed = false

    /// "yyyy-MM-dd" in the Gregorian calendar, the format the budget RPC stores.
    private static var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private var amount: Decimal? {
        let ascii = amountText.map { ch -> Character in
            if let v = ch.wholeNumberValue { return Character(String(v)) }
            return ch
        }
        let digits = String(ascii).filter(\.isNumber)
        return digits.isEmpty ? nil : Decimal(string: digits)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(CatalogL10n.string("budget.amountPlaceholder"), text: $amountText)
                        .keyboardType(.numberPad)
                        .font(.dsTitle2)
                } header: {
                    CatalogL10n.text("budget.amount")
                } footer: {
                    CatalogL10n.text("budget.footer")
                }
                Section {
                    Toggle(CatalogL10n.string("budget.hasDate"), isOn: $hasDate)
                    if hasDate {
                        DatePicker(CatalogL10n.string("budget.date"), selection: $weddingDate, in: Date.now..., displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(CatalogL10n.string("budget.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(CatalogL10n.string("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(CatalogL10n.string("common.save")) { save() }
                        .disabled(amount == nil || isSaving)
                }
            }
            .alert(CatalogL10n.string("common.saveFailed"), isPresented: $failed) {
                Button(CatalogL10n.string("common.ok"), role: .cancel) {}
            }
            .onAppear {
                if let budget = store.budget {
                    amountText = "\(budget.total)"
                    if let date = budget.weddingDate.flatMap(Self.dayFormatter.date(from:)) {
                        hasDate = true
                        weddingDate = date
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let amount else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await store.save(total: amount, weddingDate: hasDate ? Self.dayFormatter.string(from: weddingDate) : nil)
                analytics(.budgetSet, nil, props: ["amount": "\(amount)"])
                dismiss()
            } catch {
                failed = true
            }
        }
    }
}
