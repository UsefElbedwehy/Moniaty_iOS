package co.munyati.providerstudio.domain

import co.munyati.shared.media.VideoAsset
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** The provider's own business as returned by `get_my_business` (all statuses, incl. paused). */
@Serializable
data class MyBusiness(
    val id: String,
    val status: Status,
    val businessName: String? = null,
    val bio: String? = null,
    val logoUrl: String? = null,
    val coverUrl: String? = null,
    val address: String? = null,
    val cityId: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    val instagram: String? = null,
    val crNumber: String? = null,
    val freelanceDocNumber: String? = null,
    val isVerified: Boolean = false,
    val femaleStaffOnly: Boolean = false,
    val trialEndsAt: String? = null,
    val reviewNote: String? = null,
    val categoryIds: List<String> = emptyList(),
    val cityIds: List<String> = emptyList(),
    val limits: Limits,
    val services: List<MyService> = emptyList(),
    val stores: List<MyStore> = emptyList(),
) {
    @Serializable
    enum class Status {
        @SerialName("pending") Pending,
        @SerialName("approved") Approved,
        @SerialName("rejected") Rejected,
        @SerialName("suspended") Suspended,
    }

    @Serializable
    data class Limits(val maxServices: Int, val maxStores: Int, val maxPhotos: Int? = null)

    val activeServiceCount: Int get() = services.count { it.status == MyService.Status.Active }

    /** Profile essentials an admin needs before approving (and brides need to find them). */
    val setupSteps: List<SetupStep>
        get() = listOf(
            SetupStep(SetupStep.Key.Profile, !businessName.isNullOrEmpty() && logoUrl != null),
            SetupStep(SetupStep.Key.Coverage, categoryIds.isNotEmpty() && cityIds.isNotEmpty()),
            SetupStep(SetupStep.Key.Location, lat != null && lng != null),
            SetupStep(SetupStep.Key.Service, services.isNotEmpty()),
        )
}

data class SetupStep(val key: Key, val done: Boolean) {
    enum class Key { Profile, Coverage, Location, Service }
}

@Serializable
data class MyService(
    val id: String,
    val title: String,
    val description: String? = null,
    val categoryId: String,
    val price: Double,
    val durationMinutes: Int? = null,
    val femaleStaffOnly: Boolean = false,
    val atCustomerLocation: Boolean = false,
    val storeId: String? = null,
    val imageUrls: List<String> = emptyList(),
    val status: Status = Status.Active,
    /** Missing from backends older than the videos migration. */
    val videos: List<VideoAsset> = emptyList(),
) {
    @Serializable
    enum class Status {
        @SerialName("active") Active,
        @SerialName("paused") Paused,
    }
}

@Serializable
data class MyStore(
    val id: String,
    val name: String,
    val description: String? = null,
    val logoUrl: String? = null,
    val address: String? = null,
    val cityId: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    val instagram: String? = null,
    val isActive: Boolean = true,
)

/** Editable copy used by the business form. */
data class BusinessDraft(
    val businessName: String = "",
    val bio: String = "",
    val categoryIds: Set<String> = emptySet(),
    val cityIds: Set<String> = emptySet(),
    val address: String = "",
    val cityId: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    val instagram: String = "",
    val logoUrl: String? = null,
    val coverUrl: String? = null,
    val crNumber: String = "",
    val freelanceDocNumber: String = "",
    val femaleStaffOnly: Boolean = false,
) {
    constructor(b: MyBusiness) : this(
        businessName = b.businessName.orEmpty(),
        bio = b.bio.orEmpty(),
        categoryIds = b.categoryIds.toSet(),
        cityIds = b.cityIds.toSet(),
        address = b.address.orEmpty(),
        cityId = b.cityId,
        lat = b.lat,
        lng = b.lng,
        instagram = b.instagram.orEmpty(),
        logoUrl = b.logoUrl,
        coverUrl = b.coverUrl,
        crNumber = b.crNumber.orEmpty(),
        freelanceDocNumber = b.freelanceDocNumber.orEmpty(),
        femaleStaffOnly = b.femaleStaffOnly,
    )

    val isValid: Boolean get() = businessName.trim().length >= 2
}

/** Editable copy used by the service form. */
data class ServiceDraft(
    val id: String? = null,
    val title: String = "",
    val description: String = "",
    val categoryId: String? = null,
    val priceText: String = "",
    val durationMinutes: Int? = null,
    val femaleStaffOnly: Boolean = false,
    val atCustomerLocation: Boolean = false,
    val storeId: String? = null,
    val imageUrls: List<String> = emptyList(),
    val isActive: Boolean = true,
    val videos: List<VideoAsset> = emptyList(),
) {
    constructor(s: MyService) : this(
        id = s.id,
        title = s.title,
        description = s.description.orEmpty(),
        categoryId = s.categoryId,
        priceText = if (s.price % 1.0 == 0.0) s.price.toLong().toString() else s.price.toString(),
        durationMinutes = s.durationMinutes,
        femaleStaffOnly = s.femaleStaffOnly,
        atCustomerLocation = s.atCustomerLocation,
        storeId = s.storeId,
        imageUrls = s.imageUrls,
        isActive = s.status == MyService.Status.Active,
        videos = s.videos,
    )

    /** The price typed in Arabic or Latin digits ("٢٥٠٫٥" or "250.5"). */
    val price: Double?
        get() {
            val ascii = priceText.map { ch ->
                when (ch) {
                    in '٠'..'٩' -> '0' + (ch - '٠')
                    in '۰'..'۹' -> '0' + (ch - '۰')
                    '٫' -> '.'
                    else -> ch
                }
            }.filter { it.isDigit() || it == '.' }.joinToString("")
            return ascii.toDoubleOrNull()
        }

    val isValid: Boolean get() = title.trim().length >= 2 && categoryId != null && price != null
}

/** Editable copy used by the store form. */
data class StoreDraft(
    val id: String? = null,
    val name: String = "",
    val description: String = "",
    val address: String = "",
    val cityId: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    val instagram: String = "",
    val logoUrl: String? = null,
    val isActive: Boolean = true,
) {
    constructor(s: MyStore) : this(
        id = s.id, name = s.name, description = s.description.orEmpty(), address = s.address.orEmpty(),
        cityId = s.cityId, lat = s.lat, lng = s.lng, instagram = s.instagram.orEmpty(), logoUrl = s.logoUrl, isActive = s.isActive,
    )

    val isValid: Boolean get() = name.trim().length >= 2
}

/** Result of saving a service or store: the plan limit can refuse it (requirement 2). */
sealed interface SaveResult {
    data class Saved(val id: String) : SaveResult
    data class LimitReached(val max: Int) : SaveResult
    /** The backend refused the media (e.g. a video URL that isn't the provider's own upload). */
    data object InvalidMedia : SaveResult
}
