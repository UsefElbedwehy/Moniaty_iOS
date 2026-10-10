import SwiftUI
import PhotosUI
import Core
import DesignSystem
import Shared

/// Public entry point of the Trust feature (Phase 5): reviews, report, block and support.
/// Other features don't depend on this package: the App hands them these views as hooks.
@MainActor
public final class TrustFeature {
    let repository: TrustRepository
    let uploader: MediaUploading
    /// Guests (no account) are asked to sign in before writing anything.
    let isSignedIn: () -> Bool
    let requireSignIn: () -> Void

    public init(repository: TrustRepository, uploader: MediaUploading,
                isSignedIn: @escaping () -> Bool, requireSignIn: @escaping () -> Void) {
        self.repository = repository
        self.uploader = uploader
        self.isSignedIn = isSignedIn
        self.requireSignIn = requireSignIn
    }

    /// Rating summary and the latest reviews on a provider page, with "See all".
    public func reviewsSection(providerId: String) -> some View {
        ReviewsSection(feature: self, providerId: providerId)
    }

    /// "Rate your experience" on a completed booking, or the review already written.
    public func bookingReviewSection(bookingId: String, role: ReviewRole) -> some View {
        BookingReviewSection(feature: self, bookingId: bookingId, role: role)
    }

    /// A "…" toolbar menu: report, and optionally block (a user id, or the other side of a booking).
    public func moreMenu(_ target: ReportTarget, blockUserId: String? = nil, blockBookingId: String? = nil,
                         onBlocked: (() -> Void)? = nil) -> some View {
        MoreMenu(feature: self, target: target, blockUserId: blockUserId, blockBookingId: blockBookingId, onBlocked: onBlocked)
    }

    public func supportScreen(contacts: [SupportContact], faqURL: URL?) -> some View {
        SupportScreen(feature: self, contacts: contacts, faqURL: faqURL)
    }

    /// A help request about one booking (presented as a sheet).
    public func ticketSheet(bookingId: String?) -> some View {
        NavigationStack { TicketComposer(feature: self, bookingId: bookingId, onSent: {}) }
    }

    public func blockedUsersScreen() -> some View {
        BlockedUsersScreen(feature: self)
    }
}

/// A support channel from remote config (`support.contact_methods`).
public struct SupportContact: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case email, whatsapp, phone }
    public let kind: Kind
    public let value: String
    public var id: String { kind.rawValue + value }

    public init(kind: Kind, value: String) {
        self.kind = kind
        self.value = value
    }

    var url: URL? {
        switch kind {
        case .email: URL(string: "mailto:\(value)")
        case .phone: URL(string: "tel:\(value.filter { $0.isNumber || $0 == "+" })")
        case .whatsapp: URL(string: "https://wa.me/\(value.filter(\.isNumber))")
        }
    }
}

enum TrustL10n {
    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }

    static func text(_ key: String) -> Text { Text(verbatim: string(key)) }

    static func key(_ key: String) -> LocalizedStringKey { LocalizedStringKey("\(string(key))") }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), arguments: args)
    }

    static func refusal(_ code: String) -> String {
        let value = string("error.\(code)")
        return value == "error.\(code)" ? string("error.generic") : value
    }
}

func appError(_ error: Error) -> AppError {
    (error as? AppError) ?? .unknown(message: error.localizedDescription)
}

// MARK: - Stars

struct StarsView: View {
    let rating: Double
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: Double(star) <= rating.rounded() ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(Color.dsPremiumGold)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(TrustL10n.format("reviews.stars", Int(rating.rounded())))
    }
}

struct StarPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            ForEach(1...5, id: \.self) { star in
                Button { rating = star } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.dsPremiumGold)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(TrustL10n.format("reviews.stars", star))
                .accessibilityAddTraits(star == rating ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Provider reviews

struct ReviewsSection: View {
    let feature: TrustFeature
    let providerId: String
    @State private var page: ReviewsPage?

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                TrustL10n.text("reviews.title").font(.dsTitle2)
                Spacer()
                if let page, page.ratingCount > 3 {
                    NavigationLink {
                        ReviewsListScreen(feature: feature, providerId: providerId)
                    } label: {
                        TrustL10n.text("reviews.seeAll").font(.dsSubhead)
                    }
                    .tint(Color.dsPrimary)
                }
            }
            if let page {
                if page.ratingCount == 0 {
                    TrustL10n.text("reviews.none").font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                } else {
                    RatingSummary(page: page)
                    ForEach(page.items.prefix(3)) { ReviewRow(feature: feature, review: $0) }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .task { page = try? await feature.repository.providerReviews(providerId: providerId, limit: 3, offset: 0) }
    }
}

struct RatingSummary: View {
    let page: ReviewsPage

    var body: some View {
        let avg = NSDecimalNumber(decimal: page.ratingAvg ?? 0).doubleValue
        HStack(alignment: .center, spacing: DSSpacing.lg) {
            VStack(spacing: 2) {
                Text(verbatim: avg.formatted(.number.precision(.fractionLength(1)))).font(.dsLargeTitle)
                StarsView(rating: avg)
                Text(verbatim: TrustL10n.format("reviews.count", page.ratingCount))
                    .font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
            }
            VStack(spacing: 3) {
                ForEach((1...5).reversed(), id: \.self) { star in
                    let n = page.distribution[String(star)] ?? 0
                    HStack(spacing: 6) {
                        Text(verbatim: "\(star)").font(.dsCaption).frame(width: 12)
                        GeometryReader { proxy in
                            Capsule().fill(Color.dsPrimaryMuted)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(Color.dsPremiumGold)
                                        .frame(width: page.ratingCount > 0 ? proxy.size.width * CGFloat(n) / CGFloat(page.ratingCount) : 0)
                                }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ReviewRow: View {
    let feature: TrustFeature
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                Text(verbatim: review.authorName).font(.dsHeadline)
                Spacer()
                feature.moreMenu(.review(review.id))
            }
            HStack(spacing: DSSpacing.xs) {
                StarsView(rating: Double(review.rating))
                Text(verbatim: review.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                if let title = review.serviceTitle {
                    Text(verbatim: "· " + title).font(.dsCaption).foregroundStyle(Color.dsTextSecondary).lineLimit(1)
                }
            }
            if let text = review.body, !text.isEmpty {
                Text(verbatim: text).font(.dsBody)
            }
            if !review.photoUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(review.photoUrls, id: \.self) { url in
                            RemoteImageView(url: url)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            if let reply = review.providerReply {
                VStack(alignment: .leading, spacing: 2) {
                    TrustL10n.text("reviews.reply").font(.dsCaption).foregroundStyle(Color.dsPrimary)
                    Text(verbatim: reply).font(.dsFootnote)
                }
                .padding(DSSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsPrimaryMuted))
            }
        }
        .padding(DSSpacing.md)
        .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsSurface))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.card).strokeBorder(Color.dsBorder))
    }
}

struct ReviewsListScreen: View {
    let feature: TrustFeature
    let providerId: String
    @State private var state: ViewState<ReviewsPage> = .loading
    @State private var items: [Review] = []
    @State private var hasMore = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.sm) {
                switch state {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                case .error(let error):
                    ErrorStateView(error: error) { Task { await load(reset: true) } }
                default:
                    if let page = state.value { RatingSummary(page: page) }
                    ForEach(items) { review in
                        ReviewRow(feature: feature, review: review)
                            .onAppear { if review == items.last, hasMore { Task { await load(reset: false) } } }
                    }
                }
            }
            .padding(DSSpacing.lg)
        }
        .dsScreenBackground()
        .navigationTitle(TrustL10n.string("reviews.title"))
        .task { await load(reset: true) }
        .refreshable { await load(reset: true) }
        .trackScreen("reviews")
    }

    private func load(reset: Bool) async {
        do {
            let page = try await feature.repository.providerReviews(providerId: providerId, limit: 20, offset: reset ? 0 : items.count)
            items = reset ? page.items : items + page.items
            hasMore = page.items.count == 20
            state = .loaded(page)
        } catch {
            if state.value == nil { state = .error(appError(error)) }
        }
    }
}

// MARK: - Booking review

struct BookingReviewSection: View {
    let feature: TrustFeature
    let bookingId: String
    let role: ReviewRole
    @State private var reviewState: MyReviewState?
    @State private var composing = false

    var body: some View {
        Group {
            if let review = reviewState?.review {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    TrustL10n.text(role == .bride ? "review.mine.bride" : "review.mine.provider").font(.dsHeadline)
                    StarsView(rating: Double(review.rating), size: 16)
                    if let text = review.body { Text(verbatim: text).font(.dsSubhead) }
                    if review.status == "pending" {
                        TrustL10n.text("review.pending").font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if reviewState?.canReview == true {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    TrustL10n.text(role == .bride ? "review.prompt.bride" : "review.prompt.provider").font(.dsHeadline)
                    PrimaryButton(TrustL10n.key("review.write"), systemImage: "star") { composing = true }
                }
            }
        }
        .task { reviewState = try? await feature.repository.myReview(bookingId: bookingId) }
        .sheet(isPresented: $composing) {
            NavigationStack {
                ReviewComposer(feature: feature, bookingId: bookingId, role: role) {
                    Task { reviewState = try? await feature.repository.myReview(bookingId: bookingId) }
                }
            }
        }
    }
}

struct ReviewComposer: View {
    let feature: TrustFeature
    let bookingId: String
    let role: ReviewRole
    let onSent: () -> Void
    @State private var rating = 0
    @State private var text = ""
    @State private var photos: [URL] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var isSending = false
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analytics) private var analytics

    var body: some View {
        Form {
            Section {
                StarPicker(rating: $rating).padding(.vertical, DSSpacing.sm)
            }
            Section {
                TextField(TrustL10n.string(role == .bride ? "review.text.bride" : "review.text.provider"), text: $text, axis: .vertical)
                    .lineLimit(4...8)
            } footer: {
                TrustL10n.text(role == .bride ? "review.footer.bride" : "review.footer.provider")
            }
            if role == .bride {
                Section(TrustL10n.string("review.photos")) {
                    if !photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(photos, id: \.self) { url in
                                    RemoteImageView(url: url).frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                    if photos.count < 4 {
                        // PhotosPicker's label closure is Sendable: read main-actor state outside it.
                        let isUploading = isUploading
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 4 - photos.count, matching: .images) {
                            Label {
                                TrustL10n.text("review.addPhotos")
                            } icon: {
                                if isUploading { ProgressView() } else { Image(systemName: "photo.badge.plus") }
                            }
                        }
                        .disabled(isUploading)
                    }
                }
            }
        }
        .navigationTitle(TrustL10n.string("review.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(TrustL10n.string("common.cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(TrustL10n.string("common.send")) { send() }.disabled(rating == 0 || isSending || isUploading)
            }
        }
        .onChange(of: pickerItems) { _, picked in
            guard !picked.isEmpty else { return }
            Task { await upload(picked) }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(TrustL10n.string("common.ok"), role: .cancel) {}
        }
        .trackScreen("review_compose")
    }

    private func upload(_ picked: [PhotosPickerItem]) async {
        isUploading = true
        defer { isUploading = false; pickerItems = [] }
        for item in picked {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let jpeg = ImageCompressor.jpeg(from: data) else { continue }
            if let url = try? await feature.uploader.uploadJPEG(jpeg, folder: "reviews") { photos.append(url) }
        }
    }

    private func send() {
        isSending = true
        Task {
            defer { isSending = false }
            do {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                switch try await feature.repository.submitReview(bookingId: bookingId, rating: rating,
                                                                 body: trimmed.isEmpty ? nil : trimmed, photoUrls: photos) {
                case .ok:
                    analytics(.reviewSubmitted, bookingId, context: role.rawValue)
                    onSent()
                    dismiss()
                case .refused(let code):
                    message = TrustL10n.refusal(code)
                }
            } catch {
                message = TrustL10n.string("error.generic")
            }
        }
    }
}

// MARK: - Report and block

struct MoreMenu: View {
    let feature: TrustFeature
    let target: ReportTarget
    let blockUserId: String?
    let blockBookingId: String?
    let onBlocked: (() -> Void)?
    @State private var reporting = false
    @State private var confirmBlock = false
    @State private var notice: String?
    @Environment(\.analytics) private var analytics

    var body: some View {
        Menu {
            Button(role: .destructive) {
                guard feature.isSignedIn() else { feature.requireSignIn(); return }
                reporting = true
            } label: {
                Label(TrustL10n.string("report.action"), systemImage: "flag")
            }
            if blockUserId != nil || blockBookingId != nil {
                Button(role: .destructive) {
                    guard feature.isSignedIn() else { feature.requireSignIn(); return }
                    confirmBlock = true
                } label: {
                    Label(TrustL10n.string("block.action"), systemImage: "hand.raised")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .accessibilityLabel(TrustL10n.string("more"))
        }
        .sheet(isPresented: $reporting) {
            NavigationStack {
                ReportSheet(feature: feature, target: target) { notice = TrustL10n.string("report.thanks") }
            }
        }
        .confirmationDialog(TrustL10n.string("block.confirm.title"), isPresented: $confirmBlock, titleVisibility: .visible) {
            Button(TrustL10n.string("block.action"), role: .destructive) { block() }
            Button(TrustL10n.string("common.cancel"), role: .cancel) {}
        } message: {
            TrustL10n.text("block.confirm.message")
        }
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button(TrustL10n.string("common.ok"), role: .cancel) {}
        }
    }

    private func block() {
        Task {
            do {
                if let blockUserId {
                    try await feature.repository.block(userId: blockUserId)
                } else if let blockBookingId {
                    try await feature.repository.blockBookingParty(bookingId: blockBookingId)
                }
                analytics(.userBlocked, blockUserId ?? blockBookingId)
                notice = TrustL10n.string("block.done")
                onBlocked?()
            } catch {
                notice = TrustL10n.string("error.generic")
            }
        }
    }
}

struct ReportSheet: View {
    let feature: TrustFeature
    let target: ReportTarget
    let onSent: () -> Void
    @State private var reason: ReportReason = .inappropriate
    @State private var details = ""
    @State private var isSending = false
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analytics) private var analytics

    var body: some View {
        Form {
            Picker(TrustL10n.string("report.reason"), selection: $reason) {
                ForEach(ReportReason.allCases, id: \.self) { r in
                    TrustL10n.text("report.reason.\(r.rawValue)").tag(r)
                }
            }
            .pickerStyle(.inline)
            Section {
                TextField(TrustL10n.string("report.details"), text: $details, axis: .vertical).lineLimit(3...6)
            } footer: {
                TrustL10n.text("report.footer")
            }
        }
        .navigationTitle(TrustL10n.string("report.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(TrustL10n.string("common.cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(TrustL10n.string("common.send")) { send() }.disabled(isSending)
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(TrustL10n.string("common.ok"), role: .cancel) {}
        }
        .presentationDetents([.large])
    }

    private func send() {
        isSending = true
        Task {
            defer { isSending = false }
            do {
                let text = details.trimmingCharacters(in: .whitespacesAndNewlines)
                switch try await feature.repository.report(target, reason: reason, details: text.isEmpty ? nil : text) {
                case .ok:
                    analytics(.reportSubmitted, target.id, context: target.type)
                    dismiss()
                    onSent()
                case .refused(let code):
                    message = TrustL10n.refusal(code)
                }
            } catch {
                message = TrustL10n.string("error.generic")
            }
        }
    }
}

struct BlockedUsersScreen: View {
    let feature: TrustFeature
    @State private var state: ViewState<[BlockedUser]> = .loading

    var body: some View {
        List {
            switch state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            case .error(let error):
                ErrorStateView(error: error) { Task { await load() } }.listRowBackground(Color.clear)
            case .loaded(let list), .refreshing(let list):
                ForEach(list) { user in
                    HStack {
                        Text(verbatim: user.name)
                        Spacer()
                        Button(TrustL10n.string("block.unblock")) {
                            Task {
                                try? await feature.repository.unblock(userId: user.userId)
                                await load()
                            }
                        }
                        .tint(Color.dsPrimary)
                    }
                }
            case .empty, .offline:
                EmptyStateView(systemImage: "hand.raised", title: TrustL10n.key("block.empty.title"),
                               message: TrustL10n.key("block.empty.message"))
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .dsScreenBackground()
        .navigationTitle(TrustL10n.string("block.list.title"))
        .task { await load() }
        .trackScreen("blocked_users")
    }

    private func load() async {
        do {
            let list = try await feature.repository.blockedUsers()
            state = list.isEmpty ? .empty : .loaded(list)
        } catch {
            if state.value == nil { state = .error(appError(error)) }
        }
    }
}

// MARK: - Support

struct SupportScreen: View {
    let feature: TrustFeature
    let contacts: [SupportContact]
    let faqURL: URL?
    @State private var tickets: [SupportTicket] = []
    @State private var composing = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                if let faqURL {
                    Button { openURL(faqURL) } label: { Label(TrustL10n.string("support.faq"), systemImage: "questionmark.circle") }
                }
                ForEach(contacts) { contact in
                    if let url = contact.url {
                        Button { openURL(url) } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    TrustL10n.text("support.contact.\(contact.kind.rawValue)")
                                    Text(verbatim: contact.value).font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                                        .environment(\.layoutDirection, .leftToRight)
                                }
                            } icon: {
                                Image(systemName: contact.kind == .email ? "envelope" : contact.kind == .phone ? "phone" : "message")
                            }
                        }
                    }
                }
            } footer: {
                TrustL10n.text("support.footer")
            }
            .tint(Color.dsTextPrimary)

            Section {
                Button {
                    guard feature.isSignedIn() else { feature.requireSignIn(); return }
                    composing = true
                } label: {
                    Label(TrustL10n.string("support.newTicket"), systemImage: "square.and.pencil")
                }
                .tint(Color.dsPrimary)
                ForEach(tickets) { ticket in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(verbatim: ticket.subject).font(.dsHeadline)
                            Spacer()
                            Text(verbatim: TrustL10n.string("support.status.\(ticket.status)"))
                                .font(.dsCaption)
                                .foregroundStyle(ticket.status == "answered" ? Color.dsSuccess : Color.dsTextSecondary)
                        }
                        Text(verbatim: ticket.message).font(.dsFootnote).foregroundStyle(Color.dsTextSecondary).lineLimit(2)
                        if let reply = ticket.adminReply {
                            Text(verbatim: reply)
                                .font(.dsSubhead)
                                .padding(DSSpacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsPrimaryMuted))
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                TrustL10n.text("support.tickets")
            }
        }
        .scrollContentBackground(.hidden)
        .dsScreenBackground()
        .navigationTitle(TrustL10n.string("support.title"))
        .sheet(isPresented: $composing) {
            NavigationStack {
                TicketComposer(feature: feature, bookingId: nil) { Task { await load() } }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .trackScreen("support")
    }

    private func load() async {
        guard feature.isSignedIn() else { return }
        if let list = try? await feature.repository.tickets() { tickets = list }
    }
}

struct TicketComposer: View {
    let feature: TrustFeature
    let bookingId: String?
    let onSent: () -> Void
    @State private var subject = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var alert: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analytics) private var analytics

    private var isValid: Bool {
        subject.trimmingCharacters(in: .whitespaces).count >= 3 && message.trimmingCharacters(in: .whitespaces).count >= 3
    }

    var body: some View {
        Form {
            TextField(TrustL10n.string("support.subject"), text: $subject)
            TextField(TrustL10n.string("support.message"), text: $message, axis: .vertical).lineLimit(5...10)
            if bookingId != nil {
                TrustL10n.text("support.aboutBooking").font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
            }
        }
        .navigationTitle(TrustL10n.string("support.newTicket"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(TrustL10n.string("common.cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(TrustL10n.string("common.send")) { send() }.disabled(!isValid || isSending)
            }
        }
        .alert(alert ?? "", isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })) {
            Button(TrustL10n.string("common.ok"), role: .cancel) {}
        }
    }

    private func send() {
        isSending = true
        Task {
            defer { isSending = false }
            do {
                switch try await feature.repository.createTicket(subject: subject, message: message, bookingId: bookingId) {
                case .ok:
                    analytics(.supportTicketCreated, bookingId)
                    onSent()
                    dismiss()
                case .refused(let code):
                    alert = TrustL10n.refusal(code)
                }
            } catch {
                alert = TrustL10n.string("error.generic")
            }
        }
    }
}
