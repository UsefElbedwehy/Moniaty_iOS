package co.munyati.catalog.data

import co.munyati.shared.media.VideoAsset
import co.munyati.catalog.domain.Budget
import co.munyati.catalog.domain.HomeContent
import co.munyati.catalog.domain.MapPin
import co.munyati.catalog.domain.Preparation
import co.munyati.catalog.domain.ProviderProfile
import co.munyati.catalog.domain.ProviderSummary
import co.munyati.catalog.domain.ServiceCard
import co.munyati.catalog.domain.ServiceDetail
import co.munyati.catalog.domain.ServiceFilter
import co.munyati.catalog.domain.StoreDetail
import co.munyati.catalog.domain.StoreSummary
import co.munyati.networking.ApiClient
import co.munyati.networking.ApiEndpoint
import co.munyati.networking.EmptyBody
import co.munyati.networking.decode
import co.munyati.networking.send
import kotlinx.serialization.Serializable
import kotlinx.serialization.serializer

interface CatalogRepository {
    suspend fun home(cityIds: List<String>?, maxPrice: Double?): HomeContent
    suspend fun search(filter: ServiceFilter, cityIds: List<String>?, maxPrice: Double?, offset: Int): List<ServiceCard>
    suspend fun service(id: String): ServiceDetail?
    suspend fun provider(id: String): ProviderProfile?
    suspend fun store(id: String): StoreDetail?
    suspend fun mapPins(minLat: Double, minLng: Double, maxLat: Double, maxLng: Double, cityIds: List<String>?, categoryId: String?): List<MapPin>
    suspend fun toggleFavorite(serviceId: String): Boolean
    suspend fun favorites(): List<ServiceCard>
    suspend fun budget(): Budget?
    suspend fun setBudget(total: Double, weddingDate: String?): Budget?
    /** "My preparations": every call returns the whole list, in display order. */
    suspend fun preparations(): List<Preparation>
    suspend fun savePreparation(id: String?, title: String, note: String?): List<Preparation>
    suspend fun setPreparationDone(id: String, done: Boolean): List<Preparation>
    suspend fun deletePreparation(id: String): List<Preparation>
}

/** Page size of `search_services`, shared with the list's "load more" rule. */
const val SEARCH_PAGE_SIZE = 30

/** Supabase RPCs from `supabase/migrations/20261011000000_catalog.sql`. */
class RemoteCatalogRepository(private val client: ApiClient) : CatalogRepository {
    override suspend fun home(cityIds: List<String>?, maxPrice: Double?): HomeContent =
        client.send(ApiEndpoint.rpc("get_home"), HomeArgs(cityIds, maxPrice))

    override suspend fun search(filter: ServiceFilter, cityIds: List<String>?, maxPrice: Double?, offset: Int): List<ServiceCard> =
        client.send(
            ApiEndpoint.rpc("search_services"),
            SearchArgs(
                pQuery = filter.query.ifEmpty { null },
                pCategoryId = filter.categoryId,
                pCityIds = cityIds,
                pMaxPrice = if (filter.withinBudget) maxPrice else null,
                pFemaleOnly = filter.femaleOnly,
                pSort = filter.sort.rawValue,
                pLimit = SEARCH_PAGE_SIZE,
                pOffset = offset,
            ),
        )

    override suspend fun service(id: String): ServiceDetail? = flattened(ApiEndpoint.rpc("get_service"), id) { raw ->
        val card = decode(serializer<ServiceCard>(), raw)
        val extras = decode(ServiceExtras.serializer(), raw)
        ServiceDetail(card, extras.description, extras.durationMinutes, extras.atCustomerLocation, extras.imageUrls,
            extras.provider, extras.store, extras.moreFromProvider, extras.videos, extras.isOwn)
    }

    override suspend fun provider(id: String): ProviderProfile? = flattened(ApiEndpoint.rpc("get_provider"), id) { raw ->
        val summary = decode(serializer<ProviderSummary>(), raw)
        val extras = decode(ProviderExtras.serializer(), raw)
        ProviderProfile(summary, extras.bio, extras.coverUrl, extras.address, extras.instagram, extras.services, extras.stores)
    }

    override suspend fun store(id: String): StoreDetail? = flattened(ApiEndpoint.rpc("get_store"), id) { raw ->
        val summary = decode(serializer<StoreSummary>(), raw)
        val extras = decode(StoreExtras.serializer(), raw)
        StoreDetail(summary, extras.description, extras.instagram, extras.provider, extras.services)
    }

    override suspend fun mapPins(minLat: Double, minLng: Double, maxLat: Double, maxLng: Double, cityIds: List<String>?, categoryId: String?): List<MapPin> =
        client.send(ApiEndpoint.rpc("get_map_pins"), MapArgs(minLat, minLng, maxLat, maxLng, cityIds, categoryId))

    override suspend fun toggleFavorite(serviceId: String): Boolean =
        client.send<FavoriteArgs, FavoriteResult>(ApiEndpoint.rpc("toggle_favorite"), FavoriteArgs(serviceId)).isFavorite

    override suspend fun favorites(): List<ServiceCard> = client.send(ApiEndpoint.rpc("get_my_favorites"), EmptyBody())

    override suspend fun budget(): Budget? = client.send(ApiEndpoint.rpc("get_my_budget"), EmptyBody())

    override suspend fun setBudget(total: Double, weddingDate: String?): Budget? =
        client.send(ApiEndpoint.rpc("set_my_budget"), BudgetArgs(total, weddingDate))

    // "My preparations": `supabase/migrations/20261028000000_bride_preparations.sql`.

    override suspend fun preparations(): List<Preparation> = client.send(ApiEndpoint.rpc("get_my_preparations"), EmptyBody())

    override suspend fun savePreparation(id: String?, title: String, note: String?): List<Preparation> =
        client.send(ApiEndpoint.rpc("save_my_preparation"), PreparationArgs(id, title, note))

    override suspend fun setPreparationDone(id: String, done: Boolean): List<Preparation> =
        client.send(ApiEndpoint.rpc("set_my_preparation_done"), PreparationDoneArgs(id, done))

    override suspend fun deletePreparation(id: String): List<Preparation> =
        client.send(ApiEndpoint.rpc("delete_my_preparation"), IdArgs(id))

    /** Detail RPCs answer `null` when missing, or one object holding a summary plus extras. */
    private suspend fun <T> flattened(endpoint: ApiEndpoint, id: String, build: ApiClient.(String) -> T): T? {
        val raw = client.sendRaw(endpoint, client.json.encodeToString(IdArgs.serializer(), IdArgs(id)))
        if (raw.isBlank() || raw.trim() == "null") return null
        return client.build(raw)
    }
}

@Serializable private data class IdArgs(val pId: String)
@Serializable private data class HomeArgs(val pCityIds: List<String>?, val pMaxPrice: Double?)
@Serializable
private data class SearchArgs(
    val pQuery: String?,
    val pCategoryId: String?,
    val pCityIds: List<String>?,
    val pMaxPrice: Double?,
    val pFemaleOnly: Boolean,
    val pSort: String,
    val pLimit: Int,
    val pOffset: Int,
)
@Serializable
private data class MapArgs(val pMinLat: Double, val pMinLng: Double, val pMaxLat: Double, val pMaxLng: Double, val pCityIds: List<String>?, val pCategoryId: String?)
@Serializable private data class FavoriteArgs(val pServiceId: String)
@Serializable private data class FavoriteResult(val isFavorite: Boolean)
@Serializable private data class BudgetArgs(val pTotal: Double, val pWeddingDate: String?)
/** Without `pId` the RPC adds a new item. */
@Serializable private data class PreparationArgs(val pId: String?, val pTitle: String, val pNote: String?)
@Serializable private data class PreparationDoneArgs(val pId: String, val pDone: Boolean)

@Serializable
private data class ServiceExtras(
    val description: String? = null,
    val durationMinutes: Int? = null,
    val atCustomerLocation: Boolean = false,
    val imageUrls: List<String> = emptyList(),
    val provider: ProviderSummary,
    val store: StoreSummary? = null,
    val moreFromProvider: List<ServiceCard> = emptyList(),
    val videos: List<VideoAsset> = emptyList(),
    val isOwn: Boolean = false,
)

@Serializable
private data class ProviderExtras(
    val bio: String? = null,
    val coverUrl: String? = null,
    val address: String? = null,
    val instagram: String? = null,
    val services: List<ServiceCard> = emptyList(),
    val stores: List<StoreSummary> = emptyList(),
)

@Serializable
private data class StoreExtras(
    val description: String? = null,
    val instagram: String? = null,
    val provider: ProviderSummary,
    val services: List<ServiceCard> = emptyList(),
)
