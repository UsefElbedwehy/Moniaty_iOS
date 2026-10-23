package co.munyati.app.backend

import co.munyati.core.error.AppError
import co.munyati.networking.ApiClient
import co.munyati.networking.ApiEndpoint
import co.munyati.networking.decode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException

/** A CMS page the admin dashboard manages (terms, privacy, about, help). */
@Serializable
data class CmsPage(val slug: String, val title: String, val bodyMarkdown: String)

/** Read-only CMS pages; `null` when the slug doesn't exist or isn't published. */
interface CmsPageRepository {
    suspend fun fetchPage(slug: String, locale: String): CmsPage?
}

class SupabaseCmsPageRepository(private val client: ApiClient) : CmsPageRepository {
    override suspend fun fetchPage(slug: String, locale: String): CmsPage? {
        val raw = client.sendRaw(ApiEndpoint.Cms.getPage, client.json.encodeToString(PageArgs.serializer(), PageArgs(slug, locale)))
        if (raw.isBlank() || raw.trim() == "null") return null
        return client.decode(CmsPage.serializer(), raw)
    }
}

@Serializable private data class PageArgs(val pSlug: String, val pLocale: String)

/** In-memory pages for offline runs, the same placeholder copy as iOS. */
class MockCmsPageRepository : CmsPageRepository {
    override suspend fun fetchPage(slug: String, locale: String): CmsPage? {
        val ar = locale == "ar"
        val title = when (slug) {
            "help" -> if (ar) "المساعدة" else "Help"
            "terms" -> if (ar) "الشروط والأحكام" else "Terms of Service"
            "privacy" -> if (ar) "سياسة الخصوصية" else "Privacy Policy"
            "about" -> if (ar) "عن منيتي" else "About Munyati"
            else -> return null
        }
        val body = if (ar) "هذا محتوى تجريبي — النص الحقيقي يأتي من محرر الصفحات في لوحة التحكم."
        else "This is mock content — the real copy comes from the admin dashboard's Pages editor."
        return CmsPage(slug, title, body)
    }
}

/**
 * In-app account deletion through the `delete-account` edge function (App Store 5.1.1(v), and
 * Google Play's account deletion policy).
 */
class AccountDeleter(
    private val baseUrl: String,
    private val anonKey: String,
    private val accessToken: suspend () -> String?,
    private val http: OkHttpClient = OkHttpClient(),
) {
    suspend fun delete() {
        val token = accessToken() ?: throw AppError.Authentication(AppError.AuthFailureReason.NotAuthenticated)
        val request = Request.Builder()
            .url("${baseUrl.trimEnd('/')}/functions/v1/delete-account")
            .header("apikey", anonKey)
            .header("Authorization", "Bearer $token")
            .post("{}".toRequestBody("application/json".toMediaType()))
            .build()
        val code = withContext(Dispatchers.IO) {
            try {
                http.newCall(request).execute().use { it.code }
            } catch (e: IOException) {
                throw AppError.Network(AppError.NetworkFailureReason.NoConnection)
            }
        }
        if (code !in 200..299) throw AppError.Server(code, "Account deletion failed.")
    }
}
