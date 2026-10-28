import SwiftUI
import DesignSystem
import Shared

/// "Bride details" (تفاصيل العروس): about her (name, age, nationality, phone; skin and hair;
/// allergies), then the wedding (date, city, venue, guests, notes). Every field is optional. The
/// provider of each of her bookings sees them (name and phone once the payment is confirmed), so
/// the screen says so at the top. The date is the budget's date too.
struct BrideDetailsScreen: View {
    let feature: CatalogFeature
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var ageText = ""
    @State private var nationality = ""
    @State private var phone = ""
    @State private var skinType = ""
    @State private var skinTone = ""
    @State private var hairType = ""
    @State private var hairLength = ""
    @State private var allergies = ""
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

    /// The number in a field, counting Arabic-Indic digits typed on an Arabic keyboard.
    private static func number(_ text: String) -> Int? {
        Int(text.compactMap { $0.wholeNumberValue.map(String.init) }.joined())
    }

    private var age: Int? { Self.number(ageText) }
    private var guestCount: Int? { Self.number(guestsText) }
    private var ageValid: Bool { ageText.isEmpty || (age.map { (16...70).contains($0) } ?? false) }
    private var guestsValid: Bool { guestsText.isEmpty || (guestCount.map { (1...10_000).contains($0) } ?? false) }

    /// A Saudi mobile in any common form (05…, 5…, 9665…, +9665…) → +9665XXXXXXXX; nil if not one.
    private static func saudiMobile(_ text: String) -> String? {
        var digits = text.compactMap { $0.wholeNumberValue.map(String.init) }.joined()
        if digits.hasPrefix("00966") { digits.removeFirst(5) } else if digits.hasPrefix("966") { digits.removeFirst(3) }
        if digits.hasPrefix("0") { digits.removeFirst() }
        guard digits.count == 9, digits.hasPrefix("5") else { return nil }
        return "+966" + digits
    }

    private var phoneValid: Bool { phone.trimmingCharacters(in: .whitespaces).isEmpty || Self.saudiMobile(phone) != nil }
    private var canSave: Bool { ageValid && guestsValid && phoneValid && !isSaving }

    private var isArabic: Bool { Locale.current.language.languageCode?.identifier == "ar" }

    var body: some View {
        Form {
            Section {
                Label(CatalogL10n.string("brideDetails.intro"), systemImage: "info.circle")
                    .font(.dsFootnote)
                    .foregroundStyle(Color.dsTextSecondary)
            }

            // About her
            Section {
                TextField(CatalogL10n.string("brideDetails.name"), text: $fullName)
                    .textContentType(.name)
                TextField(CatalogL10n.string("brideDetails.age"), text: $ageText)
                    .keyboardType(.numberPad)
                TextField(CatalogL10n.string("brideDetails.nationality"), text: $nationality)
                TextField(CatalogL10n.string("brideDetails.phone"), text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            } header: {
                CatalogL10n.text("brideDetails.section.me")
            } footer: {
                if !ageValid {
                    CatalogL10n.text("brideDetails.age.invalid").foregroundStyle(Color.dsError)
                } else if !phoneValid {
                    CatalogL10n.text("brideDetails.phone.invalid").foregroundStyle(Color.dsError)
                } else {
                    CatalogL10n.text("brideDetails.privacy")
                }
            }
            Section {
                choice("brideDetails.skinType", values: BrideDetails.skinTypes, selection: $skinType)
                choice("brideDetails.skinTone", values: BrideDetails.skinTones, selection: $skinTone)
                choice("brideDetails.hairType", values: BrideDetails.hairTypes, selection: $hairType)
                choice("brideDetails.hairLength", values: BrideDetails.hairLengths, selection: $hairLength)
            } header: {
                CatalogL10n.text("brideDetails.section.looks")
            }
            Section {
                TextField(CatalogL10n.string("brideDetails.allergies.placeholder"), text: $allergies, axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                CatalogL10n.text("brideDetails.allergies")
            }

            // The wedding
            Section {
                Toggle(CatalogL10n.string("budget.hasDate"), isOn: $hasDate)
                if hasDate {
                    DatePicker(CatalogL10n.string("budget.date"), selection: $weddingDate, in: Date.now..., displayedComponents: .date)
                }
                Picker(CatalogL10n.string("brideDetails.city"), selection: $cityId) {
                    Text(verbatim: CatalogL10n.string("brideDetails.none")).tag("")
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
                    .disabled(!canSave)
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

    /// A picker over one choice field, with «لم تُحدَّد» first.
    private func choice(_ key: String, values: [String], selection: Binding<String>) -> some View {
        Picker(CatalogL10n.string(key), selection: selection) {
            Text(verbatim: CatalogL10n.string("brideDetails.none")).tag("")
            ForEach(values, id: \.self) { value in
                Text(verbatim: CatalogL10n.string("\(key).\(value)")).tag(value)
            }
        }
    }

    /// Fills the form once from what she saved; her account's name and phone pre-fill empty fields.
    private func fill() {
        guard !didFill else { return }
        didFill = true
        let saved = feature.brideDetails.details
        fullName = saved?.fullName ?? feature.context.displayName ?? ""
        ageText = saved?.age.map { "\($0)" } ?? ""
        nationality = saved?.nationality ?? ""
        phone = (saved?.phone ?? feature.context.phone).map(Self.localPhone) ?? ""
        skinType = saved?.skinType ?? ""
        skinTone = saved?.skinTone ?? ""
        hairType = saved?.hairType ?? ""
        hairLength = saved?.hairLength ?? ""
        allergies = saved?.allergies ?? ""
        if let date = (saved?.weddingDate ?? feature.weddingDate).flatMap(Self.dayFormatter.date(from:)) {
            hasDate = true
            weddingDate = date
        }
        cityId = saved?.cityId ?? ""
        venue = saved?.venue ?? ""
        guestsText = saved?.guestCount.map { "\($0)" } ?? ""
        notes = saved?.notes ?? ""
    }

    /// +9665XXXXXXXX → 05XXXXXXXX, how people write it.
    private static func localPhone(_ phone: String) -> String {
        phone.hasPrefix("+966") ? "0" + phone.dropFirst(4) : phone
    }

    private func save() {
        let trimmed = { (text: String, limit: Int) -> String? in
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : String(t.prefix(limit))
        }
        let details = BrideDetails(
            fullName: trimmed(fullName, 80),
            age: age,
            nationality: trimmed(nationality, 40),
            phone: Self.saudiMobile(phone),
            skinType: skinType.isEmpty ? nil : skinType,
            skinTone: skinTone.isEmpty ? nil : skinTone,
            hairType: hairType.isEmpty ? nil : hairType,
            hairLength: hairLength.isEmpty ? nil : hairLength,
            allergies: trimmed(allergies, 500),
            weddingDate: hasDate ? Self.dayFormatter.string(from: weddingDate) : nil,
            cityId: cityId.isEmpty ? nil : cityId,
            venue: trimmed(venue, 120),
            guestCount: guestCount,
            notes: trimmed(notes, 1000)
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
