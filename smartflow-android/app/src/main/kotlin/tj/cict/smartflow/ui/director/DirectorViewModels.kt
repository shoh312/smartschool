package tj.cict.smartflow.ui.director

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import java.io.File
import java.time.LocalDate
import java.time.LocalTime
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.toUiState
import tj.cict.smartflow.data.dto.AnalyticsDto
import tj.cict.smartflow.data.dto.CalendarEventDto
import tj.cict.smartflow.data.dto.CameraCreateRequest
import tj.cict.smartflow.data.dto.CameraDto
import tj.cict.smartflow.data.dto.CameraPositionCreateRequest
import tj.cict.smartflow.data.dto.CameraPositionDto
import tj.cict.smartflow.data.dto.CameraStatusDto
import tj.cict.smartflow.data.dto.ClassDto
import tj.cict.smartflow.data.dto.ClassSubjectAverageDto
import tj.cict.smartflow.data.dto.ClassSubjectDto
import tj.cict.smartflow.data.dto.LeaderboardEntryDto
import tj.cict.smartflow.data.dto.LiveStatusDto
import tj.cict.smartflow.data.dto.NeedsAttentionDto
import tj.cict.smartflow.data.dto.SchoolAnnouncementDto
import tj.cict.smartflow.data.dto.SchoolSettingsDto
import tj.cict.smartflow.data.dto.SchoolSettingsUpdate
import tj.cict.smartflow.data.dto.StudentDto
import tj.cict.smartflow.data.dto.TeacherDto
import tj.cict.smartflow.data.repo.DirectorRepository
import tj.cict.smartflow.data.repo.StudentEdit
import tj.cict.smartflow.domain.AttendanceStatus

// ---------------------------------------------------------------- live

data class LiveUi(
    val rows: UiState<List<LiveStatusDto>> = UiState.Loading,
    val cameras: List<CameraStatusDto> = emptyList(),
    val updatedAt: LocalTime? = null,
    val refreshing: Boolean = false,
) {
    val list: List<LiveStatusDto> get() = (rows as? UiState.Ready)?.data.orEmpty()
    fun count(s: AttendanceStatus) = list.count { AttendanceStatus.fromApi(it.status) == s }
    /** Not yet seen, but the lesson has not started -- not "absent". */
    val waiting: Int get() = list.count { AttendanceStatus.fromApi(it.status) == AttendanceStatus.UNKNOWN }
}

/** Today's picture, refreshed every 15 s while a screen is looking. */
class LiveViewModel(private val repo: DirectorRepository) : ViewModel() {
    private val _ui = MutableStateFlow(LiveUi())
    val ui: StateFlow<LiveUi> = _ui.asStateFlow()
    private var loop: Job? = null

    fun start() {
        if (loop?.isActive == true) return
        loop = viewModelScope.launch {
            while (isActive) { refresh(); delay(15_000) }
        }
    }

    fun stop() { loop?.cancel(); loop = null }

    fun refresh() {
        viewModelScope.launch {
            _ui.update { it.copy(refreshing = true) }
            val live = viewModelScope.async { repo.liveStatus() }
            val cams = viewModelScope.async { repo.cameraStatus() }
            val l = live.await(); val c = cams.await()
            _ui.update {
                it.copy(
                    rows = if (l is ApiResult.Err && it.rows is UiState.Ready) it.rows else l.toUiState(),
                    cameras = (c as? ApiResult.Ok)?.value ?: it.cameras,
                    updatedAt = LocalTime.now(), refreshing = false,
                )
            }
        }
    }

    override fun onCleared() { stop() }
}

// --------------------------------------------------------------- video

sealed interface VideoState {
    data object Idle : VideoState
    data object Connecting : VideoState
    data class Streaming(val frame: Bitmap) : VideoState
    /** Socket open, nothing arriving -- the camera is not producing right now. */
    data class Silent(val phase: String?) : VideoState
    data class Failed(val reason: String) : VideoState
}

/**
 * The camera's JPEG frames over a websocket, decoded as they arrive. One
 * socket at a time; leaving the screen closes it so the server stops
 * encoding for nobody.
 */
class LiveVideoViewModel(private val repo: DirectorRepository, private val client: OkHttpClient) : ViewModel() {
    private val _state = MutableStateFlow<VideoState>(VideoState.Idle)
    val state: StateFlow<VideoState> = _state.asStateFlow()
    private val _cameras = MutableStateFlow<UiState<List<CameraDto>>>(UiState.Loading)
    val cameras: StateFlow<UiState<List<CameraDto>>> = _cameras.asStateFlow()
    private val _selected = MutableStateFlow<Int?>(null)
    val selected: StateFlow<Int?> = _selected.asStateFlow()
    private var socket: WebSocket? = null
    private var silence: Job? = null

    fun load() {
        viewModelScope.launch {
            val r = repo.cameras()
            _cameras.value = r.toUiState()
            val first = (r as? ApiResult.Ok)?.value?.firstOrNull { it.isActive }?.id
            if (_selected.value == null && first != null) select(first)
        }
    }

    fun select(cameraId: Int) {
        _selected.value = cameraId
        connect(cameraId)
    }

    fun reconnect() { _selected.value?.let { connect(it) } }

    private fun connect(cameraId: Int) {
        disconnect()
        viewModelScope.launch {
            val url = repo.streamUrl(cameraId)
            if (url == null) { _state.value = VideoState.Failed("closed"); return@launch }
            _state.value = VideoState.Connecting
            // The server keeps the socket open even when the camera thread is
            // idle between lessons, so "connected" alone would sit on a spinner
            // for an hour. After a few silent seconds, say what the camera is doing.
            silence?.cancel()
            silence = viewModelScope.launch {
                delay(6_000)
                if (_state.value is VideoState.Connecting) {
                    val st = (repo.cameraStatus() as? ApiResult.Ok)?.value?.firstOrNull { it.cameraId == cameraId }
                    if (_state.value is VideoState.Connecting) _state.value = VideoState.Silent(st?.phase)
                }
            }
            socket = client.newWebSocket(
                Request.Builder().url(url).build(),
                object : WebSocketListener() {
                    override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                        val bmp = BitmapFactory.decodeByteArray(bytes.toByteArray(), 0, bytes.size) ?: return
                        silence?.cancel()
                        _state.value = VideoState.Streaming(bmp)
                    }
                    override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                        _state.value = VideoState.Failed(if (reason == "live_video_disabled") reason else "closed")
                    }
                    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                        _state.value = VideoState.Failed("closed")
                    }
                },
            )
        }
    }

    fun disconnect() {
        silence?.cancel()
        socket?.close(1000, null)
        socket = null
        if (_state.value !is VideoState.Failed) _state.value = VideoState.Idle
    }

    override fun onCleared() { disconnect() }
}

// ------------------------------------------------------------- school

/** The school's structure, loaded once and re-read after each write. */
data class SchoolUi(
    val classes: UiState<List<ClassDto>> = UiState.Loading,
    val students: UiState<List<StudentDto>> = UiState.Loading,
    val teachers: UiState<List<TeacherDto>> = UiState.Loading,
    val cameras: UiState<List<CameraDto>> = UiState.Loading,
    val busy: Boolean = false,
    val error: ApiError? = null,
) {
    val classList: List<ClassDto> get() = (classes as? UiState.Ready)?.data.orEmpty()
}

class SchoolViewModel(private val repo: DirectorRepository) : ViewModel() {
    private val _ui = MutableStateFlow(SchoolUi())
    val ui: StateFlow<SchoolUi> = _ui.asStateFlow()

    init { loadAll() }

    fun loadAll() {
        viewModelScope.launch {
            val c = viewModelScope.async { repo.classes() }
            val s = viewModelScope.async { repo.students() }
            val t = viewModelScope.async { repo.teachers() }
            val k = viewModelScope.async { repo.cameras() }
            _ui.update { it.copy(classes = c.await().toUiState(), students = s.await().toUiState(), teachers = t.await().toUiState(), cameras = k.await().toUiState()) }
        }
    }

    private fun <T> write(block: suspend () -> ApiResult<T>, then: suspend () -> Unit = {}) {
        if (_ui.value.busy) return
        _ui.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            when (val r = block()) {
                is ApiResult.Ok -> { then(); loadAll(); _ui.update { it.copy(busy = false) } }
                is ApiResult.Err -> _ui.update { it.copy(busy = false, error = r.error) }
            }
        }
    }

    fun createClass(name: String, grade: Int?) = write({ repo.createClass(name, grade) })
    fun deleteClass(id: Int) = write({ repo.deleteClass(id) })

    fun createStudent(context: Context, first: String, last: String, classId: Int, phone: String, parentName: String, photo: Uri) = write({
        val file = withContext(Dispatchers.IO) {
            File(context.cacheDir, "student_face.jpg").also { out -> context.contentResolver.openInputStream(photo)?.use { it.copyTo(out.outputStream()) } }
        }
        repo.createStudent(first, last, classId, phone, parentName, file, context.contentResolver.getType(photo) ?: "image/jpeg")
    })
    fun updateStudent(context: Context, id: Int, edit: StudentEdit, photo: Uri?) = write({
        val file = photo?.let { uri ->
            withContext(Dispatchers.IO) {
                File(context.cacheDir, "student_face_edit.jpg").also { out -> context.contentResolver.openInputStream(uri)?.use { it.copyTo(out.outputStream()) } }
            }
        }
        repo.updateStudent(id, edit, file, photo?.let { context.contentResolver.getType(it) ?: "image/jpeg" })
    })
    fun deleteStudent(id: Int) = write({ repo.deleteStudent(id) })

    fun createTeacher(name: String, email: String, password: String, subject: String) = write({ repo.createTeacher(name, email, password, subject) })
    fun assignClass(teacherId: Int, classId: Int, subject: String) = write({ repo.assignClass(teacherId, classId, subject) })

    fun saveCamera(id: Int?, body: CameraCreateRequest) = write({ repo.saveCamera(id, body) })
    fun deleteCamera(id: Int) = write({ repo.deleteCamera(id) })

    fun clearError() = _ui.update { it.copy(error = null) }
}

data class PositionsUi(
    val rows: UiState<List<CameraPositionDto>> = UiState.Loading,
    val busy: Boolean = false,
    val error: ApiError? = null,
)

/** The timetable of one camera in group mode. */
class PositionsViewModel(private val repo: DirectorRepository) : ViewModel() {
    private val _ui = MutableStateFlow(PositionsUi())
    val ui: StateFlow<PositionsUi> = _ui.asStateFlow()
    private var cameraId = 0

    fun load(camera: Int) {
        cameraId = camera
        viewModelScope.launch { _ui.update { it.copy(rows = repo.positions(camera).toUiState()) } }
    }

    fun add(body: CameraPositionCreateRequest) {
        if (_ui.value.busy) return
        _ui.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.addPosition(cameraId, body)) {
                is ApiResult.Ok -> { _ui.update { it.copy(busy = false) }; load(cameraId) }
                is ApiResult.Err -> _ui.update { it.copy(busy = false, error = r.error) }
            }
        }
    }

    fun delete(positionId: Int) {
        viewModelScope.launch {
            when (val r = repo.deletePosition(cameraId, positionId)) {
                is ApiResult.Ok -> load(cameraId)
                is ApiResult.Err -> _ui.update { it.copy(error = r.error) }
            }
        }
    }

    fun clearError() = _ui.update { it.copy(error = null) }
}

data class ClassDetailUi(
    val subjects: UiState<List<ClassSubjectDto>> = UiState.Loading,
    val averages: UiState<List<ClassSubjectAverageDto>> = UiState.Loading,
    val ranking: UiState<List<LeaderboardEntryDto>> = UiState.Loading,
)

class ClassDetailViewModel(private val repo: DirectorRepository) : ViewModel() {
    private val _ui = MutableStateFlow(ClassDetailUi())
    val ui: StateFlow<ClassDetailUi> = _ui.asStateFlow()
    private var loaded: Int? = null

    fun load(classId: Int) {
        if (loaded == classId) return
        loaded = classId
        viewModelScope.launch {
            val s = viewModelScope.async { repo.classSubjects(classId) }
            val a = viewModelScope.async { repo.classSubjectAverages(classId) }
            val r = viewModelScope.async { repo.classRanking(classId) }
            _ui.value = ClassDetailUi(s.await().toUiState(), a.await().toUiState(), r.await().toUiState())
        }
    }
}

// ----------------------------------------------------------- settings

class SettingsViewModel(private val repo: DirectorRepository) : ViewModel() {
    private val _state = MutableStateFlow<UiState<SchoolSettingsDto>>(UiState.Loading)
    val state: StateFlow<UiState<SchoolSettingsDto>> = _state.asStateFlow()

    fun load() { viewModelScope.launch { _state.value = repo.settings().toUiState() } }

    fun update(update: SchoolSettingsUpdate) {
        val current = (_state.value as? UiState.Ready)?.data ?: return
        // Optimistic: flip now, reconcile with what the server says.
        _state.value = UiState.Ready(current.copy(
            liveVideoEnabled = update.liveVideoEnabled ?: current.liveVideoEnabled, groupMode = update.groupMode ?: current.groupMode,
            smsEnabled = update.smsEnabled ?: current.smsEnabled, isActive = update.isActive ?: current.isActive,
        ))
        viewModelScope.launch {
            when (val r = repo.updateSettings(update)) {
                is ApiResult.Ok -> _state.value = UiState.Ready(r.value)
                is ApiResult.Err -> _state.value = UiState.Ready(current)
            }
        }
    }
}

// ---------------------------------------------------------- analytics

data class AnalyticsUi(
    val classId: Int? = null,
    val ranking: UiState<List<LeaderboardEntryDto>> = UiState.Loading,
    val attention: UiState<NeedsAttentionDto> = UiState.Loading,
)

class DirectorAnalyticsViewModel(private val repo: DirectorRepository) : ViewModel() {
    private val _ui = MutableStateFlow(AnalyticsUi())
    val ui: StateFlow<AnalyticsUi> = _ui.asStateFlow()
    private var loaded = false

    fun load() {
        if (loaded) return
        loaded = true
        viewModelScope.launch {
            val r = viewModelScope.async { repo.schoolRanking() }
            val a = viewModelScope.async { repo.needsAttention() }
            _ui.update { it.copy(ranking = r.await().toUiState(), attention = a.await().toUiState()) }
        }
    }

    fun pickClass(classId: Int?) {
        _ui.update { it.copy(classId = classId, ranking = UiState.Loading) }
        viewModelScope.launch {
            val r = if (classId == null) repo.schoolRanking() else repo.classRanking(classId)
            if (_ui.value.classId == classId) _ui.update { it.copy(ranking = r.toUiState()) }
        }
    }
}

/** One pupil's full rating, as the director sees it -- same body as the parent's screen. */
class StudentRatingViewModel(private val repo: DirectorRepository) : ViewModel() {
    private val _state = MutableStateFlow<UiState<AnalyticsDto>>(UiState.Loading)
    val state: StateFlow<UiState<AnalyticsDto>> = _state.asStateFlow()
    private val _quarter = MutableStateFlow<Int?>(null)
    val quarter: StateFlow<Int?> = _quarter.asStateFlow()
    private var studentId = 0

    fun load(id: Int) {
        if (studentId == id && _state.value is UiState.Ready) return
        studentId = id
        fetch()
    }

    fun pickQuarter(q: Int) {
        _quarter.value = q
        fetch()
    }

    private fun fetch() {
        val q = _quarter.value
        _state.value = UiState.Loading
        viewModelScope.launch {
            val r = repo.studentAnalytics(studentId, q)
            if (_quarter.value == q) _state.value = r.toUiState()
        }
    }
}

// ------------------------------------------- announcements & calendar

class DirectorNoticesViewModel(private val repo: DirectorRepository) : ViewModel() {
    private val _announcements = MutableStateFlow<UiState<List<SchoolAnnouncementDto>>>(UiState.Loading)
    val announcements: StateFlow<UiState<List<SchoolAnnouncementDto>>> = _announcements.asStateFlow()
    private val _events = MutableStateFlow<UiState<List<CalendarEventDto>>>(UiState.Loading)
    val events: StateFlow<UiState<List<CalendarEventDto>>> = _events.asStateFlow()
    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()

    fun loadAnnouncements() { viewModelScope.launch { _announcements.value = repo.announcements().toUiState() } }
    fun loadEvents() { viewModelScope.launch { _events.value = repo.calendar().toUiState() } }

    fun createAnnouncement(title: String, body: String, classId: Int?, onDone: () -> Unit) {
        _busy.value = true
        viewModelScope.launch { repo.createAnnouncement(title, body, classId); _busy.value = false; loadAnnouncements(); onDone() }
    }
    fun deleteAnnouncement(id: Int) { viewModelScope.launch { repo.deleteAnnouncement(id); loadAnnouncements() } }

    fun createEvent(title: String, desc: String?, type: String, start: LocalDate, end: LocalDate?, classId: Int?, onDone: () -> Unit) {
        _busy.value = true
        viewModelScope.launch { repo.createEvent(title, desc, type, start, end, classId); _busy.value = false; loadEvents(); onDone() }
    }
    fun deleteEvent(id: Int) { viewModelScope.launch { repo.deleteEvent(id); loadEvents() } }
}
