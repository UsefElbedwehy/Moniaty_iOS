package co.munyati.providerstudio.data

import co.munyati.shared.media.VideoAsset
import co.munyati.catalog.domain.CatalogCategory
import co.munyati.catalog.domain.City
import co.munyati.networking.ApiClient
import co.munyati.networking.ApiEndpoint
import co.munyati.networking.EmptyBody
import co.munyati.networking.decode
import co.munyati.networking.send
import co.munyati.providerstudio.domain.BusinessDraft
import co.munyati.providerstudio.domain.Insights
import co.munyati.providerstudio.domain.MyBusiness
import co.munyati.providerstudio.domain.SaveResult
import co.munyati.providerstudio.domain.ServiceDraft
import co.munyati.providerstudio.domain.StoreDraft
import co.munyati.providerstudio.domain.SubscriptionOverview
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject

interface StudioRepository {
    suspend fun business(): MyBusiness
    suspend fun updateBusiness(draft: BusinessDraft)
    suspend fun saveService(draft: ServiceDraft): SaveResult
    suspend fun deleteService(id: String)
    suspend fun saveStore(draft: StoreDraft): SaveResult
    suspend fun deleteStore(id: String)
    suspend fun categories(): List<CatalogCategory>
    suspend fun cities(): List<City>
    suspend fun subscription(): SubscriptionOverview
    suspend fun insights(days: Int): Insights
}

private fun String.nilIfBlank(): String? = trim().ifEmpty { null }

/** Supabase RPCs from `supabase/migrations/20261011000000_catalog.sql` and `..._subscriptions.sql`. */
class RemoteStudioRepository(private val client: ApiClient) : StudioRepository {
    override suspend fun business(): MyBusiness = client.send(ApiEndpoint.rpc("get_my_business"), EmptyBody())

    override suspend fun updateBusiness(draft: BusinessDraft) {
        val d = draft
        client.send<BusinessArgs, OkResult>(
            ApiEndpoint.rpc("update_my_business"),
            BusinessArgs(
                pBusinessName = d.businessName, pBio = d.bio.nilIfBlank(), pCategoryIds = d.categoryIds.toList(),
                pCityIds = d.cityIds.toList(), pAddress = d.address.nilIfBlank(), pCityId = d.cityId, pLat = d.lat, pLng = d.lng,
                pInstagram = d.instagram.nilIfBlank(), pLogoUrl = d.logoUrl, pCoverUrl = d.coverUrl,
                pCrNumber = d.crNumber.nilIfBlank(), pFreelanceDocNumber = d.freelanceDocNumber.nilIfBlank(),
                pFemaleStaffOnly = d.femaleStaffOnly,
            ),
        )
    }

    override suspend fun saveService(draft: ServiceDraft): SaveResult {
        val d = draft
        val result = sendWithId(
            "upsert_my_service", d.id, ServiceArgs.serializer(),
            ServiceArgs(
                pId = d.id, pTitle = d.title, pCategoryId = d.categoryId.orEmpty(), pPrice = d.price ?: 0.0,
                pDescription = d.description.nilIfBlank(), pDurationMinutes = d.durationMinutes,
                pFemaleStaffOnly = d.femaleStaffOnly, pAtCustomerLocation = d.atCustomerLocation, pStoreId = d.storeId,
                pImageUrls = d.imageUrls, pStatus = if (d.isActive) "active" else "paused",
                pVideos = d.videos,
            ),
        )
        return result.toDomain(result.maxServices)
    }

    override suspend fun deleteService(id: String) {
        client.send<IdArgs, OkResult>(ApiEndpoint.rpc("delete_my_service"), IdArgs(id))
    }

    override suspend fun saveStore(draft: StoreDraft): SaveResult {
        val d = draft
        val result = sendWithId(
            "upsert_my_store", d.id, StoreArgs.serializer(),
            StoreArgs(
                pId = d.id, pName = d.name, pDescription = d.description.nilIfBlank(), pAddress = d.address.nilIfBlank(),
                pCityId = d.cityId, pLat = d.lat, pLng = d.lng, pInstagram = d.instagram.nilIfBlank(),
                pLogoUrl = d.logoUrl, pIsActive = d.isActive,
            ),
        )
        return result.toDomain(result.maxStores)
    }

    override suspend fun deleteStore(id: String) {
        client.send<IdArgs, OkResult>(ApiEndpoint.rpc("delete_my_store"), IdArgs(id))
    }

    override suspend fun categories(): List<CatalogCategory> = client.send(ApiEndpoint.Catalog.categories, EmptyBody())

    override suspend fun cities(): List<City> = client.send(ApiEndpoint.Catalog.cities, EmptyBody())

    override suspend fun subscription(): SubscriptionOverview = client.send(ApiEndpoint.rpc("get_my_subscription"), EmptyBody())

    override suspend fun insights(days: Int): Insights = client.send(ApiEndpoint.rpc("get_my_insights"), DaysArgs(days))

    /**
     * `p_id` has no SQL default, so it must be sent even when null (a new row). The shared JSON
     * format omits nulls, so put it back explicitly.
     */
    private suspend fun <A> sendWithId(rpc: String, id: String?, serializer: KSerializer<A>, args: A): SaveDto {
        val encoded = client.json.encodeToJsonElement(serializer, args).jsonObject
        val body = if (id == null) JsonObject(encoded + ("p_id" to JsonNull)) else encoded
        val raw = client.sendRaw(ApiEndpoint.rpc(rpc), body.toString())
        return client.decode(SaveDto.serializer(), raw)
    }
}

@Serializable private data class IdArgs(val pId: String)
@Serializable private data class DaysArgs(val pDays: Int)
@Serializable private data class OkResult(val ok: Boolean? = null)

@Serializable
private data class SaveDto(
    val ok: Boolean,
    val id: String? = null,
    val error: String? = null,
    val maxServices: Int? = null,
    val maxStores: Int? = null,
) {
    fun toDomain(max: Int?): SaveResult = when {
        ok && id != null -> SaveResult.Saved(id)
        error == "invalid_video" -> SaveResult.InvalidMedia
        else -> SaveResult.LimitReached(max ?: 0)
    }
}

@Serializable
private data class BusinessArgs(
    val pBusinessName: String,
    val pBio: String?,
    val pCategoryIds: List<String>,
    val pCityIds: List<String>,
    val pAddress: String?,
    val pCityId: String?,
    val pLat: Double?,
    val pLng: Double?,
    val pInstagram: String?,
    val pLogoUrl: String?,
    val pCoverUrl: String?,
    val pCrNumber: String?,
    val pFreelanceDocNumber: String?,
    val pFemaleStaffOnly: Boolean,
)

@Serializable
private data class ServiceArgs(
    val pId: String?,
    val pTitle: String,
    val pCategoryId: String,
    val pPrice: Double,
    val pDescription: String?,
    val pDurationMinutes: Int?,
    val pFemaleStaffOnly: Boolean,
    val pAtCustomerLocation: Boolean,
    val pStoreId: String?,
    val pImageUrls: List<String>,
    val pStatus: String,
    val pVideos: List<VideoAsset>,
)

@Serializable
private data class StoreArgs(
    val pId: String?,
    val pName: String,
    val pDescription: String?,
    val pAddress: String?,
    val pCityId: String?,
    val pLat: Double?,
    val pLng: Double?,
    val pInstagram: String?,
    val pLogoUrl: String?,
    val pIsActive: Boolean,
)
