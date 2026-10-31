package co.munyati.providerstudio.data

import co.munyati.catalog.data.MockCatalogRepository
import co.munyati.catalog.domain.City
import co.munyati.providerstudio.domain.BusinessDraft
import co.munyati.providerstudio.domain.CheckoutStart
import co.munyati.providerstudio.domain.Entitlement
import co.munyati.providerstudio.domain.Insights
import co.munyati.providerstudio.domain.MyBusiness
import co.munyati.providerstudio.domain.MyService
import co.munyati.providerstudio.domain.MyStore
import co.munyati.providerstudio.domain.PlanCheckout
import co.munyati.providerstudio.domain.PlanLimits
import co.munyati.providerstudio.domain.PlanPayment
import co.munyati.providerstudio.domain.PlanPaymentStatus
import co.munyati.providerstudio.domain.SaveResult
import co.munyati.providerstudio.domain.ServiceDraft
import co.munyati.providerstudio.domain.StoreDraft
import co.munyati.providerstudio.domain.SubscriptionOverview
import co.munyati.providerstudio.domain.SubscriptionPlan
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit
import java.util.UUID
import kotlin.random.Random

/**
 * In-memory studio for running without a backend, the same as iOS. Starts as a fresh, pending
 * provider; saving the business profile counts as the admin's approval, which starts the trial.
 */
class MockStudioRepository : StudioRepository {
    private val mutex = Mutex()
    private var draft = BusinessDraft()
    private val services = linkedMapOf<String, ServiceDraft>()
    private val stores = linkedMapOf<String, StoreDraft>()
    private var trialEndsAt: Instant? = null
    private var paidPlanId: String? = null
    private var paidUntil: Instant? = null
    private val payments = mutableListOf<PlanPayment>()

    private val plans = listOf(
        SubscriptionPlan("normal", "العادية", "Normal", featuresAr = listOf("خدمة واحدة", "٦ صور لكل خدمة", "ظهور عادي", "إحصائيات أساسية"),
            featuresEn = listOf("1 service", "6 photos per service", "Standard placement", "Basic insights"),
            priceSar = 99.0, maxServices = 1, maxStores = 0, maxPhotos = 6, insightsLevel = "basic", rank = 1),
        SubscriptionPlan("plus", "بلس", "Plus", featuresAr = listOf("٣ خدمات", "متجر واحد", "١٥ صورة لكل خدمة", "ظهور مُعزَّز", "إحصائيات كاملة"),
            featuresEn = listOf("3 services", "1 store", "15 photos per service", "Boosted placement", "Full insights"),
            priceSar = 249.0, maxServices = 3, maxStores = 1, maxPhotos = 15, insightsLevel = "full", rank = 2, isRecommended = true),
        SubscriptionPlan("diamond", "دايموند", "Diamond", featuresAr = listOf("١٠ خدمات", "٣ متاجر", "٣٠ صورة لكل خدمة", "أعلى الظهور وشارة مميّزة", "بنر شهري في الرئيسية"),
            featuresEn = listOf("10 services", "3 stores", "30 photos per service", "Top placement and a featured badge", "A monthly Home banner"),
            priceSar = 499.0, maxServices = 10, maxStores = 3, maxPhotos = 30, isFeatured = true, insightsLevel = "export", rank = 3),
    )

    private val currentPlan get() = plans.firstOrNull { it.id == (paidPlanId ?: "diamond") } ?: plans[2]

    override suspend fun business(): MyBusiness = mutex.withLock {
        MyBusiness(
            id = "mock-provider",
            status = if (trialEndsAt == null) MyBusiness.Status.Pending else MyBusiness.Status.Approved,
            businessName = draft.businessName, bio = draft.bio, address = draft.address, instagram = draft.instagram,
            crNumber = draft.crNumber, femaleStaffOnly = draft.femaleStaffOnly, audience = draft.audience.rawValue, logoUrl = draft.logoUrl, cityId = draft.cityId,
            lat = draft.lat, lng = draft.lng,
            categoryIds = draft.categoryIds.toList(), cityIds = draft.cityIds.toList(),
            limits = MyBusiness.Limits(currentPlan.maxServices, currentPlan.maxStores, currentPlan.maxPhotos),
            services = services.values.map {
                MyService(it.id!!, it.title, it.description, it.categoryId.orEmpty(), it.price ?: 0.0, it.durationMinutes,
                    it.femaleStaffOnly, it.atCustomerLocation, it.storeId, it.imageUrls,
                    if (it.isActive) MyService.Status.Active else MyService.Status.Paused, it.videos)
            },
            stores = stores.values.map { MyStore(it.id!!, it.name, it.description, it.logoUrl, it.address, it.cityId, it.lat, it.lng, it.instagram, it.isActive) },
        )
    }

    override suspend fun updateBusiness(draft: BusinessDraft) = mutex.withLock {
        this.draft = draft
        if (trialEndsAt == null) trialEndsAt = Instant.now().plus(60, ChronoUnit.DAYS)
    }

    override suspend fun saveService(draft: ServiceDraft): SaveResult = mutex.withLock {
        val id = draft.id ?: UUID.randomUUID().toString()
        val active = services.values.count { it.isActive && it.id != id }
        if (draft.isActive && active >= currentPlan.maxServices) return@withLock SaveResult.LimitReached(currentPlan.maxServices)
        services[id] = draft.copy(id = id)
        SaveResult.Saved(id)
    }

    override suspend fun deleteService(id: String) = mutex.withLock { services.remove(id); Unit }

    override suspend fun saveStore(draft: StoreDraft): SaveResult = mutex.withLock {
        if (draft.id == null && stores.size >= currentPlan.maxStores) return@withLock SaveResult.LimitReached(currentPlan.maxStores)
        val id = draft.id ?: UUID.randomUUID().toString()
        stores[id] = draft.copy(id = id)
        SaveResult.Saved(id)
    }

    override suspend fun deleteStore(id: String) = mutex.withLock { stores.remove(id); Unit }

    override suspend fun categories() = MockCatalogRepository().home(null, null).categories

    override suspend fun cities() = listOf(City("dammam", "الدمام", "Dammam"), City("khobar", "الخبر", "Khobar"), City("qatif", "القطيف", "Qatif"))

    override suspend fun subscription(): SubscriptionOverview = mutex.withLock {
        val now = Instant.now()
        val subscribed = paidUntil?.isAfter(now) == true
        val onTrial = trialEndsAt?.isAfter(now) == true
        val state = when {
            subscribed -> Entitlement.State.Subscribed
            trialEndsAt == null -> Entitlement.State.Pending
            onTrial -> Entitlement.State.Trial
            else -> Entitlement.State.Expired
        }
        SubscriptionOverview(
            entitlement = Entitlement(
                state = state, planId = currentPlan.id, isListed = subscribed || onTrial,
                trialEndsAtRaw = trialEndsAt?.toString(),
                periodEndsAtRaw = paidUntil?.takeIf { subscribed }?.toString(),
                paidUntilRaw = paidUntil?.takeIf { subscribed }?.toString(),
                source = if (subscribed) "tap" else null,
            ),
            limits = PlanLimits(currentPlan.id, currentPlan.maxServices, currentPlan.maxStores, currentPlan.maxPhotos),
            usage = SubscriptionOverview.Usage(services.values.count { it.isActive }, stores.values.count { it.isActive }),
            plans = plans,
            payments = payments.toList(),
        )
    }

    override suspend fun insights(days: Int): Insights = mutex.withLock {
        val full = currentPlan.insightsLevel != "basic"
        Insights(
            level = currentPlan.insightsLevel, days = days, profileViews = 230, serviceViews = 412, requests = 4,
            contactTaps = if (full) 37 else null, favorites = if (full) 18 else null, approved = if (full) 3 else null,
            completed = if (full) 2 else null, revenue = if (full) 5600.0 else null,
            services = if (full) services.values.map { Insights.ServiceRow(it.id!!, it.title, Random.nextInt(20, 200), Random.nextInt(0, 3)) } else null,
        )
    }

    /** What a captured Tap payment does on the server, simplified: one month of the plan. */
    internal suspend fun activate(planId: String): String = mutex.withLock {
        val id = UUID.randomUUID().toString()
        val start = maxOf(Instant.now(), paidUntil ?: Instant.now())
        paidPlanId = planId
        paidUntil = start.atZone(ZoneOffset.UTC).plusMonths(1).toInstant()
        val price = plans.firstOrNull { it.id == planId }?.priceSar ?: 0.0
        val now = Instant.now().toString()
        payments.add(0, PlanPayment(id, planId, price, "SAR", PlanPaymentStatus.Captured, now, now))
        // Above the new plan's limit: pause the extra services.
        services.entries.filter { it.value.isActive }.drop(currentPlan.maxServices).forEach { it.setValue(it.value.copy(isActive = false)) }
        id
    }
}

/** Offline stand-in for Tap: every payment succeeds immediately. */
class MockPlanCheckout(private val repository: MockStudioRepository) : PlanCheckout {
    override suspend fun start(planId: String) = CheckoutStart.Completed(repository.activate(planId))
    override suspend fun status(paymentId: String) = PlanPaymentStatus.Captured
}
