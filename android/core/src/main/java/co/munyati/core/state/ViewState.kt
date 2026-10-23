package co.munyati.core.state

import co.munyati.core.error.AppError

/**
 * The single source of truth for what a screen renders. Every ViewModel exposes exactly one
 * `ViewState<T>` — never a cluster of booleans (`isLoading`, `hasError`, ...).
 */
sealed interface ViewState<out T> {
    data object Loading : ViewState<Nothing>
    data class Refreshing<T>(override val value: T) : ViewState<T>
    data class Loaded<T>(override val value: T) : ViewState<T>
    data object Empty : ViewState<Nothing>
    data class Error(override val error: AppError) : ViewState<Nothing>
    data object Offline : ViewState<Nothing>

    val value: T?
        get() = null

    val isLoading: Boolean get() = this is Loading

    val error: AppError? get() = null

    /** Maps the loaded/refreshing payload, preserving every other case as-is. */
    fun <R> map(transform: (T) -> R): ViewState<R> = when (this) {
        Loading -> Loading
        is Refreshing -> Refreshing(transform(value))
        is Loaded -> Loaded(transform(value))
        Empty -> Empty
        is Error -> this
        Offline -> Offline
    }
}
