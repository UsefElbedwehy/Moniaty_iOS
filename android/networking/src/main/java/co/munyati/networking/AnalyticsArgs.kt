package co.munyati.networking

import kotlinx.serialization.Serializable

/** Arguments for the `record_analytics_event` RPC (curated business events, `docs/PLAN.md` §5). */
@Serializable
data class RecordAnalyticsEventArgs(
    val pEventType: String,
    val pEntityId: String?,
    val pContextId: String? = null,
    val pProps: Map<String, String>? = null,
)

/** Arguments for the `log_client_error` RPC (the app-side half of the error log). */
@Serializable
data class LogClientErrorArgs(
    val pCode: String,
    val pMessage: String,
    val pScreen: String?,
    val pAppVersion: String?,
    val pOsVersion: String?,
)
