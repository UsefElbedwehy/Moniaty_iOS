import SwiftUI
import DesignSystem
import Shared
import Catalog
import Booking
import ProviderStudio

/// The four native tabs (`docs/PLAN.md` §3). Home and Explore come from the Catalog feature
/// (bride) and the ProviderStudio feature (provider); Bookings from the Booking feature.
enum AppTab: Hashable {
    case home, explore, bookings, profile
}

// MARK: - Bride

struct BrideShell: View {
    let environment: AppEnvironment
    @State private var tab: AppTab = .home
    @State private var homePath = NavigationPath()
    @State private var bookingsPath = NavigationPath()
    @State private var profilePath = NavigationPath()

    private var catalog: CatalogFeature { environment.catalog }
    private var booking: BookingFeature { environment.booking }

    var body: some View {
        @Bindable var session = environment.session
        TabView(selection: $tab) {
            NavigationStack(path: $homePath) {
                catalog.homeScreen()
                    .navigationDestination(for: CatalogRoute.self) { catalog.destination(for: $0) }
                    .navigationDestination(for: BookingRoute.self) { booking.destination(for: $0, role: .bride) }
            }
            .tabItem { Label(L10n.string("tab.home"), systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack {
                catalog.exploreScreen()
                    .navigationDestination(for: CatalogRoute.self) { catalog.destination(for: $0) }
            }
            .tabItem { Label(L10n.string("tab.explore"), systemImage: "map") }
            .tag(AppTab.explore)

            NavigationStack(path: $bookingsPath) {
                BookingsTab(environment: environment, role: .bride)
                    .navigationDestination(for: BookingRoute.self) { booking.destination(for: $0, role: .bride) }
                    .navigationDestination(for: CatalogRoute.self) { catalog.destination(for: $0) }
            }
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
        .sheet(item: $session.bookingRequest) { service in
            NavigationStack {
                booking.requestScreen(for: service) { id in
                    tab = .bookings
                    bookingsPath = NavigationPath([BookingRoute.detail(id: id)])
                }
            }
        }
        .onChange(of: environment.deepLink.pending, initial: true) { _, link in
            route(link)
        }
    }

    private func route(_ link: DeepLink?) {
        guard let link else { return }
        switch link {
        case .booking(let id):
            tab = .bookings
            bookingsPath = NavigationPath([BookingRoute.detail(id: id)])
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
    @State private var bookingsPath = NavigationPath()

    private var catalog: CatalogFeature { environment.catalog }
    private var booking: BookingFeature { environment.booking }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $homePath) {
                environment.studio.homeScreen()
                    .navigationDestination(for: CatalogRoute.self) { catalog.destination(for: $0) }
                    .navigationDestination(for: BookingRoute.self) { booking.destination(for: $0, role: .provider) }
                    .navigationDestination(for: StudioRoute.self) { environment.studio.destination(for: $0) }
            }
            .tabItem { Label(L10n.string("tab.home"), systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack {
                catalog.exploreScreen()
                    .navigationDestination(for: CatalogRoute.self) { catalog.destination(for: $0) }
            }
            .tabItem { Label(L10n.string("tab.explore"), systemImage: "map") }
            .tag(AppTab.explore)

            NavigationStack(path: $bookingsPath) {
                BookingsTab(environment: environment, role: .provider)
                    .navigationDestination(for: BookingRoute.self) { booking.destination(for: $0, role: .provider) }
                    .navigationDestination(for: CatalogRoute.self) { catalog.destination(for: $0) }
            }
            .tabItem { Label(L10n.string("tab.providerBookings"), systemImage: "calendar") }
            .tag(AppTab.bookings)

            NavigationStack { ProfileScreen(environment: environment) }
                .tabItem { Label(L10n.string("tab.profile"), systemImage: "person") }
                .tag(AppTab.profile)
        }
        .onChange(of: environment.deepLink.pending, initial: true) { _, link in
            guard let link else { return }
            switch link {
            case .booking(let id):
                tab = .bookings
                bookingsPath = NavigationPath([BookingRoute.detail(id: id)])
            case .plans:
                tab = .home
                homePath = NavigationPath([StudioRoute.plans])
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

// MARK: - Bookings

/// The bookings tab: the Booking feature's list for an account, a sign-in prompt for a guest.
struct BookingsTab: View {
    let environment: AppEnvironment
    let role: BookingRole

    var body: some View {
        if environment.session.hasAccount {
            environment.booking.bookingsScreen(role: role)
        } else {
            EmptyStateView(
                systemImage: "person.crop.circle.badge.plus",
                title: L10n.key("bookings.guest.title"),
                message: L10n.key("bookings.guest.message"),
                actionTitle: L10n.key("auth.signIn")
            ) {
                environment.session.isPresentingAuth = true
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dsScreenBackground()
            .navigationTitle(L10n.string("tab.bookings"))
            .trackScreen("bookings_guest")
        }
    }
}
