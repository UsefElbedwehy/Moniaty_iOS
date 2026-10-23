package co.munyati.app.backend

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** A persisted Supabase session (the Android twin of iOS `KeychainSessionStore`). */
@Serializable
data class PersistedSession(
    val accessToken: String,
    val refreshToken: String?,
    val userId: String,
    val phone: String?,
    val expiresAtMillis: Long,
)

/** Keeps the session in encrypted preferences (Android Keystore-backed), surviving app restarts. */
class SessionStore(context: Context) {
    private val prefs: SharedPreferences = runCatching {
        EncryptedSharedPreferences.create(
            context,
            "munyati_session",
            MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }.getOrElse {
        // A corrupted keyset (e.g. restored from a backup on another device) can't be decrypted;
        // start clean rather than crash. The user signs in again.
        context.deleteSharedPreferences("munyati_session")
        context.getSharedPreferences("munyati_session_fallback", Context.MODE_PRIVATE)
    }

    fun load(): PersistedSession? =
        prefs.getString(KEY, null)?.let { runCatching { Json.decodeFromString<PersistedSession>(it) }.getOrNull() }

    fun save(session: PersistedSession) = prefs.edit().putString(KEY, Json.encodeToString(PersistedSession.serializer(), session)).apply()

    fun clear() = prefs.edit().remove(KEY).apply()

    private companion object {
        const val KEY = "session"
    }
}
