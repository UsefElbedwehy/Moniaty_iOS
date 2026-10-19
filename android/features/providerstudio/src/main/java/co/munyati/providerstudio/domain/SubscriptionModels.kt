package co.munyati.providerstudio.domain

import co.munyati.core.dates.PostgresDate
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.Locale

private val isEnglish get() = Locale.getDefault().language == "en"

internal fun studioLocalized(ar: String, en: String): String =
    if (isEnglish) en.ifEmpty { ar } else ar.ifEmpty { en }

/** A plan from `subscription_plans` (Normal / Plus / Diamond, dashboard-editable). */
@Serializable
data class SubscriptionPlan(
    val id: String,
    val nameAr: String,
    val nameEn: String,
    val descriptionAr: String? = null,
    val descriptionEn: String? = null,
    val featuresAr: List<String> = emptyList(),
    val featuresEn: List<String> = emptyList(),
    val priceSar: Double,
    val periodMonths: Int = 1,
    val maxServices: Int,
    val maxStores: Int,
    val maxPhotos: Int,
    val isFeatured: Boolean = false,
    val insightsLevel: String = "basic",
    val rank: Int = 0,
    val isRecommended: Boolean = false,
) {
    val name: String get() = studioLocalized(nameAr, nameEn)
    val details: String? get() = studioLocalized(descriptionAr.orEmpty(), descriptionEn.orEmpty()).trim().ifEmpty { null }
    val features: List<String> get() = if (isEnglish) featuresEn else featuresAr
}

/** What the provider is entitled to now. The app reads this, never how it was paid (decision #2). */
@Serializable
data class Entitlement(
    val state: State,
    val planId: String? = null,
    val source: String? = null,
    @SerialName("trial_ends_at") val trialEndsAtRaw: String? = null,
    @SerialName("period_ends_at") val periodEndsAtRaw: String? = null,
    /** End of everything already paid for, including a plan queued after the current one. */
    @SerialName("paid_until") val paidUntilRaw: String? = null,
    val nextPlanId: String? = null,
    @SerialName("next_starts_at") val nextStartsAtRaw: String? = null,
    val isListed: Boolean = false,
) {
    @Serializable
    enum class State {
        @SerialName("pending") Pending,
        @SerialName("trial") Trial,
        @SerialName("subscribed") Subscribed,
        @SerialName("expired") Expired,
    }

    val trialEndsAt: Instant? get() = PostgresDate.parse(trialEndsAtRaw)
    val periodEndsAt: Instant? get() = PostgresDate.parse(periodEndsAtRaw)
    val paidUntil: Instant? get() = PostgresDate.parse(paidUntilRaw)
    val nextStartsAt: Instant? get() = PostgresDate.parse(nextStartsAtRaw)

    /** When the listing stops unless the provider pays: the trial end, or the paid time's end. */
    val listedUntil: Instant?
        get() = when (state) {
            State.Trial -> paidUntil ?: trialEndsAt
            State.Subscribed -> paidUntil ?: periodEndsAt
            State.Pending, State.Expired -> null
        }

    fun daysLeft(now: Instant = Instant.now()): Int? {
        val end = listedUntil ?: return null
        return ChronoUnit.DAYS.between(now, end).toInt().coerceAtLeast(0)
    }
}

@Serializable
data class PlanLimits(val planId: String? = null, val maxServices: Int, val maxStores: Int, val maxPhotos: Int? = null)

@Serializable
enum class PlanPaymentStatus {
    @SerialName("initiated") Initiated,
    @SerialName("captured") Captured,
    @SerialName("failed") Failed,
    @SerialName("review") Review;

    val rawValue: String get() = name.lowercase()

    companion object {
        fun from(raw: String?) = entries.firstOrNull { it.rawValue == raw }
    }
}

@Serializable
data class PlanPayment(
    val id: String,
    val planId: String,
    val amount: Double,
    val currency: String = "SAR",
    val status: PlanPaymentStatus,
    @SerialName("created_at") val createdAtRaw: String,
    @SerialName("captured_at") val capturedAtRaw: String? = null,
) {
    val createdAt: Instant? get() = PostgresDate.parse(createdAtRaw)
}

/** `get_my_subscription`: state, limits, usage, the plans to choose from and recent payments. */
@Serializable
data class SubscriptionOverview(
    val entitlement: Entitlement,
    val limits: PlanLimits,
    val usage: Usage,
    val plans: List<SubscriptionPlan> = emptyList(),
    val payments: List<PlanPayment> = emptyList(),
) {
    @Serializable
    data class Usage(val activeServices: Int, val activeStores: Int)

    val currentPlan: SubscriptionPlan? get() = plans.firstOrNull { it.id == entitlement.planId }
    val nextPlan: SubscriptionPlan? get() = plans.firstOrNull { it.id == entitlement.nextPlanId }
    fun plan(id: String?): SubscriptionPlan? = plans.firstOrNull { it.id == id }
}

/** `get_my_insights`. Basic plans get the first numbers; the rest are null. */
@Serializable
data class Insights(
    val level: String,
    val days: Int,
    val profileViews: Int,
    val serviceViews: Int,
    val requests: Int,
    val contactTaps: Int? = null,
    val favorites: Int? = null,
    val approved: Int? = null,
    val completed: Int? = null,
    val revenue: Double? = null,
    val services: List<ServiceRow>? = null,
) {
    @Serializable
    data class ServiceRow(val id: String, val title: String, val views: Int, val requests: Int)

    val isFull: Boolean get() = level != "basic"
}

/** Starting a plan payment. */
sealed interface CheckoutStart {
    /** Open Tap's hosted page; it returns to `munyati://pay-return`. */
    data class Open(val paymentId: String, val url: String) : CheckoutStart
    /** Nothing to open (offline mock): check the status right away. */
    data class Completed(val paymentId: String) : CheckoutStart
    /** Refused by the server, e.g. "not_approved", "too_many_attempts". */
    data class Refused(val code: String) : CheckoutStart
}

/** Plan payments, implemented by the App (Tap edge function, or a mock). */
interface PlanCheckout {
    suspend fun start(planId: String): CheckoutStart
    suspend fun status(paymentId: String): PlanPaymentStatus
}
