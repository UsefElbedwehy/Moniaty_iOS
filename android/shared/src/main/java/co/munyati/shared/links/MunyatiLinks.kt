package co.munyati.shared.links

import android.content.Context
import android.content.Intent

/** Shareable universal links (the same as iOS `MunyatiLinks`; parsed by the App's `DeepLink`). */
object MunyatiLinks {
    const val BASE = "https://munyati.co"
    fun provider(id: String) = "$BASE/p/$id"
    fun service(id: String) = "$BASE/s/$id"
    fun store(id: String) = "$BASE/store/$id"
    fun category(id: String) = "$BASE/c/$id"
}

/** Opens the system share sheet for [url] (the Android twin of SwiftUI's `ShareLink`). */
fun Context.shareLink(url: String, subject: String? = null) {
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, url)
        subject?.let { putExtra(Intent.EXTRA_SUBJECT, it) }
    }
    startActivity(Intent.createChooser(send, null))
}
