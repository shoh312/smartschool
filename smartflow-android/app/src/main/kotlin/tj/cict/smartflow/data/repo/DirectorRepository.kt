package tj.cict.smartflow.data.repo

import java.io.File
import java.time.LocalDate
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody
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
import tj.cict.smartflow.data.dto.AnalyticsDto
import tj.cict.smartflow.data.dto.AnnouncementCreateRequest
import tj.cict.smartflow.data.dto.AssignClassRequest
import tj.cict.smartflow.data.dto.CalendarEventCreateRequest
import tj.cict.smartflow.data.dto.CalendarEventDto
import tj.cict.smartflow.data.dto.CameraCreateRequest
import tj.cict.smartflow.data.dto.CameraDto
import tj.cict.smartflow.data.dto.CameraPositionCreateRequest
import tj.cict.smartflow.data.dto.CameraPositionDto
import tj.cict.smartflow.data.dto.CameraStatusDto
import tj.cict.smartflow.data.dto.ClassAssignmentDto
import tj.cict.smartflow.data.dto.ClassCreateRequest
import tj.cict.smartflow.data.dto.ClassDto
import tj.cict.smartflow.data.dto.ClassSubjectAverageDto
import tj.cict.smartflow.data.dto.ClassSubjectDto
import tj.cict.smartflow.data.dto.GradeDto
import tj.cict.smartflow.data.dto.AbsenceDto
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

/** What a director edits: the pupil as the form holds it. */
data class StudentEdit(
    val firstName: String,
    val lastName: String,
    val classId: Int,
    val parentPhone: String?,
    val username: String? = null,
    val password: String? = null,
)

/** Everything a director does against the school server. */
class DirectorRepository(private val api: SchoolApi, private val session: SessionStore) {

    private suspend fun <T> safeCall(block: suspend () -> T): ApiResult<T> {
        val result = rawCall(block)
        if (result is ApiResult.Err && result.error == ApiError.Unauthorized) session.clear()
        return result
    }

    private fun text(v: String): RequestBody = v.toRequestBody("text/plain".toMediaType())
    private fun photoPart(photo: File, mime: String) = MultipartBody.Part.createFormData("file", photo.name, photo.asRequestBody(mime.toMediaType()))

    suspend fun login(email: String, password: String, serverUrl: String?): ApiResult<Unit> {
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

    /** The token and server for a websocket, which cannot carry headers. */
    suspend fun streamUrl(cameraId: Int): String? {
        val s = session.current() ?: return null
        val base = s.serverUrl ?: return null
        return base.replaceFirst("http", "ws") + "ws/stream?camera_id=$cameraId&token=${s.token}"
    }

    // ---------------------------------------------------------- live

    suspend fun liveStatus(): ApiResult<List<LiveStatusDto>> = safeCall { api.liveStatus() }
    suspend fun cameraStatus(): ApiResult<List<CameraStatusDto>> = safeCall { api.cameraStatus() }

    // ------------------------------------------------------- classes

    suspend fun classes(): ApiResult<List<ClassDto>> =
        safeCall { api.classes() }.map { it.sortedWith(compareBy({ it.grade ?: 0 }, { it.name })) }

    suspend fun createClass(name: String, grade: Int?): ApiResult<ClassDto> = safeCall { api.createClass(ClassCreateRequest(name, grade)) }
    suspend fun deleteClass(id: Int): ApiResult<Unit> = safeCall { api.deleteClass(id) }
    suspend fun classSubjects(classId: Int): ApiResult<List<ClassSubjectDto>> = safeCall { api.classSubjects(classId) }

    // ------------------------------------------------------ journal (read-only for a director)
    suspend fun grades(classId: Int): ApiResult<List<GradeDto>> = safeCall { api.grades(classId, null, limit = 3000) }
    suspend fun absences(classId: Int): ApiResult<List<AbsenceDto>> = safeCall { api.absences(classId, null) }

    // ------------------------------------------------------ students

    suspend fun students(): ApiResult<List<StudentDto>> =
        safeCall { api.allStudents() }.map { list -> list.filter { it.isActive } }

    suspend fun createStudent(firstName: String, lastName: String, classId: Int, parentPhone: String, parentName: String?, photo: File, mime: String): ApiResult<StudentDto> =
        safeCall {
            api.createStudent(
                text(firstName), text(lastName), text(classId.toString()), text(parentPhone),
                parentName?.takeIf { it.isNotBlank() }?.let { text(it) },
                photoPart(photo, mime),
            )
        }

    suspend fun updateStudent(id: Int, edit: StudentEdit, photo: File?, mime: String?): ApiResult<StudentDto> =
        safeCall {
            api.updateStudent(
                id, text(edit.firstName), text(edit.lastName), text(edit.classId.toString()),
                edit.parentPhone?.takeIf { it.isNotBlank() }?.let { text(it) },
                edit.username?.takeIf { it.isNotBlank() }?.let { text(it) },
                edit.password?.takeIf { it.isNotBlank() }?.let { text(it) },
                if (photo != null && mime != null) photoPart(photo, mime) else null,
            )
        }

    suspend fun deleteStudent(id: Int): ApiResult<Unit> = safeCall { api.deleteStudent(id) }

    // ------------------------------------------------------ teachers

    suspend fun teachers(): ApiResult<List<TeacherDto>> = safeCall { api.teachers() }

    suspend fun createTeacher(name: String, email: String, password: String, subject: String?): ApiResult<TeacherDto> =
        safeCall { api.createTeacher(TeacherCreateRequest(name, email, password, subject?.takeIf { it.isNotBlank() })) }

    suspend fun assignClass(teacherId: Int, classId: Int, subject: String): ApiResult<ClassAssignmentDto> =
        safeCall { api.assignClass(teacherId, AssignClassRequest(classId, subject)) }

    // ------------------------------------------------------- cameras

    suspend fun cameras(): ApiResult<List<CameraDto>> = safeCall { api.cameras() }

    suspend fun saveCamera(id: Int?, body: CameraCreateRequest): ApiResult<CameraDto> =
        if (id == null) safeCall { api.createCamera(body) } else safeCall { api.updateCamera(id, body) }

    suspend fun deleteCamera(id: Int): ApiResult<Unit> = safeCall { api.deleteCamera(id) }

    suspend fun positions(cameraId: Int): ApiResult<List<CameraPositionDto>> = safeCall { api.positions(cameraId) }

    suspend fun addPosition(cameraId: Int, body: CameraPositionCreateRequest): ApiResult<CameraPositionDto> =
        safeCall { api.createPosition(cameraId, body) }

    suspend fun deletePosition(cameraId: Int, positionId: Int): ApiResult<Unit> = safeCall { api.deletePosition(cameraId, positionId) }

    // ------------------------------------------------------ settings

    suspend fun settings(): ApiResult<SchoolSettingsDto> = safeCall { api.settings() }
    suspend fun updateSettings(update: SchoolSettingsUpdate): ApiResult<SchoolSettingsDto> = safeCall { api.updateSettings(update) }

    // ----------------------------------------------- announcements & calendar

    suspend fun announcements(): ApiResult<List<SchoolAnnouncementDto>> = safeCall { api.announcements() }

    suspend fun createAnnouncement(title: String, body: String, classId: Int?): ApiResult<SchoolAnnouncementDto> =
        safeCall { api.createAnnouncement(AnnouncementCreateRequest(title, body, classId)) }

    suspend fun deleteAnnouncement(id: Int): ApiResult<Unit> = safeCall { api.deleteAnnouncement(id) }

    suspend fun calendar(): ApiResult<List<CalendarEventDto>> = safeCall { api.calendar() }

    suspend fun createEvent(title: String, description: String?, type: String, start: LocalDate, end: LocalDate?, classId: Int?): ApiResult<CalendarEventDto> =
        safeCall { api.createEvent(CalendarEventCreateRequest(title, description, type, start, end, classId)) }

    suspend fun deleteEvent(id: Int): ApiResult<Unit> = safeCall { api.deleteEvent(id) }

    // ----------------------------------------------------- analytics

    suspend fun studentAnalytics(studentId: Int, quarter: Int?): ApiResult<AnalyticsDto> = safeCall { api.studentAnalytics(studentId, quarter) }
    suspend fun schoolRanking(): ApiResult<List<LeaderboardEntryDto>> = safeCall { api.schoolRanking() }
    suspend fun classRanking(classId: Int): ApiResult<List<LeaderboardEntryDto>> = safeCall { api.classRanking(classId) }
    suspend fun needsAttention(): ApiResult<NeedsAttentionDto> = safeCall { api.needsAttention() }
    suspend fun classSubjectAverages(classId: Int): ApiResult<List<ClassSubjectAverageDto>> = safeCall { api.classSubjectAverages(classId) }
}
