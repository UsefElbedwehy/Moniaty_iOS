import SwiftUI
import Observation
import PhotosUI
import MapKit
import Core
import DesignSystem
import Shared
import Catalog

/// Public entry point of the provider studio: the provider's Home tab, where they build the
/// profile, services and stores that brides will see once an admin approves them.
@MainActor
public final class StudioFeature {
    let store: StudioStore
    let uploader: MediaUploading
    /// Booking settings screens, supplied by the App from the Booking feature (Phase 3).
    var settingsDestination: ((StudioSettingsLink) -> AnyView)?

    public init(repository: StudioRepository, uploader: MediaUploading) {
        self.store = StudioStore(repository: repository)
        self.uploader = uploader
    }

    public func homeScreen() -> some View {
        StudioHomeScreen(feature: self)
    }

    /// Adds the working-hours and payout-method rows to the studio home.
    public func setSettingsDestination(_ destination: @escaping (StudioSettingsLink) -> AnyView) {
        settingsDestination = destination
    }
}

/// Studio rows whose screens live in another feature.
public enum StudioSettingsLink: CaseIterable, Sendable {
    case availability, paymentMethods

    var systemImage: String {
        switch self {
        case .availability: "clock"
        case .paymentMethods: "banknote"
        }
    }

    var titleKey: String {
        switch self {
        case .availability: "studio.availability"
        case .paymentMethods: "studio.paymentMethods"
        }
    }

    var subtitleKey: String { titleKey + ".subtitle" }
}

/// Shared state for every studio screen, reloaded after each save.
@MainActor
@Observable
final class StudioStore {
    private(set) var state: ViewState<MyBusiness> = .loading
    private(set) var categories: [CatalogCategory] = []
    private(set) var cities: [City] = []
    let repository: StudioRepository

    init(repository: StudioRepository) {
        self.repository = repository
    }

    var business: MyBusiness? { state.value }

    func load() async {
        do {
            async let business = repository.business()
            async let categories = repository.categories()
            async let cities = repository.cities()
            let (b, c, ci) = try await (business, categories, cities)
            self.categories = c
            self.cities = ci
            state = .loaded(b)
        } catch {
            if state.value == nil { state = .error((error as? AppError) ?? .unknown(message: error.localizedDescription)) }
        }
    }

    func reload() async {
        if let fresh = try? await repository.business() { state = .loaded(fresh) }
    }

    func categoryName(_ id: String) -> String {
        categories.first { $0.id == id }?.name ?? id
    }

    func cityName(_ id: String) -> String {
        cities.first { $0.id == id }?.name() ?? id
    }
}

// MARK: - Studio home (provider's Home tab)

struct StudioHomeScreen: View {
    let feature: StudioFeature
    private var store: StudioStore { feature.store }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                switch store.state {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                case .error(let error):
                    ErrorStateView(error: error) { Task { await store.load() } }
                case .loaded(let business), .refreshing(let business):
                    content(business)
                case .empty, .offline:
                    ErrorStateView(error: .offline) { Task { await store.load() } }
                }
            }
            .padding(DSSpacing.lg)
        }
        .dsScreenBackground()
        .navigationTitle(StudioL10n.string("studio.title"))
        .task { await store.load() }
        .refreshable { await store.load() }
        .trackScreen("studio_home")
    }

    @ViewBuilder
    private func content(_ business: MyBusiness) -> some View {
        statusCard(business)

        let steps = business.setupSteps
        if steps.contains(where: { !$0.done }) {
            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    StudioL10n.text("studio.setup.title").font(.dsHeadline)
                    ForEach(steps, id: \.key) { step in
                        Label {
                            StudioL10n.text(step.key).font(.dsSubhead)
                        } icon: {
                            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.done ? Color.dsSuccess : Color.dsDisabled)
                        }
                    }
                }
            }
        }

        VStack(spacing: DSSpacing.sm) {
            NavigationLink {
                BusinessEditScreen(feature: feature, business: business)
            } label: {
                StudioRow(systemImage: "person.text.rectangle", title: StudioL10n.string("studio.business"),
                          subtitle: business.businessName ?? StudioL10n.string("studio.business.empty"))
            }
            NavigationLink {
                ServicesListScreen(feature: feature)
            } label: {
                StudioRow(systemImage: "sparkles", title: StudioL10n.string("studio.services"),
                          subtitle: StudioL10n.format("studio.services.count", business.activeServiceCount, business.limits.maxServices))
            }
            NavigationLink {
                StoresListScreen(feature: feature)
            } label: {
                StudioRow(systemImage: "storefront", title: StudioL10n.string("studio.stores"),
                          subtitle: StudioL10n.format("studio.stores.count", business.stores.count, business.limits.maxStores))
            }
            if let destination = feature.settingsDestination {
                ForEach(StudioSettingsLink.allCases, id: \.self) { link in
                    NavigationLink {
                        destination(link)
                    } label: {
                        StudioRow(systemImage: link.systemImage, title: StudioL10n.string(link.titleKey),
                                  subtitle: StudioL10n.string(link.subtitleKey))
                    }
                }
            }
            if business.status == .approved {
                NavigationLink(value: CatalogRoute.provider(id: business.id)) {
                    StudioRow(systemImage: "eye", title: StudioL10n.string("studio.preview"), subtitle: nil)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func statusCard(_ business: MyBusiness) -> some View {
        let (key, kind): (String, StatusBadgeKind) = switch business.status {
        case .pending: ("studio.status.pending", .pending)
        case .approved: ("studio.status.approved", .live)
        case .rejected: ("studio.status.rejected", .rejected)
        case .suspended: ("studio.status.suspended", .rejected)
        }
        return DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                StatusBadge(kind: kind, text: StudioL10n.key(key))
                StudioL10n.text("\(key).message")
                    .font(.dsFootnote)
                    .foregroundStyle(Color.dsTextSecondary)
                if let note = business.reviewNote, !note.isEmpty, business.status != .approved {
                    Text(verbatim: note).font(.dsFootnote)
                }
                if business.isVerified {
                    Label(StudioL10n.string("studio.verified"), systemImage: "checkmark.seal.fill")
                        .font(.dsFootnote)
                        .foregroundStyle(Color.dsPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct StudioRow: View {
    let systemImage: String
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.dsPrimary)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.dsPrimaryMuted))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.dsHeadline).foregroundStyle(Color.dsTextPrimary)
                if let subtitle {
                    Text(verbatim: subtitle).font(.dsFootnote).foregroundStyle(Color.dsTextSecondary).lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.forward").foregroundStyle(Color.dsTextSecondary)
        }
        .padding(DSSpacing.md)
        .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsSurface))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.card).strokeBorder(Color.dsBorder))
        .contentShape(Rectangle())
    }
}

// MARK: - Shared form pieces

/// Picks photos, compresses and uploads them, and reports the public URLs.
struct PhotoUploadButton: View {
    let uploader: MediaUploading
    let folder: String
    let maxCount: Int
    let onUploaded: ([URL]) -> Void
    @State private var items: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var failed = false

    var body: some View {
        PhotosPicker(selection: $items, maxSelectionCount: max(1, maxCount), matching: .images) {
            HStack(spacing: DSSpacing.xs) {
                if isUploading { ProgressView() } else { Image(systemName: "photo.badge.plus") }
                StudioL10n.text(maxCount == 1 ? "photo.pickOne" : "photo.pick")
            }
        }
        .disabled(isUploading || maxCount < 1)
        .onChange(of: items) { _, picked in
            guard !picked.isEmpty else { return }
            Task { await upload(picked) }
        }
        .alert(StudioL10n.string("photo.failed"), isPresented: $failed) {
            Button(StudioL10n.string("common.ok"), role: .cancel) {}
        }
    }

    private func upload(_ picked: [PhotosPickerItem]) async {
        isUploading = true
        defer { isUploading = false; items = [] }
        var urls: [URL] = []
        for item in picked {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let jpeg = ImageCompressor.jpeg(from: data) else { continue }
            do {
                urls.append(try await uploader.uploadJPEG(jpeg, folder: folder))
            } catch {
                failed = true
            }
        }
        if !urls.isEmpty { onUploaded(urls) }
    }
}

/// Map with a fixed centre pin: the provider moves the map under the pin to set a location.
struct LocationPicker: View {
    @Binding var lat: Double?
    @Binding var lng: Double?
    @State private var position: MapCameraPosition

    init(lat: Binding<Double?>, lng: Binding<Double?>) {
        _lat = lat
        _lng = lng
        let center = CLLocationCoordinate2D(latitude: lat.wrappedValue ?? 26.35, longitude: lng.wrappedValue ?? 50.12)
        _position = State(initialValue: .region(MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))))
    }

    var body: some View {
        Map(position: $position) { UserAnnotation() }
            .mapControls { MapUserLocationButton() }
            .onMapCameraChange(frequency: .onEnd) { context in
                lat = context.region.center.latitude
                lng = context.region.center.longitude
            }
            .overlay {
                Image(systemName: "mappin")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.dsPrimary)
                    .offset(y: -16)
                    .accessibilityHidden(true)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityLabel(StudioL10n.string("location.hint"))
    }
}

/// Multi-select list (categories, cities) shown on a pushed screen.
struct MultiSelectScreen: View {
    let title: String
    let options: [Option]

    struct Option: Identifiable, Hashable {
        let id: String
        let name: String
    }
    @Binding var selection: Set<String>

    var body: some View {
        List(options) { option in
            Button {
                if selection.contains(option.id) { selection.remove(option.id) } else { selection.insert(option.id) }
            } label: {
                HStack {
                    Text(verbatim: option.name).foregroundStyle(Color.dsTextPrimary)
                    Spacer()
                    if selection.contains(option.id) {
                        Image(systemName: "checkmark").foregroundStyle(Color.dsPrimary)
                    }
                }
            }
            .accessibilityAddTraits(selection.contains(option.id) ? .isSelected : [])
        }
        .navigationTitle(title)
    }
}
