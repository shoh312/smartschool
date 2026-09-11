package tj.cict.smartflow.data.dto

import java.time.LocalDate
import java.time.LocalDateTime
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// School-server shapes the director role reads and writes.

@Serializable
data class DirectorLoginRequest(val email: String, val password: String)

@Serializable
data class DirectorDto(
    val id: Int,
    @SerialName("school_id") val schoolId: Int? = null,
    @SerialName("full_name") val fullName: String,
    val email: String,
)

@Serializable
data class DirectorTokenResponse(
    @SerialName("access_token") val accessToken: String,
    val director: DirectorDto? = null,
    @SerialName("must_change_password") val mustChangePassword: Boolean = false,
)

@Serializable
data class ClassDto(
    val id: Int,
    val name: String,
    val grade: Int? = null,
    @SerialName("start_time") val startTime: String? = null,
    @SerialName("end_time") val endTime: String? = null,
)

@Serializable
data class ClassCreateRequest(val name: String, val grade: Int? = null)

@Serializable
data class CameraDto(
    val id: Int,
    @SerialName("class_id") val classId: Int? = null,
    val name: String,
    @SerialName("ip_address") val ipAddress: String? = null,
    @SerialName("rtsp_url") val rtspUrl: String? = null,
    @SerialName("is_active") val isActive: Boolean = true,
)

@Serializable
data class CameraCreateRequest(
    @SerialName("class_id") val classId: Int? = null,
    val name: String,
    @SerialName("ip_address") val ipAddress: String? = null,
    @SerialName("rtsp_url") val rtspUrl: String? = null,
    @SerialName("is_active") val isActive: Boolean = true,
)

/** The camera loop's own view of itself; keys as `camera_statuses()` writes them. */
@Serializable
data class CameraStatusDto(
    @SerialName("camera_id") val cameraId: Int,
    @SerialName("camera_name") val cameraName: String? = null,
    @SerialName("class_name") val className: String? = null,
    val connected: Boolean = false,
    val detecting: Boolean = false,
    val phase: String? = null,
    @SerialName("roll_call") val rollCall: Boolean = false,
    @SerialName("seconds_to_detect") val secondsToDetect: Int? = null,
    @SerialName("seconds_to_roll_call_close") val secondsToRollCallClose: Int? = null,
    @SerialName("detecting_for") val detectingFor: Int? = null,
    @SerialName("stale_seconds") val staleSeconds: Int? = null,
)

@Serializable
data class LiveStatusDto(
    @SerialName("student_id") val studentId: Int,
    @SerialName("first_name") val firstName: String,
    @SerialName("last_name") val lastName: String,
    @SerialName("class_id") val classId: Int? = null,
    @SerialName("class_name") val className: String? = null,
    @SerialName("class_lesson_state") val classLessonState: String = "none",
    val status: String,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("time_in") val timeIn: LocalDateTime? = null,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("last_seen") val lastSeen: LocalDateTime? = null,
    @Serializable(LocalDateTimeSerializer::class)
    @SerialName("detected_at") val detectedAt: LocalDateTime? = null,
)

@Serializable
data class SchoolSettingsDto(
    @SerialName("live_video_enabled") val liveVideoEnabled: Boolean = true,
    @SerialName("group_mode") val groupMode: Boolean = false,
    @SerialName("sms_enabled") val smsEnabled: Boolean = true,
    @SerialName("is_active") val isActive: Boolean = true,
)

@Serializable
data class SchoolSettingsUpdate(
    @SerialName("live_video_enabled") val liveVideoEnabled: Boolean? = null,
    @SerialName("group_mode") val groupMode: Boolean? = null,
    @SerialName("sms_enabled") val smsEnabled: Boolean? = null,
    @SerialName("is_active") val isActive: Boolean? = null,
)

@Serializable
data class TeacherCreateRequest(
    @SerialName("full_name") val fullName: String,
    val email: String,
    val password: String,
    val subject: String? = null,
)

@Serializable
data class AssignClassRequest(@SerialName("class_id") val classId: Int, val subject: String)

@Serializable
data class ClassSubjectDto(val id: Int, val subject: String? = null, @SerialName("teacher_id") val teacherId: Int, @SerialName("teacher_name") val teacherName: String)

@Serializable
data class AnnouncementCreateRequest(val title: String, val body: String, @SerialName("class_id") val classId: Int? = null)

@Serializable
data class CalendarEventCreateRequest(
    val title: String,
    val description: String? = null,
    @SerialName("event_type") val eventType: String,
    @Serializable(LocalDateSerializer::class)
    @SerialName("start_date") val startDate: LocalDate,
    @Serializable(LocalDateSerializer::class)
    @SerialName("end_date") val endDate: LocalDate? = null,
    @SerialName("class_id") val classId: Int? = null,
)

@Serializable
data class LeaderboardEntryDto(
    @SerialName("student_id") val studentId: Int,
    @SerialName("first_name") val firstName: String,
    @SerialName("last_name") val lastName: String,
    @SerialName("class_id") val classId: Int? = null,
    @SerialName("class_name") val className: String? = null,
    @SerialName("overall_average") val overallAverage: Double? = null,
    val position: Int,
    @SerialName("out_of") val outOf: Int,
)

@Serializable
data class DeclinerDto(
    @SerialName("student_id") val studentId: Int,
    @SerialName("first_name") val firstName: String,
    @SerialName("last_name") val lastName: String,
    @SerialName("class_name") val className: String? = null,
    @SerialName("current_average") val currentAverage: Double,
    @SerialName("previous_average") val previousAverage: Double,
    val delta: Double,
)

@Serializable
data class NeedsAttentionDto(
    @SerialName("bottom_performers") val bottomPerformers: List<LeaderboardEntryDto> = emptyList(),
    @SerialName("biggest_decliners") val biggestDecliners: List<DeclinerDto> = emptyList(),
)

@Serializable
data class ClassSubjectAverageDto(val subject: String, val average: Double, @SerialName("grade_count") val gradeCount: Int, @SerialName("student_count") val studentCount: Int)
