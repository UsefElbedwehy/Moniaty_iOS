import SwiftUI
import PhotosUI
import CryptoKit
import Core
import DesignSystem
import Shared
import Catalog

// MARK: - List (mockup 5 / provider inbox, mockup 7)

struct BookingsListScreen: View {
    let feature: BookingFeature
    let role: BookingRole
    @State private var showActive = true
    @State private var state: ViewState<[BookingSummary]> = .loading

    var body: some View {
        List {
            Section {
                Picker("", selection: $showActive) {
                    BookingL10n.text("list.active").tag(true)
                    BookingL10n.text("list.past").tag(false)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }
            switch state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            case .error(let error):
                ErrorStateView(error: error) { Task { await load() } }.listRowBackground(Color.clear)
            case .loaded(let list), .refreshing(let list):
                ForEach(list) { booking in
                    NavigationLink(value: BookingRoute.detail(id: booking.id)) {
                        BookingRow(booking: booking, role: role)
                    }
                }
            case .empty, .offline:
                EmptyStateView(systemImage: "calendar", title: BookingL10n.key("list.empty.title"),
                               message: BookingL10n.key(role == .bride ? "list.empty.bride" : "list.empty.provider"))
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .dsScreenBackground()
        .navigationTitle(BookingL10n.string(role == .bride ? "list.title.bride" : "list.title.provider"))
        .task(id: showActive) { await load() }
        .refreshable { await load() }
        .onAppear { Task { await load() } }
        .trackScreen(role == .bride ? "my_bookings" : "provider_bookings")
    }

    private func load() async {
        do {
            let list = try await feature.repository.bookings(active: showActive)
            state = list.isEmpty ? .empty : .loaded(list)
        } catch {
            if state.value == nil { state = .error(appError(error)) }
        }
    }
}

struct BookingRow: View {
    let booking: BookingSummary
    let role: BookingRole

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                StatusPill(status: booking.status, role: role)
                if booking.isDemo {
                    Text(verbatim: BookingL10n.string("demo.badge"))
                        .font(.dsCaption)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.dsPrimaryMuted))
                }
                Spacer()
                Text(verbatim: booking.referenceCode).font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
            }
            Text(verbatim: "\(booking.serviceTitle) · \(role == .bride ? (booking.provider.name ?? "") : (booking.brideName ?? ""))")
                .font(.dsHeadline)
                .lineLimit(1)
            Text(verbatim: "\(bookingDateText(booking.startsAt)) · \(formatSAR(booking.price))")
                .font(.dsFootnote)
                .foregroundStyle(Color.dsTextSecondary)
        }
        .padding(.vertical, 4)
    }
}

struct StatusPill: View {
    let status: BookingStatus
    let role: BookingRole

    var body: some View {
        let kind: StatusBadgeKind = switch status {
        case .paymentConfirmed, .completed: .live
        case .declined, .cancelledByBride, .cancelledByProvider, .expired, .disputed: .rejected
        case .awaitingPayment where role == .bride: .featured
        case .paymentSubmitted where role == .provider: .featured
        case .requested where role == .provider: .featured
        default: .pending
        }
        StatusBadge(kind: kind, text: BookingL10n.key("status.\(status.rawValue)"))
    }
}

// MARK: - Detail

struct BookingDetailScreen: View {
    let feature: BookingFeature
    let bookingId: String
    let role: BookingRole

    @State private var state: ViewState<BookingDetail> = .loading
    @State private var isWorking = false
    @State private var message: String?
    @State private var sheet: Sheet?
    @State private var confirmCancel = false
    @State private var showHelp = false

    enum Sheet: Identifiable {
        case pay, propose, decline, rejectPayment, dispute, receipt(BookingReceipt)
        var id: String {
            switch self {
            case .pay: "pay"
            case .propose: "propose"
            case .decline: "decline"
            case .rejectPayment: "reject"
            case .dispute: "dispute"
            case .receipt(let r): "receipt-\(r.id)"
            }
        }
    }

    var body: some View {
        ScrollView {
            switch state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, minHeight: 300)
            case .error(let error):
                ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let detail), .refreshing(let detail):
                content(detail)
            case .empty, .offline:
                EmptyStateView(systemImage: "calendar.badge.exclamationmark", title: BookingL10n.key("detail.missing"),
                               message: BookingL10n.key("error.generic"))
            }
        }
        .dsScreenBackground()
        .navigationTitle(state.value?.summary.referenceCode ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let trust = feature.trustViews, state.value?.summary.isDemo == false {
                ToolbarItem(placement: .topBarTrailing) { trust.moreMenu(bookingId) }
            }
        }
        .sheet(isPresented: $showHelp) {
            feature.trustViews?.helpSheet(bookingId)
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $sheet) { sheet in
            NavigationStack { sheetContent(sheet) }
        }
        .confirmationDialog(BookingL10n.string("action.cancel.confirm"), isPresented: $confirmCancel, titleVisibility: .visible) {
            Button(BookingL10n.string("action.cancel"), role: .destructive) {
                run { try await feature.repository.cancel(bookingId: bookingId, reason: nil) }
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(BookingL10n.string("common.ok"), role: .cancel) {}
        }
        .trackScreen("booking_detail")
    }

    @ViewBuilder
    private func content(_ detail: BookingDetail) -> some View {
        let b = detail.summary
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            if b.isDemo {
                Label(BookingL10n.string("demo.banner"), systemImage: "sparkles")
                    .font(.dsFootnote)
                    .padding(DSSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.dsPrimaryMuted))
            }
            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    StatusPill(status: b.status, role: role)
                    Text(verbatim: b.serviceTitle).font(.dsTitle2)
                    Text(verbatim: role == .bride ? (b.provider.name ?? "") : (b.brideName ?? "")).font(.dsSubhead)
                    Text(verbatim: bookingDateText(b.startsAt)).font(.dsSubhead).foregroundStyle(Color.dsTextSecondary)
                    Text(verbatim: formatSAR(b.price)).font(.dsHeadline).foregroundStyle(Color.dsPrimary)
                    if let note = b.note, !note.isEmpty {
                        Text(verbatim: note).font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                    }
                    ProgressSteps(step: b.status.step)
                    Text(verbatim: BookingL10n.string("hint.\(role.rawValue).\(b.status.rawValue)"))
                        .font(.dsFootnote)
                        .foregroundStyle(Color.dsTextSecondary)
                    if let due = b.paymentDueAt, b.status == .awaitingPayment {
                        Text(verbatim: BookingL10n.format("detail.payBy", bookingDateText(due)))
                            .font(.dsFootnote).foregroundStyle(Color.dsPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let proposal = detail.proposal {
                DSCard {
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        BookingL10n.text("proposal.title").font(.dsHeadline)
                        Text(verbatim: bookingDateText(proposal.startsAt)).font(.dsSubhead)
                        if let note = proposal.note, !note.isEmpty { Text(verbatim: note).font(.dsFootnote) }
                        Text(verbatim: BookingL10n.format("proposal.expires", bookingDateText(proposal.expiresAt)))
                            .font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            actions(detail)

            if !detail.receipts.isEmpty {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    BookingL10n.text("receipts.title").font(.dsHeadline)
                    ForEach(detail.receipts) { receipt in
                        Button { sheet = .receipt(receipt) } label: {
                            HStack {
                                Image(systemName: "doc.text.image").foregroundStyle(Color.dsPrimary)
                                VStack(alignment: .leading) {
                                    Text(verbatim: formatSAR(receipt.amount)).font(.dsSubhead)
                                    Text(verbatim: BookingL10n.string("receipt.status.\(receipt.status)"))
                                        .font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                                    if let reason = receipt.rejectReason { Text(verbatim: reason).font(.dsCaption) }
                                }
                                Spacer()
                                Image(systemName: "chevron.forward").foregroundStyle(Color.dsTextSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if b.status == .completed, !b.isDemo, let trust = feature.trustViews {
                trust.review(bookingId, role)
            }

            if !b.isDemo, feature.trustViews != nil {
                Button { showHelp = true } label: {
                    Label(BookingL10n.string("action.help"), systemImage: "questionmark.bubble")
                        .font(.dsSubhead)
                }
                .tint(Color.dsPrimary)
            }

            if !detail.events.isEmpty {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    BookingL10n.text("timeline.title").font(.dsHeadline)
                    ForEach(Array(detail.events.enumerated()), id: \.offset) { _, event in
                        HStack(alignment: .top, spacing: DSSpacing.sm) {
                            Circle().fill(Color.dsPremiumGold).frame(width: 8, height: 8).padding(.top, 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: BookingL10n.string("status.\(event.toStatus.rawValue)")).font(.dsSubhead)
                                Text(verbatim: event.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(DSSpacing.lg)
    }

    /// The buttons depend on the viewer's side and the booking's status (mirrors the SQL state machine).
    @ViewBuilder
    private func actions(_ detail: BookingDetail) -> some View {
        let b = detail.summary
        VStack(spacing: DSSpacing.sm) {
            switch (role, b.status) {
            case (.bride, .rescheduleProposed):
                PrimaryButton(BookingL10n.key("action.acceptTime"), isLoading: isWorking) {
                    run { try await feature.repository.respondToProposal(bookingId: bookingId, accept: true) }
                }
                SecondaryButton(BookingL10n.key("action.rejectTime")) {
                    run { try await feature.repository.respondToProposal(bookingId: bookingId, accept: false) }
                }
            case (.bride, .awaitingPayment):
                PrimaryButton(BookingL10n.key("action.pay"), systemImage: "creditcard") { sheet = .pay }
            case (.provider, .requested):
                PrimaryButton(BookingL10n.key("action.approve"), isLoading: isWorking) {
                    run { try await feature.repository.approve(bookingId: bookingId) }
                }
                SecondaryButton(BookingL10n.key("action.propose")) { sheet = .propose }
                SecondaryButton(BookingL10n.key("action.decline")) { sheet = .decline }
            case (.provider, .paymentSubmitted):
                if let receipt = detail.receipts.first {
                    SecondaryButton(BookingL10n.key("action.viewReceipt"), systemImage: "doc.text.image") { sheet = .receipt(receipt) }
                }
                PrimaryButton(BookingL10n.key("action.confirmPayment"), isLoading: isWorking) {
                    run { try await feature.repository.confirmPayment(bookingId: bookingId) }
                }
                SecondaryButton(BookingL10n.key("action.rejectPayment")) { sheet = .rejectPayment }
            case (.provider, .paymentConfirmed):
                PrimaryButton(BookingL10n.key("action.complete"), isLoading: isWorking) {
                    run { try await feature.repository.complete(bookingId: bookingId) }
                }
            default:
                EmptyView()
            }

            if [.requested, .rescheduleProposed, .awaitingPayment].contains(b.status) {
                Button(BookingL10n.string("action.cancel"), role: .destructive) { confirmCancel = true }
                    .frame(minHeight: 44)
            }
            if !b.isDemo, detail.openDispute == nil,
               [.awaitingPayment, .paymentSubmitted, .paymentConfirmed, .completed].contains(b.status) {
                Button(BookingL10n.string("action.dispute")) { sheet = .dispute }
                    .font(.dsFootnote)
                    .frame(minHeight: 44)
            }
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: Sheet) -> some View {
        switch sheet {
        case .pay:
            if let detail = state.value {
                PaymentScreen(feature: feature, detail: detail) { Task { await load() } }
            }
        case .propose:
            ProposeTimeSheet { date, note in
                try await feature.repository.proposeReschedule(bookingId: bookingId, startsAt: date, note: note)
            } onDone: { Task { await load() } }
        case .decline:
            ReasonSheet(titleKey: "action.decline", optional: true) { reason in
                try await feature.repository.decline(bookingId: bookingId, reason: reason)
            } onDone: { Task { await load() } }
        case .rejectPayment:
            ReasonSheet(titleKey: "action.rejectPayment", optional: false) { reason in
                try await feature.repository.rejectPayment(bookingId: bookingId, reason: reason ?? "")
            } onDone: { Task { await load() } }
        case .dispute:
            DisputeSheet { reason, details in
                try await feature.repository.openDispute(bookingId: bookingId, reason: reason, details: details)
            } onDone: { Task { await load() } }
        case .receipt(let receipt):
            ReceiptViewer(feature: feature, receipt: receipt)
        }
    }

    private func run(_ action: @escaping () async throws -> ActionResult) {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                if case .refused(let code) = try await action() { message = BookingL10n.refusal(code) }
                feature.onBookingsChanged()
            } catch {
                message = BookingL10n.string("error.generic")
            }
            await load()
        }
    }

    private func load() async {
        do {
            if let detail = try await feature.repository.booking(id: bookingId) {
                state = .loaded(detail)
            } else {
                state = .empty
            }
        } catch {
            if state.value == nil { state = .error(appError(error)) }
        }
    }
}

/// Five-segment progress bar (request → approval → payment → confirmation → done).
struct ProgressSteps: View {
    let step: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                Capsule()
                    .fill(index < step ? Color.dsPrimary : index == step ? Color.dsPremiumGold : Color.dsBorder)
                    .frame(height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(BookingL10n.format("progress.label", step, 5))
    }
}

// MARK: - Payment and receipt (mockup 6)

struct PaymentScreen: View {
    let feature: BookingFeature
    let detail: BookingDetail
    let onDone: () -> Void

    @State private var item: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var amountText = ""
    @State private var transferredAt = Date.now
    @State private var senderBank = ""
    @State private var isSending = false
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss

    private var amount: Decimal? {
        let ascii = String(amountText.map { ch in ch.wholeNumberValue.map { Character(String($0)) } ?? ch }).filter { $0.isNumber || $0 == "." }
        return ascii.isEmpty ? nil : Decimal(string: ascii)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(BookingL10n.string("pay.amount"), value: formatSAR(detail.summary.price))
                HStack {
                    VStack(alignment: .leading) {
                        BookingL10n.text("pay.reference").font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                        Text(verbatim: detail.summary.referenceCode).font(.dsTitle2).foregroundStyle(Color.dsPrimary)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    Spacer()
                    CopyButton(value: detail.summary.referenceCode)
                }
            } footer: {
                BookingL10n.text("pay.referenceHint")
            }

            Section(BookingL10n.string("pay.methods")) {
                ForEach(detail.paymentMethods, id: \.self) { method in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: "\(BookingL10n.string("method.\(method.kind)")) · \(method.label)")
                                .font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                            Text(verbatim: method.value).font(.dsSubhead.monospaced())
                                .environment(\.layoutDirection, .leftToRight)
                            Text(verbatim: BookingL10n.format("pay.beneficiary", method.accountName)).font(.dsFootnote)
                        }
                        Spacer()
                        CopyButton(value: method.value)
                    }
                }
            }

            Section {
                // PhotosPicker's label closure is Sendable: read main-actor state outside it.
                let attached = imageData != nil
                PhotosPicker(selection: $item, matching: .images) {
                    Label(BookingL10n.string(attached ? "pay.attached" : "pay.attach"),
                          systemImage: attached ? "checkmark.circle.fill" : "photo.badge.plus")
                }
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                        .accessibilityLabel(BookingL10n.string("pay.attached"))
                }
                TextField(BookingL10n.string("pay.transferredAmount"), text: $amountText).keyboardType(.decimalPad)
                DatePicker(BookingL10n.string("pay.transferTime"), selection: $transferredAt, in: ...Date.now)
                TextField(BookingL10n.string("pay.senderBank"), text: $senderBank)
            } header: {
                BookingL10n.text("pay.receipt")
            } footer: {
                BookingL10n.text("pay.disclaimer")
            }
        }
        .navigationTitle(BookingL10n.string("pay.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(BookingL10n.string("common.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(BookingL10n.string("pay.submit")) { submit() }
                    .disabled(imageData == nil || amount == nil || isSending)
            }
        }
        .onChange(of: item) { _, picked in
            Task {
                guard let data = try? await picked?.loadTransferable(type: Data.self) else { return }
                imageData = ImageCompressor.jpeg(from: data, maxDimension: 2000, quality: 0.85)
            }
        }
        .onAppear { if amountText.isEmpty { amountText = "\(detail.summary.price)" } }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(BookingL10n.string("common.ok"), role: .cancel) {}
        }
    }

    private func submit() {
        guard let imageData, let amount else { return }
        isSending = true
        Task {
            defer { isSending = false }
            do {
                let path = try await feature.receipts.upload(jpeg: imageData, bookingId: detail.summary.id)
                let hash = SHA256.hash(data: imageData).map { String(format: "%02x", $0) }.joined()
                switch try await feature.repository.submitReceipt(bookingId: detail.summary.id, storagePath: path, amount: amount,
                                                                  transferredAt: transferredAt,
                                                                  senderBank: senderBank.isEmpty ? nil : senderBank, sha256: hash) {
                case .ok:
                    feature.onBookingsChanged()
                    onDone()
                    dismiss()
                case .refused(let code):
                    message = BookingL10n.refusal(code)
                }
            } catch {
                message = BookingL10n.string("error.upload")
            }
        }
    }
}

struct CopyButton: View {
    let value: String
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = value
            copied = true
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(BookingL10n.string(copied ? "common.copied" : "common.copy"))
    }
}

struct ReceiptViewer: View {
    let feature: BookingFeature
    let receipt: BookingReceipt
    @State private var image: UIImage?
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .accessibilityLabel(BookingL10n.string("receipts.title"))
            } else if receipt.storagePath == nil {
                // The demo booking's sample receipt.
                VStack(spacing: DSSpacing.sm) {
                    Image(systemName: "doc.richtext").font(.system(size: 64)).foregroundStyle(Color.dsPrimary)
                    BookingL10n.text("demo.receipt").font(.dsFootnote)
                }
                .frame(maxHeight: .infinity)
            } else if failed {
                ErrorStateView(error: .network(.noConnection)) { Task { await load() } }
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent(BookingL10n.string("pay.transferredAmount"), value: formatSAR(receipt.amount))
                if let bank = receipt.senderBank { LabeledContent(BookingL10n.string("pay.senderBank"), value: bank) }
                if let at = receipt.transferredAt {
                    LabeledContent(BookingL10n.string("pay.transferTime"), value: at.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .font(.dsSubhead)
        }
        .padding(DSSpacing.lg)
        .navigationTitle(BookingL10n.string("receipts.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button(BookingL10n.string("common.done")) { dismiss() } }
        }
        .task { await load() }
    }

    private func load() async {
        guard let path = receipt.storagePath else { return }
        do {
            image = UIImage(data: try await feature.receipts.download(path: path))
            failed = image == nil
        } catch {
            failed = true
        }
    }
}

// MARK: - Small action sheets

struct ProposeTimeSheet: View {
    let action: (Date, String?) async throws -> ActionResult
    let onDone: () -> Void
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var note = ""
    @State private var isSending = false
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            DatePicker(BookingL10n.string("proposal.newTime"), selection: $date, in: Date.now.addingTimeInterval(7200)...,
                       displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
            TextField(BookingL10n.string("proposal.note"), text: $note, axis: .vertical)
        }
        .navigationTitle(BookingL10n.string("action.propose"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(BookingL10n.string("common.cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(BookingL10n.string("common.send")) {
                    isSending = true
                    Task {
                        defer { isSending = false }
                        do {
                            switch try await action(date, note.isEmpty ? nil : note) {
                            case .ok: onDone(); dismiss()
                            case .refused(let code): message = BookingL10n.refusal(code)
                            }
                        } catch { message = BookingL10n.string("error.generic") }
                    }
                }
                .disabled(isSending)
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(BookingL10n.string("common.ok"), role: .cancel) {}
        }
    }
}

struct ReasonSheet: View {
    let titleKey: String
    let optional: Bool
    let action: (String?) async throws -> ActionResult
    let onDone: () -> Void
    @State private var reason = ""
    @State private var isSending = false
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            TextField(BookingL10n.string(optional ? "reason.optional" : "reason.required"), text: $reason, axis: .vertical)
                .lineLimit(3...6)
        }
        .navigationTitle(BookingL10n.string(titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(BookingL10n.string("common.cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(BookingL10n.string("common.send")) {
                    isSending = true
                    Task {
                        defer { isSending = false }
                        do {
                            _ = try await action(reason.isEmpty ? nil : reason)
                            onDone()
                            dismiss()
                        } catch { failed = true }
                    }
                }
                .disabled(isSending || (!optional && reason.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
        .alert(BookingL10n.string("error.generic"), isPresented: $failed) {
            Button(BookingL10n.string("common.ok"), role: .cancel) {}
        }
        .presentationDetents([.medium])
    }
}

struct DisputeSheet: View {
    let action: (DisputeReason, String?) async throws -> ActionResult
    let onDone: () -> Void
    @State private var reason: DisputeReason = .paymentNotReceived
    @State private var details = ""
    @State private var isSending = false
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Picker(BookingL10n.string("dispute.reason"), selection: $reason) {
                ForEach(DisputeReason.allCases, id: \.self) { r in
                    Text(verbatim: BookingL10n.string("dispute.\(r.rawValue)")).tag(r)
                }
            }
            Section {
                TextField(BookingL10n.string("dispute.details"), text: $details, axis: .vertical).lineLimit(3...8)
            } footer: {
                BookingL10n.text("dispute.footer")
            }
        }
        .navigationTitle(BookingL10n.string("action.dispute"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(BookingL10n.string("common.cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(BookingL10n.string("common.send")) {
                    isSending = true
                    Task {
                        defer { isSending = false }
                        do {
                            _ = try await action(reason, details.isEmpty ? nil : details)
                            onDone()
                            dismiss()
                        } catch { failed = true }
                    }
                }
                .disabled(isSending)
            }
        }
        .alert(BookingL10n.string("error.generic"), isPresented: $failed) {
            Button(BookingL10n.string("common.ok"), role: .cancel) {}
        }
    }
}
