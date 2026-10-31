package co.munyati.core.configuration

/**
 * Whom a customer browses for, and whom a provider serves: the bride herself (e.g. bridal
 * makeup), the wedding guests «المعازيم» (e.g. guests' makeup, food), or both. Customers see only
 * providers that serve their audience; [Both] on either side matches everyone. Stored as
 * `profiles.audience` / `providers.audience`.
 */
enum class Audience(val rawValue: String) {
    Bride("bride"),
    Guests("guests"),
    Both("both");

    companion object {
        fun from(raw: String?): Audience? = entries.firstOrNull { it.rawValue == raw }
    }
}
