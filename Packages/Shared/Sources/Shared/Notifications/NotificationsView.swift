import SwiftUI
import DesignSystem
import Core

/// The notifications screen reached from the Home bell or Account's menu. Backed by real,
/// server-written rows (`NotificationsRepository`) — database triggers write a row whenever a
/// place is approved/rejected, a review comes in, a promotion request is decided, or a payment
/// is logged against the user's place. Assumes an ambient `NavigationStack` from whichever
/// caller pushed it (both Home and Account have their own) — it must NOT own one itself, for the
/// same reason `PlaceDetailScreen`/`BusinessProfileScreen` don't (see their doc comments).
public struct NotificationsView: View {
    let repository: NotificationsRepository
    let onSelectPlace: (String) -> Void
    let onSelectBusiness: (String) -> Void
    @State private var state: ViewState<[AppNotification]> = .loading
    @State private var showDeleteAllConfirm = false

    public init(
        repository: NotificationsRepository,
        onSelectPlace: @escaping (String) -> Void = { _ in },
        onSelectBusiness: @escaping (String) -> Void = { _ in }
    ) {
        self.repository = repository
        self.onSelectPlace = onSelectPlace
        self.onSelectBusiness = onSelectBusiness
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dsScreenBackground(.dsSurface)
            .navigationTitle(Text("notifications.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    if case .loaded(let items) = state, !items.isEmpty {
                        Menu {
                            if items.contains(where: { !$0.isRead }) {
                                Button("notifications.markAllRead", systemImage: "checkmark.circle") {
                                    Task { await markAllRead() }
                                }
                            }
                            Button("notifications.deleteAll", systemImage: "trash", role: .destructive) {
                                showDeleteAllConfirm = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                #endif
            }
            .confirmationDialog(
                Text("notifications.deleteAll.confirm.title"),
                isPresented: $showDeleteAllConfirm,
                titleVisibility: .visible
            ) {
                Button("notifications.deleteAll.confirm.action", role: .destructive) {
                    Task { await deleteAll() }
                }
                Button("common.cancel", role: .cancel) {}
            }
            .task { await load() }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView()
        case .offline:
            ErrorStateView(error: .offline) { Task { await load() } }
        case .error(let error):
            ErrorStateView(error: error) { Task { await load() } }
        case .empty:
            EmptyStateView(systemImage: "bell", title: "notifications.empty.title", message: "notifications.empty.message")
        case .loaded(let items), .refreshing(let items):
            List {
                ForEach(items) { item in
                    NotificationRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture { handleSelect(item) }
                        .listRowInsets(EdgeInsets(top: 10, leading: DSSpacing.md, bottom: 10, trailing: DSSpacing.md))
                        #if os(iOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("notifications.delete", systemImage: "trash", role: .destructive) {
                                Task { await delete(item) }
                            }
                        }
                        #endif
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func load() async {
        state = .loading
        Task {
            do {
                let items = try await repository.fetchNotifications()
                state = items.isEmpty ? .empty : .loaded(items)
            } catch let error as AppError {
                state = error == .offline ? .offline : .error(error)
            } catch {
                state = .error(.unknown(message: error.localizedDescription))
            }
        }
    }

    private func markAllRead() async {
        guard case .loaded(let items) = state else { return }
        // Optimistic — the unread dots disappear immediately either way.
        state = .loaded(items.map(readVersion))
        try? await repository.markAllRead()
        await load()
    }

    /// Deletes one notification: drop it from the list immediately (optimistic), then delete it
    /// server-side. On failure we reload so a row that didn't actually delete reappears.
    private func delete(_ item: AppNotification) async {
        guard case .loaded(let items) = state else { return }
        let remaining = items.filter { $0.id != item.id }
        state = remaining.isEmpty ? .empty : .loaded(remaining)
        do {
            try await repository.deleteNotification(id: item.id)
        } catch {
            await load()
        }
    }

    /// Clears the whole inbox (optimistic → empty), then deletes server-side; reloads on failure.
    private func deleteAll() async {
        state = .empty
        do {
            try await repository.deleteAllNotifications()
        } catch {
            await load()
        }
    }

    /// Marks the tapped row read (optimistic, matching `markAllRead`'s pattern) and, if it points
    /// at a place, hands the id up to whichever host (Home/Account) owns the navigation stack.
    private func handleSelect(_ item: AppNotification) {
        if !item.isRead {
            if case .loaded(let items) = state {
                state = .loaded(items.map { $0.id == item.id ? readVersion($0) : $0 })
            }
            Task { try? await repository.markRead(id: item.id) }
        }
        // Every tap counts as an open, read or not — unlike `markRead`, which `markAllRead` also
        // satisfies without anyone having actually opened anything.
        Task { try? await repository.markOpened(id: item.id) }
        if let placeId = item.placeId {
            onSelectPlace(placeId)
        } else if let businessId = item.businessId {
            onSelectBusiness(businessId)
        }
    }

    private func readVersion(_ item: AppNotification) -> AppNotification {
        AppNotification(id: item.id, kind: item.kind, title: item.title, subtitle: item.subtitle, body: item.body, imageURL: item.imageURL, placeId: item.placeId, businessId: item.businessId, isRead: true, createdAt: item.createdAt)
    }
}

private struct NotificationRow: View {
    let item: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: item.kind.icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(item.kind.tint)
                .frame(width: 34, height: 34)
                .background(item.kind.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.dsSubhead.weight(.semibold)).foregroundStyle(Color.dsTextPrimary)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.dsFootnote.weight(.medium)).foregroundStyle(Color.dsTextPrimary)
                }
                Text(item.body).font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                if let imageURL = item.imageURL {
                    RemoteImageView(url: imageURL, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
                        .padding(.top, 4)
                }
                Text(item.createdAt, format: .relative(presentation: .named)).font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
            }
            Spacer(minLength: 0)
            if !item.isRead {
                Circle().fill(Color.dsPrimary).frame(width: 8, height: 8).padding(.top, 6)
            }
            if item.placeId != nil || item.businessId != nil {
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary.opacity(0.5))
                    .padding(.top, 6)
            }
        }
    }
}
