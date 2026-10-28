import SwiftUI
import Core
import DesignSystem
import Shared

/// "My preparations" (تجهيزاتي): the bride's own checklist for the wedding. She adds an item in
/// the field at the top (or with a note from +), ticks it when it's done, and taps it to edit
/// its text and note or delete it. Done items move to their own section below.
struct PreparationsScreen: View {
    let feature: CatalogFeature
    @Environment(\.analytics) private var analytics
    @State private var phase: Phase = .loading
    @State private var newTitle = ""
    @State private var editing: PreparationDraft?
    @State private var isAdding = false
    @State private var failed = false
    @FocusState private var addFocused: Bool

    private var store: PreparationsStore { feature.preparations }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                switch phase {
                case .loading:
                    ProgressView().tint(Color.dsPrimary).frame(maxWidth: .infinity, minHeight: 240)
                case .error(let error):
                    ErrorStateView(error: error) { Task { await load() } }
                case .ready:
                    addField
                    if store.items.isEmpty {
                        EmptyStateView(
                            systemImage: "checklist",
                            title: CatalogL10n.key("preparations.empty.title"),
                            message: CatalogL10n.key("preparations.empty.message")
                        )
                        .padding(.top, DSSpacing.lg)
                    } else {
                        progress
                        section(titleKey: "preparations.section.todo", items: store.open)
                        section(titleKey: "preparations.section.done", items: store.done)
                    }
                }
            }
            .padding(DSSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .dsScreenBackground()
        .navigationTitle(CatalogL10n.string("preparations.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = PreparationDraft(id: nil, title: newTitle, note: "")
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(CatalogL10n.string("preparations.new"))
                .disabled(feature.context.isGuest)
            }
        }
        .sheet(item: $editing) { draft in
            PreparationEditor(draft: draft, store: store) { saved in
                if saved, draft.id == nil { newTitle = "" }
            }
        }
        .alert(CatalogL10n.string("common.saveFailed"), isPresented: $failed) {
            Button(CatalogL10n.string("common.ok"), role: .cancel) {}
        }
        .task { await load() }
        .refreshable { await load() }
        .trackScreen("preparations")
    }

    private enum Phase { case loading, error(AppError), ready }

    // MARK: Parts

    private var addField: some View {
        HStack(spacing: DSSpacing.sm) {
            TextField(CatalogL10n.string("preparations.add.placeholder"), text: $newTitle)
                .font(.dsBody)
                .submitLabel(.done)
                .focused($addFocused)
                .onSubmit { add() }
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm + 2)
                .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSRadius.button))
                .overlay {
                    RoundedRectangle(cornerRadius: DSRadius.button)
                        .stroke(addFocused ? Color.dsPrimary : Color.dsBorder, lineWidth: 1)
                }
            Button(action: add) {
                Group {
                    if isAdding { ProgressView().tint(.white) } else { Image(systemName: "plus").font(.dsHeadline) }
                }
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(trimmedNewTitle.isEmpty ? Color.dsDisabled : Color.dsPrimary,
                            in: RoundedRectangle(cornerRadius: DSRadius.button))
            }
            .disabled(trimmedNewTitle.isEmpty || isAdding)
            .accessibilityLabel(CatalogL10n.string("preparations.add"))
        }
    }

    private var progress: some View {
        let done = store.done.count
        let total = store.items.count
        return DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                HStack {
                    Text(verbatim: CatalogL10n.format("preparations.progress", done, total))
                        .font(.dsHeadline)
                        .foregroundStyle(Color.dsTextPrimary)
                    Spacer(minLength: 0)
                    if done == total {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.dsSuccess)
                    }
                }
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(Color.dsPrimary)
                if done == total {
                    CatalogL10n.text("preparations.allDone")
                        .font(.dsFootnote)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func section(titleKey: String, items: [Preparation]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text(verbatim: "\(CatalogL10n.string(titleKey)) (\(items.count.formatted()))")
                    .font(.dsSubhead)
                    .foregroundStyle(Color.dsTextSecondary)
                DSCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(items) { item in
                            row(item)
                            if item.id != items.last?.id {
                                Divider().padding(.leading, DSSpacing.md + 30)
                            }
                        }
                    }
                }
            }
        }
    }

    private func row(_ item: Preparation) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Button { toggle(item) } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isDone ? Color.dsSuccess : Color.dsBorder)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(CatalogL10n.string(item.isDone ? "preparations.markOpen" : "preparations.markDone"))

            Button {
                editing = PreparationDraft(id: item.id, title: item.title, note: item.note ?? "")
            } label: {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text(verbatim: item.title)
                        .font(.dsBody)
                        .strikethrough(item.isDone)
                        .foregroundStyle(item.isDone ? Color.dsTextSecondary : Color.dsTextPrimary)
                    if let note = item.note, !note.isEmpty {
                        Text(verbatim: note)
                            .font(.dsFootnote)
                            .foregroundStyle(Color.dsTextSecondary)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    do { try await store.delete(item) } catch { failed = true }
                }
            } label: {
                Label(CatalogL10n.string("preparations.delete"), systemImage: "trash")
            }
        }
    }

    // MARK: Actions

    private var trimmedNewTitle: String { newTitle.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func load() async {
        guard !feature.context.isGuest else { phase = .ready; return }
        if store.hasLoaded { phase = .ready }
        do {
            try await store.reload()
            phase = .ready
        } catch {
            if !store.hasLoaded { phase = .error(appError(error)) }
        }
    }

    private func add() {
        let title = trimmedNewTitle
        guard !title.isEmpty, !isAdding else { return }
        guard !feature.context.isGuest else { feature.requireSignIn(); return }
        isAdding = true
        Task {
            defer { isAdding = false }
            do {
                try await store.save(id: nil, title: String(title.prefix(120)), note: nil)
                newTitle = ""
            } catch {
                failed = true
                analytics.error(code: "preparation_add", message: error.localizedDescription, screen: "preparations")
            }
        }
    }

    private func toggle(_ item: Preparation) {
        Task {
            do { try await store.toggle(item) } catch { failed = true }
        }
    }
}

/// What the editor sheet starts from: an existing item (id) or a new one (nil).
struct PreparationDraft: Identifiable {
    let id: String?
    var title: String
    var note: String
}

/// Edits an item's text and note, or deletes it.
struct PreparationEditor: View {
    let draft: PreparationDraft
    let store: PreparationsStore
    let onClose: (_ saved: Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var note = ""
    @State private var isSaving = false
    @State private var failed = false
    @State private var confirmDelete = false

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(CatalogL10n.string("preparations.add.placeholder"), text: $title)
                } header: {
                    CatalogL10n.text("preparations.field.title")
                }
                Section {
                    TextField(CatalogL10n.string("preparations.note.placeholder"), text: $note, axis: .vertical)
                        .lineLimit(3...10)
                } header: {
                    CatalogL10n.text("preparations.field.note")
                }
                if draft.id != nil {
                    Section {
                        Button(CatalogL10n.string("preparations.delete"), role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .dsFormBackground()
            .navigationTitle(CatalogL10n.string(draft.id == nil ? "preparations.new" : "preparations.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(CatalogL10n.string("common.cancel")) { close(saved: false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(CatalogL10n.string("common.save")) { save() }
                        .disabled(trimmedTitle.isEmpty || isSaving)
                }
            }
            .confirmationDialog(CatalogL10n.string("preparations.delete.confirm"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(CatalogL10n.string("preparations.delete"), role: .destructive) { delete() }
            }
            .alert(CatalogL10n.string("common.saveFailed"), isPresented: $failed) {
                Button(CatalogL10n.string("common.ok"), role: .cancel) {}
            }
            .onAppear {
                title = draft.title
                note = draft.note
            }
        }
        .presentationDetents([.medium, .large])
        .trackScreen("preparation_editor")
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await store.save(id: draft.id, title: String(trimmedTitle.prefix(120)), note: String(note.prefix(1000)))
                close(saved: true)
            } catch {
                failed = true
            }
        }
    }

    private func delete() {
        guard let id = draft.id else { return }
        Task {
            do {
                try await store.delete(Preparation(id: id, title: draft.title))
                close(saved: true)
            } catch {
                failed = true
            }
        }
    }

    private func close(saved: Bool) {
        onClose(saved)
        dismiss()
    }
}
