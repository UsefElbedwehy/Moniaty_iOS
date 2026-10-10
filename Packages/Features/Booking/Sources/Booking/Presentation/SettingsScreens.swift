import SwiftUI
import Core
import DesignSystem
import Shared

// MARK: - Availability (provider studio)

/// Weekly working hours (one range per weekday) and upcoming days off.
struct AvailabilityScreen: View {
    let feature: BookingFeature

    private struct Day: Identifiable {
        let weekday: Int
        var isOpen: Bool
        var start: Date
        var end: Date
        var id: Int { weekday }
    }

    @State private var days: [Day] = []
    @State private var daysOff: [Date] = []
    @State private var newDayOff = Calendar.current.startOfDay(for: .now)
    @State private var state: ViewState<Bool> = .loading
    @State private var isSaving = false
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            switch state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity)
            case .error(let error):
                ErrorStateView(error: error) { Task { await load() } }
            default:
                Section {
                    ForEach($days) { $day in
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            Toggle(isOn: $day.isOpen) {
                                Text(verbatim: Self.weekdayName(day.weekday)).font(.dsHeadline)
                            }
                            .tint(Color.dsPrimary)
                            if day.isOpen {
                                HStack {
                                    DatePicker(BookingL10n.string("availability.from"), selection: $day.start,
                                               displayedComponents: .hourAndMinute)
                                    DatePicker(BookingL10n.string("availability.to"), selection: $day.end,
                                               displayedComponents: .hourAndMinute)
                                }
                                .font(.dsFootnote)
                            }
                        }
                    }
                } header: {
                    BookingL10n.text("availability.weekly")
                } footer: {
                    BookingL10n.text("availability.weeklyFooter")
                }

                Section {
                    ForEach(daysOff, id: \.self) { day in
                        Text(verbatim: day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    }
                    .onDelete { daysOff.remove(atOffsets: $0) }
                    HStack {
                        DatePicker(BookingL10n.string("availability.addDayOff"), selection: $newDayOff,
                                   in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                        Button {
                            let day = Calendar.current.startOfDay(for: newDayOff)
                            if !daysOff.contains(day) { daysOff = (daysOff + [day]).sorted() }
                        } label: {
                            Image(systemName: "plus.circle.fill").foregroundStyle(Color.dsPrimary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(BookingL10n.string("availability.addDayOff"))
                    }
                } header: {
                    BookingL10n.text("availability.daysOff")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .dsScreenBackground()
        .navigationTitle(BookingL10n.string("availability.title"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(BookingL10n.string("common.save")) { save() }
                    .disabled(isSaving || state.value == nil || !isValid)
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(BookingL10n.string("common.ok"), role: .cancel) {}
        }
        .task { await load() }
        .trackScreen("studio_availability")
    }

    private var isValid: Bool {
        days.allSatisfy { !$0.isOpen || Self.time($0.start) < Self.time($0.end) }
    }

    private func load() async {
        do {
            let availability = try await feature.repository.availability()
            days = (0...6).map { weekday in
                if let rule = availability.rules.first(where: { $0.weekday == weekday }) {
                    return Day(weekday: weekday, isOpen: true, start: Self.date(rule.startTime), end: Self.date(rule.endTime))
                }
                return Day(weekday: weekday, isOpen: false, start: Self.date("10:00"), end: Self.date("22:00"))
            }
            daysOff = availability.daysOff.compactMap { DateFormatter.day.date(from: $0) }
                .map { Calendar.current.startOfDay(for: $0) }
            state = .loaded(true)
        } catch {
            state = .error(appError(error))
        }
    }

    private func save() {
        let rules = days.filter(\.isOpen).map {
            Availability.Rule(weekday: $0.weekday, startTime: Self.time($0.start), endTime: Self.time($0.end))
        }
        let off = daysOff.map { DateFormatter.day.string(from: $0) }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await feature.repository.saveAvailability(Availability(rules: rules, daysOff: off))
                dismiss()
            } catch {
                message = BookingL10n.string("error.generic")
            }
        }
    }

    /// 0 = Sunday, matching Postgres `extract(dow …)`.
    private static func weekdayName(_ weekday: Int) -> String {
        Calendar.current.weekdaySymbols[weekday]
    }

    private static func date(_ hhmm: String) -> Date {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        return Calendar.current.date(bySettingHour: parts.first ?? 0, minute: parts.count > 1 ? parts[1] : 0,
                                     second: 0, of: .now) ?? .now
    }

    private static func time(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

// MARK: - Payment methods (provider studio)

/// Where brides transfer money. Approved bookings keep a snapshot, so edits never change them.
struct PaymentMethodsScreen: View {
    let feature: BookingFeature
    @State private var state: ViewState<[PaymentMethod]> = .loading
    @State private var editing: PaymentMethodDraft?

    var body: some View {
        List {
            switch state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            case .error(let error):
                ErrorStateView(error: error) { Task { await load() } }.listRowBackground(Color.clear)
            case .loaded(let list), .refreshing(let list):
                Section {
                    ForEach(list) { method in
                        Button { editing = PaymentMethodDraft(method) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(verbatim: method.label).font(.dsHeadline)
                                    Spacer()
                                    if !method.isActive {
                                        BookingL10n.text("methods.inactive").font(.dsCaption)
                                            .foregroundStyle(Color.dsTextSecondary)
                                    }
                                }
                                Text(verbatim: BookingL10n.string("method.\(method.kind)") + " · " + method.value)
                                    .font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                            .foregroundStyle(Color.dsTextPrimary)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { list[$0].id }
                        Task {
                            for id in ids { try? await feature.repository.deletePaymentMethod(id: id) }
                            await load()
                        }
                    }
                } footer: {
                    BookingL10n.text("methods.footer")
                }
            case .empty, .offline:
                EmptyStateView(systemImage: "banknote", title: BookingL10n.key("methods.empty.title"),
                               message: BookingL10n.key("methods.empty.message"))
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .dsScreenBackground()
        .navigationTitle(BookingL10n.string("methods.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = PaymentMethodDraft() } label: { Image(systemName: "plus") }
                    .accessibilityLabel(BookingL10n.string("methods.add"))
            }
        }
        .sheet(item: $editing) { draft in
            NavigationStack {
                PaymentMethodEditor(feature: feature, draft: draft) { Task { await load() } }
            }
        }
        .task { await load() }
        .trackScreen("studio_payment_methods")
    }

    private func load() async {
        do {
            let list = try await feature.repository.paymentMethods()
            state = list.isEmpty ? .empty : .loaded(list)
        } catch {
            if state.value == nil { state = .error(appError(error)) }
        }
    }
}

struct PaymentMethodEditor: View {
    let feature: BookingFeature
    @State var draft: PaymentMethodDraft
    let onSaved: () -> Void
    @State private var isSaving = false
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss

    private static let kinds = ["iban", "sarie_alias", "wallet"]

    var body: some View {
        Form {
            Section {
                Picker(BookingL10n.string("methods.kind"), selection: $draft.kind) {
                    ForEach(Self.kinds, id: \.self) { kind in
                        BookingL10n.text("method.\(kind)").tag(kind)
                    }
                }
                TextField(BookingL10n.string("methods.label"), text: $draft.label)
                TextField(BookingL10n.string("methods.accountName"), text: $draft.accountName)
                TextField(BookingL10n.string("methods.value.\(draft.kind)"), text: $draft.value)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(draft.kind == "iban" ? .default : .phonePad)
                    .environment(\.layoutDirection, .leftToRight)
                Toggle(BookingL10n.string("methods.active"), isOn: $draft.isActive).tint(Color.dsPrimary)
            } footer: {
                BookingL10n.text("methods.hint.\(draft.kind)")
            }
        }
        .navigationTitle(BookingL10n.string(draft.id == nil ? "methods.add" : "methods.edit"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(BookingL10n.string("common.cancel")) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(BookingL10n.string("common.save")) { save() }
                    .disabled(isSaving || !draft.isValid)
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(BookingL10n.string("common.ok"), role: .cancel) {}
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                switch try await feature.repository.savePaymentMethod(draft) {
                case .ok:
                    onSaved()
                    dismiss()
                case .refused(let code):
                    message = BookingL10n.refusal(code)
                }
            } catch {
                message = BookingL10n.string("error.generic")
            }
        }
    }
}
