package co.munyati.catalog.data

import co.munyati.shared.media.VideoAsset
import co.munyati.catalog.domain.Budget
import co.munyati.catalog.domain.BrideDetails
import co.munyati.catalog.domain.Preparation
import co.munyati.catalog.domain.CatalogCategory
import co.munyati.catalog.domain.HomeBanner
import co.munyati.catalog.domain.HomeContent
import co.munyati.catalog.domain.MapPin
import co.munyati.catalog.domain.ProviderProfile
import co.munyati.catalog.domain.ProviderSummary
import co.munyati.catalog.domain.ServiceCard
import co.munyati.catalog.domain.ServiceDetail
import co.munyati.catalog.domain.ServiceFilter
import co.munyati.catalog.domain.StoreDetail
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Sample catalog for running without a backend (and for tests) — the same data as iOS. */
class MockCatalogRepository : CatalogRepository {
    private val mutex = Mutex()
    private val favoriteIds = mutableSetOf<String>()
    private var storedBudget: Budget? = null
    private val storedPreparations = mutableListOf<Preparation>()
    private var storedBrideDetails: BrideDetails? = null

    private data class Provider(val summary: ProviderSummary, val lat: Double, val lng: Double)
    private data class Service(
        val id: String, val title: String, val price: Double, val categoryId: String, val providerId: String,
        val durationMinutes: Int? = null, val atCustomerLocation: Boolean = false, val description: String? = null,
    )

    private val categories = listOf(
        CatalogCategory("makeup", "خبيرة مكياج", "Makeup artist", iconSymbol = "paintbrush.pointed", priceHintAr = "٣٥٠ – ٣٬٠٠٠ ر.س", priceHintEn = "SAR 350 – 3,000"),
        CatalogCategory("photography", "مصورة فوتو", "Photographer", iconSymbol = "camera"),
        CatalogCategory("venues", "قصور وقاعات الأفراح", "Wedding halls & venues", iconSymbol = "building.columns"),
        CatalogCategory("henna", "نقش الحناء", "Henna artist", iconSymbol = "hand.raised"),
        CatalogCategory("kosha_decor", "الكوش والتنسيق", "Kosha & décor", iconSymbol = "sparkles.rectangle.stack"),
        CatalogCategory("dresses", "فساتين الزفاف", "Wedding dresses", iconSymbol = "tshirt"),
        CatalogCategory("coffee_servers", "الضيافة", "Hospitality", iconSymbol = "dallah"),
        CatalogCategory("cakes_sweets", "الكيك والحلويات", "Cakes & sweets", iconSymbol = "birthday.cake"),
    )

    private val providers = listOf(
        Provider(ProviderSummary("p-lamsa", "لمسة جمال", isVerified = true, femaleStaffOnly = true, cityIds = listOf("dammam", "khobar")), 26.285, 50.208),
        Provider(ProviderSummary("p-reem", "عدسة ريم", isVerified = true, femaleStaffOnly = true, cityIds = listOf("khobar")), 26.30, 50.19),
        Provider(ProviderSummary("p-lulu", "قصر اللؤلؤة", isVerified = false, femaleStaffOnly = false, cityIds = listOf("dammam")), 26.43, 50.10),
        Provider(ProviderSummary("p-henna", "حناء نجد", isVerified = false, femaleStaffOnly = true, cityIds = listOf("qatif")), 26.52, 50.01),
    )

    private val services = listOf(
        Service("s1", "مكياج العروس", 2800.0, "makeup", "p-lamsa", 180, true, "مكياج ناعم يدوم طوال الليلة، شامل الرموش وتثبيت التسريحة."),
        Service("s2", "مكياج ليلة الحناء", 1500.0, "makeup", "p-lamsa", 120),
        Service("s3", "تصوير الزفاف كاملاً", 6500.0, "photography", "p-reem", 360),
        Service("s4", "جلسة تصوير العروس", 3500.0, "photography", "p-reem", 120),
        Service("s5", "قاعة كبرى حتى ٤٠٠ ضيفة", 28000.0, "venues", "p-lulu"),
        Service("s6", "نقش حناء العروس", 600.0, "henna", "p-henna", 90),
    )

    private fun summary(id: String) = providers.firstOrNull { it.summary.id == id }?.summary ?: ProviderSummary(id)

    private fun card(s: Service): ServiceCard {
        val p = summary(s.providerId)
        return ServiceCard(
            id = s.id, title = s.title, price = s.price, categoryId = s.categoryId, providerId = s.providerId,
            providerName = p.name, isVerified = p.isVerified, femaleStaffOnly = p.femaleStaffOnly,
            isFavorite = s.id in favoriteIds, imageUrl = "https://picsum.photos/seed/${s.id}/800/600",
        )
    }

    private fun matches(s: Service, cityIds: List<String>?) =
        cityIds.isNullOrEmpty() || summary(s.providerId).cityIds.any { it in cityIds }

    override suspend fun home(cityIds: List<String>?, maxPrice: Double?) = mutex.withLock {
        val visible = services.filter { matches(it, cityIds) }
        HomeContent(
            banners = listOf(
                HomeBanner(
                    id = "mock-banner", titleAr = "عروض موسم الأعراس", titleEn = "Wedding season offers",
                    subtitleAr = "خصومات من مقدّمات خدمة مختارات", subtitleEn = "Discounts from selected providers",
                    ctaAr = "تصفّحي المكياج", ctaEn = "Browse makeup", linkUrl = "https://munyati.co/c/makeup",
                ),
            ),
            categories = categories.map { c -> c.copy(serviceCount = visible.count { it.categoryId == c.id }) },
            featured = visible.filter { maxPrice == null || it.price <= maxPrice }.map(::card),
            newest = visible.reversed().map(::card),
        )
    }

    override suspend fun search(filter: ServiceFilter, cityIds: List<String>?, maxPrice: Double?, offset: Int) = mutex.withLock {
        if (offset != 0) return@withLock emptyList()
        var list = services.filter { s ->
            matches(s, cityIds) &&
                (filter.categoryId == null || s.categoryId == filter.categoryId) &&
                (filter.query.isEmpty() || filter.query in s.title) &&
                (!filter.withinBudget || maxPrice == null || s.price <= maxPrice)
        }
        list = when (filter.sort) {
            ServiceFilter.Sort.PriceAsc -> list.sortedBy { it.price }
            ServiceFilter.Sort.PriceDesc -> list.sortedByDescending { it.price }
            ServiceFilter.Sort.Newest -> list.reversed()
            ServiceFilter.Sort.Recommended -> list
        }
        list.map(::card).filter { !filter.femaleOnly || it.femaleStaffOnly }
    }

    override suspend fun service(id: String) = mutex.withLock {
        val s = services.firstOrNull { it.id == id } ?: return@withLock null
        ServiceDetail(
            card = card(s),
            description = s.description,
            durationMinutes = s.durationMinutes,
            atCustomerLocation = s.atCustomerLocation,
            imageUrls = (1..3).map { "https://picsum.photos/seed/$id-$it/1200/900" },
            provider = summary(s.providerId),
            store = null,
            moreFromProvider = services.filter { it.providerId == s.providerId && it.id != id }.map(::card),
            // A public sample clip, so the gallery and viewer can be tried without a backend.
            videos = listOf(VideoAsset("https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4",
                "https://picsum.photos/seed/$id-video/1200/900", 10)),
        )
    }

    override suspend fun provider(id: String) = mutex.withLock {
        ProviderProfile(
            summary = summary(id),
            bio = "نسعد بخدمتك في أجمل أيامك.",
            coverUrl = null, address = null, instagram = null,
            services = services.filter { it.providerId == id }.map(::card),
            stores = emptyList(),
        )
    }

    override suspend fun store(id: String): StoreDetail? = null

    override suspend fun mapPins(minLat: Double, minLng: Double, maxLat: Double, maxLng: Double, cityIds: List<String>?, categoryId: String?) =
        providers.map { MapPin("provider", it.summary.id, it.summary.name, it.lat, it.lng) }

    override suspend fun toggleFavorite(serviceId: String) = mutex.withLock {
        if (!favoriteIds.remove(serviceId)) favoriteIds.add(serviceId)
        serviceId in favoriteIds
    }

    override suspend fun favorites() = mutex.withLock { services.filter { it.id in favoriteIds }.map(::card) }

    override suspend fun budget() = mutex.withLock { storedBudget }

    override suspend fun setBudget(total: Double, weddingDate: String?) = mutex.withLock {
        storedBrideDetails = storedBrideDetails?.copy(weddingDate = weddingDate)
        Budget(total, 0.0, total, weddingDate).also { storedBudget = it }
    }

    override suspend fun brideDetails() = mutex.withLock {
        storedBrideDetails ?: storedBudget?.weddingDate?.let { BrideDetails(weddingDate = it) }
    }

    override suspend fun setBrideDetails(details: BrideDetails) = mutex.withLock {
        val names = mapOf("dammam" to ("الدمام" to "Dammam"), "khobar" to ("الخبر" to "Khobar"), "qatif" to ("القطيف" to "Qatif"))
        val saved = details.copy(cityNameAr = details.cityId?.let { names[it]?.first }, cityNameEn = details.cityId?.let { names[it]?.second })
        storedBrideDetails = saved
        // One wedding date, like the server.
        storedBudget = storedBudget?.copy(weddingDate = details.weddingDate)
        saved
    }

    override suspend fun preparations() = mutex.withLock { orderedPreparations() }

    override suspend fun savePreparation(id: String?, title: String, note: String?) = mutex.withLock {
        val cleanNote = note?.trim()?.ifEmpty { null }
        val index = storedPreparations.indexOfFirst { it.id == id }
        if (id != null && index >= 0) {
            storedPreparations[index] = storedPreparations[index].copy(title = title, note = cleanNote)
        } else {
            storedPreparations += Preparation(java.util.UUID.randomUUID().toString(), title, cleanNote)
        }
        orderedPreparations()
    }

    override suspend fun setPreparationDone(id: String, done: Boolean) = mutex.withLock {
        val index = storedPreparations.indexOfFirst { it.id == id }
        if (index >= 0) {
            val item = storedPreparations.removeAt(index).copy(isDone = done)
            // Like the server: open items keep their order, the latest done one comes first.
            if (done) storedPreparations.add(0, item) else storedPreparations += item
        }
        orderedPreparations()
    }

    override suspend fun deletePreparation(id: String) = mutex.withLock {
        storedPreparations.removeAll { it.id == id }
        orderedPreparations()
    }

    private fun orderedPreparations() = storedPreparations.filter { !it.isDone } + storedPreparations.filter { it.isDone }
}
