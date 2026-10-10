import SwiftUI
import Core
import DesignSystem
import Shared

// MARK: - Service detail

struct ServiceDetailScreen: View {
    let feature: CatalogFeature
    let serviceId: String
    @State private var state: ViewState<ServiceDetail> = .loading
    @State private var showComingSoon = false
    @Environment(\.analytics) private var analytics

    var body: some View {
        ScrollView {
            LoadableContent(state: state, emptyTitle: "detail.missing.title", emptyMessage: "detail.missing.message",
                            retry: { Task { await load() } }) { detail in
                content(detail)
            }
        }
        .dsScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let detail = state.value {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    FavoriteButton(card: detail.card, feature: feature)
                    ShareLink(item: MunyatiLinks.service(detail.card.id), subject: Text(verbatim: detail.card.title)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .simultaneousGesture(TapGesture().onEnded { analytics(.shareTap, detail.card.id, context: "service") })
                    .accessibilityLabel(CatalogL10n.string("share"))
                    feature.trustViews?.moreMenu(.service(detail.card.id))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let detail = state.value { bookBar(detail) }
        }
        .alert(CatalogL10n.string("book.comingSoon.title"), isPresented: $showComingSoon) {
            Button(CatalogL10n.string("common.ok"), role: .cancel) {}
        } message: {
            CatalogL10n.text("book.comingSoon.message")
        }
        .task { await load() }
        .trackScreen("service_detail")
    }

    @ViewBuilder
    private func content(_ detail: ServiceDetail) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            gallery(detail)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(verbatim: detail.card.title).font(.dsTitle1)
                Text(verbatim: formatSAR(detail.card.price)).font(.dsTitle2).foregroundStyle(Color.dsPrimary)
            }
            NavigationLink(value: CatalogRoute.provider(id: detail.provider.id)) {
                ProviderRow(provider: detail.provider)
            }
            .buttonStyle(.plain)
            facts(detail)
            if let description = detail.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    CatalogL10n.text("detail.about").font(.dsHeadline)
                    Text(verbatim: description).font(.dsBody).foregroundStyle(Color.dsTextSecondary)
                }
            }
            if let store = detail.store {
                NavigationLink(value: CatalogRoute.store(id: store.id)) {
                    InfoRow(systemImage: "storefront", title: store.name, subtitle: store.address)
                }
                .buttonStyle(.plain)
            }
            ServiceCarousel(title: CatalogL10n.string("detail.moreFromProvider"), cards: detail.moreFromProvider, feature: feature)
        }
        .padding(DSSpacing.lg)
    }

    private func gallery(_ detail: ServiceDetail) -> some View {
        let urls = detail.imageUrls.isEmpty ? [detail.card.imageUrl].compactMap { $0 } : detail.imageUrls
        return TabView {
            if urls.isEmpty {
                Color.dsPrimaryMuted
            }
            ForEach(urls, id: \.self) { url in
                RemoteImageView(url: url)
            }
        }
        .tabViewStyle(.page)
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
        .accessibilityHidden(true)
    }

    private func facts(_ detail: ServiceDetail) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            if let minutes = detail.durationMinutes {
                InfoRow(systemImage: "clock", title: durationText(minutes), subtitle: nil)
            }
            if detail.atCustomerLocation {
                InfoRow(systemImage: "house", title: CatalogL10n.string("detail.atLocation"), subtitle: nil)
            }
            if detail.card.femaleStaffOnly {
                InfoRow(systemImage: "person.2", title: CatalogL10n.string("detail.femaleOnly"), subtitle: nil)
            }
        }
    }

    private func durationText(_ minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = minutes >= 60 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .full
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes)"
    }

    private func bookBar(_ detail: ServiceDetail) -> some View {
        HStack(spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: 0) {
                CatalogL10n.text("detail.price").font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                Text(verbatim: formatSAR(detail.card.price)).font(.dsHeadline)
            }
            PrimaryButton(CatalogL10n.key("book.cta")) {
                analytics(.bookingStarted, detail.card.id)
                if let onBook = feature.onBook {
                    onBook(detail.card)
                } else {
                    showComingSoon = true
                }
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.sm)
        .background(.bar)
    }

    private func load() async {
        do {
            if let detail = try await feature.repository.service(id: serviceId) {
                state = .loaded(detail)
                analytics(.serviceView, serviceId, context: detail.provider.id, props: ["category_id": detail.card.categoryId])
            } else {
                state = .empty
            }
        } catch {
            state = .error(appError(error))
        }
    }
}

// MARK: - Provider profile

struct ProviderScreen: View {
    let feature: CatalogFeature
    let providerId: String
    @State private var state: ViewState<ProviderProfile> = .loading
    @Environment(\.analytics) private var analytics

    var body: some View {
        ScrollView {
            LoadableContent(state: state, emptyTitle: "detail.missing.title", emptyMessage: "detail.missing.message",
                            retry: { Task { await load() } }) { profile in
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    ZStack(alignment: .bottomLeading) {
                        RemoteImageView(url: profile.coverUrl)
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .background(Color.dsPrimaryMuted)
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
                        ProviderAvatar(url: profile.summary.logoUrl, name: profile.summary.name, size: 72)
                            .offset(x: DSSpacing.lg, y: 36)
                    }
                    .padding(.bottom, 36)
                    ProviderRow(provider: profile.summary, showsChevron: false)
                    if let bio = profile.bio, !bio.isEmpty {
                        Text(verbatim: bio).font(.dsBody).foregroundStyle(Color.dsTextSecondary)
                    }
                    if let address = profile.address, !address.isEmpty {
                        InfoRow(systemImage: "mappin.and.ellipse", title: address, subtitle: nil)
                    }
                    if !profile.stores.isEmpty {
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            CatalogL10n.text("detail.stores").font(.dsTitle2)
                            ForEach(profile.stores) { store in
                                NavigationLink(value: CatalogRoute.store(id: store.id)) {
                                    InfoRow(systemImage: "storefront", title: store.name, subtitle: store.address)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    CatalogL10n.text("detail.services").font(.dsTitle2)
                    ServiceGrid(cards: profile.services, feature: feature)
                    feature.trustViews?.reviews(providerId)
                }
                .padding(DSSpacing.lg)
            }
        }
        .dsScreenBackground()
        .navigationTitle(state.value?.summary.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: MunyatiLinks.provider(providerId)) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel(CatalogL10n.string("share"))
                    .simultaneousGesture(TapGesture().onEnded { analytics(.shareTap, providerId, context: "provider") })
                feature.trustViews?.moreMenu(.provider(providerId))
            }
        }
        .task { await load() }
        .trackScreen("provider_profile")
    }

    private func load() async {
        do {
            if let profile = try await feature.repository.provider(id: providerId) {
                state = .loaded(profile)
                analytics(.providerView, providerId)
            } else {
                state = .empty
            }
        } catch {
            state = .error(appError(error))
        }
    }
}

// MARK: - Store

struct StoreScreen: View {
    let feature: CatalogFeature
    let storeId: String
    @State private var state: ViewState<StoreDetail> = .loading
    @Environment(\.analytics) private var analytics

    var body: some View {
        ScrollView {
            LoadableContent(state: state, emptyTitle: "detail.missing.title", emptyMessage: "detail.missing.message",
                            retry: { Task { await load() } }) { store in
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    HStack(spacing: DSSpacing.md) {
                        ProviderAvatar(url: store.summary.logoUrl, name: store.summary.name, size: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: store.summary.name).font(.dsTitle1)
                            if let address = store.summary.address {
                                Text(verbatim: address).font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                            }
                        }
                    }
                    if let description = store.description, !description.isEmpty {
                        Text(verbatim: description).font(.dsBody).foregroundStyle(Color.dsTextSecondary)
                    }
                    NavigationLink(value: CatalogRoute.provider(id: store.provider.id)) {
                        ProviderRow(provider: store.provider)
                    }
                    .buttonStyle(.plain)
                    ServiceGrid(cards: store.services, feature: feature)
                }
                .padding(DSSpacing.lg)
            }
        }
        .dsScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                feature.trustViews?.moreMenu(.store(storeId))
                ShareLink(item: MunyatiLinks.store(storeId)) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel(CatalogL10n.string("share"))
            }
        }
        .task { await load() }
        .trackScreen("store")
    }

    private func load() async {
        do {
            if let store = try await feature.repository.store(id: storeId) {
                state = .loaded(store)
                analytics(.storeView, storeId)
            } else {
                state = .empty
            }
        } catch {
            state = .error(appError(error))
        }
    }
}

// MARK: - Small shared rows

struct ProviderAvatar: View {
    let url: URL?
    let name: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let url {
                RemoteImageView(url: url)
            } else {
                Text(verbatim: String(name?.first ?? "م"))
                    .font(.custom(DSFonts.displayBold, size: size * 0.42))
                    .foregroundStyle(Color.dsPremiumGold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.dsPrimary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.dsBackground, lineWidth: 3))
        .accessibilityHidden(true)
    }
}

struct ProviderRow: View {
    let provider: ProviderSummary
    var showsChevron = true

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            ProviderAvatar(url: provider.logoUrl, name: provider.name, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(verbatim: provider.name ?? "").font(.dsHeadline)
                    if provider.isVerified {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.dsPrimary)
                            .accessibilityLabel(CatalogL10n.string("badge.verified"))
                    }
                }
                if let avg = provider.ratingAvg, let count = provider.ratingCount, count > 0 {
                    RatingLabel(avg: avg, count: count)
                }
                if provider.femaleStaffOnly {
                    CatalogL10n.text("detail.femaleOnly").font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                }
            }
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.forward").foregroundStyle(Color.dsTextSecondary)
            }
        }
        .padding(DSSpacing.sm)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.dsSurface))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.dsBorder))
        .contentShape(Rectangle())
    }
}

struct InfoRow: View {
    let systemImage: String
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.dsPrimary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.dsSubhead).foregroundStyle(Color.dsTextPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle).font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
