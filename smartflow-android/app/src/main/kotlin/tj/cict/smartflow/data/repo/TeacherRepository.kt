package tj.cict.smartflow.data.repo

import java.io.File
import java.time.LocalDate
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
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

/** Everything a teacher does against the school server. */
class TeacherRepository(private val api: SchoolApi, private val session: SessionStore) {

    private suspend fun <T> safeCall(block: suspend () -> T): ApiResult<T> {
        val result = rawCall(block)
        if (result is ApiResult.Err && result.error == ApiError.Unauthorized) session.clear()
        return result
    }

    // ------------------------------------------------------------ server

    suspend fun resolveServer(): String? =
        SchoolDiscovery.resolve(SchoolDiscovery.probeClient, session.lastServerUrl())?.also { session.rememberServerUrl(it) }

    // ------------------------------------------------------------- login

    suspend fun login(email: String, password: String, serverUrl: String?): ApiResult<Unit> {
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

    // ----------------------------------------------------------- classes

    suspend fun myClasses(): ApiResult<List<ClassAssignmentDto>> = safeCall { api.myClasses() }

    suspend fun roster(classId: Int): ApiResult<List<StudentDto>> =
        safeCall { api.roster(classId) }.map { list -> list.filter { it.isActive } }

    // ------------------------------------------------------------ grades

    suspend fun grades(classId: Int, subject: String): ApiResult<List<GradeDto>> = safeCall { api.grades(classId, subject) }

    suspend fun addGrade(studentId: Int, classId: Int, subject: String, value: Int, comment: String?): ApiResult<GradeDto> =
        safeCall { api.createGrade(GradeCreateRequest(studentId, classId, subject, value, comment?.takeIf { it.isNotBlank() })) }

    suspend fun updateGrade(id: Int, value: Int?, comment: String?): ApiResult<GradeDto> =
        safeCall { api.updateGrade(id, GradeUpdateRequest(value, comment)) }

    suspend fun deleteGrade(id: Int): ApiResult<Unit> = safeCall { api.deleteGrade(id) }

    suspend fun absences(classId: Int, subject: String?): ApiResult<List<AbsenceDto>> = safeCall { api.absences(classId, subject) }

    suspend fun scanJournal(classId: Int, subject: String, file: File, mime: String): ApiResult<List<ScanRowDto>> = safeCall {
        api.scanJournal(
            classId.toString().toRequestBody("text/plain".toMediaType()),
            subject.toRequestBody("text/plain".toMediaType()),
            MultipartBody.Part.createFormData("file", file.name, file.asRequestBody(mime.toMediaType())),
        ).results
    }

    // ------------------------------------------------------------- diary

    suspend fun diary(classId: Int, on: LocalDate): ApiResult<List<TeacherDiaryEntryDto>> =
        safeCall { api.diary(classId, on.toString()) }

    suspend fun updateDiary(lessonId: Int, on: LocalDate, homework: String?, comment: String?): ApiResult<TeacherDiaryEntryDto> =
        safeCall { api.updateDiary(lessonId, on.toString(), DiaryLogUpdateRequest(homework, comment)) }

    // --------------------------------------------------------- materials

    suspend fun materials(): ApiResult<List<MaterialSummaryDto>> = safeCall { api.materials() }

    suspend fun assignments(): ApiResult<List<TeacherAssignmentDto>> = safeCall { api.assignments() }

    suspend fun results(id: Int): ApiResult<AssignmentResultsDto> = safeCall { api.results(id) }

    suspend fun transferGrades(id: Int, items: Map<Int, Int>): ApiResult<AssignmentResultsDto> =
        safeCall { api.transferGrades(id, GradeTransferRequest(items.map { (s, v) -> GradeTransferItem(s, v) })) }

    // ------------------------------------------------------------ school

    suspend fun calendar(): ApiResult<List<CalendarEventDto>> = safeCall { api.calendar() }

    suspend fun announcements(): ApiResult<List<SchoolAnnouncementDto>> = safeCall { api.announcements() }
}
