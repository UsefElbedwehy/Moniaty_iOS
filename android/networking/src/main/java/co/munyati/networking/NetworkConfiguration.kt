package co.munyati.networking

/**
 * Where to send requests, which headers every request carries by default, and how long to wait.
 */
data class NetworkConfiguration(
    val baseUrl: String,
    val defaultHeaders: Map<String, String> = emptyMap(),
    val timeoutSeconds: Long = 30,
)
