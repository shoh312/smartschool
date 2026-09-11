package tj.cict.smartflow.data.dto

import java.time.LocalDate
import java.time.LocalDateTime
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// School-server shapes the teacher role reads and writes.

@Serializable
data class TeacherLoginRequest(val email: String, val password: String)

@Serializable
data class TeacherDto(
    val id: Int,
    @SerialName("full_name") val fullName: String,
    val email: String,
    val subject: String? = null,
    @SerialName("is_active") val isActive: Boolean = true,
)

@Serializable
data class TeacherTokenResponse(@SerialName("access_token") val accessToken: String, val teacher: TeacherDto)

/** One (class, subject) the teacher is assigned to. */
@Serializable
data class ClassAssignmentDto(
    val id: Int,
    @SerialName("class_id") val classId: Int,
    val subject: String? = null,
    @SerialName("class_name") val className: String? = null,
)

@Serializable
data class GradeCreateRequest(
    @SerialName("student_id") val studentId: Int,
    @SerialName("class_id") val classId: Int,
    val subject: String,
    val value: Int,
    val comment: String? = null,
)

@Serializable
data class GradeUpdateRequest(val value: Int? = null, val comment: String? = null)

@Serializable
data class AbsenceDto(
    @SerialName("student_id") val studentId: Int,
    val subject: String,
    @Serializable(LocalDateSerializer::class) val date: LocalDate,
    @SerialName("lesson_id") val lessonId: Int,
)

/** The class diary as the school server returns it (teacher id included). */
@Serializable
data class TeacherDiaryEntryDto(
    @SerialName("lesson_id") val lessonId: Int,
    val subject: String,
    @SerialName("start_time") val startTime: String,
    @SerialName("duration_minutes") val durationMinutes: Int,
    val room: String? = null,
    @SerialName("teacher_id") val teacherId: Int? = null,
    @SerialName("teacher_name") val teacherName: String? = null,
    val homework: String? = null,
    @SerialName("teacher_comment") val teacherComment: String? = null,
)

@Serializable
data class DiaryLogUpdateRequest(val homework: String? = null, @SerialName("teacher_comment") val teacherComment: String? = null)

@Serializable
data class ScanRowDto(
    @SerialName("raw_name") val rawName: String,
    @SerialName("student_id") val studentId: Int? = null,
    @SerialName("matched_name") val matchedName: String? = null,
    val confidence: Double = 0.0,
    val absent: Boolean = false,
    val grade: Int? = null,
)

@Serializable
data class ScanResponse(val results: List<ScanRowDto> = emptyList())

@Serializable
data class MaterialSummaryDto(
    val id: Int,
    val title: String,
    val description: String? = null,
    val subject: String,
    @SerialName("teacher_id") val teacherId: Int,
    @SerialName("teacher_name") val teacherName: String? = null,
    @SerialName("question_count") val questionCount: Int = 0,
    @SerialName("page_count") val pageCount: Int = 0,
    @SerialName("max_score") val maxScore: Int = 0,
    @SerialName("assigned_class_count") val assignedClassCount: Int = 0,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("updated_at") val updatedAt: LocalDateTime? = null,
)

@Serializable
data class TeacherAssignmentDto(
    val id: Int,
    @SerialName("material_id") val materialId: Int,
    @SerialName("material_title") val materialTitle: String,
    val subject: String,
    @SerialName("class_id") val classId: Int,
    @SerialName("class_name") val className: String? = null,
    val mode: String,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("due_at") val dueAt: LocalDateTime? = null,
    @SerialName("max_attempts") val maxAttempts: Int? = null,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("published_at") val publishedAt: LocalDateTime? = null,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("grades_transferred_at") val gradesTransferredAt: LocalDateTime? = null,
    @SerialName("question_count") val questionCount: Int = 0,
    @SerialName("max_score") val maxScore: Int = 0,
    @SerialName("student_count") val studentCount: Int = 0,
    @SerialName("submitted_count") val submittedCount: Int = 0,
    @SerialName("results_visible") val resultsVisible: Boolean = false,
)

@Serializable
data class ResultRowDto(
    @SerialName("student_id") val studentId: Int,
    @SerialName("student_name") val studentName: String,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("submitted_at") val submittedAt: LocalDateTime? = null,
    @SerialName("attempt_count") val attemptCount: Int = 0,
    val score: Int? = null,
    @SerialName("max_score") val maxScore: Int? = null,
    val percent: Int? = null,
    @SerialName("suggested_grade") val suggestedGrade: Int? = null,
    val transferred: Boolean = false,
)

@Serializable
data class AssignmentResultsDto(
    val assignment: TeacherAssignmentDto,
    @SerialName("results_visible") val resultsVisible: Boolean,
    val rows: List<ResultRowDto> = emptyList(),
)

@Serializable
data class GradeTransferItem(@SerialName("student_id") val studentId: Int, val value: Int)

@Serializable
data class GradeTransferRequest(val items: List<GradeTransferItem>)

@Serializable
data class SchoolAnnouncementDto(
    val id: Int,
    @SerialName("class_id") val classId: Int? = null,
    val title: String,
    val body: String,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("created_at") val createdAt: LocalDateTime? = null,
)

// ------------------------------------------------ authoring materials

/** A block as the teacher writes it: the key travels with it here. */
@Serializable
data class BlockInDto(
    @SerialName("block_type") val blockType: String,
    val body: String = "",
    @SerialName("question_type") val questionType: String? = null,
    val options: kotlinx.serialization.json.JsonElement? = null,
    val correct: kotlinx.serialization.json.JsonElement? = null,
    val points: Int = 1,
    /** Present on saved and drafted blocks; ignored when sending. */
    val id: Int? = null,
    val position: Int = 0,
)

@Serializable
data class MaterialCreateRequest(val title: String, val description: String? = null, val subject: String? = null, val blocks: List<BlockInDto>)

@Serializable
data class MaterialUpdateRequest(val title: String? = null, val description: String? = null, val blocks: List<BlockInDto>? = null)

@Serializable
data class MaterialFullDto(
    val id: Int,
    val title: String,
    val description: String? = null,
    val subject: String,
    val blocks: List<BlockInDto> = emptyList(),
)

@Serializable
data class AiGenerateResponse(
    val title: String = "",
    val description: String? = null,
    val blocks: List<BlockInDto> = emptyList(),
    @SerialName("dropped_count") val droppedCount: Int = 0,
)

@Serializable
data class AssignmentCreateRequest(
    @SerialName("material_id") val materialId: Int,
    @SerialName("class_ids") val classIds: List<Int>,
    val mode: String = "practice",
    @SerialName("due_at") val dueAt: String? = null,
    @SerialName("max_attempts") val maxAttempts: Int? = null,
)
