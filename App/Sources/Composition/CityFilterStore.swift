import Foundation
import Observation
import Catalog

/// The bride's city choice (`docs/PLAN.md` §4.9): one or more cities, or «الكل» (All).
/// "All" is a client-side option, not a database row: an empty selection means all cities.
/// Every list, search and map query will pass `queryCityIds` (nil = no filter).
@MainActor
@Observable
final class CityFilterStore {
    var available: [City] = []
    private(set) var selected: Set<String> = []

    var isAll: Bool { selected.isEmpty }

    /// The RPC argument: nil for "All", else the chosen ids.
    var queryCityIds: [String]? { isAll ? nil : Array(selected).sorted() }

    func restore(_ ids: [String]) {
        selected = Set(ids)
    }

    func selectAll() {
        selected.removeAll()
    }

    func toggle(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
        // Choosing every city is the same as "All".
        if !available.isEmpty, selected.count == available.count {
            selected.removeAll()
        }
    }

    /// Short label for headers, e.g. "الدمام، الخبر +1" or "كل المدن".
    func summary(allLabel: String, locale: Locale = .current) -> String {
        guard !isAll else { return allLabel }
        let names = available.filter { selected.contains($0.id) }.map { $0.name(locale: locale) }
        guard names.count > 2 else { return names.joined(separator: "، ") }
        return names.prefix(2).joined(separator: "، ") + " +\(names.count - 2)"
    }
}
