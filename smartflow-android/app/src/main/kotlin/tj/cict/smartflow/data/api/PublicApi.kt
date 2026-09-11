package tj.cict.smartflow.data.api

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query
import tj.cict.smartflow.data.dto.AnalyticsDto
import tj.cict.smartflow.data.dto.AnswerRequest
import tj.cict.smartflow.data.dto.AnswerResponse
import tj.cict.smartflow.data.dto.AssignmentDetailDto
import tj.cict.smartflow.data.dto.AttemptResultDto
import tj.cict.smartflow.data.dto.StudentLoginRequest
import tj.cict.smartflow.data.dto.StudentLoginResponse
import tj.cict.smartflow.data.dto.AnnouncementDto
import tj.cict.smartflow.data.dto.AssignmentDto
import tj.cict.smartflow.data.dto.AttendanceDto
import tj.cict.smartflow.data.dto.CalendarEventDto
import tj.cict.smartflow.data.dto.DiaryEntryDto
import tj.cict.smartflow.data.dto.GradeDto
import tj.cict.smartflow.data.dto.LoginRequest
import tj.cict.smartflow.data.dto.LoginResponse
import tj.cict.smartflow.data.dto.NotificationDto
import tj.cict.smartflow.data.dto.PhoneRequest
import tj.cict.smartflow.data.dto.RequestCodeResponse
import tj.cict.smartflow.data.dto.SetPasswordRequest
import tj.cict.smartflow.data.dto.StudentDto
import tj.cict.smartflow.data.dto.VerifyCodeRequest
import tj.cict.smartflow.data.dto.VerifyCodeResponse

/** The parent-facing surface of the public server. */
interface PublicApi {
    @POST("auth/login")
    suspend fun login(@Body body: LoginRequest): LoginResponse

    @POST("auth/request-code")
    suspend fun requestCode(@Body body: PhoneRequest): RequestCodeResponse

    @POST("auth/verify-code")
    suspend fun verifyCode(@Body body: VerifyCodeRequest): VerifyCodeResponse

    @POST("auth/set-password")
    suspend fun setPassword(@Body body: SetPasswordRequest): LoginResponse

    @POST("auth/student/login")
    suspend fun studentLogin(@Body body: StudentLoginRequest): StudentLoginResponse

    @GET("students/me")
    suspend fun myStudents(): List<StudentDto>

    @GET("attendance/history")
    suspend fun attendance(@Query("student_id") studentId: Int, @Query("limit") limit: Int = 200): List<AttendanceDto>

    @GET("grades")
    suspend fun grades(@Query("student_id") studentId: Int, @Query("limit") limit: Int = 300): List<GradeDto>

    @GET("diary/{studentId}")
    suspend fun diary(@Path("studentId") studentId: Int, @Query("on") on: String): List<DiaryEntryDto>

    @GET("diary/homework/{studentId}")
    suspend fun homework(@Path("studentId") studentId: Int, @Query("days") days: Int = 14): List<DiaryEntryDto>

    @GET("materials/assignments")
    suspend fun assignments(@Query("student_id") studentId: Int): List<AssignmentDto>

    @GET("materials/assignments/{id}")
    suspend fun assignment(@Path("id") id: Int, @Query("student_id") studentId: Int): AssignmentDetailDto

    @POST("materials/assignments/{id}/start")
    suspend fun startAttempt(@Path("id") id: Int, @Query("student_id") studentId: Int): AssignmentDetailDto

    @POST("materials/attempts/{attemptId}/answer")
    suspend fun answer(@Path("attemptId") attemptId: Int, @Body body: AnswerRequest): AnswerResponse

    @POST("materials/attempts/{attemptId}/submit")
    suspend fun submit(@Path("attemptId") attemptId: Int): AttemptResultDto

    @GET("calendar/events")
    suspend fun calendar(@Query("student_id") studentId: Int): List<CalendarEventDto>

    @GET("announcements")
    suspend fun announcements(@Query("student_id") studentId: Int): List<AnnouncementDto>

    @GET("notifications/parent/{parentId}")
    suspend fun notifications(@Path("parentId") parentId: Int, @Query("limit") limit: Int = 100): List<NotificationDto>

    @GET("analytics/student/{studentId}")
    suspend fun analytics(@Path("studentId") studentId: Int, @Query("quarter") quarter: Int?): AnalyticsDto
}
