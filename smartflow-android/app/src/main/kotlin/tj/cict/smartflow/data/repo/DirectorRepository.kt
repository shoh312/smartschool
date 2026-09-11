package tj.cict.smartflow.data.repo

import java.io.File
import java.time.LocalDate
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.network.map
import tj.cict.smartflow.core.network.safeCall as rawCall
import tj.cict.smartflow.core.session.Role
import tj.cict.smartflow.core.session.Session
import tj.cict.smartflow.core.session.SessionStore
import tj.cict.smartflow.data.api.SchoolApi
import tj.cict.smartflow.data.dto.AnnouncementCreateRequest
import tj.cict.smartflow.data.dto.AssignClassRequest
import tj.cict.smartflow.data.dto.CalendarEventCreateRequest
import tj.cict.smartflow.data.dto.CalendarEventDto
import tj.cict.smartflow.data.dto.CameraCreateRequest
import tj.cict.smartflow.data.dto.CameraDto
import tj.cict.smartflow.data.dto.CameraStatusDto
import tj.cict.smartflow.data.dto.ClassAssignmentDto
import tj.cict.smartflow.data.dto.ClassCreateRequest
import tj.cict.smartflow.data.dto.ClassDto
import tj.cict.smartflow.data.dto.ClassSubjectAverageDto
import tj.cict.smartflow.data.dto.ClassSubjectDto
import tj.cict.smartflow.data.dto.DirectorLoginRequest
import tj.cict.smartflow.data.dto.LeaderboardEntryDto
import tj.cict.smartflow.data.dto.LiveStatusDto
import tj.cict.smartflow.data.dto.NeedsAttentionDto
import tj.cict.smartflow.data.dto.SchoolAnnouncementDto
import tj.cict.smartflow.data.dto.SchoolSettingsDto
import tj.cict.smartflow.data.dto.SchoolSettingsUpdate
import tj.cict.smartflow.data.dto.StudentDto
import tj.cict.smartflow.data.dto.TeacherCreateRequest
import tj.cict.smartflow.data.dto.TeacherDto

/** Everything a director does against the school server, with the demo alongside. */
class DirectorRepository(private val api: SchoolApi, private val session: SessionStore) {
    private suspend fun isDemo() = session.token() == DemoDirector.TOKEN

    private suspend fun <T> safeCall(block: suspend () -> T): ApiResult<T> {
        val result = rawCall(block)
        if (result is ApiResult.Err && result.error == ApiError.Unauthorized) session.clear()
        return result
    }

    private fun text(v: String) = v.toRequestBody("text/plain".toMediaType())

    suspend fun login(email: String, password: String, serverUrl: String?): ApiResult<Unit> {
        if (email.trim().equals(DemoDirector.EMAIL, ignoreCase = true) || email.trim().equals("demo", ignoreCase = true)) {
            session.save(Session(DemoDirector.TOKEN, Role.DIRECTOR, 1, DemoDirector.NAME, DemoDirector.EMAIL, null, null))
            return ApiResult.Ok(Unit)
        }
        val url = serverUrl ?: return ApiResult.Err(ApiError.Network)
        session.rememberServerUrl(url)
        return when (val r = safeCall { api.directorLogin(DirectorLoginRequest(email.trim(), password)) }) {
            is ApiResult.Err -> r
            is ApiResult.Ok -> {
                val d = r.value.director
                session.save(Session(r.value.accessToken, Role.DIRECTOR, d?.id ?: 0, d?.fullName.orEmpty(), email.trim(), null, url))
                ApiResult.Ok(Unit)
            }
        }
    }

    suspend fun loginDemo() = login(DemoDirector.EMAIL, "", null)

    /** The token and server for a websocket, which cannot carry headers. */
    suspend fun streamUrl(cameraId: Int): String? {
        val s = session.current() ?: return null
        val base = s.serverUrl ?: return null
        return base.replaceFirst("http", "ws") + "ws/stream?camera_id=$cameraId&token=${s.token}"
    }

    // ---------------------------------------------------------- live

    suspend fun liveStatus(): ApiResult<List<LiveStatusDto>> =
        if (isDemo()) ApiResult.Ok(DemoDirector.liveStatus()) else safeCall { api.liveStatus() }

    suspend fun cameraStatus(): ApiResult<List<CameraStatusDto>> =
        if (isDemo()) ApiResult.Ok(DemoDirector.cameraStatus()) else safeCall { api.cameraStatus() }

    // ------------------------------------------------------- classes

    suspend fun classes(): ApiResult<List<ClassDto>> =
        if (isDemo()) ApiResult.Ok(DemoDirector.classes.toList()) else safeCall { api.classes() }.map { it.sortedWith(compareBy({ it.grade ?: 0 }, { it.name })) }

    suspend fun createClass(name: String, grade: Int?): ApiResult<ClassDto> =
        if (isDemo()) ApiResult.Ok(DemoDirector.addClass(name, grade)) else safeCall { api.createClass(ClassCreateRequest(name, grade)) }

    suspend fun deleteClass(id: Int): ApiResult<Unit> =
        if (isDemo()) { DemoDirector.removeClass(id); ApiResult.Ok(Unit) } else safeCall { api.deleteClass(id) }

    suspend fun classSubjects(classId: Int): ApiResult<List<ClassSubjectDto>> =
        if (isDemo()) ApiResult.Ok(DemoDirector.subjectsOf(classId)) else safeCall { api.classSubjects(classId) }

    // ------------------------------------------------------ students

    suspend fun students(): ApiResult<List<StudentDto>> =
        if (isDemo()) ApiResult.Ok(DemoDirector.students()) else safeCall { api.allStudents() }.map { list -> list.filter { it.isActive } }

    suspend fun createStudent(firstName: String, lastName: String, classId: Int, parentPhone: String, parentName: String?, photo: File, mime: String): ApiResult<StudentDto> =
        if (isDemo()) ApiResult.Ok(DemoDirector.addStudent(firstName, lastName, classId))
        else safeCall {
            api.createStudent(
                text(firstName), text(lastName), text(classId.toString()), text(parentPhone),
                parentName?.takeIf { it.isNotBlank() }?.let { text(it) },
                MultipartBody.Part.createFormData("file", photo.name, photo.asRequestBody(mime.toMediaType())),
            )
        }

    suspend fun deleteStudent(id: Int): ApiResult<Unit> =
        if (isDemo()) { DemoDirector.removeStudent(id); ApiResult.Ok(Unit) } else safeCall { api.deleteStudent(id) }

    // ------------------------------------------------------ teachers

    suspend fun teachers(): ApiResult<List<TeacherDto>> =
        if (isDemo()) ApiResult.Ok(DemoDirector.teachers.toList()) else safeCall { api.teachers() }

    suspend fun createTeacher(name: String, email: String, password: String, subject: String?): ApiResult<TeacherDto> =
        if (isDemo()) ApiResult.Ok(DemoDirector.addTeacher(name, email, subject))
        else safeCall { api.createTeacher(TeacherCreateRequest(name, email, password, subject?.takeIf { it.isNotBlank() })) }

    suspend fun assignClass(teacherId: Int, classId: Int, subject: String): ApiResult<ClassAssignmentDto> =
        if (isDemo()) ApiResult.Ok(ClassAssignmentDto(0, classId, subject, DemoDirector.classes.firstOrNull { it.id == classId }?.name))
        else safeCall { api.assignClass(teacherId, AssignClassRequest(classId, subject)) }

    // ------------------------------------------------------- cameras

    suspend fun cameras(): ApiResult<List<CameraDto>> =
        if (isDemo()) ApiResult.Ok(DemoDirector.cameras.toList()) else safeCall { api.cameras() }

    suspend fun saveCamera(id: Int?, body: CameraCreateRequest): ApiResult<CameraDto> = when {
        isDemo() -> (if (id == null) DemoDirector.addCamera(body) else DemoDirector.updateCamera(id, body))?.let { ApiResult.Ok(it) } ?: ApiResult.Err(ApiError.Detail("not_found", 404))
        id == null -> safeCall { api.createCamera(body) }
        else -> safeCall { api.updateCamera(id, body) }
    }

    suspend fun deleteCamera(id: Int): ApiResult<Unit> =
        if (isDemo()) { DemoDirector.removeCamera(id); ApiResult.Ok(Unit) } else safeCall { api.deleteCamera(id) }

    // ------------------------------------------------------ settings

    suspend fun settings(): ApiResult<SchoolSettingsDto> =
        if (isDemo()) ApiResult.Ok(DemoDirector.settings) else safeCall { api.settings() }

    suspend fun updateSettings(update: SchoolSettingsUpdate): ApiResult<SchoolSettingsDto> =
        if (isDemo()) {
            val s = DemoDirector.settings
            DemoDirector.settings = s.copy(
                liveVideoEnabled = update.liveVideoEnabled ?: s.liveVideoEnabled, groupMode = update.groupMode ?: s.groupMode,
                smsEnabled = update.smsEnabled ?: s.smsEnabled, isActive = update.isActive ?: s.isActive,
            )
            ApiResult.Ok(DemoDirector.settings)
        } else safeCall { api.updateSettings(update) }

    // ----------------------------------------------- announcements & calendar

    suspend fun announcements(): ApiResult<List<SchoolAnnouncementDto>> =
        if (isDemo()) ApiResult.Ok(demoAnnouncements.toList()) else safeCall { api.announcements() }

    private val demoAnnouncements = DemoTeacher.announcements().toMutableList()

    suspend fun createAnnouncement(title: String, body: String, classId: Int?): ApiResult<SchoolAnnouncementDto> =
        if (isDemo()) ApiResult.Ok(SchoolAnnouncementDto(100 + demoAnnouncements.size, classId, title, body, java.time.LocalDateTime.now()).also { demoAnnouncements.add(0, it) })
        else safeCall { api.createAnnouncement(AnnouncementCreateRequest(title, body, classId)) }

    suspend fun deleteAnnouncement(id: Int): ApiResult<Unit> =
        if (isDemo()) { demoAnnouncements.removeAll { it.id == id }; ApiResult.Ok(Unit) } else safeCall { api.deleteAnnouncement(id) }

    private val demoEvents = DemoData.calendar().toMutableList()

    suspend fun calendar(): ApiResult<List<CalendarEventDto>> =
        if (isDemo()) ApiResult.Ok(demoEvents.toList()) else safeCall { api.calendar() }

    suspend fun createEvent(title: String, description: String?, type: String, start: LocalDate, end: LocalDate?, classId: Int?): ApiResult<CalendarEventDto> =
        if (isDemo()) ApiResult.Ok(CalendarEventDto(100 + demoEvents.size, title, description, type, start, end).also { demoEvents += it })
        else safeCall { api.createEvent(CalendarEventCreateRequest(title, description, type, start, end, classId)) }

    suspend fun deleteEvent(id: Int): ApiResult<Unit> =
        if (isDemo()) { demoEvents.removeAll { it.id == id }; ApiResult.Ok(Unit) } else safeCall { api.deleteEvent(id) }

    // ----------------------------------------------------- analytics

    suspend fun schoolRanking(): ApiResult<List<LeaderboardEntryDto>> =
        if (isDemo()) ApiResult.Ok(DemoDirector.ranking(null)) else safeCall { api.schoolRanking() }

    suspend fun classRanking(classId: Int): ApiResult<List<LeaderboardEntryDto>> =
        if (isDemo()) ApiResult.Ok(DemoDirector.ranking(classId)) else safeCall { api.classRanking(classId) }

    suspend fun needsAttention(): ApiResult<NeedsAttentionDto> =
        if (isDemo()) ApiResult.Ok(DemoDirector.needsAttention()) else safeCall { api.needsAttention() }

    suspend fun classSubjectAverages(classId: Int): ApiResult<List<ClassSubjectAverageDto>> =
        if (isDemo()) ApiResult.Ok(DemoDirector.classSubjects(classId)) else safeCall { api.classSubjectAverages(classId) }
}
