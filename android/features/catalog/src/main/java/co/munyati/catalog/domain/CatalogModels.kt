package co.munyati.catalog.domain

import kotlinx.serialization.Serializable
import java.math.RoundingMode
import java.text.NumberFormat
import java.util.Locale

// Wire models decode straight from the RPC JSON (snake_case handled by the API client), like iOS.

/** Picks the Arabic or English variant for the current language (Arabic unless English). */
fun localized(ar: String, en: String, locale: Locale = Locale.getDefault()): String =
    if (locale.language == "en") en else ar

/** A city the app serves (dashboard-managed). */
@Serializable
data class City(val id: String, val nameAr: String, val nameEn: String, val lat: Double? = null, val lng: Double? = null) {
    fun name(locale: Locale = Locale.getDefault()) = localized(nameAr, nameEn, locale)
}

/** A service category (dashboard-managed; icons can change without an app release). */
@Serializable
data class CatalogCategory(
    val id: String,
    val nameAr: String,
    val nameEn: String,
    val iconUrl: String? = null,
    val iconSymbol: String? = null,
    val priceHintAr: String? = null,
    val priceHintEn: String? = null,
    val serviceCount: Int? = null,
) {
    val name: String get() = localized(nameAr, nameEn)
    val priceHint: String? get() = localized(priceHintAr.orEmpty(), priceHintEn.orEmpty()).ifEmpty { null }
}

/** The card shown in every list. */
@Serializable
data class ServiceCard(
    val id: String,
    val title: String,
    val price: Double,
    val imageUrl: String? = null,
    val categoryId: String,
    val providerId: String,
    val providerName: String? = null,
    val providerLogoUrl: String? = null,
    val isVerified: Boolean = false,
    /** Diamond plan: "featured" badge. */
    val isFeatured: Boolean? = null,
    /** Approved bride reviews. */
    val ratingAvg: Double? = null,
    val ratingCount: Int? = null,
    val femaleStaffOnly: Boolean = false,
    val isFavorite: Boolean = false,
)

@Serializable
data class ProviderSummary(
    val id: String,
    val name: String? = null,
    val logoUrl: String? = null,
    val isVerified: Boolean = false,
    val femaleStaffOnly: Boolean = false,
    val cityIds: List<String> = emptyList(),
    val ratingAvg: Double? = null,
    val ratingCount: Int? = null,
)

@Serializable
data class StoreSummary(
    val id: String,
    val name: String,
    val logoUrl: String? = null,
    val address: String? = null,
    val cityId: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
)

/** A service page. The RPC returns the card fields at the top level, beside the extras. */
data class ServiceDetail(
    val card: ServiceCard,
    val description: String?,
    val durationMinutes: Int?,
    val atCustomerLocation: Boolean,
    val imageUrls: List<String>,
    val provider: ProviderSummary,
    val store: StoreSummary?,
    val moreFromProvider: List<ServiceCard>,
)

/** A provider page; summary fields at the top level, beside the extras. */
data class ProviderProfile(
    val summary: ProviderSummary,
    val bio: String?,
    val coverUrl: String?,
    val address: String?,
    val instagram: String?,
    val services: List<ServiceCard>,
    val stores: List<StoreSummary>,
)

/** A store page; summary fields at the top level, beside the extras. */
data class StoreDetail(
    val summary: StoreSummary,
    val description: String?,
    val instagram: String?,
    val provider: ProviderSummary,
    val services: List<ServiceCard>,
)

@Serializable
data class HomeContent(
    val categories: List<CatalogCategory> = emptyList(),
    val featured: List<ServiceCard> = emptyList(),
    val newest: List<ServiceCard> = emptyList(),
)

@Serializable
data class MapPin(
    val kind: String, // "provider" | "store"
    val id: String,
    val name: String? = null,
    val lat: Double,
    val lng: Double,
    val logoUrl: String? = null,
)

/** The bride's wedding budget (requirement 13). `reserved` is the sum of approved bookings. */
@Serializable
data class Budget(val total: Double, val reserved: Double, val remaining: Double, val weddingDate: String? = null) {
    /** 0…1, how much of the budget is reserved. */
    val usedFraction: Float get() = if (total <= 0) 0f else (reserved / total).toFloat().coerceIn(0f, 1f)
}

/** What a services list shows: a category, a free-text search, or both. */
data class ServiceFilter(
    val categoryId: String? = null,
    val title: String? = null,
    val query: String = "",
    val withinBudget: Boolean = false,
    val femaleOnly: Boolean = false,
    val sort: Sort = Sort.Recommended,
) {
    enum class Sort(val rawValue: String) {
        Recommended("recommended"), PriceAsc("price_asc"), PriceDesc("price_desc"), Newest("newest");

        companion object {
            fun from(raw: String) = entries.firstOrNull { it.rawValue == raw } ?: Recommended
        }
    }
}

/** "٢٬٨٠٠ ر.س" / "SAR 2,800": up to two decimals, the current locale's digits. */
fun formatAmount(amount: Double, locale: Locale = Locale.getDefault()): String =
    NumberFormat.getNumberInstance(locale).apply {
        minimumFractionDigits = 0
        maximumFractionDigits = 2
        roundingMode = RoundingMode.HALF_EVEN
    }.format(amount)
