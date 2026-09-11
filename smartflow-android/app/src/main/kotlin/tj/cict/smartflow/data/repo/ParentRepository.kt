package tj.cict.smartflow.data.repo

import java.time.LocalDate
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.network.map
import tj.cict.smartflow.core.network.safeCall as rawCall
import tj.cict.smartflow.core.session.SessionStore
import tj.cict.smartflow.data.api.PublicApi
import kotlinx.serialization.json.JsonElement
import tj.cict.smartflow.data.dto.AnalyticsDto
import tj.cict.smartflow.data.dto.AnswerRequest
import tj.cict.smartflow.data.dto.AnswerResponse
import tj.cict.smartflow.data.dto.AssignmentDetailDto
import tj.cict.smartflow.data.dto.AttemptResultDto
import tj.cict.smartflow.data.dto.AnnouncementDto
import tj.cict.smartflow.data.dto.AssignmentDto
import tj.cict.smartflow.data.dto.CalendarEventDto
import tj.cict.smartflow.data.dto.DiaryEntryDto
import tj.cict.smartflow.data.dto.GradeDto
import tj.cict.smartflow.data.dto.NotificationDto
import tj.cict.smartflow.domain.AttendanceDay
import tj.cict.smartflow.domain.Child
import tj.cict.smartflow.domain.toChild
import tj.cict.smartflow.domain.toDay

/** Everything a parent reads about their children. Thin: one call, one map. */
class ParentRepository(private val api: PublicApi, private val session: SessionStore) {

    // A rejected token means the session is over, whichever screen noticed
    // first. Clearing it here flips the whole app back to sign-in, instead
    // of every screen showing its own "session ended" and none acting.
    private suspend fun isDemo() = session.token() == DemoData.TOKEN

    private suspend fun <T> safeCall(block: suspend () -> T): ApiResult<T> {
        val result = rawCall(block)
        if (result is ApiResult.Err && result.error == ApiError.Unauthorized) session.clear()
        return result
    }

    suspend fun children(): ApiResult<List<Child>> =
        if (isDemo()) ApiResult.Ok(DemoData.children) else
        safeCall { api.myStudents() }.map { list -> list.filter { it.isActive }.map { it.toChild() } }

    suspend fun attendance(childId: Int): ApiResult<List<AttendanceDay>> =
        if (isDemo()) ApiResult.Ok(DemoData.attendance(childId)) else
        safeCall { api.attendance(childId) }.map { list -> list.map { it.toDay() } }

    suspend fun grades(childId: Int): ApiResult<List<GradeDto>> =
        if (isDemo()) ApiResult.Ok(DemoData.grades(childId)) else safeCall { api.grades(childId) }

    suspend fun diary(childId: Int, on: LocalDate): ApiResult<List<DiaryEntryDto>> =
        if (isDemo()) ApiResult.Ok(DemoData.diary(childId, on)) else
        safeCall { api.diary(childId, on.toString()) }

    suspend fun homework(childId: Int): ApiResult<List<DiaryEntryDto>> =
        if (isDemo()) ApiResult.Ok(DemoData.homework(childId)) else safeCall { api.homework(childId) }

    suspend fun assignments(childId: Int): ApiResult<List<AssignmentDto>> =
        if (isDemo()) ApiResult.Ok(DemoData.assignments(childId)) else safeCall { api.assignments(childId) }

    suspend fun calendar(childId: Int): ApiResult<List<CalendarEventDto>> =
        if (isDemo()) ApiResult.Ok(DemoData.calendar()) else safeCall { api.calendar(childId) }

    suspend fun announcements(childId: Int): ApiResult<List<AnnouncementDto>> =
        if (isDemo()) ApiResult.Ok(DemoData.announcements()) else
        safeCall { api.announcements(childId) }

    suspend fun notifications(parentId: Int): ApiResult<List<NotificationDto>> =
        if (isDemo()) ApiResult.Ok(DemoData.notifications()) else
        safeCall { api.notifications(parentId) }

    suspend fun analytics(childId: Int, quarter: Int?): ApiResult<AnalyticsDto> =
        if (isDemo()) ApiResult.Ok(DemoData.analytics(childId, quarter)) else
        safeCall { api.analytics(childId, quarter) }

    // ------------------------------------------------- assignment player

    suspend fun assignmentDetail(childId: Int, id: Int): ApiResult<AssignmentDetailDto> =
        if (isDemo()) DemoData.assignmentDetail(childId, id)?.let { ApiResult.Ok(it) } ?: ApiResult.Err(ApiError.Detail("not_found", 404))
        else safeCall { api.assignment(id, childId) }

    suspend fun startAttempt(childId: Int, id: Int): ApiResult<AssignmentDetailDto> =
        if (isDemo()) DemoData.startAttempt(childId, id)?.let { ApiResult.Ok(it) } ?: ApiResult.Err(ApiError.Detail("not_found", 404))
        else safeCall { api.startAttempt(id, childId) }

    suspend fun answer(attemptId: Int, blockId: Int, answer: JsonElement): ApiResult<AnswerResponse> =
        if (isDemo()) ApiResult.Ok(DemoData.answer(attemptId, blockId, answer))
        else safeCall { api.answer(attemptId, AnswerRequest(blockId, answer)) }

    suspend fun submit(attemptId: Int): ApiResult<AttemptResultDto> =
        if (isDemo()) ApiResult.Ok(DemoData.submit(attemptId))
        else safeCall { api.submit(attemptId) }
}
