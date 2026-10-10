import SwiftUI
import DesignSystem
import Shared
import Catalog

/// The four native tabs (`docs/PLAN.md` §3). Home and Explore come from the Catalog feature
/// (bride) and the ProviderStudio feature (provider); bookings arrive in Phase 3.
enum AppTab: Hashable {
    case home, explore, bookings, profile
}

// MARK: - Bride

struct BrideShell: View {
    let environment: AppEnvironment
    @State private var tab: AppTab = .home
    @State private var homePath = NavigationPath()
    @State private var profilePath = NavigationPath()

    private var catalog: CatalogFeature { environment.catalog }

    var body: some View {
        @Bindable var session = environment.session
        TabView(selection: $tab) {
            NavigationStack(path: $homePath) {
                catalog.homeScreen()
                    .navigationDestination(for: CatalogRoute.self) { catalog.destination(for: $0) }
            }
            .tabItem { Label(L10n.string("tab.home"), systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack {
                catalog.exploreScreen()
                    .navigationDestination(for: CatalogRoute.self) { catalog.destination(for: $0) }
            }
            .tabItem { Label(L10n.string("tab.explore"), systemImage: "map") }
            .tag(AppTab.explore)

            NavigationStack { BookingsPlaceholderScreen(environment: environment) }
                .tabItem { Label(L10n.string("tab.bookings"), systemImage: "calendar") }
                .tag(AppTab.bookings)

            NavigationStack(path: $profilePath) {
                ProfileScreen(environment: environment)
                    .navigationDestination(for: CatalogRoute.self) { catalog.destination(for: $0) }
            }
            .tabItem { Label(L10n.string("tab.profile"), systemImage: "person") }
            .tag(AppTab.profile)
        }
        .sheet(isPresented: $session.isPickingCities) {
            CityPickerSheet(environment: environment)
        }
        .onChange(of: environment.deepLink.pending, initial: true) { _, link in
            route(link)
        }
    }

    private func route(_ link: DeepLink?) {
        guard let link else { return }
        switch link {
        case .booking:
            tab = .bookings
        case .provider(let id):
            tab = .home
            homePath.append(CatalogRoute.provider(id: id))
        case .service(let id):
            tab = .home
            homePath.append(CatalogRoute.service(id: id))
        case .store(let id):
            tab = .home
            homePath.append(CatalogRoute.store(id: id))
        case .category(let id):
            tab = .home
            homePath.append(CatalogRoute.services(ServiceFilter(categoryId: id)))
        case .plans, .notifications:
            tab = .home
        }
        environment.deepLink.pending = nil
    }
}

// MARK: - Provider

struct ProviderShell: View {
    let environment: AppEnvironment
    @State private var tab: AppTab = .home
    @State private var homePath = NavigationPath()

    private var catalog: CatalogFeature { environment.catalog }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $homePath) {
                environment.studio.homeScreen()
                    .navigationDestination(for: CatalogRoute.self) { catalog.destination(for: $0) }
            }
            .tabItem { Label(L10n.string("tab.home"), systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack {
                catalog.exploreScreen()
                    .navigationDestination(for: CatalogRoute.self) { catalog.destination(for: $0) }
            }
            .tabItem { Label(L10n.string("tab.explore"), systemImage: "map") }
            .tag(AppTab.explore)

            NavigationStack { BookingsPlaceholderScreen(environment: environment) }
                .tabItem { Label(L10n.string("tab.providerBookings"), systemImage: "calendar") }
                .tag(AppTab.bookings)

            NavigationStack { ProfileScreen(environment: environment) }
                .tabItem { Label(L10n.string("tab.profile"), systemImage: "person") }
                .tag(AppTab.profile)
        }
        .onChange(of: environment.deepLink.pending, initial: true) { _, link in
            guard let link else { return }
            switch link {
            case .booking: tab = .bookings
            case .plans: tab = .profile
            case .provider(let id):
                tab = .home
                homePath.append(CatalogRoute.provider(id: id))
            case .service(let id):
                tab = .home
                homePath.append(CatalogRoute.service(id: id))
            case .store(let id):
                tab = .home
                homePath.append(CatalogRoute.store(id: id))
            case .category, .notifications: tab = .home
            }
            environment.deepLink.pending = nil
        }
    }
}

// MARK: - Bookings (Phase 3)

struct BookingsPlaceholderScreen: View {
    let environment: AppEnvironment

    var body: some View {
        Group {
            if environment.session.hasAccount {
                EmptyStateView(
                    systemImage: "calendar",
                    title: L10n.key("bookings.empty.title"),
                    message: L10n.key("bookings.empty.message")
                )
            } else {
                EmptyStateView(
                    systemImage: "person.crop.circle.badge.plus",
                    title: L10n.key("bookings.guest.title"),
                    message: L10n.key("bookings.guest.message"),
                    actionTitle: L10n.key("auth.signIn")
                ) {
                    environment.session.isPresentingAuth = true
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dsScreenBackground()
        .navigationTitle(L10n.string("tab.bookings"))
        .trackScreen("bookings")
    }
}
