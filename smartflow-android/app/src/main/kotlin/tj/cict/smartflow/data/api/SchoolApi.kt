package tj.cict.smartflow.data.api

import okhttp3.MultipartBody
import okhttp3.RequestBody
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Part
import retrofit2.http.Path
import retrofit2.http.Query
import tj.cict.smartflow.data.dto.AbsenceDto
import tj.cict.smartflow.data.dto.AiGenerateResponse
import tj.cict.smartflow.data.dto.AssignmentCreateRequest
import tj.cict.smartflow.data.dto.MaterialCreateRequest
import tj.cict.smartflow.data.dto.MaterialFullDto
import tj.cict.smartflow.data.dto.MaterialUpdateRequest
import tj.cict.smartflow.data.dto.AnalyticsDto
import tj.cict.smartflow.data.dto.AnnouncementCreateRequest
import tj.cict.smartflow.data.dto.AssignClassRequest
import tj.cict.smartflow.data.dto.CalendarEventCreateRequest
import tj.cict.smartflow.data.dto.CameraCreateRequest
import tj.cict.smartflow.data.dto.CameraDto
import tj.cict.smartflow.data.dto.CameraPositionCreateRequest
import tj.cict.smartflow.data.dto.CameraPositionDto
import tj.cict.smartflow.data.dto.CameraStatusDto
import tj.cict.smartflow.data.dto.ClassCreateRequest
import tj.cict.smartflow.data.dto.ClassDto
import tj.cict.smartflow.data.dto.ClassSubjectAverageDto
import tj.cict.smartflow.data.dto.ClassSubjectDto
import tj.cict.smartflow.data.dto.DirectorLoginRequest
import tj.cict.smartflow.data.dto.DirectorTokenResponse
import tj.cict.smartflow.data.dto.LeaderboardEntryDto
import tj.cict.smartflow.data.dto.LiveStatusDto
import tj.cict.smartflow.data.dto.NeedsAttentionDto
import tj.cict.smartflow.data.dto.SchoolSettingsDto
import tj.cict.smartflow.data.dto.SchoolSettingsUpdate
import tj.cict.smartflow.data.dto.TeacherCreateRequest
import retrofit2.http.PUT
import tj.cict.smartflow.data.dto.AssignmentResultsDto
import tj.cict.smartflow.data.dto.CalendarEventDto
import tj.cict.smartflow.data.dto.ClassAssignmentDto
import tj.cict.smartflow.data.dto.DiaryLogUpdateRequest
import tj.cict.smartflow.data.dto.GradeCreateRequest
import tj.cict.smartflow.data.dto.GradeDto
import tj.cict.smartflow.data.dto.GradeTransferRequest
import tj.cict.smartflow.data.dto.GradeUpdateRequest
import tj.cict.smartflow.data.dto.MaterialSummaryDto
import tj.cict.smartflow.data.dto.ScanResponse
import tj.cict.smartflow.data.dto.SchoolAnnouncementDto
import tj.cict.smartflow.data.dto.StudentDto
import tj.cict.smartflow.data.dto.TeacherAssignmentDto
import tj.cict.smartflow.data.dto.TeacherDiaryEntryDto
import tj.cict.smartflow.data.dto.TeacherDto
import tj.cict.smartflow.data.dto.TeacherLoginRequest
import tj.cict.smartflow.data.dto.TeacherTokenResponse

/** The school server on the LAN, as a teacher uses it. */
interface SchoolApi {
    @POST("auth/teacher/login")
    suspend fun teacherLogin(@Body body: TeacherLoginRequest): TeacherTokenResponse

    @GET("auth/teacher/me")
    suspend fun teacherMe(): TeacherDto

    @GET("teachers/me/classes")
    suspend fun myClasses(): List<ClassAssignmentDto>

    @GET("teachers/me/classes/{classId}/students")
    suspend fun roster(@Path("classId") classId: Int): List<StudentDto>

    @GET("grades")
    suspend fun grades(@Query("class_id") classId: Int, @Query("subject") subject: String, @Query("limit") limit: Int = 500): List<GradeDto>

    @POST("grades")
    suspend fun createGrade(@Body body: GradeCreateRequest): GradeDto

    @PATCH("grades/{id}")
    suspend fun updateGrade(@Path("id") id: Int, @Body body: GradeUpdateRequest): GradeDto

    @DELETE("grades/{id}")
    suspend fun deleteGrade(@Path("id") id: Int)

    @GET("journal/absences")
    suspend fun absences(@Query("class_id") classId: Int, @Query("subject") subject: String?): List<AbsenceDto>

    @Multipart
    @POST("journal/scan-photo")
    suspend fun scanJournal(
        @Part("class_id") classId: RequestBody,
        @Part("subject") subject: RequestBody,
        @Part file: MultipartBody.Part,
    ): ScanResponse

    @GET("diary")
    suspend fun diary(@Query("class_id") classId: Int, @Query("on") on: String): List<TeacherDiaryEntryDto>

    @PATCH("diary/{lessonId}")
    suspend fun updateDiary(@Path("lessonId") lessonId: Int, @Query("on") on: String, @Body body: DiaryLogUpdateRequest): TeacherDiaryEntryDto

    @GET("materials")
    suspend fun materials(@Query("scope") scope: String = "mine"): List<MaterialSummaryDto>

    @GET("materials/{id}")
    suspend fun material(@Path("id") id: Int): MaterialFullDto

    @POST("materials")
    suspend fun createMaterial(@Body body: MaterialCreateRequest): MaterialFullDto

    @PATCH("materials/{id}")
    suspend fun updateMaterial(@Path("id") id: Int, @Body body: MaterialUpdateRequest): MaterialFullDto

    @DELETE("materials/{id}")
    suspend fun deleteMaterial(@Path("id") id: Int)

    @Multipart
    @POST("materials/ai/generate")
    suspend fun aiGenerate(
        @Part("kind") kind: RequestBody,
        @Part("topic") topic: RequestBody?,
        @Part("source_text") sourceText: RequestBody?,
        @Part("question_count") questionCount: RequestBody,
        @Part("page_count") pageCount: RequestBody,
        @Part("question_types") questionTypes: RequestBody,
        @Part("difficulty") difficulty: RequestBody,
        @Part("language") language: RequestBody,
        @Part file: MultipartBody.Part?,
    ): AiGenerateResponse

    @POST("material-assignments")
    suspend fun createAssignments(@Body body: AssignmentCreateRequest): List<TeacherAssignmentDto>

    @GET("material-assignments")
    suspend fun assignments(): List<TeacherAssignmentDto>

    @GET("material-assignments/{id}/results")
    suspend fun results(@Path("id") id: Int): AssignmentResultsDto

    @POST("material-assignments/{id}/transfer-grades")
    suspend fun transferGrades(@Path("id") id: Int, @Body body: GradeTransferRequest): AssignmentResultsDto

    @GET("calendar/events")
    suspend fun calendar(): List<CalendarEventDto>

    @GET("announcements")
    suspend fun announcements(): List<SchoolAnnouncementDto>

    // ------------------------------------------------------------ director

    @POST("auth/director/login")
    suspend fun directorLogin(@Body body: DirectorLoginRequest): DirectorTokenResponse

    @GET("classes")
    suspend fun classes(): List<ClassDto>

    @POST("classes")
    suspend fun createClass(@Body body: ClassCreateRequest): ClassDto

    @DELETE("classes/{id}")
    suspend fun deleteClass(@Path("id") id: Int)

    @GET("students")
    suspend fun allStudents(): List<StudentDto>

    @Multipart
    @POST("students/director-create")
    suspend fun createStudent(
        @Part("first_name") firstName: RequestBody,
        @Part("last_name") lastName: RequestBody,
        @Part("class_id") classId: RequestBody,
        @Part("parent_phone") parentPhone: RequestBody,
        @Part("parent_full_name") parentName: RequestBody?,
        @Part file: MultipartBody.Part,
    ): StudentDto

    @Multipart
    @PUT("students/{id}")
    suspend fun updateStudent(
        @Path("id") id: Int,
        @Part("first_name") firstName: RequestBody,
        @Part("last_name") lastName: RequestBody,
        @Part("class_id") classId: RequestBody,
        @Part("parent_phone") parentPhone: RequestBody?,
        @Part("username") username: RequestBody?,
        @Part("password") password: RequestBody?,
        @Part file: MultipartBody.Part?,
    ): StudentDto

    @DELETE("students/{id}")
    suspend fun deleteStudent(@Path("id") id: Int)

    @GET("teachers")
    suspend fun teachers(): List<TeacherDto>

    @POST("teachers")
    suspend fun createTeacher(@Body body: TeacherCreateRequest): TeacherDto

    @POST("teachers/{id}/classes")
    suspend fun assignClass(@Path("id") teacherId: Int, @Body body: AssignClassRequest): ClassAssignmentDto

    @GET("classes/{id}/subjects")
    suspend fun classSubjects(@Path("id") classId: Int): List<ClassSubjectDto>

    @GET("cameras")
    suspend fun cameras(): List<CameraDto>

    @GET("cameras/status")
    suspend fun cameraStatus(): List<CameraStatusDto>

    @POST("cameras")
    suspend fun createCamera(@Body body: CameraCreateRequest): CameraDto

    @PUT("cameras/{id}")
    suspend fun updateCamera(@Path("id") id: Int, @Body body: CameraCreateRequest): CameraDto

    @DELETE("cameras/{id}")
    suspend fun deleteCamera(@Path("id") id: Int)

    @GET("cameras/{id}/positions")
    suspend fun positions(@Path("id") cameraId: Int): List<CameraPositionDto>

    @POST("cameras/{id}/positions")
    suspend fun createPosition(@Path("id") cameraId: Int, @Body body: CameraPositionCreateRequest): CameraPositionDto

    @DELETE("cameras/{id}/positions/{positionId}")
    suspend fun deletePosition(@Path("id") cameraId: Int, @Path("positionId") positionId: Int)

    @GET("attendance/live-status")
    suspend fun liveStatus(): List<LiveStatusDto>

    @GET("school/settings")
    suspend fun settings(): SchoolSettingsDto

    @PUT("school/settings")
    suspend fun updateSettings(@Body body: SchoolSettingsUpdate): SchoolSettingsDto

    @POST("announcements")
    suspend fun createAnnouncement(@Body body: AnnouncementCreateRequest): SchoolAnnouncementDto

    @DELETE("announcements/{id}")
    suspend fun deleteAnnouncement(@Path("id") id: Int)

    @POST("calendar/events")
    suspend fun createEvent(@Body body: CalendarEventCreateRequest): CalendarEventDto

    @DELETE("calendar/events/{id}")
    suspend fun deleteEvent(@Path("id") id: Int)

    @GET("analytics/student/{id}")
    suspend fun studentAnalytics(@Path("id") studentId: Int, @Query("quarter") quarter: Int? = null): AnalyticsDto

    @GET("analytics/school/ranking")
    suspend fun schoolRanking(@Query("quarter") quarter: Int? = null): List<LeaderboardEntryDto>

    @GET("analytics/class/{id}/ranking")
    suspend fun classRanking(@Path("id") classId: Int, @Query("quarter") quarter: Int? = null): List<LeaderboardEntryDto>

    @GET("analytics/school/needs-attention")
    suspend fun needsAttention(@Query("quarter") quarter: Int? = null): NeedsAttentionDto

    @GET("analytics/class/{id}/subjects")
    suspend fun classSubjectAverages(@Path("id") classId: Int, @Query("quarter") quarter: Int? = null): List<ClassSubjectAverageDto>
}
