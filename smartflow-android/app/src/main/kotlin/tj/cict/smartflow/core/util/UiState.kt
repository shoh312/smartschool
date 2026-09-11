package tj.cict.smartflow.core.util

import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult

sealed interface UiState<out T> {
    data object Loading : UiState<Nothing>
    data class Ready<T>(val data: T) : UiState<T>
    data class Failed(val error: ApiError) : UiState<Nothing>
}

fun <T> ApiResult<T>.toUiState(): UiState<T> = when (this) {
    is ApiResult.Ok -> UiState.Ready(value)
    is ApiResult.Err -> UiState.Failed(error)
}

val <T> UiState<T>.dataOrNull: T? get() = (this as? UiState.Ready)?.data
