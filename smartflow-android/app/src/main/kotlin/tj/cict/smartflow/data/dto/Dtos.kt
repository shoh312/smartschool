package tj.cict.smartflow.data.dto

import java.time.LocalDate
import java.time.LocalDateTime
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ---------------------------------------------------------------- auth

@Serializable
data class LoginRequest(val phone: String, val password: String? = null)

@Serializable
data class LoginResponse(
    val status: String,
    @SerialName("access_token") val accessToken: String? = null,
    @SerialName("parent_id") val parentId: Int? = null,
    @SerialName("full_name") val fullName: String? = null,
    val phone: String? = null,
)

@Serializable
data class PhoneRequest(val phone: String)

@Serializable
data class RequestCodeResponse(
    val status: String,
    @SerialName("phone_masked") val phoneMasked: String,
    @SerialName("expires_in_seconds") val expiresInSeconds: Int,
    val delivered: Boolean = true,
)

@Serializable
data class VerifyCodeRequest(val phone: String, val code: String)

@Serializable
data class VerifyCodeResponse(
    val status: String,
    @SerialName("setup_token") val setupToken: String,
    @SerialName("full_name") val fullName: String? = null,
)

@Serializable
data class SetPasswordRequest(
    @SerialName("setup_token") val setupToken: String,
    @SerialName("full_name") val fullName: String,
    val password: String,
)

// ------------------------------------------------------------ students

@Serializable
data class StudentDto(
    val id: Int,
    @SerialName("class_id") val classId: Int? = null,
    @SerialName("class_name") val className: String? = null,
    @SerialName("parent_phone") val parentPhone: String? = null,
    @SerialName("parent_name") val parentName: String? = null,
    val username: String? = null,
    @SerialName("first_name") val firstName: String,
    @SerialName("last_name") val lastName: String,
    @SerialName("is_active") val isActive: Boolean = true,
)

// ---------------------------------------------------------- attendance

@Serializable
data class AttendanceDto(
    val id: Int,
    @SerialName("student_id") val studentId: Int,
    val status: String,
    @Serializable(LocalDateSerializer::class)
    @SerialName("attendance_date") val date: LocalDate,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("time_in") val timeIn: LocalDateTime? = null,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("time_out") val timeOut: LocalDateTime? = null,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("last_seen") val lastSeen: LocalDateTime? = null,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("detected_at") val detectedAt: LocalDateTime? = null,
)

// -------------------------------------------------------------- grades

@Serializable
data class GradeDto(
    val id: Int,
    @SerialName("student_id") val studentId: Int,
    val subject: String,
    val value: Int,
    val comment: String? = null,
    @SerialName("teacher_name") val teacherName: String? = null,
    @Serializable(LocalDateSerializer::class)
    @SerialName("grade_date") val date: LocalDate,
    val quarter: Int? = null,
)

// --------------------------------------------------------------- diary

@Serializable
data class DiaryEntryDto(
    @SerialName("lesson_id") val lessonId: Int,
    val subject: String,
    val room: String? = null,
    @SerialName("teacher_name") val teacherName: String? = null,
    @SerialName("start_time") val startTime: String,
    @SerialName("duration_minutes") val durationMinutes: Int,
    @Serializable(LocalDateSerializer::class)
    @SerialName("log_date") val date: LocalDate,
    val homework: String? = null,
    @SerialName("teacher_comment") val teacherComment: String? = null,
    val grade: Int? = null,
)

// --------------------------------------------------------- assignments

@Serializable
data class AssignmentDto(
    val id: Int,
    val title: String,
    val description: String? = null,
    val subject: String,
    @SerialName("teacher_name") val teacherName: String? = null,
    val mode: String,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("due_at") val dueAt: LocalDateTime? = null,
    @SerialName("question_count") val questionCount: Int = 0,
    @SerialName("max_score") val maxScore: Int = 0,
    @SerialName("attempts_used") val attemptsUsed: Int = 0,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("submitted_at") val submittedAt: LocalDateTime? = null,
    @SerialName("is_overdue") val isOverdue: Boolean = false,
    val score: Int? = null,
    val percent: Int? = null,
    @SerialName("score_visible") val scoreVisible: Boolean = false,
)

// ------------------------------------------------------------ calendar

@Serializable
data class CalendarEventDto(
    val id: Int,
    val title: String,
    val description: String? = null,
    @SerialName("event_type") val eventType: String,
    @Serializable(LocalDateSerializer::class)
    @SerialName("start_date") val startDate: LocalDate,
    @Serializable(LocalDateSerializer::class)
    @SerialName("end_date") val endDate: LocalDate? = null,
)

// ------------------------------------------------------- announcements

@Serializable
data class AnnouncementDto(
    val id: Int,
    val title: String,
    val body: String,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("created_at_local") val createdAt: LocalDateTime? = null,
)

// ------------------------------------------------------- notifications

@Serializable
data class NotificationDto(
    val id: Int,
    @SerialName("student_id") val studentId: Int? = null,
    @SerialName("event_type") val eventType: String,
    val title: String,
    val body: String,
    val status: String,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("sent_at") val sentAt: LocalDateTime? = null,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("created_at") val createdAt: LocalDateTime? = null,
)

// ----------------------------------------------------------- analytics

@Serializable
data class SubjectAverageDto(val subject: String, val average: Double, @SerialName("grade_count") val gradeCount: Int)

@Serializable
data class RankDto(val position: Int? = null, @SerialName("out_of") val outOf: Int)

@Serializable
data class QuarterPointDto(val quarter: Int, @SerialName("overall_average") val overallAverage: Double? = null)

@Serializable
data class AnalyticsDto(
    @SerialName("student_id") val studentId: Int,
    @SerialName("first_name") val firstName: String,
    @SerialName("last_name") val lastName: String,
    val quarter: Int,
    @SerialName("school_year") val schoolYear: Int? = null,
    @SerialName("overall_average") val overallAverage: Double? = null,
    @SerialName("class_rank") val classRank: RankDto,
    @SerialName("parallel_rank") val parallelRank: RankDto,
    @SerialName("school_rank") val schoolRank: RankDto,
    @SerialName("class_average") val classAverage: Double? = null,
    @SerialName("parallel_average") val parallelAverage: Double? = null,
    @SerialName("school_average") val schoolAverage: Double? = null,
    @SerialName("subject_breakdown") val subjects: List<SubjectAverageDto> = emptyList(),
    @SerialName("strongest_subject") val strongestSubject: String? = null,
    @SerialName("weakest_subject") val weakestSubject: String? = null,
    @SerialName("lesson_attendance_rate") val lessonAttendanceRate: Double? = null,
    val trend: List<QuarterPointDto> = emptyList(),
)

// ------------------------------------------------------- student login

@Serializable
data class StudentLoginRequest(val username: String, val password: String)

@Serializable
data class StudentLoginResponse(
    val status: String,
    @SerialName("access_token") val accessToken: String,
    @SerialName("student_id") val studentId: Int,
    @SerialName("full_name") val fullName: String? = null,
    @SerialName("class_name") val className: String? = null,
)

// --------------------------------------------------- assignment player

/** A block as the pupil sees it: a page of text, or a question without its key. */
@Serializable
data class BlockDto(
    val id: Int,
    val position: Int,
    @SerialName("block_type") val blockType: String,
    val body: String,
    @SerialName("question_type") val questionType: String? = null,
    val options: kotlinx.serialization.json.JsonElement? = null,
    val points: Int = 1,
)

@Serializable
data class AssignmentDetailDto(
    val id: Int,
    val title: String,
    val description: String? = null,
    val subject: String,
    @SerialName("teacher_name") val teacherName: String? = null,
    val mode: String,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("due_at") val dueAt: LocalDateTime? = null,
    @SerialName("max_attempts") val maxAttempts: Int? = null,
    @SerialName("question_count") val questionCount: Int = 0,
    @SerialName("max_score") val maxScore: Int = 0,
    @SerialName("attempts_used") val attemptsUsed: Int = 0,
    @SerialName("attempts_left") val attemptsLeft: Int? = null,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("submitted_at") val submittedAt: LocalDateTime? = null,
    @SerialName("is_overdue") val isOverdue: Boolean = false,
    @SerialName("can_start") val canStart: Boolean = false,
    val score: Int? = null,
    val percent: Int? = null,
    @SerialName("score_visible") val scoreVisible: Boolean = false,
    val blocks: List<BlockDto> = emptyList(),
    @SerialName("attempt_id") val attemptId: Int? = null,
    @SerialName("saved_answers") val savedAnswers: Map<String, kotlinx.serialization.json.JsonElement> = emptyMap(),
)

@Serializable
data class AnswerRequest(@SerialName("block_id") val blockId: Int, val answer: kotlinx.serialization.json.JsonElement)

@Serializable
data class AnswerResponse(val saved: Boolean = true, val correct: Boolean? = null)

@Serializable
data class AttemptResultDto(
    @SerialName("attempt_id") val attemptId: Int,
    @SerialName("score_visible") val scoreVisible: Boolean,
    val score: Int? = null,
    @SerialName("max_score") val maxScore: Int? = null,
    val percent: Int? = null,
    @SerialName("per_question") val perQuestion: Map<String, Boolean>? = null,
)
