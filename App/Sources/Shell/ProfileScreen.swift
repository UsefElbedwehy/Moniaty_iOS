import SwiftUI
import DesignSystem
import Shared
import Catalog
import Trust

/// Profile & settings, shared by both roles. Phase 1: identity, cities, legal pages, support,
/// sign out and in-app account deletion (App Store guideline 5.1.1(v)).
struct ProfileScreen: View {
    let environment: AppEnvironment
    @State private var showCities = false
    @State private var showBudget = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var deleteFailed = false

    private var session: AppSession { environment.session }

    var body: some View {
        List {
            Section {
                if session.hasAccount, let user = session.user {
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        Text(verbatim: user.displayName ?? "")
                            .font(.dsTitle2)
                        L10n.text(user.role == .provider ? "profile.role.provider" : "profile.role.bride")
                            .font(.dsFootnote)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    .padding(.vertical, DSSpacing.xxs)
                } else {
                    Button {
                        session.isPresentingAuth = true
                    } label: {
                        Label(L10n.string("auth.signIn"), systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }

            if session.role != .provider {
                Section(L10n.string("profile.section.wedding")) {
                    NavigationLink(value: CatalogRoute.favorites) {
                        Label(L10n.string("profile.favorites"), systemImage: "heart")
                    }
                    Button {
                        if session.hasAccount { showBudget = true } else { session.isPresentingAuth = true }
                    } label: {
                        Label(L10n.string("profile.budget"), systemImage: "banknote")
                    }
                }
                Section(L10n.string("profile.section.preferences")) {
                    Button {
                        showCities = true
                    } label: {
                        LabeledContent(L10n.string("profile.cities"),
                                       value: environment.cities.summary(allLabel: L10n.string("cities.all")))
                    }
                }
            }

            Section(L10n.string("profile.section.app")) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    Label(L10n.string("profile.language"), systemImage: "globe")
                }
                NavigationLink {
                    CMSPageScreen(slug: "terms", repository: environment.cmsPageRepository)
                } label: { Label(L10n.string("profile.terms"), systemImage: "doc.text") }
                NavigationLink {
                    CMSPageScreen(slug: "privacy", repository: environment.cmsPageRepository)
                } label: { Label(L10n.string("profile.privacy"), systemImage: "lock.shield") }
                NavigationLink {
                    CMSPageScreen(slug: "about", repository: environment.cmsPageRepository)
                } label: { Label(L10n.string("profile.about"), systemImage: "info.circle") }
                NavigationLink {
                    environment.trust.supportScreen(contacts: supportContacts, faqURL: environment.remoteConfig.config?.support.helpCenterURL)
                } label: { Label(L10n.string("profile.support"), systemImage: "questionmark.circle") }
                if session.hasAccount {
                    NavigationLink {
                        environment.trust.blockedUsersScreen()
                    } label: { Label(L10n.string("profile.blocked"), systemImage: "hand.raised") }
                }
            }

            if session.hasAccount {
                Section {
                    Button(L10n.string("profile.signOut")) {
                        Task { await environment.signOut() }
                    }
                    Button(L10n.string("profile.deleteAccount"), role: .destructive) {
                        confirmDelete = true
                    }
                    .disabled(isDeleting)
                }
            }

            Section {
                Text(verbatim: "\(L10n.string("profile.version")) \(AppEnvironment.appVersionString)")
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsTextSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .dsScreenBackground()
        .navigationTitle(L10n.string("tab.profile"))
        .sheet(isPresented: $showCities) {
            CityPickerSheet(environment: environment)
        }
        .sheet(isPresented: $showBudget) {
            environment.catalog.budgetEditor()
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

    /// Contact channels from remote config, with the published email as a fallback.
    private var supportContacts: [SupportContact] {
        let methods = environment.remoteConfig.config?.support.contactMethods ?? []
        let contacts = methods.compactMap { m in SupportContact.Kind(rawValue: m.type).map { SupportContact(kind: $0, value: m.value) } }
        return contacts.isEmpty ? [SupportContact(kind: .email, value: "contact@munyati.co")] : contacts
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
                EmptyStateView(systemImage: "wifi.slash", title: L10n.key("common.errorTitle"), message: L10n.key("common.errorMessage"))
            } else {
                ProgressView().padding(.top, DSSpacing.xxl)
            }
        }
        .dsScreenBackground()
        .navigationTitle(page?.title ?? "")
        .task {
            let locale = Locale.current.language.languageCode?.identifier == "ar" ? "ar" : "en"
            do { page = try await repository.fetchPage(slug: slug, locale: locale); failed = page == nil }
            catch { failed = true }
        }
    }
}
