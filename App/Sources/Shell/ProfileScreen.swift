import SwiftUI
import StoreKit
import DesignSystem
import Shared
import Catalog
import Trust

/// Profile & settings, shared by both roles (Profile v2, modeled on Kolna Al-Khafji and Lamha):
/// a burgundy identity hero, stats, a share card, grouped rows with colored icon tiles,
/// follow-us links from remote config, sign out and in-app account deletion
/// (App Store guideline 5.1.1(v)), and a brand footer.
struct ProfileScreen: View {
    let environment: AppEnvironment
    @State private var showCities = false
    @State private var showBudget = false
    @State private var confirmDelete = false
    @State private var confirmSignOut = false
    @State private var isDeleting = false
    @State private var deleteFailed = false
    @State private var bookingsCount: Int?
    @State private var favoritesCount: Int?
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system
    @Environment(\.requestReview) private var requestReview

    private var session: AppSession { environment.session }
    private var isBride: Bool { session.role != .provider }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.lg) {
                if session.hasAccount, isBride {
                    // The stats card overlaps the hero by a fixed amount and grows downward with
                    // the text size, so it never covers the hero's content.
                    VStack(spacing: -Self.statsOverlap) {
                        hero
                        stats.padding(.horizontal, DSSpacing.lg)
                    }
                } else {
                    hero
                }
                Group {
                    shareCard
                    if isBride { weddingSection }
                    appSection
                    helpSection
                    followUs
                    if session.hasAccount { accountSection }
                    footer
                }
                .padding(.horizontal, DSSpacing.lg)
            }
            .padding(.bottom, DSSpacing.xl)
        }
        .dsScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(DSGradient.primaryStart)
        }
        .task(id: session.user?.id) { await loadStats() }
        .refreshable { await loadStats() }
        .sheet(isPresented: $showCities) {
            CityPickerSheet(environment: environment)
        }
        .sheet(isPresented: $showBudget) {
            environment.catalog.budgetEditor()
        }
        .confirmationDialog(L10n.string("profile.signOut.confirmTitle"), isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button(L10n.string("profile.signOut")) { Task { await environment.signOut() } }
        }
        .confirmationDialog(L10n.string("profile.deleteAccount.confirmTitle"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L10n.string("profile.deleteAccount.confirm"), role: .destructive) {
                Task {
                    isDeleting = true
                    defer { isDeleting = false }
                    do { try await environment.deleteAccount() } catch { deleteFailed = true }
                }
            }
        } message: {
            L10n.text("profile.deleteAccount.message")
        }
        .alert(L10n.string("profile.deleteAccount.failed"), isPresented: $deleteFailed) {
            Button(L10n.string("common.ok"), role: .cancel) {}
        }
        .trackScreen("profile")
    }

    /// How far the stats card reaches up into the hero.
    private static let statsOverlap: CGFloat = 40

    private func loadStats() async {
        guard session.hasAccount, isBride else { return }
        async let bookings = environment.booking.activeBookingsCount()
        async let favorites = environment.catalog.favoritesCount()
        (bookingsCount, favoritesCount) = await (bookings, favorites)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: DSSpacing.xs) {
            HStack {
                L10n.text("tab.profile")
                    .font(.dsTitle1)
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .padding(.bottom, DSSpacing.xs)

            avatar
            if session.hasAccount, let user = session.user {
                Text(verbatim: user.displayName ?? "")
                    .font(.dsLargeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                if let phone = user.phone {
                    // Isolated left-to-right so the "+" stays in front in Arabic.
                    Text(verbatim: "\u{2066}\(Self.formatPhone(phone))\u{2069}")
                        .font(.dsSubhead)
                        .foregroundStyle(.white.opacity(0.8))
                }
                HStack(spacing: 6) {
                    DSSparkle(size: 10)
                    L10n.text(user.role == .provider ? "profile.role.provider" : "profile.role.bride")
                }
                .font(.dsCaption)
                .foregroundStyle(Color.dsPremiumGold)
                .padding(.horizontal, DSSpacing.sm)
                .frame(minHeight: 28)
                .overlay(Capsule().strokeBorder(Color.dsPremiumGold))
            } else {
                L10n.text("profile.guest.title")
                    .font(.dsTitle1)
                    .foregroundStyle(.white)
                L10n.text("profile.guest.message")
                    .font(.dsFootnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                Button {
                    session.isPresentingAuth = true
                } label: {
                    L10n.text("auth.signIn")
                        .font(.dsHeadline)
                        .foregroundStyle(Color.dsPrimaryPress)
                        .padding(.horizontal, DSSpacing.xl)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(DSGradient.gold))
                }
                .buttonStyle(.plain)
                .padding(.top, DSSpacing.xs)
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.sm)
        .padding(.bottom, session.hasAccount && isBride ? Self.statsOverlap + DSSpacing.lg : DSSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(DSBrandHeroBackground())
    }

    private var avatar: some View {
        Group {
            if session.hasAccount, let initial = session.user?.displayName?.trimmingCharacters(in: .whitespaces).first {
                Text(verbatim: String(initial))
                    .font(.custom(DSFonts.displayBold, size: 42, relativeTo: .largeTitle))
                    .foregroundStyle(Color.dsPrimary)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.dsPrimary)
            }
        }
        .frame(width: 96, height: 96)
        .background(Circle().fill(Color.dsPrimaryMuted))
        .overlay(Circle().strokeBorder(Color.dsPremiumGold, lineWidth: 3))
        .accessibilityHidden(true)
    }

    /// "+966 55 111 1111" from the stored "+966551111111".
    static func formatPhone(_ phone: String) -> String {
        guard phone.hasPrefix("+966"), phone.count == 13 else { return phone }
        let digits = Array(phone.dropFirst(4))
        return "+966 \(String(digits[0..<2])) \(String(digits[2..<5])) \(String(digits[5...]))"
    }

    // MARK: Stats

    private var stats: some View {
        HStack(spacing: 0) {
            stat(value: bookingsCount, key: "profile.stats.bookings")
            Divider().frame(height: 36)
            NavigationLink(value: CatalogRoute.favorites) {
                stat(value: favoritesCount, key: "profile.stats.favorites")
            }
            .buttonStyle(.plain)
            Divider().frame(height: 36)
            if let days = environment.catalog.daysUntilWedding {
                stat(value: days, key: "profile.stats.days")
            } else {
                Button { showBudget = true } label: { stat(value: nil, key: "profile.stats.setDate") }
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DSSpacing.md)
        .background(RoundedRectangle(cornerRadius: DSRadius.card + 2).fill(Color.dsSurface))
        .dsShadow(DSShadow.level2)
    }

    private func stat(value: Int?, key: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value.map { $0.formatted() } ?? "—")
                .font(.dsTitle1)
                .foregroundStyle(Color.dsPrimary)
            L10n.text(key)
                .font(.dsCaption)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: Share

    private var shareCard: some View {
        ShareLink(item: URL(string: "https://munyati.co")!, message: Text(verbatim: L10n.string("profile.share.message"))) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.dsPrimaryPress)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.55)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    L10n.text(isBride ? "profile.share.title" : "profile.share.titleProvider")
                        .font(.dsHeadline)
                    L10n.text("profile.share.subtitle")
                        .font(.dsFootnote)
                        .opacity(0.85)
                }
                .foregroundStyle(Color.dsPrimaryPress)
                Spacer(minLength: 0)
            }
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // The watermark lives in an overlay of the card's own shape so it never makes
                // the background taller than the card.
                RoundedRectangle(cornerRadius: DSRadius.card + 2)
                    .fill(DSGradient.gold)
                    .overlay(alignment: .bottomTrailing) {
                        DSBrand.ring
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.dsPrimary.opacity(0.14))
                            .frame(width: 110, height: 110)
                            .offset(x: 18, y: 26)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.card + 2))
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    // MARK: Sections

    private var weddingSection: some View {
        ProfileSection(titleKey: "profile.section.wedding") {
            NavigationLink(value: CatalogRoute.favorites) {
                ProfileRow(symbol: "heart.fill", tint: .pink, titleKey: "profile.favorites")
            }
            ProfileDivider()
            Button {
                if session.hasAccount { showBudget = true } else { session.isPresentingAuth = true }
            } label: {
                ProfileRow(symbol: "banknote", tint: .gold, titleKey: "profile.budget",
                           value: environment.catalog.currentBudget.map { formatSAR($0.remaining) })
            }
            ProfileDivider()
            Button { showCities = true } label: {
                ProfileRow(symbol: "mappin.and.ellipse", tint: .brand, titleKey: "profile.cities",
                           value: environment.cities.summary(allLabel: L10n.string("cities.all")))
            }
        }
    }

    private var appSection: some View {
        ProfileSection(titleKey: "profile.section.app") {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            } label: {
                // Opens the app's page in iOS Settings, where the language is chosen.
                ProfileRow(symbol: "globe", tint: .blue, titleKey: "profile.language",
                           value: L10n.string("profile.language.current"), trailingSymbol: "arrow.up.forward")
            }
            ProfileDivider()
            Menu {
                Picker(L10n.string("profile.appearance"), selection: $appearance) {
                    ForEach(Appearance.allCases, id: \.self) { option in
                        Text(verbatim: L10n.string(option.titleKey)).tag(option)
                    }
                }
            } label: {
                ProfileRow(symbol: "moon.fill", tint: .purple, titleKey: "profile.appearance",
                           value: L10n.string(appearance.titleKey), trailingSymbol: "chevron.up.chevron.down")
            }
        }
    }

    private var helpSection: some View {
        ProfileSection(titleKey: "profile.section.help") {
            NavigationLink {
                environment.trust.supportScreen(contacts: supportContacts, faqURL: environment.remoteConfig.config?.support.helpCenterURL)
            } label: { ProfileRow(symbol: "bubble.left.and.bubble.right.fill", tint: .green, titleKey: "profile.support") }
            ProfileDivider()
            NavigationLink {
                CMSPageScreen(slug: "about", repository: environment.cmsPageRepository)
            } label: { ProfileRow(brandIcon: true, tint: .brand, titleKey: "profile.about") }
            ProfileDivider()
            NavigationLink {
                CMSPageScreen(slug: "terms", repository: environment.cmsPageRepository)
            } label: { ProfileRow(symbol: "doc.text", tint: .neutral, titleKey: "profile.terms") }
            ProfileDivider()
            NavigationLink {
                CMSPageScreen(slug: "privacy", repository: environment.cmsPageRepository)
            } label: { ProfileRow(symbol: "lock.shield", tint: .neutral, titleKey: "profile.privacy") }
            ProfileDivider()
            Button { requestReview() } label: {
                ProfileRow(symbol: "star.fill", tint: .gold, titleKey: "profile.rate", showsChevron: false)
            }
        }
    }

    /// Social accounts from remote config (`social_links`), as round icon buttons.
    @ViewBuilder
    private var followUs: some View {
        let links = (environment.remoteConfig.config?.socialLinks ?? [:]).sorted { Self.socialOrder($0.key) < Self.socialOrder($1.key) }
        if !links.isEmpty {
            VStack(spacing: DSSpacing.sm) {
                L10n.text("profile.followUs")
                    .font(.dsFootnote.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                HStack(spacing: DSSpacing.sm) {
                    ForEach(links, id: \.key) { link in
                        Link(destination: link.value) {
                            Image(systemName: Self.socialSymbol(link.key))
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(Color.dsPrimary)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(Color.dsSurface))
                                .overlay(Circle().strokeBorder(Color.dsBorder))
                        }
                        .accessibilityLabel(Text(verbatim: link.key.capitalized))
                    }
                }
            }
        }
    }

    private static let socialKeys = ["instagram", "tiktok", "snapchat", "x", "twitter", "whatsapp", "youtube"]
    private static func socialOrder(_ key: String) -> Int { socialKeys.firstIndex(of: key.lowercased()) ?? socialKeys.count }
    private static func socialSymbol(_ key: String) -> String {
        switch key.lowercased() {
        case "instagram": "camera"
        case "tiktok": "music.note"
        case "snapchat": "camera.viewfinder"
        case "x", "twitter": "at"
        case "whatsapp": "phone.bubble.fill"
        case "youtube": "play.rectangle.fill"
        default: "link"
        }
    }

    private var accountSection: some View {
        ProfileSection(titleKey: nil) {
            NavigationLink {
                environment.trust.blockedUsersScreen()
            } label: { ProfileRow(symbol: "hand.raised", tint: .neutral, titleKey: "profile.blocked") }
            ProfileDivider()
            Button { confirmSignOut = true } label: {
                ProfileRow(symbol: "rectangle.portrait.and.arrow.right", tint: .brand, titleKey: "profile.signOut", showsChevron: false)
            }
            ProfileDivider()
            Button { confirmDelete = true } label: {
                ProfileRow(symbol: "trash", tint: .danger, titleKey: "profile.deleteAccount", showsChevron: false, isDestructive: true)
            }
            .disabled(isDeleting)
        }
    }

    private var footer: some View {
        VStack(spacing: DSSpacing.xxs) {
            DSBrand.ring
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            Text(verbatim: L10n.string("profile.brand"))
                .font(.dsTitle2)
                .foregroundStyle(Color.dsPrimary)
            Text(verbatim: "\(L10n.string("profile.tagline")) · \(L10n.string("profile.version")) \(AppEnvironment.appVersionString)")
                .font(.dsCaption)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DSSpacing.xs)
    }

    /// Contact channels from remote config, with the published email as a fallback.
    private var supportContacts: [SupportContact] {
        let methods = environment.remoteConfig.config?.support.contactMethods ?? []
        let contacts = methods.compactMap { m in SupportContact.Kind(rawValue: m.type).map { SupportContact(kind: $0, value: m.value) } }
        return contacts.isEmpty ? [SupportContact(kind: .email, value: "contact@munyati.co")] : contacts
    }
}

/// A titled group of rows on a surface card.
private struct ProfileSection<Content: View>: View {
    let titleKey: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            if let titleKey {
                L10n.text(titleKey)
                    .font(.dsFootnote.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.horizontal, 6)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsSurface))
                .overlay(RoundedRectangle(cornerRadius: DSRadius.card).strokeBorder(Color.dsBorder))
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))
        }
    }
}

private struct ProfileDivider: View {
    var body: some View {
        Divider().padding(.leading, 62)
    }
}

/// The colored icon tile behind each row's symbol.
private enum ProfileTint {
    case pink, gold, brand, blue, purple, green, neutral, danger

    var foreground: Color {
        switch self {
        case .pink: .dsAccentRose
        case .gold: .dsAccentGold
        case .brand: .dsPrimary
        case .blue: .dsAccentBlue
        case .purple: .dsAccentPurple
        case .green: .dsSuccess
        case .neutral: .dsTextSecondary
        case .danger: .dsError
        }
    }

    var background: Color { foreground.opacity(0.13) }
}

private struct ProfileRow: View {
    var symbol: String?
    var brandIcon = false
    let tint: ProfileTint
    let titleKey: String
    var value: String?
    var trailingSymbol: String?
    var showsChevron = true
    var isDestructive = false

    init(symbol: String? = nil, brandIcon: Bool = false, tint: ProfileTint, titleKey: String, value: String? = nil,
         trailingSymbol: String? = nil, showsChevron: Bool = true, isDestructive: Bool = false) {
        self.symbol = symbol
        self.brandIcon = brandIcon
        self.tint = tint
        self.titleKey = titleKey
        self.value = value
        self.trailingSymbol = trailingSymbol
        self.showsChevron = showsChevron
        self.isDestructive = isDestructive
    }

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Group {
                if brandIcon {
                    DSBrand.ring.resizable().scaledToFit().frame(width: 22, height: 22)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint.foreground)
                }
            }
            .frame(width: 36, height: 36)
            .background(RoundedRectangle(cornerRadius: 11).fill(tint.background))
            .accessibilityHidden(true)

            L10n.text(titleKey)
                .font(.dsBody.weight(isDestructive ? .semibold : .medium))
                .foregroundStyle(isDestructive ? Color.dsError : Color.dsTextPrimary)
            Spacer(minLength: DSSpacing.xs)
            if let value {
                Text(verbatim: value)
                    .font(.dsFootnote)
                    .foregroundStyle(Color.dsTextSecondary)
                    .lineLimit(1)
            }
            if let trailingSymbol {
                Image(systemName: trailingSymbol)
                    .font(.dsFootnote.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .accessibilityHidden(true)
            } else if showsChevron {
                Image(systemName: "chevron.forward")
                    .font(.dsFootnote.weight(.semibold))
                    .foregroundStyle(Color.dsDisabled)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Multi-select city picker with «الكل» (All), `docs/PLAN.md` §4.9.
struct CityPickerSheet: View {
    let environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let store = environment.cities
        NavigationStack {
            List {
                row(title: L10n.string("cities.all"), isOn: store.isAll) { store.selectAll() }
                ForEach(store.available) { city in
                    row(title: city.name(), isOn: store.selected.contains(city.id)) { store.toggle(city.id) }
                }
            }
            .dsFormBackground()
            .navigationTitle(L10n.string("cities.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.done")) {
                        Task { await environment.saveCities() }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(verbatim: title).foregroundStyle(Color.dsTextPrimary)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Color.dsPrimary : Color.dsDisabled)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A CMS page (terms, privacy, about) fetched from the dashboard-managed `cms_pages` table.
struct CMSPageScreen: View {
    let slug: String
    let repository: CMSPageRepository
    @State private var page: CMSPage?
    @State private var failed = false

    var body: some View {
        ScrollView {
            if let page {
                CMSMarkdownView(markdown: page.bodyMarkdown)
                    .padding(DSSpacing.lg)
            } else if failed {
                VStack(spacing: DSSpacing.md) {
                    EmptyStateView(systemImage: "wifi.slash", title: L10n.key("common.errorTitle"), message: L10n.key("common.errorMessage"))
                    Button(L10n.string("common.retry")) { Task { await load() } }
                        .font(.dsHeadline)
                        .foregroundStyle(Color.dsPrimary)
                }
            } else {
                ProgressView().padding(.top, DSSpacing.xxl)
            }
        }
        .dsScreenBackground()
        .navigationTitle(page?.title ?? "")
        .task { await load() }
    }

    private func load() async {
        failed = false
        let locale = Locale.current.language.languageCode?.identifier == "ar" ? "ar" : "en"
        do { page = try await repository.fetchPage(slug: slug, locale: locale); failed = page == nil }
        catch { failed = true }
    }
}
