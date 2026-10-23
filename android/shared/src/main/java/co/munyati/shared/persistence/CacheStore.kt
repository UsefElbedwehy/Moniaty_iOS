package co.munyati.shared.persistence

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Local cache abstraction. Features depend on this interface, never on a storage mechanism, so
 * JSON-on-disk can be swapped later without touching call sites.
 */
interface CacheStore<T> {
    suspend fun save(value: T)
    suspend fun load(): T?
    suspend fun clear()
}

/** JSON-on-disk [CacheStore], writing `<cacheDir>/Munyati/<key>.json`. */
class FileCacheStore<T>(
    context: Context,
    key: String,
    private val serializer: KSerializer<T>,
    private val json: Json = Json { ignoreUnknownKeys = true },
) : CacheStore<T> {
    private val file = File(File(context.cacheDir, "Munyati"), "$key.json")
    private val mutex = Mutex()

    override suspend fun save(value: T) = withContext(Dispatchers.IO) {
        mutex.withLock {
            file.parentFile?.mkdirs()
            file.writeText(json.encodeToString(serializer, value))
        }
    }

    override suspend fun load(): T? = withContext(Dispatchers.IO) {
        mutex.withLock {
            runCatching { json.decodeFromString(serializer, file.readText()) }.getOrNull()
        }
    }

    override suspend fun clear() = withContext(Dispatchers.IO) {
        mutex.withLock { file.delete(); Unit }
    }
}
