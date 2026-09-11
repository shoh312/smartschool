package tj.cict.smartflow.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.core.util.toUiState

/**
 * Most detail pages are "one child, one list". This is that, once: a
 * subclass supplies the call, the screen gets a [UiState] to draw.
 */
abstract class ChildDataViewModel<T> : ViewModel() {
    private val _state = MutableStateFlow<UiState<T>>(UiState.Loading)
    val state: StateFlow<UiState<T>> = _state.asStateFlow()
    private var loadedFor: Int? = null

    protected abstract suspend fun fetch(childId: Int): ApiResult<T>

    /** Loads once per child; a different child replaces the data. */
    fun load(childId: Int, force: Boolean = false) {
        if (!force && loadedFor == childId && _state.value !is UiState.Failed) return
        loadedFor = childId
        _state.value = UiState.Loading
        viewModelScope.launch { _state.value = fetch(childId).toUiState() }
    }
}

/** Header plus a body that already knows how to draw loading and failure. */
@Composable
fun <T> DetailScaffold(
    title: String,
    subtitle: String?,
    state: UiState<T>,
    onBack: (() -> Unit)?,
    onRetry: () -> Unit,
    headerTrailing: (@Composable () -> Unit)? = null,
    belowHeader: (@Composable () -> Unit)? = null,
    content: @Composable (T) -> Unit,
) {
    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(title, subtitle = subtitle, onBack = onBack, trailing = headerTrailing)
            belowHeader?.invoke()
            when (state) {
                UiState.Loading -> SkeletonList()
                is UiState.Failed -> ErrorState(state.error.message(), onRetry)
                is UiState.Ready -> content(state.data)
            }
        }
    }
}
