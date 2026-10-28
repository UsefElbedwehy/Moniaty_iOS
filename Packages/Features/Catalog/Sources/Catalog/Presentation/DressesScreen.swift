import SwiftUI
import Core
import DesignSystem
import Shared

/// «فساتين»: dresses for rent, listed by the admin, in three lists (wedding, jalwa, evening).
/// A notice at the top tells dress owners how to list theirs; tapping a dress shows it large with
/// its price and buttons to reach the owner on WhatsApp or by phone.
struct DressesScreen: View {
    let feature: CatalogFeature
    @State private var kind: DressListing.Kind = .wedding
    @State private var state: ViewState<DressListingsPage> = .loading
    @State private var open: DressListing?

    private let columns = [GridItem(.flexible(), spacing: DSSpacing.md), GridItem(.flexible(), spacing: DSSpacing.md)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Picker(CatalogL10n.string("dresses.title"), selection: $kind) {
                    ForEach(DressListing.Kind.allCases, id: \.self) { kind in
                        Text(verbatim: CatalogL10n.string("dresses.kind.\(kind.rawValue)")).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                if case .loaded(let page) = state, let notice = page.notice, notice.phone != nil {
                    DressNoticeCard(notice: notice)
                }

                LoadableContent(state: state, emptyTitle: "dresses.empty.title", emptyMessage: "dresses.empty.message",
                                retry: { Task { await load() } }) { page in
                    if page.listings.isEmpty {
                        EmptyStateView(systemImage: "tshirt", title: CatalogL10n.key("dresses.empty.title"),
                                       message: CatalogL10n.key("dresses.empty.message"))
                    } else {
                        LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                            ForEach(page.listings) { dress in
                                Button { open = dress } label: { DressCard(dress: dress) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(DSSpacing.lg)
        }
        .dsScreenBackground()
        .navigationTitle(CatalogL10n.string("dresses.title"))
        .task(id: kind) { await load() }
        .refreshable { await load() }
        .sheet(item: $open) { DressSheet(dress: $0) }
        .trackScreen("dresses")
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            state = .loaded(try await feature.repository.dresses(kind: kind))
        } catch {
            state = .error(appError(error))
        }
    }
}

/// A dress in the grid: the photo (3:4) and the price.
private struct DressCard: View {
    let dress: DressListing

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Color.dsPrimaryMuted
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay { RemoteImageView(url: dress.imageUrl, thumbnail: true) }
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
            Text(verbatim: formatSAR(dress.price))
                .font(.dsHeadline)
                .foregroundStyle(Color.dsPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The dress large, with its price and the owner's WhatsApp and phone.
private struct DressSheet: View {
    let dress: DressListing
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    RemoteImageView(url: dress.imageUrl, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        CatalogL10n.text("dresses.rentPrice").font(.dsSubhead).foregroundStyle(Color.dsTextSecondary)
                        Text(verbatim: formatSAR(dress.price)).font(.dsTitle1).foregroundStyle(Color.dsPrimary)
                    }
                    CatalogL10n.text("dresses.contactOwner").font(.dsHeadline).foregroundStyle(Color.dsTextPrimary)
                    if let url = dress.whatsAppURL {
                        PrimaryButton(CatalogL10n.key("dresses.whatsapp"), systemImage: "message.fill") { openURL(url) }
                    }
                    if let url = dress.callURL {
                        SecondaryButton(CatalogL10n.key("dresses.call"), systemImage: "phone.fill") { openURL(url) }
                    }
                    Text(verbatim: localPhone(dress.contactPhone))
                        .font(.dsFootnote)
                        .foregroundStyle(Color.dsTextSecondary)
                        .environment(\.layoutDirection, .leftToRight)
                        .frame(maxWidth: .infinity)
                }
                .padding(DSSpacing.lg)
            }
            .dsScreenBackground()
            .navigationTitle(CatalogL10n.string("dresses.kind.\(dress.kind.rawValue)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(CatalogL10n.string("common.close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .trackScreen("dress_detail")
    }
}

/// «اعرضي فستانك للإيجار بـ ٢٠ ريال لمدة شهر»: how a dress owner gets listed.
private struct DressNoticeCard: View {
    let notice: DressNotice
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: "tag.fill").foregroundStyle(Color.dsPrimaryPress)
                Text(verbatim: CatalogL10n.format("dresses.notice.title", formatSAR(notice.price ?? 20)))
                    .font(.dsHeadline)
                    .foregroundStyle(Color.dsPrimaryPress)
            }
            CatalogL10n.text("dresses.notice.body")
                .font(.dsFootnote)
                .foregroundStyle(Color.dsPrimaryPress.opacity(0.85))
            HStack(spacing: DSSpacing.sm) {
                if let url = notice.whatsAppURL {
                    Button { openURL(url) } label: {
                        Label(CatalogL10n.string("dresses.whatsapp"), systemImage: "message.fill")
                            .font(.dsSubhead.weight(.semibold))
                            .padding(.horizontal, DSSpacing.md).padding(.vertical, DSSpacing.xs)
                            .background(Capsule().fill(Color.dsPrimary))
                            .foregroundStyle(.white)
                    }
                }
                if let url = notice.callURL {
                    Button { openURL(url) } label: {
                        Label(CatalogL10n.string("dresses.call"), systemImage: "phone.fill")
                            .font(.dsSubhead.weight(.semibold))
                            .padding(.horizontal, DSSpacing.md).padding(.vertical, DSSpacing.xs)
                            .background(Capsule().strokeBorder(Color.dsPrimary))
                            .foregroundStyle(Color.dsPrimary)
                    }
                }
            }
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(DSGradient.gold))
    }
}

/// +9665XXXXXXXX → 05XXXXXXXX, how people write it.
private func localPhone(_ phone: String) -> String {
    phone.hasPrefix("+966") ? "0" + phone.dropFirst(4) : phone
}
