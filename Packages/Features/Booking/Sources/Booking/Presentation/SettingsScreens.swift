import SwiftUI
import Core
import DesignSystem
import Shared

// MARK: - Availability (provider studio)

/// How the provider takes bookings, and when: weekly hours (one range per weekday) with days off;
/// or specific dates, each with its hours; or on request (the bride picks any date and time and
/// the provider accepts or declines).
struct AvailabilityScreen: View {
    let feature: BookingFeature

    private struct Day: Identifiable {
        let weekday: Int
        var isOpen: Bool
        var start: Date
        var end: Date
        var id: Int { weekday }
    }

    private struct DateSlot: Identifiable, Hashable {
        let id = UUID()
        var day: Date
        var start: Date
        var end: Date
    }

    @State private var mode = "weekly"
    @State private var dates: [DateSlot] = []
    @State private var newDate = Calendar.current.startOfDay(for: .now)
    @State private var newStart = AvailabilityScreen.date("16:00")
    @State private var newEnd = AvailabilityScreen.date("22:00")
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
                    Picker(BookingL10n.string("availability.mode"), selection: $mode) {
                        ForEach(["weekly", "dates", "request"], id: \.self) { m in
                            Text(verbatim: BookingL10n.string("availability.mode.\(m)")).tag(m)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    BookingL10n.text("availability.mode")
                } footer: {
                    BookingL10n.text("availability.mode.footer.\(mode)")
                }

                if mode == "dates" { datesSections }
                if mode == "weekly" { weeklySections }
            }
        }
        .dsFormBackground()
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

    /// "dates" mode: her upcoming dates with their hours, and a row to add one.
    @ViewBuilder
    private var datesSections: some View {
        Section {
            if dates.isEmpty {
                BookingL10n.text("availability.dates.empty").foregroundStyle(Color.dsTextSecondary)
            }
            ForEach($dates) { $slot in
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(verbatim: slot.day.displayFormatted(.dateTime.weekday(.wide).day().month(.wide))).font(.dsHeadline)
                    HStack {
                        DatePicker(BookingL10n.string("availability.from"), selection: $slot.start, displayedComponents: .hourAndMinute)
                        DatePicker(BookingL10n.string("availability.to"), selection: $slot.end, displayedComponents: .hourAndMinute)
                    }
                    .font(.dsFootnote)
                }
            }
            .onDelete { dates.remove(atOffsets: $0) }
        } header: {
            BookingL10n.text("availability.dates")
        } footer: {
            BookingL10n.text("availability.dates.footer")
        }
        Section {
            DatePicker(BookingL10n.string("availability.date"), selection: $newDate,
                       in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
            HStack {
                DatePicker(BookingL10n.string("availability.from"), selection: $newStart, displayedComponents: .hourAndMinute)
                DatePicker(BookingL10n.string("availability.to"), selection: $newEnd, displayedComponents: .hourAndMinute)
            }
            .font(.dsFootnote)
            Button {
                let day = Calendar.current.startOfDay(for: newDate)
                dates = (dates + [DateSlot(day: day, start: newStart, end: newEnd)]).sorted { $0.day < $1.day }
            } label: {
                Label(BookingL10n.string("availability.addDate"), systemImage: "plus.circle.fill")
            }
            .disabled(Self.time(newStart) >= Self.time(newEnd))
        } header: {
            BookingL10n.text("availability.addDate")
        }
    }

    /// "weekly" mode: the hours for each weekday and the days off.
    @ViewBuilder
    private var weeklySections: some View {
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
                Text(verbatim: day.displayFormatted(.dateTime.weekday(.wide).day().month(.wide)))
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

    private var isValid: Bool {
        days.allSatisfy { !$0.isOpen || Self.time($0.start) < Self.time($0.end) }
            && dates.allSatisfy { Self.time($0.start) < Self.time($0.end) }
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
            mode = availability.mode ?? "weekly"
            dates = (availability.dates ?? []).compactMap { window in
                DateFormatter.day.date(from: window.day).map {
                    DateSlot(day: Calendar.current.startOfDay(for: $0), start: Self.date(window.startTime), end: Self.date(window.endTime))
                }
            }
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
                let windows = dates.map {
                    Availability.DateWindow(day: DateFormatter.day.string(from: $0.day), startTime: Self.time($0.start), endTime: Self.time($0.end))
                }
                try await feature.repository.saveAvailability(Availability(rules: rules, daysOff: off, mode: mode, dates: windows))
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

    fileprivate static func date(_ hhmm: String) -> Date {
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
    @State private var deleteFailed = false

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
                            for id in ids {
                                do { try await feature.repository.deletePaymentMethod(id: id) } catch { deleteFailed = true }
                            }
                            await load()
                        }
                    }
                } footer: {
                    BookingL10n.text("methods.footer")
                }
            case .offline:
                ErrorStateView(error: .offline) { Task { await load() } }.listRowBackground(Color.clear)
            case .empty:
                EmptyStateView(systemImage: "banknote", title: BookingL10n.key("methods.empty.title"),
                               message: BookingL10n.key("methods.empty.message"))
                    .listRowBackground(Color.clear)
            }
        }
        .dsFormBackground()
        .navigationTitle(BookingL10n.string("methods.title"))
        .alert(BookingL10n.string("error.generic"), isPresented: $deleteFailed) {
            Button(BookingL10n.string("common.ok"), role: .cancel) {}
        }
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
        .dsFormBackground()
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
