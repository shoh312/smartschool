package tj.cict.smartflow.ui.assignments

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonElement
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.toUiState
import tj.cict.smartflow.data.dto.AssignmentDetailDto
import tj.cict.smartflow.data.dto.AttemptResultDto
import tj.cict.smartflow.data.dto.BlockDto
import tj.cict.smartflow.data.repo.ParentRepository

sealed interface Phase {
    data object Overview : Phase
    data class Playing(val index: Int) : Phase
    data class Finished(val result: AttemptResultDto) : Phase
}

data class PlayerUi(
    val detail: UiState<AssignmentDetailDto> = UiState.Loading,
    val phase: Phase = Phase.Overview,
    /** block id -> the answer as sent. Seeded from what the server had saved. */
    val answers: Map<Int, JsonElement> = emptyMap(),
    /** block id -> right/wrong, practice mode only. */
    val feedback: Map<Int, Boolean> = emptyMap(),
    val busy: Boolean = false,
    val error: ApiError? = null,
) {
    val data: AssignmentDetailDto? get() = (detail as? UiState.Ready)?.data
    val blocks: List<BlockDto> get() = data?.blocks.orEmpty()
    val questions: List<BlockDto> get() = blocks.filter { it.blockType == "question" }
    val unanswered: Int get() = questions.count { it.id !in answers }
}

/**
 * One attempt at one assignment. Answers go to the server as they are
 * given, so a closed app costs nothing; submit only totals them up.
 */
class PlayerViewModel(private val repo: ParentRepository) : ViewModel() {
    private val _ui = MutableStateFlow(PlayerUi())
    val ui: StateFlow<PlayerUi> = _ui.asStateFlow()
    private var childId = 0
    private var assignmentId = 0

    fun load(child: Int, assignment: Int) {
        if (childId == child && assignmentId == assignment && _ui.value.detail is UiState.Ready) return
        childId = child
        assignmentId = assignment
        _ui.update { PlayerUi() }
        viewModelScope.launch { apply(repo.assignmentDetail(child, assignment)) }
    }

    private fun apply(result: ApiResult<AssignmentDetailDto>) {
        _ui.update { state ->
            val saved = (result as? ApiResult.Ok)?.value?.savedAnswers.orEmpty()
                .mapNotNull { (k, v) -> k.toIntOrNull()?.let { it to v } }.toMap()
            state.copy(detail = result.toUiState(), answers = if (saved.isNotEmpty()) saved else state.answers, busy = false)
        }
    }

    fun start() {
        if (_ui.value.busy) return
        _ui.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.startAttempt(childId, assignmentId)) {
                is ApiResult.Ok -> {
                    apply(r)
                    // Resume where they left off: the first block still unanswered.
                    val blocks = r.value.blocks
                    val answered = _ui.value.answers.keys
                    val first = blocks.indexOfFirst { it.blockType == "question" && it.id !in answered }.takeIf { it >= 0 } ?: 0
                    _ui.update { it.copy(phase = Phase.Playing(if (answered.isEmpty()) 0 else first)) }
                }
                is ApiResult.Err -> _ui.update { it.copy(busy = false, error = r.error) }
            }
        }
    }

    fun goTo(index: Int) {
        val n = _ui.value.blocks.size
        if (index in 0 until n) _ui.update { it.copy(phase = Phase.Playing(index)) }
    }

    fun answer(block: BlockDto, value: JsonElement) {
        val attempt = _ui.value.data?.attemptId ?: return
        _ui.update { it.copy(answers = it.answers + (block.id to value)) }
        viewModelScope.launch {
            when (val r = repo.answer(attempt, block.id, value)) {
                is ApiResult.Ok -> r.value.correct?.let { ok -> _ui.update { it.copy(feedback = it.feedback + (block.id to ok)) } }
                is ApiResult.Err -> _ui.update { it.copy(error = r.error) }
            }
        }
    }

    fun submit() {
        val attempt = _ui.value.data?.attemptId ?: return
        if (_ui.value.busy) return
        _ui.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.submit(attempt)) {
                is ApiResult.Ok -> {
                    _ui.update { it.copy(busy = false, phase = Phase.Finished(r.value)) }
                    // Refresh the summary underneath so "attempts left" and the score are current.
                    apply(repo.assignmentDetail(childId, assignmentId))
                }
                is ApiResult.Err -> _ui.update { it.copy(busy = false, error = r.error) }
            }
        }
    }

    fun backToOverview() {
        _ui.update { it.copy(phase = Phase.Overview, answers = emptyMap(), feedback = emptyMap()) }
        viewModelScope.launch { apply(repo.assignmentDetail(childId, assignmentId)) }
    }

    fun clearError() = _ui.update { it.copy(error = null) }
}
