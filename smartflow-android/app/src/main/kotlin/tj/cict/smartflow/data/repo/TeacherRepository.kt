package tj.cict.smartflow.data.repo

import java.io.File
import java.time.LocalDate
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.network.SchoolDiscovery
import tj.cict.smartflow.core.network.map
import tj.cict.smartflow.core.network.safeCall as rawCall
import tj.cict.smartflow.core.session.Role
import tj.cict.smartflow.core.session.Session
import tj.cict.smartflow.core.session.SessionStore
import tj.cict.smartflow.data.api.SchoolApi
import tj.cict.smartflow.data.dto.AbsenceDto
import tj.cict.smartflow.data.dto.AssignmentResultsDto
import tj.cict.smartflow.data.dto.CalendarEventDto
import tj.cict.smartflow.data.dto.ClassAssignmentDto
import tj.cict.smartflow.data.dto.DiaryLogUpdateRequest
import tj.cict.smartflow.data.dto.GradeCreateRequest
import tj.cict.smartflow.data.dto.GradeDto
import tj.cict.smartflow.data.dto.GradeTransferItem
import tj.cict.smartflow.data.dto.GradeTransferRequest
import tj.cict.smartflow.data.dto.GradeUpdateRequest
import tj.cict.smartflow.data.dto.MaterialSummaryDto
import tj.cict.smartflow.data.dto.ScanRowDto
import tj.cict.smartflow.data.dto.SchoolAnnouncementDto
import tj.cict.smartflow.data.dto.StudentDto
import tj.cict.smartflow.data.dto.TeacherAssignmentDto
import tj.cict.smartflow.data.dto.TeacherDiaryEntryDto
import tj.cict.smartflow.data.dto.TeacherLoginRequest

/** Everything a teacher does against the school server, with the demo alongside. */
class TeacherRepository(
    private val api: SchoolApi,
    private val client: OkHttpClient,
    private val session: SessionStore,
) {
    private suspend fun isDemo() = session.token() == DemoTeacher.TOKEN

    private suspend fun <T> safeCall(block: suspend () -> T): ApiResult<T> {
        val result = rawCall(block)
        if (result is ApiResult.Err && result.error == ApiError.Unauthorized) session.clear()
        return result
    }

    // ------------------------------------------------------------ server

    suspend fun resolveServer(): String? = SchoolDiscovery.resolve(client, session.lastServerUrl())?.also { session.rememberServerUrl(it) }

    suspend fun checkServer(url: String): Boolean = SchoolDiscovery.isReachable(client, url).also { if (it) session.rememberServerUrl(url) }

    // ------------------------------------------------------------- login

    suspend fun login(email: String, password: String, serverUrl: String?): ApiResult<Unit> {
        if (email.trim().equals(DemoTeacher.EMAIL, ignoreCase = true) || email.trim().equals("demo", ignoreCase = true)) {
            session.save(Session(DemoTeacher.TOKEN, Role.TEACHER, DemoTeacher.me.id, DemoTeacher.me.fullName, DemoTeacher.EMAIL, null, null))
            return ApiResult.Ok(Unit)
        }
        val url = serverUrl ?: return ApiResult.Err(ApiError.Network)
        session.rememberServerUrl(url)
        return when (val r = safeCall { api.teacherLogin(TeacherLoginRequest(email.trim(), password)) }) {
            is ApiResult.Err -> r
            is ApiResult.Ok -> {
                val t = r.value.teacher
                session.save(Session(r.value.accessToken, Role.TEACHER, t.id, t.fullName, t.email, t.subject, url))
                ApiResult.Ok(Unit)
            }
        }
    }

    suspend fun loginDemo() = login(DemoTeacher.EMAIL, "", null)

    // ----------------------------------------------------------- classes

    suspend fun myClasses(): ApiResult<List<ClassAssignmentDto>> =
        if (isDemo()) ApiResult.Ok(DemoTeacher.classes) else safeCall { api.myClasses() }

    suspend fun roster(classId: Int): ApiResult<List<StudentDto>> =
        if (isDemo()) ApiResult.Ok(DemoTeacher.roster(classId)) else safeCall { api.roster(classId) }.map { list -> list.filter { it.isActive } }

    // ------------------------------------------------------------ grades

    suspend fun grades(classId: Int, subject: String): ApiResult<List<GradeDto>> =
        if (isDemo()) ApiResult.Ok(DemoTeacher.grades(classId)) else safeCall { api.grades(classId, subject) }

    suspend fun addGrade(studentId: Int, classId: Int, subject: String, value: Int, comment: String?): ApiResult<GradeDto> =
        if (isDemo()) ApiResult.Ok(DemoTeacher.addGrade(studentId, classId, value, comment))
        else safeCall { api.createGrade(GradeCreateRequest(studentId, classId, subject, value, comment?.takeIf { it.isNotBlank() })) }

    suspend fun updateGrade(id: Int, value: Int?, comment: String?): ApiResult<GradeDto> =
        if (isDemo()) DemoTeacher.updateGrade(id, value, comment)?.let { ApiResult.Ok(it) } ?: ApiResult.Err(ApiError.Detail("not_found", 404))
        else safeCall { api.updateGrade(id, GradeUpdateRequest(value, comment)) }

    suspend fun deleteGrade(id: Int): ApiResult<Unit> =
        if (isDemo()) { DemoTeacher.deleteGrade(id); ApiResult.Ok(Unit) } else safeCall { api.deleteGrade(id) }

    suspend fun absences(classId: Int, subject: String?): ApiResult<List<AbsenceDto>> =
        if (isDemo()) ApiResult.Ok(DemoTeacher.absences(classId)) else safeCall { api.absences(classId, subject) }

    suspend fun scanJournal(classId: Int, subject: String, file: File, mime: String): ApiResult<List<ScanRowDto>> {
        if (isDemo()) return ApiResult.Ok(DemoTeacher.scan(classId))
        return safeCall {
            api.scanJournal(
                classId.toString().toRequestBody("text/plain".toMediaType()),
                subject.toRequestBody("text/plain".toMediaType()),
                MultipartBody.Part.createFormData("file", file.name, file.asRequestBody(mime.toMediaType())),
            ).results
        }
    }

    // ------------------------------------------------------------- diary

    suspend fun diary(classId: Int, on: LocalDate): ApiResult<List<TeacherDiaryEntryDto>> =
        if (isDemo()) ApiResult.Ok(DemoTeacher.diary(classId, on)) else safeCall { api.diary(classId, on.toString()) }

    suspend fun updateDiary(lessonId: Int, on: LocalDate, homework: String?, comment: String?): ApiResult<TeacherDiaryEntryDto> =
        if (isDemo()) DemoTeacher.updateDiary(lessonId, on, homework, comment)?.let { ApiResult.Ok(it) } ?: ApiResult.Err(ApiError.Detail("not_found", 404))
        else safeCall { api.updateDiary(lessonId, on.toString(), DiaryLogUpdateRequest(homework, comment)) }

    // --------------------------------------------------------- materials

    suspend fun materials(): ApiResult<List<MaterialSummaryDto>> =
        if (isDemo()) ApiResult.Ok(DemoTeacher.materials) else safeCall { api.materials() }

    suspend fun assignments(): ApiResult<List<TeacherAssignmentDto>> =
        if (isDemo()) ApiResult.Ok(DemoTeacher.assignments) else safeCall { api.assignments() }

    suspend fun results(id: Int): ApiResult<AssignmentResultsDto> =
        if (isDemo()) DemoTeacher.results(id)?.let { ApiResult.Ok(it) } ?: ApiResult.Err(ApiError.Detail("not_found", 404))
        else safeCall { api.results(id) }

    suspend fun transferGrades(id: Int, items: Map<Int, Int>): ApiResult<AssignmentResultsDto> =
        if (isDemo()) DemoTeacher.transfer(id, items.keys.toList())?.let { ApiResult.Ok(it) } ?: ApiResult.Err(ApiError.Detail("not_found", 404))
        else safeCall { api.transferGrades(id, GradeTransferRequest(items.map { (s, v) -> GradeTransferItem(s, v) })) }

    // ------------------------------------------------------------ school

    suspend fun calendar(): ApiResult<List<CalendarEventDto>> =
        if (isDemo()) ApiResult.Ok(DemoTeacher.calendar()) else safeCall { api.calendar() }

    suspend fun announcements(): ApiResult<List<SchoolAnnouncementDto>> =
        if (isDemo()) ApiResult.Ok(DemoTeacher.announcements()) else safeCall { api.announcements() }
}
