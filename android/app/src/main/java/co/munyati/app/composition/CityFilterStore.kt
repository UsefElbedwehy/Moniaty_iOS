package co.munyati.app.composition

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.munyati.app.backend.City
import java.util.Locale

/**
 * The bride's city choice (`docs/PLAN.md` §4.9): one or more cities, or «الكل» (All). "All" is a
 * client-side option: an empty selection means all cities.
 */
class CityFilterStore {
    var available: List<City> by mutableStateOf(emptyList())
    var selected: Set<String> by mutableStateOf(emptySet())
        private set

    val isAll: Boolean get() = selected.isEmpty()

    /** The RPC argument: null for "All", else the chosen ids. */
    val queryCityIds: List<String>? get() = if (isAll) null else selected.sorted()

    fun restore(ids: List<String>) {
        selected = ids.toSet()
    }

    fun selectAll() {
        selected = emptySet()
    }

    fun toggle(id: String) {
        val next = if (id in selected) selected - id else selected + id
        // Choosing every city is the same as "All".
        selected = if (available.isNotEmpty() && next.size == available.size) emptySet() else next
    }

    /** Short label for headers, e.g. "الدمام، الخبر +1" or "كل المدن". */
    fun summary(allLabel: String, locale: Locale = Locale.getDefault()): String {
        if (isAll) return allLabel
        val names = available.filter { it.id in selected }.map { it.name(locale) }
        if (names.size <= 2) return names.joinToString("، ")
        return names.take(2).joinToString("، ") + " +${names.size - 2}"
    }
}
