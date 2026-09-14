package tj.cict.smartflow.ui.teacher

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import java.io.File
import java.time.LocalDate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.toUiState
import tj.cict.smartflow.data.dto.AssignmentResultsDto
import tj.cict.smartflow.data.dto.CalendarEventDto
import tj.cict.smartflow.data.dto.ClassAssignmentDto
import tj.cict.smartflow.data.dto.GradeDto
import tj.cict.smartflow.data.dto.AbsenceDto
import tj.cict.smartflow.data.dto.MaterialSummaryDto
import tj.cict.smartflow.data.dto.ScanRowDto
import tj.cict.smartflow.data.dto.SchoolAnnouncementDto
import tj.cict.smartflow.data.dto.StudentDto
import tj.cict.smartflow.data.dto.TeacherAssignmentDto
import tj.cict.smartflow.data.dto.TeacherDiaryEntryDto
import tj.cict.smartflow.data.repo.TeacherRepository

// ------------------------------------------------------------- classes

/** The teacher's (class, subject) list. Shared by home, journal and diary. */
class TeacherClassesViewModel(private val repo: TeacherRepository) : ViewModel() {
    private val _state = MutableStateFlow<UiState<List<ClassAssignmentDto>>>(UiState.Loading)
    val state: StateFlow<UiState<List<ClassAssignmentDto>>> = _state.asStateFlow()
    private val _refreshing = MutableStateFlow(false)
    val refreshing: StateFlow<Boolean> = _refreshing.asStateFlow()

    init { load() }

    fun load(force: Boolean = false) {
        if (force) _refreshing.value = true else if (_state.value is UiState.Ready) return
        viewModelScope.launch {
            _state.value = repo.myClasses().toUiState()
            _refreshing.value = false
        }
    }
}

// ------------------------------------------------------------- journal

data class JournalRow(val student: StudentDto, val grades: List<GradeDto>, val absentToday: Boolean) {
    val today: GradeDto? get() = grades.firstOrNull { it.date == LocalDate.now() }
    val average: Double? get() = grades.takeIf { it.isNotEmpty() }?.map { it.value }?.average()
}

data class JournalUi(
    val rows: UiState<List<JournalRow>> = UiState.Loading,
    val absences: List<AbsenceDto> = emptyList(),
    val saving: Boolean = false,
    val error: ApiError? = null,
    val toast: Int? = null,
)

class ClassJournalViewModel(private val repo: TeacherRepository) : ViewModel() {
    private val _ui = MutableStateFlow(JournalUi())
    val ui: StateFlow<JournalUi> = _ui.asStateFlow()
    private var classId = 0
    private var subject = ""

    fun open(classId: Int, subject: String) {
        if (this.classId == classId && this.subject == subject && _ui.value.rows is UiState.Ready) return
        this.classId = classId; this.subject = subject
        load()
    }

    fun load() {
        _ui.update { it.copy(rows = UiState.Loading) }
        viewModelScope.launch {
            val roster = viewModelScope.async { repo.roster(classId) }
            val grades = viewModelScope.async { repo.grades(classId, subject) }
            val absences = viewModelScope.async { repo.absences(classId, subject) }
            val r = roster.await(); val g = grades.await(); val a = absences.await()
            if (r is ApiResult.Err) { _ui.update { it.copy(rows = UiState.Failed(r.error)) }; return@launch }
            val byStudent = (g as? ApiResult.Ok)?.value.orEmpty().groupBy { it.studentId }
            val absentToday = (a as? ApiResult.Ok)?.value.orEmpty().filter { it.date == LocalDate.now() }.map { it.studentId }.toSet()
            val rows = (r as ApiResult.Ok).value.map { s ->
                JournalRow(s, byStudent[s.id].orEmpty().sortedByDescending { it.date }, s.id in absentToday)
            }
            _ui.update { it.copy(rows = UiState.Ready(rows), absences = (a as? ApiResult.Ok)?.value.orEmpty()) }
        }
    }

    fun give(student: StudentDto, value: Int, comment: String?, existing: GradeDto?) {
        if (_ui.value.saving) return
        _ui.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            val r = if (existing != null) repo.updateGrade(existing.id, value, comment ?: "") else repo.addGrade(student.id, classId, subject, value, comment)
            when (r) {
                is ApiResult.Ok -> { _ui.update { it.copy(saving = false, toast = tj.cict.smartflow.R.string.grade_saved) }; load() }
                is ApiResult.Err -> _ui.update { it.copy(saving = false, error = r.error) }
            }
        }
    }

    fun delete(grade: GradeDto) {
        viewModelScope.launch {
            when (val r = repo.deleteGrade(grade.id)) {
                is ApiResult.Ok -> load()
                is ApiResult.Err -> _ui.update { it.copy(error = r.error) }
            }
        }
    }

    fun clearToast() = _ui.update { it.copy(toast = null, error = null) }
}

// --------------------------------------------------------------- diary

data class TeacherDiaryUi(
    val classId: Int? = null,
    val date: LocalDate = LocalDate.now(),
    val entries: UiState<List<TeacherDiaryEntryDto>> = UiState.Loading,
    val saving: Boolean = false,
    val error: ApiError? = null,
)

class TeacherDiaryViewModel(private val repo: TeacherRepository) : ViewModel() {
    private val _ui = MutableStateFlow(TeacherDiaryUi())
    val ui: StateFlow<TeacherDiaryUi> = _ui.asStateFlow()

    fun openClass(classId: Int) {
        if (_ui.value.classId == classId) return
        _ui.update { it.copy(classId = classId) }
        load()
    }

    fun pick(date: LocalDate) {
        if (_ui.value.date == date) return
        _ui.update { it.copy(date = date) }
        load()
    }

    fun shiftWeek(delta: Long) = pick(_ui.value.date.plusWeeks(delta))

    fun load() {
        val id = _ui.value.classId ?: return
        val date = _ui.value.date
        _ui.update { it.copy(entries = UiState.Loading) }
        viewModelScope.launch {
            val r = repo.diary(id, date).toUiState()
            if (_ui.value.date == date && _ui.value.classId == id) _ui.update { it.copy(entries = r) }
        }
    }

    fun save(lessonId: Int, homework: String, comment: String, onDone: () -> Unit) {
        if (_ui.value.saving) return
        _ui.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.updateDiary(lessonId, _ui.value.date, homework, comment)) {
                is ApiResult.Ok -> { _ui.update { it.copy(saving = false) }; load(); onDone() }
                is ApiResult.Err -> _ui.update { it.copy(saving = false, error = r.error) }
            }
        }
    }

    fun clearError() = _ui.update { it.copy(error = null) }
}

// ---------------------------------------------------------------- scan

data class ScanRow(val raw: ScanRowDto, val grade: Int?, val absent: Boolean, val include: Boolean)

data class ScanUi(
    val phase: Phase = Phase.Idle,
    val rows: List<ScanRow> = emptyList(),
    val error: ApiError? = null,
    val saved: Int? = null,
) {
    enum class Phase { Idle, Reading, Review, Saving }
    val toSave: List<ScanRow> get() = rows.filter { it.include && !it.absent && it.grade != null && it.raw.studentId != null }
}

class ScanJournalViewModel(private val repo: TeacherRepository) : ViewModel() {
    private val _ui = MutableStateFlow(ScanUi())
    val ui: StateFlow<ScanUi> = _ui.asStateFlow()

    fun scan(context: Context, uri: Uri, classId: Int, subject: String) {
        _ui.update { ScanUi(phase = ScanUi.Phase.Reading) }
        viewModelScope.launch {
            val file = withContext(Dispatchers.IO) {
                File(context.cacheDir, "journal_scan.jpg").also { out ->
                    context.contentResolver.openInputStream(uri)?.use { it.copyTo(out.outputStream()) }
                }
            }
            val mime = context.contentResolver.getType(uri) ?: "image/jpeg"
            when (val r = repo.scanJournal(classId, subject, file, mime)) {
                is ApiResult.Ok -> _ui.update {
                    it.copy(
                        phase = ScanUi.Phase.Review,
                        rows = r.value.map { row -> ScanRow(row, row.grade, row.absent, include = row.studentId != null && (row.absent || row.grade != null)) },
                    )
                }
                is ApiResult.Err -> _ui.update { it.copy(phase = ScanUi.Phase.Idle, error = r.error) }
            }
        }
    }

    fun setGrade(index: Int, grade: Int?) = _ui.update { s -> s.copy(rows = s.rows.mapIndexed { i, r -> if (i == index) r.copy(grade = grade, absent = false, include = grade != null) else r }) }
    fun toggle(index: Int) = _ui.update { s -> s.copy(rows = s.rows.mapIndexed { i, r -> if (i == index) r.copy(include = !r.include) else r }) }

    fun saveAll(classId: Int, subject: String) {
        val rows = _ui.value.toSave
        if (rows.isEmpty() || _ui.value.phase == ScanUi.Phase.Saving) return
        _ui.update { it.copy(phase = ScanUi.Phase.Saving, error = null) }
        viewModelScope.launch {
            var ok = 0
            var firstError: ApiError? = null
            for (row in rows) {
                when (val r = repo.addGrade(row.raw.studentId!!, classId, subject, row.grade!!, null)) {
                    is ApiResult.Ok -> ok++
                    is ApiResult.Err -> if (firstError == null) firstError = r.error
                }
            }
            _ui.update { it.copy(phase = if (firstError == null) ScanUi.Phase.Idle else ScanUi.Phase.Review, saved = ok, error = firstError, rows = if (firstError == null) emptyList() else it.rows) }
        }
    }

    fun reset() = _ui.update { ScanUi() }
    fun clearError() = _ui.update { it.copy(error = null) }
}

// ----------------------------------------------------------- materials

data class MaterialsUi(
    val materials: UiState<List<MaterialSummaryDto>> = UiState.Loading,
    val assignments: UiState<List<TeacherAssignmentDto>> = UiState.Loading,
)

class MaterialsViewModel(private val repo: TeacherRepository) : ViewModel() {
    private val _ui = MutableStateFlow(MaterialsUi())
    val ui: StateFlow<MaterialsUi> = _ui.asStateFlow()
    private var loaded = false

    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()
    private val _error = MutableStateFlow<ApiError?>(null)
    val error: StateFlow<ApiError?> = _error.asStateFlow()

    fun assign(materialId: Int, classIds: List<Int>, mode: String, dueAt: String?, maxAttempts: Int?, onDone: () -> Unit) {
        if (_busy.value) return
        _busy.value = true
        viewModelScope.launch {
            when (val r = repo.assign(materialId, classIds, mode, dueAt, maxAttempts)) {
                is ApiResult.Ok -> { _busy.value = false; load(force = true); onDone() }
                is ApiResult.Err -> { _busy.value = false; _error.value = r.error }
            }
        }
    }

    fun delete(materialId: Int) {
        viewModelScope.launch {
            when (val r = repo.deleteMaterial(materialId)) {
                is ApiResult.Ok -> load(force = true)
                is ApiResult.Err -> _error.value = r.error
            }
        }
    }

    fun clearError() { _error.value = null }

    fun load(force: Boolean = false) {
        if (loaded && !force) return
        loaded = true
        viewModelScope.launch {
            val m = viewModelScope.async { repo.materials() }
            val a = viewModelScope.async { repo.assignments() }
            _ui.value = MaterialsUi(m.await().toUiState(), a.await().toUiState())
        }
    }
}

data class ResultsUi(
    val data: UiState<AssignmentResultsDto> = UiState.Loading,
    /** student id -> the mark the teacher will send. Pre-filled from the suggestion. */
    val marks: Map<Int, Int> = emptyMap(),
    val saving: Boolean = false,
    val error: ApiError? = null,
    val done: Boolean = false,
)

class ResultsViewModel(private val repo: TeacherRepository) : ViewModel() {
    private val _ui = MutableStateFlow(ResultsUi())
    val ui: StateFlow<ResultsUi> = _ui.asStateFlow()
    private var id = 0

    fun load(assignmentId: Int) {
        if (id == assignmentId && _ui.value.data is UiState.Ready) return
        id = assignmentId
        _ui.value = ResultsUi()
        viewModelScope.launch { apply(repo.results(assignmentId)) }
    }

    private fun apply(r: ApiResult<AssignmentResultsDto>) {
        _ui.update { s ->
            val marks = (r as? ApiResult.Ok)?.value?.rows.orEmpty()
                .filter { !it.transferred && it.suggestedGrade != null }
                .associate { it.studentId to it.suggestedGrade!! }
            s.copy(data = r.toUiState(), marks = marks, saving = false)
        }
    }

    fun setMark(studentId: Int, value: Int?) = _ui.update { s -> s.copy(marks = if (value == null) s.marks - studentId else s.marks + (studentId to value)) }

    fun transfer() {
        val marks = _ui.value.marks
        if (marks.isEmpty() || _ui.value.saving) return
        _ui.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.transferGrades(id, marks)) {
                is ApiResult.Ok -> { apply(r); _ui.update { it.copy(done = true) } }
                is ApiResult.Err -> _ui.update { it.copy(saving = false, error = r.error) }
            }
        }
    }

    fun clearFlags() = _ui.update { it.copy(error = null, done = false) }
}

// ------------------------------------------------------------- school

class SchoolInfoViewModel(private val repo: TeacherRepository) : ViewModel() {
    private val _calendar = MutableStateFlow<UiState<List<CalendarEventDto>>>(UiState.Loading)
    val calendar: StateFlow<UiState<List<CalendarEventDto>>> = _calendar.asStateFlow()
    private val _announcements = MutableStateFlow<UiState<List<SchoolAnnouncementDto>>>(UiState.Loading)
    val announcements: StateFlow<UiState<List<SchoolAnnouncementDto>>> = _announcements.asStateFlow()

    fun loadCalendar(force: Boolean = false) {
        if (!force && _calendar.value is UiState.Ready) return
        _calendar.value = UiState.Loading
        viewModelScope.launch { _calendar.value = repo.calendar().toUiState() }
    }

    fun loadAnnouncements(force: Boolean = false) {
        if (!force && _announcements.value is UiState.Ready) return
        _announcements.value = UiState.Loading
        viewModelScope.launch { _announcements.value = repo.announcements().toUiState() }
    }
}
