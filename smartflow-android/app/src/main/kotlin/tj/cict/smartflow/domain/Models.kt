package tj.cict.smartflow.domain

import java.time.LocalDate
import java.time.LocalDateTime
import tj.cict.smartflow.data.dto.AttendanceDto
import tj.cict.smartflow.data.dto.StudentDto

enum class AttendanceStatus { PRESENT, LATE, ABSENT, LEFT_SCHOOL, UNKNOWN;

    companion object {
        fun fromApi(raw: String?): AttendanceStatus = when (raw) {
            "present" -> PRESENT
            "late" -> LATE
            "absent" -> ABSENT
            "left_school" -> LEFT_SCHOOL
            else -> UNKNOWN
        }
    }

    /** Was the child physically at school at some point that day. */
    val arrived: Boolean get() = this == PRESENT || this == LATE || this == LEFT_SCHOOL
}

data class Child(
    val id: Int,
    val firstName: String,
    val lastName: String,
    val className: String?,
) {
    val fullName: String get() = "$firstName $lastName".trim()
    val initials: String get() = listOf(firstName, lastName)
        .mapNotNull { it.firstOrNull()?.uppercaseChar() }
        .joinToString("")
}

fun StudentDto.toChild() = Child(id, firstName, lastName, className)

data class AttendanceDay(
    val date: LocalDate,
    val status: AttendanceStatus,
    val timeIn: LocalDateTime?,
    val timeOut: LocalDateTime?,
    val lastSeen: LocalDateTime?,
) {
    /** The best "when did they get there" the record offers. */
    val arrivedAt: LocalDateTime? get() = timeIn ?: lastSeen
}

fun AttendanceDto.toDay() = AttendanceDay(
    date = date,
    status = AttendanceStatus.fromApi(status),
    timeIn = timeIn,
    timeOut = timeOut,
    lastSeen = lastSeen ?: detectedAt,
)
