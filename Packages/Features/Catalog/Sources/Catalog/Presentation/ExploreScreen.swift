import SwiftUI
import MapKit
import Core
import DesignSystem
import Shared

/// Explore tab: providers and stores on a MapKit map (`docs/PLAN.md` §3, §4.10). Pins load for
/// the visible region whenever the camera settles; a category filter narrows them.
struct ExploreScreen: View {
    let feature: CatalogFeature
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 26.35, longitude: 50.12), // Dammam–Khobar–Qatif
        span: MKCoordinateSpan(latitudeDelta: 0.45, longitudeDelta: 0.45)
    ))
    @State private var region: MKCoordinateRegion?
    @State private var pins: [MapPin] = []
    @State private var categories: [CatalogCategory] = []
    @State private var categoryId: String?
    @State private var selected: CatalogRoute?

    var body: some View {
        Map(position: $position) {
            ForEach(pins) { pin in
                Annotation(pin.name ?? "", coordinate: CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lng)) {
                    Button {
                        selected = pin.kind == "store" ? .store(id: pin.id) : .provider(id: pin.id)
                    } label: {
                        Image(systemName: pin.kind == "store" ? "storefront.fill" : "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.dsPremiumGold)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.dsPrimary))
                            .overlay(Circle().strokeBorder(Color.dsBackground, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(pin.name ?? "")
                }
            }
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            region = context.region
        }
        .safeAreaInset(edge: .top) { categoryBar }
        .navigationDestination(item: $selected) { route in
            feature.destination(for: route)
        }
        .navigationTitle(CatalogL10n.string("explore.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let home = try? await feature.repository.home(cityIds: nil, maxPrice: nil) {
                categories = home.categories
            }
        }
        .task(id: TaskKey(region: region.map(RegionKey.init), categoryId: categoryId, cities: feature.context.cityIds)) {
            await loadPins()
        }
        .trackScreen("explore")
    }

    private struct RegionKey: Equatable {
        let lat: Double, lng: Double, latSpan: Double, lngSpan: Double
        init(_ r: MKCoordinateRegion) {
            lat = r.center.latitude; lng = r.center.longitude
            latSpan = r.span.latitudeDelta; lngSpan = r.span.longitudeDelta
        }
    }

    private struct TaskKey: Equatable { let region: RegionKey?; let categoryId: String?; let cities: [String]? }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSSpacing.xs) {
                Chip(CatalogL10n.key("explore.all"), isSelected: categoryId == nil) { categoryId = nil }
                ForEach(categories) { category in
                    Chip(LocalizedStringKey("\(category.name)"), isSelected: categoryId == category.id) {
                        categoryId = category.id
                    }
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.xs)
        }
        .background(.bar)
    }

    private func loadPins() async {
        let r = region ?? MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 26.35, longitude: 50.12),
                                             span: MKCoordinateSpan(latitudeDelta: 0.45, longitudeDelta: 0.45))
        let loaded = try? await feature.repository.mapPins(
            minLat: r.center.latitude - r.span.latitudeDelta / 2,
            minLng: r.center.longitude - r.span.longitudeDelta / 2,
            maxLat: r.center.latitude + r.span.latitudeDelta / 2,
            maxLng: r.center.longitude + r.span.longitudeDelta / 2,
            cityIds: feature.context.cityIds,
            categoryId: categoryId
        )
        if let loaded { pins = loaded }
    }
}
