import SwiftUI
import DesignSystem
import Shared

/// "Bride details" (تفاصيل العروس): the wedding date and city, the venue, the number of guests
/// and notes. Filled once from Profile; the provider of each of her bookings sees them, so the
/// screen says so at the top. The date is the budget's date too.
struct BrideDetailsScreen: View {
    let feature: CatalogFeature
    @Environment(\.dismiss) private var dismiss
    @State private var hasDate = false
    @State private var weddingDate = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    @State private var cityId = ""
    @State private var venue = ""
    @State private var guestsText = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var failed = false
    @State private var didFill = false

    /// "yyyy-MM-dd" in the Gregorian calendar, the format the server stores.
    private static var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    /// Arabic-Indic digits typed on an Arabic keyboard count too.
    private var guestCount: Int? {
        let digits = guestsText.compactMap { $0.wholeNumberValue.map(String.init) }.joined()
        return Int(digits)
    }

    private var guestsValid: Bool { guestsText.isEmpty || (guestCount.map { (1...10_000).contains($0) } ?? false) }

    private var isArabic: Bool { Locale.current.language.languageCode?.identifier == "ar" }

    var body: some View {
        Form {
            Section {
                Label(CatalogL10n.string("brideDetails.intro"), systemImage: "info.circle")
                    .font(.dsFootnote)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            Section {
                Toggle(CatalogL10n.string("budget.hasDate"), isOn: $hasDate)
                if hasDate {
                    DatePicker(CatalogL10n.string("budget.date"), selection: $weddingDate, in: Date.now..., displayedComponents: .date)
                }
                Picker(CatalogL10n.string("brideDetails.city"), selection: $cityId) {
                    Text(verbatim: CatalogL10n.string("brideDetails.city.none")).tag("")
                    ForEach(feature.context.cities) { city in
                        Text(verbatim: isArabic ? city.nameAr : city.nameEn).tag(city.id)
                    }
                }
            } header: {
                CatalogL10n.text("brideDetails.section.wedding")
            }
            Section {
                TextField(CatalogL10n.string("brideDetails.venue.placeholder"), text: $venue)
            } header: {
                CatalogL10n.text("brideDetails.venue")
            }
            Section {
                TextField(CatalogL10n.string("brideDetails.guests.placeholder"), text: $guestsText)
                    .keyboardType(.numberPad)
            } header: {
                CatalogL10n.text("brideDetails.guests")
            } footer: {
                if !guestsValid { CatalogL10n.text("brideDetails.guests.invalid").foregroundStyle(Color.dsError) }
            }
            Section {
                TextField(CatalogL10n.string("brideDetails.notes.placeholder"), text: $notes, axis: .vertical)
                    .lineLimit(3...10)
            } header: {
                CatalogL10n.text("brideDetails.notes")
            }
        }
        .dsFormBackground()
        .navigationTitle(CatalogL10n.string("brideDetails.title"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(CatalogL10n.string("common.save")) { save() }
                    .disabled(isSaving || !guestsValid)
            }
        }
        .alert(CatalogL10n.string("common.saveFailed"), isPresented: $failed) {
            Button(CatalogL10n.string("common.ok"), role: .cancel) {}
        }
        .task {
            await feature.brideDetails.load(isGuest: feature.context.isGuest)
            fill()
        }
        .trackScreen("bride_details")
    }

    /// Fills the form once from what she saved (not again after edits start).
    private func fill() {
        guard !didFill else { return }
        didFill = true
        let saved = feature.brideDetails.details
        if let date = (saved?.weddingDate ?? feature.weddingDate).flatMap(Self.dayFormatter.date(from:)) {
            hasDate = true
            weddingDate = date
        }
        cityId = saved?.cityId ?? ""
        venue = saved?.venue ?? ""
        guestsText = saved?.guestCount.map { "\($0)" } ?? ""
        notes = saved?.notes ?? ""
    }

    private func save() {
        let trimmed = { (text: String) -> String? in
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        let details = BrideDetails(
            weddingDate: hasDate ? Self.dayFormatter.string(from: weddingDate) : nil,
            cityId: cityId.isEmpty ? nil : cityId,
            venue: trimmed(venue).map { String($0.prefix(120)) },
            guestCount: guestCount,
            notes: trimmed(notes).map { String($0.prefix(1000)) }
        )
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await feature.brideDetails.save(details)
                feature.refreshBudget() // the date is the budget's date too
                dismiss()
            } catch {
                failed = true
            }
        }
    }
}
