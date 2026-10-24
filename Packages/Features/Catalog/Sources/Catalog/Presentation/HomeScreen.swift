import SwiftUI
import Core
import DesignSystem
import Shared

// MARK: - Home (Home v2: brand hero, carousel, picks, trust strip, provider invite)

struct HomeScreen: View {
    let feature: CatalogFeature
    @State private var state: ViewState<HomeContent> = .loading
    @State private var showBudget = false
    @Environment(\.analytics) private var analytics
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.openURL) private var openURL

    private var context: CatalogContext { feature.context }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                searchBar
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.top, -28)

                VStack(alignment: .leading, spacing: DSSpacing.xl) {
                    if !context.isGuest {
                        weddingRow
                    }
                    LoadableContent(state: state, retry: reload) { home in
                        VStack(alignment: .leading, spacing: DSSpacing.xl) {
                            let slides = slides(for: home.banners)
                            if !slides.isEmpty {
                                HomeCarousel(slides: slides, onTap: open)
                            }
                            categories(home.categories)
                            ServiceCarousel(
                                title: CatalogL10n.string(feature.budget.budget == nil ? "home.featured" : "home.withinBudget"),
                                cards: home.featured,
                                feature: feature,
                                seeAll: .services(ServiceFilter(title: CatalogL10n.string("home.withinBudget"),
                                                                 withinBudget: feature.budget.budget != nil))
                            )
                            WhyMunyatiStrip()
                            ServiceCarousel(
                                title: CatalogL10n.string("home.newest"),
                                cards: home.newest,
                                feature: feature,
                                seeAll: .services(ServiceFilter(title: CatalogL10n.string("home.newest"), sort: .newest))
                            )
                            ProviderInviteCard {
                                if let url = URL(string: "https://munyati.co/providers") { openURL(url) }
                            }
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.lg)
                .padding(.bottom, DSSpacing.xl)
            }
        }
        .dsScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        // No navigation bar here: paint the status bar in the hero's burgundy so scrolled content
        // doesn't run under the clock and the hero reads as one piece with it.
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(DSGradient.primaryStart)
        }
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

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack(spacing: DSSpacing.xs) {
                DSBrand.wordmarkReversed
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .accessibilityLabel(CatalogL10n.string("home.brand"))
                Spacer()
                NavigationLink(value: CatalogRoute.favorites) {
                    Image(systemName: "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CatalogL10n.string("favorites.title"))
                Button(action: feature.openCityPicker) {
                    Label(context.citySummary, systemImage: "mappin.and.ellipse")
                        .font(.dsSubhead)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DSSpacing.sm)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Color.white.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(Color.dsPremiumGold.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .accessibilityHint(CatalogL10n.string("cities.hint"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: CatalogL10n.string(Self.isMorning ? "home.greeting.morning" : "home.greeting.evening"))
                    .font(.dsSubhead)
                    .foregroundStyle(.white.opacity(0.85))
                Text(verbatim: context.displayName ?? CatalogL10n.string("home.guestName"))
                    .font(.dsLargeTitle)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    DSSparkle(size: 10)
                    CatalogL10n.text("home.tagline")
                        .font(.dsFootnote.weight(.medium))
                        .foregroundStyle(Color.dsPremiumGold)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.sm)
        .padding(.bottom, DSSpacing.xxl + 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSBrandHeroBackground())
    }

    private static var isMorning: Bool { Calendar.current.component(.hour, from: .now) < 12 }

    private var searchBar: some View {
        NavigationLink(value: CatalogRoute.services(ServiceFilter(title: CatalogL10n.string("search.title")))) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.dsPrimary)
                    .accessibilityHidden(true)
                CatalogL10n.text("search.placeholder")
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.dsPrimary))
                    .accessibilityHidden(true)
            }
            .font(.dsBody)
            .foregroundStyle(Color.dsTextSecondary)
            .padding(.leading, DSSpacing.md)
            .padding(.trailing, 6)
            .frame(minHeight: 56)
            .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsSurface))
            .dsShadow(DSShadow.level2)
        }
        .buttonStyle(.plain)
    }

    // MARK: Wedding countdown + budget

    private var weddingRow: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            if !typeSize.isAccessibilitySize {
                WeddingCountdownCard(days: feature.daysUntilWedding) { showBudget = true }
                    .frame(width: 128)
            }
            BudgetCardView(budget: feature.budget.budget) { showBudget = true }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Carousel

    /// Dashboard banners first, then the built-in brand slides the dashboard hasn't hidden. With
    /// both hidden and no banners, Home shows no carousel at all.
    private func slides(for banners: [HomeBanner]) -> [HomeSlide] {
        banners.map(HomeSlide.banner)
            + (context.showsBudgetSlide ? [.budget] : [])
            + (context.showsDiscoverSlide ? [.discover] : [])
    }

    private func open(_ slide: HomeSlide) {
        switch slide {
        case .banner(let banner):
            analytics(.bannerClick, banner.id)
            if let url = banner.linkUrl { feature.openLink?(url) }
        case .budget:
            if context.isGuest { feature.requireSignIn() } else { showBudget = true }
        case .discover:
            break // handled by the slide's NavigationLink
        }
    }

    // MARK: Categories

    private func categories(_ list: [CatalogCategory]) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HomeSectionTitle(title: CatalogL10n.string("home.categories"))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DSSpacing.xs, alignment: .top),
                                     count: typeSize.isAccessibilitySize ? 2 : 4),
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

// MARK: - Pieces

/// A section title with the gold sparkle from the logo.
struct HomeSectionTitle: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            DSSparkle(size: 11)
            Text(verbatim: title)
                .font(.dsTitle2)
                .foregroundStyle(Color.dsTextPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// One carousel page: a dashboard banner or a built-in brand slide.
enum HomeSlide: Identifiable, Hashable {
    case banner(HomeBanner)
    case budget
    case discover

    var id: String {
        switch self {
        case .banner(let banner): "banner-\(banner.id)"
        case .budget: "budget"
        case .discover: "discover"
        }
    }
}

/// The auto-advancing Home carousel with page dots under it.
struct HomeCarousel: View {
    let slides: [HomeSlide]
    let onTap: (HomeSlide) -> Void
    @State private var index = 0
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 190

    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            InfiniteCarousel(items: slides, autoScrollInterval: .seconds(5), showsBuiltInIndicator: false,
                             onDisplayedIndexChange: { index = $0 }) { slide in
                slideView(slide)
                    .padding(.horizontal, 1)
            }
            .frame(height: min(height, 260))
            if slides.count > 1 {
                CarouselPageIndicator(count: slides.count, index: index, tint: Color.dsPrimary)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func slideView(_ slide: HomeSlide) -> some View {
        switch slide {
        case .discover:
            NavigationLink(value: CatalogRoute.services(ServiceFilter(title: CatalogL10n.string("search.title")))) {
                HomeSlideCard(slide: slide)
            }
            .buttonStyle(.plain)
        default:
            Button { onTap(slide) } label: { HomeSlideCard(slide: slide) }
                .buttonStyle(.plain)
        }
    }
}

private struct HomeSlideCard: View {
    let slide: HomeSlide

    private var isGold: Bool { slide == .budget }
    private var ink: Color { isGold ? Color.dsPrimaryPress : .white }

    private var badge: String? { slide == .budget ? CatalogL10n.string("home.slide.budget.badge") : nil }
    private var imageOnly: Bool {
        if case .banner(let banner) = slide { return banner.isImageOnly }
        return false
    }
    private var title: String {
        switch slide {
        case .banner(let banner): banner.title ?? ""
        case .budget: CatalogL10n.string("home.slide.budget.title")
        case .discover: CatalogL10n.string("home.slide.discover.title")
        }
    }
    private var subtitle: String? {
        switch slide {
        case .banner(let banner): banner.subtitle
        case .budget: CatalogL10n.string("home.slide.budget.subtitle")
        case .discover: CatalogL10n.string("home.slide.discover.subtitle")
        }
    }
    private var cta: String? {
        switch slide {
        case .banner(let banner): banner.linkUrl == nil ? nil : banner.cta
        case .budget: CatalogL10n.string("home.slide.budget.cta")
        case .discover: CatalogL10n.string("home.slide.discover.cta")
        }
    }

    var body: some View {
        if imageOnly, case .banner(let banner) = slide, let url = banner.imageUrl {
            // A designed banner: shown exactly as uploaded. `Color.clear` takes the slot's exact size
            // and the image fills it as an overlay, so the rounded clip matches the other slides
            // (a fill image as the base view would size itself to the photo and escape the clip).
            Color.clear
                .overlay { RemoteImageView(url: url) }
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
                .contentShape(RoundedRectangle(cornerRadius: DSRadius.card))
                .accessibilityElement()
                .accessibilityLabel(banner.subtitle ?? CatalogL10n.string("home.slide.banner.image"))
                .accessibilityAddTraits(.isButton)
        } else {
            card
        }
    }

    private var card: some View {
        ZStack(alignment: .leading) {
            background
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                if let badge {
                    Text(verbatim: badge)
                        .font(.dsCaption)
                        .foregroundStyle(ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.45)))
                }
                Text(verbatim: title)
                    .font(.dsTitle1)
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    // The title keeps its second line; the subtitle gives way first.
                    .layoutPriority(1)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(.dsFootnote)
                        .foregroundStyle(ink.opacity(0.88))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if let cta {
                    Text(verbatim: cta)
                        .font(.dsSubhead.weight(.semibold))
                        .foregroundStyle(isGold ? .white : Color.dsPrimaryPress)
                        .padding(.horizontal, DSSpacing.md)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(isGold ? AnyShapeStyle(Color.dsPrimary) : AnyShapeStyle(DSGradient.gold)))
                }
            }
            .padding(DSSpacing.lg)
            .frame(maxWidth: 280, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
        .contentShape(RoundedRectangle(cornerRadius: DSRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var background: some View {
        if case .banner(let banner) = slide, let url = banner.imageUrl {
            RemoteImageView(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay {
                    // Darkens the text side so white text stays readable on any photo.
                    LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0)], startPoint: .leading, endPoint: .trailing)
                }
        } else {
            Rectangle()
                .fill(isGold ? AnyShapeStyle(DSGradient.gold) : AnyShapeStyle(DSGradient.primary))
                .overlay(alignment: .trailing) {
                    DSBrand.ring
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(isGold ? Color.dsPrimary.opacity(0.14) : Color.dsPremiumGold.opacity(0.22))
                        .frame(width: 170, height: 170)
                        .offset(x: 30)
                }
                .overlay(alignment: .topTrailing) {
                    DSSparkle(size: 14).opacity(isGold ? 0 : 0.85).padding(DSSpacing.lg)
                }
        }
    }
}

/// Days to the wedding in a gold ring; without a date, a prompt to set one.
struct WeddingCountdownCard: View {
    let days: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DSSpacing.xs) {
                CatalogL10n.text("home.countdown.title")
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                ZStack {
                    Circle().stroke(Color.dsPrimaryMuted, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: ringFraction)
                        .stroke(DSGradient.gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    if let days {
                        Text(verbatim: days.formatted())
                            .font(.dsTitle1)
                            .foregroundStyle(Color.dsPrimary)
                            .minimumScaleFactor(0.6)
                            .padding(DSSpacing.xs)
                    } else {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.dsPrimary)
                    }
                }
                .padding(3)
                .frame(width: 76, height: 76)
                Text(verbatim: CatalogL10n.string(days == nil ? "home.countdown.setDate" : (days == 0 ? "home.countdown.today" : "home.countdown.subtitle")))
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(DSSpacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsSurface))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.card).strokeBorder(Color.dsBorder))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// The ring fills up over the last year before the wedding.
    private var ringFraction: CGFloat {
        guard let days else { return 0 }
        return max(0.04, 1 - CGFloat(min(days, 365)) / 365)
    }
}

/// "Why Munyati": the three promises, as a quiet strip between the lists.
struct WhyMunyatiStrip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HomeSectionTitle(title: CatalogL10n.string("home.why.title"))
            HStack(alignment: .top, spacing: DSSpacing.xs) {
                item("checkmark.seal.fill", "home.why.verified")
                item("banknote.fill", "home.why.direct")
                item("star.fill", "home.why.reviews")
            }
            .padding(DSSpacing.md)
            .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsSurface))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.card).strokeBorder(Color.dsBorder))
        }
    }

    private func item(_ symbol: String, _ key: String) -> some View {
        VStack(spacing: DSSpacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.dsPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.dsPrimaryMuted))
                .accessibilityHidden(true)
            CatalogL10n.text(key)
                .font(.dsCaption)
                .foregroundStyle(Color.dsTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Invites service providers to join (the website explains plans and how to sign up).
struct ProviderInviteCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.sm) {
                DSBrand.ring
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    CatalogL10n.text("home.join.title")
                        .font(.dsHeadline)
                        .foregroundStyle(Color.dsTextPrimary)
                    CatalogL10n.text("home.join.subtitle")
                        .font(.dsFootnote)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.dsFootnote.weight(.semibold))
                    .foregroundStyle(Color.dsPrimary)
                    .accessibilityHidden(true)
            }
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsPrimaryMuted))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.card).strokeBorder(Color.dsPremiumGold.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
