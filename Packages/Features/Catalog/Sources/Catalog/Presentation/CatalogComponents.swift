import SwiftUI
import Core
import DesignSystem
import Shared

/// Shows a `ViewState`: spinner, content, empty, or error with retry.
struct LoadableContent<Value: Sendable, Content: View>: View {
    let state: ViewState<Value>
    var emptyTitle = "common.empty.title"
    var emptyMessage = "common.empty.message"
    let retry: () -> Void
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .tint(Color.dsPrimary)
                .frame(maxWidth: .infinity, minHeight: 240)
        case .loaded(let value), .refreshing(let value):
            content(value)
        case .empty:
            EmptyStateView(systemImage: "sparkles", title: CatalogL10n.key(emptyTitle), message: CatalogL10n.key(emptyMessage))
                .frame(maxWidth: .infinity, minHeight: 240)
        case .error(let error):
            ErrorStateView(error: error, retryAction: retry)
                .frame(maxWidth: .infinity, minHeight: 240)
        case .offline:
            ErrorStateView(error: .offline, retryAction: retry)
                .frame(maxWidth: .infinity, minHeight: 240)
        }
    }
}

/// The service card used in grids and carousels (mockup 2).
struct ServiceCardView: View {
    let card: ServiceCard
    let feature: CatalogFeature
    var width: CGFloat?

    var body: some View {
        NavigationLink(value: CatalogRoute.service(id: card.id)) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                ZStack(alignment: .topTrailing) {
                    RemoteImageView(url: card.imageUrl)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(Color.dsPrimaryMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    FavoriteButton(card: card, feature: feature)
                        .padding(6)
                }
                .overlay(alignment: .bottomLeading) {
                    if card.isFeatured == true {
                        StatusBadge(kind: .featured, text: CatalogL10n.key("badge.featured"))
                            .padding(6)
                    }
                }
                Text(verbatim: card.title)
                    .font(.dsHeadline)
                    .foregroundStyle(Color.dsTextPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(verbatim: card.providerName ?? "")
                        .lineLimit(1)
                    if card.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.dsPrimary)
                            .accessibilityLabel(CatalogL10n.string("badge.verified"))
                            .accessibilityRemoveTraits(.isSelected)
                    }
                }
                .font(.dsFootnote)
                .foregroundStyle(Color.dsTextSecondary)
                HStack {
                    Text(verbatim: formatSAR(card.price))
                        .font(.dsSubhead)
                        .foregroundStyle(Color.dsPrimary)
                    Spacer(minLength: 0)
                    if let avg = card.ratingAvg, let count = card.ratingCount, count > 0 {
                        RatingLabel(avg: avg, count: nil)
                    }
                }
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FavoriteButton: View {
    let card: ServiceCard
    let feature: CatalogFeature

    var body: some View {
        let isOn = feature.favorites.isFavorite(card)
        Button {
            feature.toggleFavorite(card)
        } label: {
            Image(systemName: isOn ? "heart.fill" : "heart")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.dsPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.dsBackground.opacity(0.92)))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CatalogL10n.string(isOn ? "favorite.remove" : "favorite.add"))
    }
}

/// Category icon: the dashboard-uploaded image when present, else the SF Symbol fallback.
struct CategoryTile: View {
    let category: CatalogCategory

    var body: some View {
        NavigationLink(value: CatalogRoute.services(ServiceFilter(categoryId: category.id, title: category.name))) {
            VStack(spacing: 6) {
                Group {
                    if let url = category.iconUrl {
                        RemoteImageView(url: url, contentMode: .fit)
                            .frame(width: 30, height: 30)
                    } else {
                        Image(systemName: category.iconSymbol ?? "sparkles")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.dsPrimary)
                    }
                }
                .frame(width: 60, height: 60)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.dsPrimaryMuted))
                .accessibilityHidden(true)
                // Two lines reserved so every tile in a row is the same height, and a long single
                // word ("photographers") shrinks a little rather than being cut off.
                Text(verbatim: category.name)
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
    }
}

/// The burgundy budget card (mockup 2). Tapping it opens the editor.
struct BudgetCardView: View {
    let budget: Budget?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                HStack {
                    CatalogL10n.text("budget.title").font(.dsSubhead)
                    Spacer()
                    Text(verbatim: CatalogL10n.string(budget == nil ? "budget.set" : "budget.edit"))
                        .font(.dsCaption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.14)))
                }
                if let budget {
                    HStack(alignment: .firstTextBaseline, spacing: DSSpacing.xs) {
                        Text(verbatim: formatSAR(budget.remaining)).font(.dsTitle2)
                        Text(verbatim: CatalogL10n.format("budget.remainingOf", formatSAR(budget.total)))
                            .font(.dsFootnote)
                            .opacity(0.85)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.18))
                            Capsule().fill(Color.dsPremiumGold)
                                .frame(width: proxy.size.width * budget.usedFraction)
                        }
                    }
                    .frame(height: 8)
                    Text(verbatim: CatalogL10n.format("budget.reserved", formatSAR(budget.reserved)))
                        .font(.dsCaption)
                        .opacity(0.9)
                } else {
                    CatalogL10n.text("budget.prompt")
                        .font(.dsFootnote)
                        .opacity(0.9)
                        .multilineTextAlignment(.leading)
                }
            }
            .foregroundStyle(Color.dsBackground)
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsPrimary))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// A titled horizontal carousel of service cards.
struct ServiceCarousel: View {
    let title: String
    let cards: [ServiceCard]
    let feature: CatalogFeature
    var seeAll: CatalogRoute?
    /// Grows with the text size so titles aren't cut to a word at large sizes.
    @ScaledMetric(relativeTo: .body) private var cardWidth: CGFloat = 170

    var body: some View {
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                HStack {
                    Text(verbatim: title).font(.dsTitle2)
                    Spacer()
                    if let seeAll {
                        NavigationLink(value: seeAll) {
                            CatalogL10n.text("common.seeAll").font(.dsSubhead)
                        }
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DSSpacing.sm) {
                        ForEach(cards) { card in
                            ServiceCardView(card: card, feature: feature, width: min(cardWidth, 300))
                        }
                    }
                }
            }
        }
    }
}

/// Grid of service cards: two columns, one at accessibility text sizes.
struct ServiceGrid: View {
    let cards: [ServiceCard]
    let feature: CatalogFeature
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // One column at accessibility sizes: two would leave a word or two per title.
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DSSpacing.sm),
                                 count: typeSize.isAccessibilitySize ? 1 : 2),
                  spacing: DSSpacing.md) {
            ForEach(cards) { card in
                ServiceCardView(card: card, feature: feature)
            }
        }
    }
}

/// "★ 4.8 (12)" from approved bride reviews.
struct RatingLabel: View {
    let avg: Decimal
    let count: Int?

    var body: some View {
        let value = NSDecimalNumber(decimal: avg).doubleValue.formatted(.number.precision(.fractionLength(1)))
        HStack(spacing: 2) {
            Image(systemName: "star.fill").foregroundStyle(Color.dsPremiumGold)
            Text(verbatim: count.map { "\(value) (\($0))" } ?? value)
        }
        .font(.dsCaption)
        .foregroundStyle(Color.dsTextSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(CatalogL10n.format("rating.a11y", value))
    }
}
