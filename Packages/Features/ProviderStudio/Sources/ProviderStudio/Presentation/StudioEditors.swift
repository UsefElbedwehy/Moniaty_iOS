import SwiftUI
import Core
import DesignSystem
import Shared
import Catalog

// MARK: - Business profile (the join form, decision #6)

struct BusinessEditScreen: View {
    let feature: StudioFeature
    @State private var draft: BusinessDraft
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(feature: StudioFeature, business: MyBusiness) {
        self.feature = feature
        _draft = State(initialValue: BusinessDraft(business))
    }

    private var store: StudioStore { feature.store }

    var body: some View {
        Form {
            Section(StudioL10n.string("business.section.identity")) {
                TextField(StudioL10n.string("business.name"), text: $draft.businessName)
                TextField(StudioL10n.string("business.bio"), text: $draft.bio, axis: .vertical)
                    .lineLimit(3...8)
                HStack(spacing: DSSpacing.md) {
                    RemoteImageView(url: draft.logoUrl)
                        .frame(width: 56, height: 56)
                        .background(Color.dsPrimaryMuted)
                        .clipShape(Circle())
                    PhotoUploadButton(uploader: feature.uploader, folder: "logos", maxCount: 1) { urls in
                        draft.logoUrl = urls.first
                    }
                }
                Toggle(StudioL10n.string("business.femaleOnly"), isOn: $draft.femaleStaffOnly)
            }

            Section(StudioL10n.string("business.section.coverage")) {
                NavigationLink {
                    MultiSelectScreen(title: StudioL10n.string("business.categories"),
                                      options: store.categories.map { .init(id: $0.id, name: $0.name) },
                                      selection: $draft.categoryIds)
                } label: {
                    LabeledContent(StudioL10n.string("business.categories"),
                                   value: draft.categoryIds.map(store.categoryName).sorted().joined(separator: "، "))
                }
                NavigationLink {
                    MultiSelectScreen(title: StudioL10n.string("business.cities"),
                                      options: store.cities.map { .init(id: $0.id, name: $0.name()) },
                                      selection: $draft.cityIds)
                } label: {
                    LabeledContent(StudioL10n.string("business.cities"),
                                   value: draft.cityIds.map(store.cityName).sorted().joined(separator: "، "))
                }
            }

            Section {
                TextField(StudioL10n.string("business.address"), text: $draft.address)
                Picker(StudioL10n.string("business.city"), selection: $draft.cityId) {
                    Text(verbatim: "—").tag(String?.none)
                    ForEach(store.cities) { city in
                        Text(verbatim: city.name()).tag(Optional(city.id))
                    }
                }
                LocationPicker(lat: $draft.lat, lng: $draft.lng)
                    .listRowInsets(EdgeInsets())
            } header: {
                StudioL10n.text("business.section.location")
            } footer: {
                StudioL10n.text("location.hint")
            }

            Section {
                TextField(StudioL10n.string("business.cr"), text: $draft.crNumber)
                    .keyboardType(.numberPad)
                TextField(StudioL10n.string("business.freelance"), text: $draft.freelanceDocNumber)
                    .keyboardType(.numberPad)
                TextField(StudioL10n.string("business.instagram"), text: $draft.instagram)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                StudioL10n.text("business.section.verification")
            } footer: {
                StudioL10n.text("business.verification.footer")
            }
        }
        .navigationTitle(StudioL10n.string("studio.business"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(StudioL10n.string("common.save")) { save() }
                    .disabled(!draft.isValid || isSaving)
            }
        }
        .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(StudioL10n.string("common.ok"), role: .cancel) {}
        }
        .trackScreen("studio_business")
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await store.repository.updateBusiness(draft)
                await store.reload()
                dismiss()
            } catch {
                errorMessage = StudioL10n.string("common.saveFailed")
            }
        }
    }
}

// MARK: - Services

struct ServicesListScreen: View {
    let feature: StudioFeature
    @State private var editing: ServiceDraft?
    private var store: StudioStore { feature.store }

    var body: some View {
        let business = store.business
        List {
            if let business {
                Section {
                    ForEach(business.services) { service in
                        Button { editing = ServiceDraft(service) } label: {
                            HStack(spacing: DSSpacing.sm) {
                                RemoteImageView(url: service.imageUrls.first)
                                    .frame(width: 52, height: 52)
                                    .background(Color.dsPrimaryMuted)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: service.title).font(.dsHeadline).foregroundStyle(Color.dsTextPrimary)
                                    Text(verbatim: "\(store.categoryName(service.categoryId)) · \(formatSAR(service.price))")
                                        .font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                                }
                                Spacer()
                                if service.status == .paused {
                                    StatusBadge(kind: .pending, text: StudioL10n.key("service.paused"))
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { business.services[$0].id }
                        Task {
                            for id in ids { try? await store.repository.deleteService(id: id) }
                            await store.reload()
                        }
                    }
                } footer: {
                    Text(verbatim: StudioL10n.format("studio.services.count", business.activeServiceCount, business.limits.maxServices))
                }
            }
        }
        .overlay {
            if business?.services.isEmpty == true {
                EmptyStateView(systemImage: "sparkles", title: StudioL10n.key("services.empty.title"),
                               message: StudioL10n.key("services.empty.message"),
                               actionTitle: StudioL10n.key("services.add")) { editing = ServiceDraft() }
            }
        }
        .navigationTitle(StudioL10n.string("studio.services"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = ServiceDraft() } label: { Image(systemName: "plus") }
                    .accessibilityLabel(StudioL10n.string("services.add"))
            }
        }
        .sheet(item: $editing) { draft in
            NavigationStack { ServiceEditScreen(feature: feature, initial: draft) }
        }
        .trackScreen("studio_services")
    }
}

// Drafts are presented with `.sheet(item:)`; their optional server id is the identity
// (nil for a new, unsaved draft).
extension ServiceDraft: Identifiable {}
extension StoreDraft: Identifiable {}

struct ServiceEditScreen: View {
    let feature: StudioFeature
    @State private var draft: ServiceDraft
    @State private var isSaving = false
    @State private var message: String?
    @State private var paywallReason: String?
    @Environment(\.dismiss) private var dismiss

    private static let durations = [30, 60, 90, 120, 180, 240, 360, 480]

    /// Photos per service on the provider's plan.
    private var maxPhotos: Int { feature.store.business?.limits.maxPhotos ?? 10 }

    init(feature: StudioFeature, initial: ServiceDraft) {
        self.feature = feature
        _draft = State(initialValue: initial)
    }

    private var store: StudioStore { feature.store }

    var body: some View {
        Form {
            Section {
                TextField(StudioL10n.string("service.title"), text: $draft.title)
                Picker(StudioL10n.string("service.category"), selection: $draft.categoryId) {
                    Text(verbatim: "—").tag(String?.none)
                    ForEach(store.categories) { category in
                        Text(verbatim: category.name).tag(Optional(category.id))
                    }
                }
                TextField(StudioL10n.string("service.price"), text: $draft.priceText)
                    .keyboardType(.decimalPad)
                Picker(StudioL10n.string("service.duration"), selection: $draft.durationMinutes) {
                    Text(verbatim: "—").tag(Int?.none)
                    ForEach(Self.durations, id: \.self) { minutes in
                        Text(verbatim: durationLabel(minutes)).tag(Optional(minutes))
                    }
                }
                TextField(StudioL10n.string("service.description"), text: $draft.description, axis: .vertical)
                    .lineLimit(3...10)
            }

            Section(StudioL10n.string("service.section.photos")) {
                if !draft.imageUrls.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(draft.imageUrls, id: \.self) { url in
                                RemoteImageView(url: url)
                                    .frame(width: 84, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            draft.imageUrls.removeAll { $0 == url }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, Color.dsPrimary)
                                        }
                                        .accessibilityLabel(StudioL10n.string("photo.remove"))
                                    }
                            }
                        }
                    }
                }
                if draft.imageUrls.count < maxPhotos {
                    PhotoUploadButton(uploader: feature.uploader, folder: "services", maxCount: maxPhotos - draft.imageUrls.count) { urls in
                        draft.imageUrls.append(contentsOf: urls)
                    }
                } else {
                    Text(verbatim: StudioL10n.format("limit.photos", maxPhotos))
                        .font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                }
            }

            Section {
                Toggle(StudioL10n.string("service.femaleOnly"), isOn: $draft.femaleStaffOnly)
                Toggle(StudioL10n.string("service.atLocation"), isOn: $draft.atCustomerLocation)
                if let stores = store.business?.stores, !stores.isEmpty {
                    Picker(StudioL10n.string("service.store"), selection: $draft.storeId) {
                        Text(verbatim: "—").tag(String?.none)
                        ForEach(stores) { s in Text(verbatim: s.name).tag(Optional(s.id)) }
                    }
                }
                Toggle(StudioL10n.string("service.active"), isOn: $draft.isActive)
            } footer: {
                StudioL10n.text("service.active.footer")
            }
        }
        .navigationTitle(StudioL10n.string(draft.id == nil ? "services.add" : "services.edit"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(StudioL10n.string("common.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(StudioL10n.string("common.save")) { save() }
                    .disabled(!draft.isValid || isSaving)
            }
        }
        .sheet(isPresented: Binding(get: { paywallReason != nil }, set: { if !$0 { paywallReason = nil } })) {
            NavigationStack { PlansScreen(feature: feature, reason: paywallReason) }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(StudioL10n.string("common.ok"), role: .cancel) {}
        }
        .onAppear {
            // New services default to the provider's first category.
            if draft.categoryId == nil { draft.categoryId = store.business?.categoryIds.first }
        }
    }

    private func durationLabel(_ minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes)"
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                switch try await store.repository.saveService(draft) {
                case .saved:
                    await store.reload()
                    dismiss()
                case .limitReached(let max):
                    paywallReason = StudioL10n.format("limit.services", max)
                }
            } catch {
                message = StudioL10n.string("common.saveFailed")
            }
        }
    }
}

// MARK: - Stores (requirement 14)

struct StoresListScreen: View {
    let feature: StudioFeature
    @State private var editing: StoreDraft?
    private var store: StudioStore { feature.store }

    var body: some View {
        let business = store.business
        List {
            if let business {
                Section {
                    ForEach(business.stores) { item in
                        Button { editing = StoreDraft(item) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: item.name).font(.dsHeadline).foregroundStyle(Color.dsTextPrimary)
                                    Text(verbatim: item.address ?? "").font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                                }
                                Spacer()
                                if !item.isActive {
                                    StatusBadge(kind: .pending, text: StudioL10n.key("store.hidden"))
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { business.stores[$0].id }
                        Task {
                            for id in ids { try? await store.repository.deleteStore(id: id) }
                            await store.reload()
                        }
                    }
                } footer: {
                    Text(verbatim: StudioL10n.format("studio.stores.count", business.stores.count, business.limits.maxStores))
                }
            }
        }
        .overlay {
            if business?.stores.isEmpty == true {
                EmptyStateView(systemImage: "storefront", title: StudioL10n.key("stores.empty.title"),
                               message: StudioL10n.key("stores.empty.message"),
                               actionTitle: StudioL10n.key("stores.add")) { editing = StoreDraft() }
            }
        }
        .navigationTitle(StudioL10n.string("studio.stores"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = StoreDraft() } label: { Image(systemName: "plus") }
                    .accessibilityLabel(StudioL10n.string("stores.add"))
            }
        }
        .sheet(item: $editing) { draft in
            NavigationStack { StoreEditScreen(feature: feature, initial: draft) }
        }
        .trackScreen("studio_stores")
    }
}

struct StoreEditScreen: View {
    let feature: StudioFeature
    @State private var draft: StoreDraft
    @State private var isSaving = false
    @State private var message: String?
    @State private var paywallReason: String?
    @Environment(\.dismiss) private var dismiss

    init(feature: StudioFeature, initial: StoreDraft) {
        self.feature = feature
        _draft = State(initialValue: initial)
    }

    private var store: StudioStore { feature.store }

    var body: some View {
        Form {
            Section {
                TextField(StudioL10n.string("store.name"), text: $draft.name)
                TextField(StudioL10n.string("store.description"), text: $draft.description, axis: .vertical)
                    .lineLimit(2...6)
                HStack(spacing: DSSpacing.md) {
                    RemoteImageView(url: draft.logoUrl)
                        .frame(width: 56, height: 56)
                        .background(Color.dsPrimaryMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    PhotoUploadButton(uploader: feature.uploader, folder: "stores", maxCount: 1) { urls in
                        draft.logoUrl = urls.first
                    }
                }
                TextField(StudioL10n.string("business.instagram"), text: $draft.instagram)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section {
                TextField(StudioL10n.string("business.address"), text: $draft.address)
                Picker(StudioL10n.string("business.city"), selection: $draft.cityId) {
                    Text(verbatim: "—").tag(String?.none)
                    ForEach(store.cities) { city in Text(verbatim: city.name()).tag(Optional(city.id)) }
                }
                LocationPicker(lat: $draft.lat, lng: $draft.lng)
                    .listRowInsets(EdgeInsets())
            } header: {
                StudioL10n.text("business.section.location")
            } footer: {
                StudioL10n.text("location.hint")
            }
            Section {
                Toggle(StudioL10n.string("store.visible"), isOn: $draft.isActive)
            }
        }
        .navigationTitle(StudioL10n.string(draft.id == nil ? "stores.add" : "stores.edit"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(StudioL10n.string("common.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(StudioL10n.string("common.save")) { save() }
                    .disabled(!draft.isValid || isSaving)
            }
        }
        .sheet(isPresented: Binding(get: { paywallReason != nil }, set: { if !$0 { paywallReason = nil } })) {
            NavigationStack { PlansScreen(feature: feature, reason: paywallReason) }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(StudioL10n.string("common.ok"), role: .cancel) {}
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                switch try await store.repository.saveStore(draft) {
                case .saved:
                    await store.reload()
                    dismiss()
                case .limitReached(let max):
                    paywallReason = StudioL10n.format("limit.stores", max)
                }
            } catch {
                message = StudioL10n.string("common.saveFailed")
            }
        }
    }
}
