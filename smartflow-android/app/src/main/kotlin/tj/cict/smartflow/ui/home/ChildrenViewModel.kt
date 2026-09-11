package tj.cict.smartflow.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import java.time.LocalDate
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.session.SessionStore
import tj.cict.smartflow.data.repo.ParentRepository
import tj.cict.smartflow.domain.AttendanceDay
import tj.cict.smartflow.domain.AttendanceStatus
import tj.cict.smartflow.domain.Child

data class ChildToday(val child: Child, val today: AttendanceDay?) {
    val status: AttendanceStatus get() = today?.status ?: AttendanceStatus.UNKNOWN
}

data class ChildrenUi(
    val loading: Boolean = true,
    val refreshing: Boolean = false,
    val children: List<ChildToday> = emptyList(),
    val selectedId: Int? = null,
    val error: ApiError? = null,
) {
    val selected: Child? get() = children.firstOrNull { it.child.id == selectedId }?.child ?: children.firstOrNull()?.child
    fun child(id: Int): Child? = children.firstOrNull { it.child.id == id }?.child
}

/**
 * The children and which one is in focus. Shared by every tab, so switching
 * the child on the diary keeps the rating on the same child.
 */
class ChildrenViewModel(private val repo: ParentRepository, private val session: SessionStore) : ViewModel() {
    private val _ui = MutableStateFlow(ChildrenUi())
    val ui: StateFlow<ChildrenUi> = _ui.asStateFlow()

    init {
        viewModelScope.launch {
            _ui.update { it.copy(selectedId = session.selectedChildId.first()) }
            load()
        }
    }

    fun refresh() {
        if (_ui.value.refreshing) return
        _ui.update { it.copy(refreshing = true) }
        viewModelScope.launch { load() }
    }

    fun select(child: Child) {
        _ui.update { it.copy(selectedId = child.id) }
        viewModelScope.launch { session.rememberChild(child.id) }
    }

    private suspend fun load() {
        when (val r = repo.children()) {
            is ApiResult.Err -> _ui.update { it.copy(loading = false, refreshing = false, error = r.error) }
            is ApiResult.Ok -> {
                val children = r.value
                // Today's row for each child, fetched together. One child or
                // four, the header waits for the slowest call, not the sum.
                val today = LocalDate.now()
                val rows = children.map { child ->
                    viewModelScope.async {
                        val days = (repo.attendance(child.id) as? ApiResult.Ok)?.value.orEmpty()
                        ChildToday(child, days.firstOrNull { it.date == today })
                    }
                }.awaitAll()
                _ui.update { state ->
                    val keep = state.selectedId?.takeIf { id -> rows.any { it.child.id == id } }
                    state.copy(loading = false, refreshing = false, error = null, children = rows, selectedId = keep ?: rows.firstOrNull()?.child?.id)
                }
            }
        }
    }
}
