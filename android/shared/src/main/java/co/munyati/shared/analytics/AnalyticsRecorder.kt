package co.munyati.shared.analytics

import androidx.compose.runtime.staticCompositionLocalOf

/**
 * The curated business events the admin dashboard and the provider Insights screen report on
 * (`docs/PLAN.md` §5). Raw values are the Postgres `analytics_event_type` labels: keep them in
 * step with the enum in `supabase/migrations/` and the iOS `AnalyticsEvent`.
 */
enum class AnalyticsEvent(val rawValue: String) {
    AppOpen("app_open"),
    RoleSelected("role_selected"),
    SignUpCompleted("sign_up_completed"),
    CategoryOpen("category_open"),
    ProviderView("provider_view"),
    ServiceView("service_view"),
    StoreView("store_view"),
    Search("search"),
    CityFilterChanged("city_filter_changed"),
    BudgetSet("budget_set"),
    BannerClick("banner_click"),
    ShareTap("share_tap"),
    WhatsappTap("whatsapp_tap"),
    CallTap("call_tap"),
    BookingStarted("booking_started"),
    BookingSubmitted("booking_submitted"),
    PaywallView("paywall_view"),
    PlanPurchaseStarted("plan_purchase_started"),
    ReviewSubmitted("review_submitted"),
    ReportSubmitted("report_submitted"),
    UserBlocked("user_blocked"),
    SupportTicketCreated("support_ticket_created"),
}

/**
 * Fire-and-forget analytics, provided once by the composition root so a feature can record without
 * knowing about Firebase or the network; previews and tests record nothing.
 */
class AnalyticsRecorder(
    private val onEvent: (event: AnalyticsEvent, entityId: String?, context: String?, props: Map<String, String>) -> Unit,
    private val onScreen: (name: String) -> Unit,
    private val onError: (code: String, message: String, screen: String?) -> Unit,
) {
    operator fun invoke(
        event: AnalyticsEvent,
        entityId: String? = null,
        context: String? = null,
        props: Map<String, String> = emptyMap(),
    ) = onEvent(event, entityId, context, props)

    fun screen(name: String) = onScreen(name)

    fun error(code: String, message: String, screen: String? = null) = onError(code, message, screen)

    companion object {
        val disabled = AnalyticsRecorder({ _, _, _, _ -> }, {}, { _, _, _ -> })
    }
}

val LocalAnalytics = staticCompositionLocalOf { AnalyticsRecorder.disabled }
