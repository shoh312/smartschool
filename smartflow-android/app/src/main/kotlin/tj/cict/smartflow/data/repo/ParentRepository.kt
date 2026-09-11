package tj.cict.smartflow.data.repo

import java.time.LocalDate
import kotlinx.serialization.json.JsonElement
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.network.map
import tj.cict.smartflow.core.network.safeCall as rawCall
import tj.cict.smartflow.core.session.SessionStore
import tj.cict.smartflow.data.api.PublicApi
import tj.cict.smartflow.data.dto.AnalyticsDto
import tj.cict.smartflow.data.dto.AnnouncementDto
import tj.cict.smartflow.data.dto.AnswerRequest
import tj.cict.smartflow.data.dto.AnswerResponse
import tj.cict.smartflow.data.dto.AssignmentDetailDto
import tj.cict.smartflow.data.dto.AssignmentDto
import tj.cict.smartflow.data.dto.AttemptResultDto
import tj.cict.smartflow.data.dto.CalendarEventDto
import tj.cict.smartflow.data.dto.DiaryEntryDto
import tj.cict.smartflow.data.dto.GradeDto
import tj.cict.smartflow.data.dto.NotificationDto
import tj.cict.smartflow.domain.AttendanceDay
import tj.cict.smartflow.domain.Child
import tj.cict.smartflow.domain.toChild
import tj.cict.smartflow.domain.toDay

/** Everything a parent or pupil reads from the Public Server. Thin: one call, one map. */
class ParentRepository(private val api: PublicApi, private val session: SessionStore) {

    // A rejected token means the session is over, whichever screen noticed
    // first. Clearing it here flips the whole app back to sign-in, instead
    // of every screen showing its own "session ended" and none acting.
    private suspend fun <T> safeCall(block: suspend () -> T): ApiResult<T> {
        val result = rawCall(block)
        if (result is ApiResult.Err && result.error == ApiError.Unauthorized) session.clear()
        return result
    }

    suspend fun children(): ApiResult<List<Child>> =
        safeCall { api.myStudents() }.map { list -> list.filter { it.isActive }.map { it.toChild() } }

    suspend fun attendance(childId: Int): ApiResult<List<AttendanceDay>> =
        safeCall { api.attendance(childId) }.map { list -> list.map { it.toDay() } }

    suspend fun grades(childId: Int): ApiResult<List<GradeDto>> = safeCall { api.grades(childId) }

    suspend fun diary(childId: Int, on: LocalDate): ApiResult<List<DiaryEntryDto>> =
        safeCall { api.diary(childId, on.toString()) }

    suspend fun homework(childId: Int): ApiResult<List<DiaryEntryDto>> = safeCall { api.homework(childId) }

    suspend fun assignments(childId: Int): ApiResult<List<AssignmentDto>> = safeCall { api.assignments(childId) }

    suspend fun calendar(childId: Int): ApiResult<List<CalendarEventDto>> = safeCall { api.calendar(childId) }

    suspend fun announcements(childId: Int): ApiResult<List<AnnouncementDto>> =
        safeCall { api.announcements(childId) }

    suspend fun notifications(parentId: Int): ApiResult<List<NotificationDto>> =
        safeCall { api.notifications(parentId) }

    suspend fun analytics(childId: Int, quarter: Int?): ApiResult<AnalyticsDto> =
        safeCall { api.analytics(childId, quarter) }

    // ------------------------------------------------- assignment player

    suspend fun assignmentDetail(childId: Int, id: Int): ApiResult<AssignmentDetailDto> =
        safeCall { api.assignment(id, childId) }

    suspend fun startAttempt(childId: Int, id: Int): ApiResult<AssignmentDetailDto> =
        safeCall { api.startAttempt(id, childId) }

    suspend fun answer(attemptId: Int, blockId: Int, answer: JsonElement): ApiResult<AnswerResponse> =
        safeCall { api.answer(attemptId, AnswerRequest(blockId, answer)) }

    suspend fun submit(attemptId: Int): ApiResult<AttemptResultDto> = safeCall { api.submit(attemptId) }
}
