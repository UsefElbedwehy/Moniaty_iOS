import SwiftUI
import MapKit
import DesignSystem
import Shared

/// The four native tabs (`docs/PLAN.md` §3). Phase 1 ships the real shell, navigation and
/// deep-link routing with placeholder content; Phase 2 and 3 replace the placeholders with the
/// Catalog, Explore and Booking features.
enum AppTab: Hashable {
    case home, explore, bookings, profile
}

// MARK: - Bride

struct BrideShell: View {
    let environment: AppEnvironment
    @State private var tab: AppTab = .home

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { BrideHomeScreen(environment: environment) }
                .tabItem { Label(L10n.string("tab.home"), systemImage: "house") }
                .tag(AppTab.home)
            NavigationStack { ExploreMapScreen(environment: environment) }
                .tabItem { Label(L10n.string("tab.explore"), systemImage: "map") }
                .tag(AppTab.explore)
            NavigationStack { BookingsPlaceholderScreen(environment: environment) }
                .tabItem { Label(L10n.string("tab.bookings"), systemImage: "calendar") }
                .tag(AppTab.bookings)
            NavigationStack { ProfileScreen(environment: environment) }
                .tabItem { Label(L10n.string("tab.profile"), systemImage: "person") }
                .tag(AppTab.profile)
        }
        .onChange(of: environment.deepLink.pending, initial: true) { _, link in
            route(link)
        }
    }

    /// Phase 1 routing: bring the right tab forward. Feature screens (provider, service,
    /// booking detail) are pushed from here once they exist.
    private func route(_ link: DeepLink?) {
        guard let link else { return }
        switch link {
        case .booking: tab = .bookings
        case .plans, .notifications, .provider, .service, .store, .category: tab = .home
        }
        environment.deepLink.pending = nil
    }
}

// MARK: - Provider

struct ProviderShell: View {
    let environment: AppEnvironment
    @State private var tab: AppTab = .home

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { ProviderHomeScreen(environment: environment) }
                .tabItem { Label(L10n.string("tab.home"), systemImage: "house") }
                .tag(AppTab.home)
            NavigationStack { ExploreMapScreen(environment: environment) }
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
            default: tab = .home
            }
            environment.deepLink.pending = nil
        }
    }
}

// MARK: - Home (bride)

struct BrideHomeScreen: View {
    let environment: AppEnvironment
    @State private var showCities = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                HStack(alignment: .center, spacing: DSSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        L10n.text("home.greeting")
                            .font(.dsFootnote)
                            .foregroundStyle(Color.dsTextSecondary)
                        Text(verbatim: environment.session.user?.displayName ?? L10n.string("home.guestName"))
                            .font(.dsTitle1)
                            .foregroundStyle(Color.dsTextPrimary)
                    }
                    Spacer()
                    Button {
                        showCities = true
                    } label: {
                        Label(environment.cities.summary(allLabel: L10n.string("cities.all")), systemImage: "mappin.and.ellipse")
                            .font(.dsSubhead)
                            .padding(.horizontal, DSSpacing.sm)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(Color.dsSurface))
                            .overlay(Capsule().strokeBorder(Color.dsBorder))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(L10n.string("cities.pickerHint"))
                }

                BudgetTeaserCard()

                ComingSoonCard(
                    systemImage: "sparkles",
                    title: L10n.string("home.comingSoon.title"),
                    message: L10n.string("home.comingSoon.message")
                )
            }
            .padding(DSSpacing.lg)
        }
        .dsScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCities) {
            CityPickerSheet(environment: environment)
        }
        .trackScreen("bride_home")
    }
}

/// The burgundy budget card from mockup 2, without numbers until the budget feature lands.
private struct BudgetTeaserCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                L10n.text("home.budget.title")
                    .font(.dsSubhead)
                Spacer()
                DSSparkle()
            }
            L10n.text("home.budget.message")
                .font(.dsFootnote)
                .opacity(0.9)
        }
        .foregroundStyle(Color.dsBackground)
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsPrimary))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Home (provider)

struct ProviderHomeScreen: View {
    let environment: AppEnvironment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    L10n.text("provider.home.welcome")
                        .font(.dsFootnote)
                        .foregroundStyle(Color.dsTextSecondary)
                    Text(verbatim: environment.session.user?.displayName ?? "")
                        .font(.dsTitle1)
                }
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: "hourglass")
                        .foregroundStyle(Color.dsPendingForeground)
                    L10n.text("provider.home.pending")
                        .font(.dsSubhead)
                        .foregroundStyle(Color.dsPendingForeground)
                }
                .padding(DSSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsPendingBackground))

                ComingSoonCard(
                    systemImage: "tray.full",
                    title: L10n.string("provider.home.comingSoon.title"),
                    message: L10n.string("provider.home.comingSoon.message")
                )
            }
            .padding(DSSpacing.lg)
        }
        .dsScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .trackScreen("provider_home")
    }
}

// MARK: - Explore

/// MapKit map centred on the first selected city (Dammam by default). Provider and store pins
/// arrive with the catalog in Phase 2.
struct ExploreMapScreen: View {
    let environment: AppEnvironment
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 26.4207, longitude: 50.0888), // Dammam
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
    ))

    var body: some View {
        Map(position: $position)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .overlay(alignment: .top) {
                L10n.text("explore.comingSoon")
                    .font(.dsFootnote)
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.xs)
                    .background(Capsule().fill(.regularMaterial))
                    .padding(.top, DSSpacing.sm)
            }
            .navigationTitle(L10n.string("tab.explore"))
            .navigationBarTitleDisplayMode(.inline)
            .trackScreen("explore")
    }
}

// MARK: - Bookings

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

// MARK: - Shared bits

struct ComingSoonCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.dsPrimary)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.dsPrimaryMuted))
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(verbatim: title).font(.dsHeadline)
                Text(verbatim: message).font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
            }
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsSurface))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.card).strokeBorder(Color.dsBorder))
        .accessibilityElement(children: .combine)
    }
}
