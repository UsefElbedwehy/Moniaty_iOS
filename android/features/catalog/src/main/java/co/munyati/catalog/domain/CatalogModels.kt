package co.munyati.catalog.domain

import co.munyati.shared.media.GalleryItem
import co.munyati.shared.media.VideoAsset
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
    /** Listed by the admin (the dresses for rent), not by providers: opens the dresses lists. */
    val adminListings: Boolean = false,
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
    /** "weekly", "dates" or "request" (the bride picks any time; the provider accepts or declines). */
    val bookingMode: String? = null,
) {
    /** The provider takes requests for any date and time («حسب الطلب»). */
    val isOnRequest: Boolean get() = bookingMode == "request"
}

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
    val videos: List<VideoAsset> = emptyList(),
    /**
     * The viewer's own service: she is its provider, or her bride account shares the provider's
     * phone number. It can't be booked (the server refuses it too).
     */
    val isOwn: Boolean = false,
) {
    /** The page's gallery: photos (or the card photo when there are none), then videos. */
    val galleryItems: List<GalleryItem>
        get() = GalleryItem.items(imageUrls.ifEmpty { listOfNotNull(card.imageUrl) }, videos)
}

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
    /** Dashboard-managed carousel slides (absent from older responses). */
    val banners: List<HomeBanner> = emptyList(),
    val categories: List<CatalogCategory> = emptyList(),
    val featured: List<ServiceCard> = emptyList(),
    val newest: List<ServiceCard> = emptyList(),
)

/**
 * A Home carousel slide from the dashboard (`home_banners`). [linkUrl] is an app link
 * (https://munyati.co/<p|s|store|c>/<id>) or an outside page.
 */
@Serializable
data class HomeBanner(
    val id: String,
    /** Optional: a banner without a title is a designed image shown on its own. */
    val titleAr: String? = null,
    val titleEn: String? = null,
    val subtitleAr: String? = null,
    val subtitleEn: String? = null,
    val ctaAr: String? = null,
    val ctaEn: String? = null,
    val imageUrl: String? = null,
    val linkUrl: String? = null,
) {
    val title: String? get() = localized(titleAr.orEmpty(), titleEn.orEmpty()).ifEmpty { null }
    val subtitle: String? get() = localized(subtitleAr.orEmpty(), subtitleEn.orEmpty()).ifEmpty { null }
    val cta: String? get() = localized(ctaAr.orEmpty(), ctaEn.orEmpty()).ifEmpty { null }

    /** No title but an image: the slide is the image alone, with no fade or text over it. */
    val isImageOnly: Boolean get() = title == null && imageUrl != null
}

@Serializable
data class MapPin(
    val kind: String, // "provider" | "store"
    val id: String,
    val name: String? = null,
    val lat: Double,
    val lng: Double,
    val logoUrl: String? = null,
)

/** A dress for rent in «فساتين», listed by the admin: a photo, the price and the owner's number. */
@Serializable
data class DressListing(
    val id: String,
    val kind: String,
    val imageUrl: String,
    val price: Double,
    /** +9665XXXXXXXX. */
    val contactPhone: String,
    /** The last day it is listed, "yyyy-MM-dd". */
    val endsOn: String? = null,
) {
    companion object {
        /** The three lists, in order. */
        val kinds = listOf("wedding", "jalwa", "evening")
    }
}

/** The notice for dress owners: list a dress for [price] riyals by contacting [phone]. */
@Serializable
data class DressNotice(val price: Double? = null, val days: Int? = null, val phone: String? = null)

/** One of the three dress lists, with the notice. */
@Serializable
data class DressListingsPage(val listings: List<DressListing> = emptyList(), val notice: DressNotice? = null)

/**
 * The bride's details (تفاصيل العروس): filled once in Profile, shown to the provider of each of her
 * bookings. [weddingDate] ("yyyy-MM-dd") is the same date the budget stores.
 */
@Serializable
data class BrideDetails(
    val fullName: String? = null,
    val age: Int? = null,
    val nationality: String? = null,
    /** The number she signed in with (+9665XXXXXXXX), from the server; she can't change it. */
    val phone: String? = null,
    /** One more number she may add (+9665XXXXXXXX). */
    val extraPhone: String? = null,
    val skinType: String? = null,
    val skinTone: String? = null,
    val hairType: String? = null,
    val hairLength: String? = null,
    val allergies: String? = null,
    val weddingDate: String? = null,
    val cityId: String? = null,
    val cityNameAr: String? = null,
    val cityNameEn: String? = null,
    val venue: String? = null,
    val guestCount: Int? = null,
    val notes: String? = null,
) {
    /** True when she has filled anything besides the date. */
    val hasEventDetails: Boolean get() = cityId != null || !venue.isNullOrEmpty() || guestCount != null || !notes.isNullOrEmpty()

    companion object {
        /** The values the server accepts for each choice field (labels are localized by the apps). */
        val skinTypes = listOf("normal", "dry", "oily", "combination", "sensitive")
        val skinTones = listOf("light", "medium", "tan", "deep")
        val hairTypes = listOf("straight", "wavy", "curly")
        val hairLengths = listOf("short", "medium", "long")
    }
}

/** Whole days from today to a "yyyy-MM-dd" day (0 on the day), null without one or after it. */
fun daysUntil(day: String?, today: java.time.LocalDate = java.time.LocalDate.now()): Int? {
    val date = day?.let { runCatching { java.time.LocalDate.parse(it) }.getOrNull() } ?: return null
    val days = java.time.temporal.ChronoUnit.DAYS.between(today, date)
    return if (days >= 0) days.toInt() else null
}

/** One item on the bride's "My preparations" checklist (تجهيزاتي), with an optional note. */
@Serializable
data class Preparation(val id: String, val title: String, val note: String? = null, val isDone: Boolean = false)

/** The bride's wedding budget (requirement 13). `reserved` is the sum of approved bookings. */
@Serializable
data class Budget(val total: Double, val reserved: Double, val remaining: Double, val weddingDate: String? = null) {
    /** Whole days from today to the wedding date (0 on the day), null without a date or after it. */
    fun daysUntilWedding(today: java.time.LocalDate = java.time.LocalDate.now()): Int? = daysUntil(weddingDate, today)

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
    /** Only services with a free time that day, "yyyy-MM-dd". */
    val date: String? = null,
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
