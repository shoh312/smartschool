package tj.cict.smartflow.data.repo

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import kotlin.random.Random
import tj.cict.smartflow.data.dto.AbsenceDto
import tj.cict.smartflow.data.dto.AssignmentResultsDto
import tj.cict.smartflow.data.dto.CalendarEventDto
import tj.cict.smartflow.data.dto.ClassAssignmentDto
import tj.cict.smartflow.data.dto.GradeDto
import tj.cict.smartflow.data.dto.MaterialSummaryDto
import tj.cict.smartflow.data.dto.ResultRowDto
import tj.cict.smartflow.data.dto.ScanRowDto
import tj.cict.smartflow.data.dto.SchoolAnnouncementDto
import tj.cict.smartflow.data.dto.StudentDto
import tj.cict.smartflow.data.dto.TeacherAssignmentDto
import tj.cict.smartflow.data.dto.TeacherDiaryEntryDto
import tj.cict.smartflow.data.dto.TeacherDto

/**
 * A maths teacher with three classes, offline. Writes (grades, homework)
 * land in memory so the demo behaves like the real thing for the length
 * of a session.
 */
object DemoTeacher {
    const val EMAIL = "demo@teacher"
    const val TOKEN = "demo-teacher"
    const val SUBJECT = "Математика"
    val me = TeacherDto(1, "Назарова Манзура", EMAIL, SUBJECT, true)

    val classes = listOf(
        ClassAssignmentDto(1, 51, SUBJECT, "5А"),
        ClassAssignmentDto(2, 52, SUBJECT, "5Б"),
        ClassAssignmentDto(3, 82, SUBJECT, "8Б"),
    )

    private val firstNames = listOf("Амина", "Далер", "Фирӯза", "Сӯҳроб", "Нигора", "Баҳром", "Мадина", "Умед", "Зарина", "Фаррух", "Шаҳноза", "Комрон")
    private val lastNames = listOf("Раҳимова", "Шарипов", "Каримова", "Олимов", "Саидова", "Назаров", "Ҳакимова", "Юсупов", "Икромова", "Мирзоев", "Қосимова", "Сафаров")

    fun roster(classId: Int): List<StudentDto> {
        val cls = classes.firstOrNull { it.classId == classId } ?: return emptyList()
        val r = Random(classId)
        val n = 10 + r.nextInt(3)
        return (0 until n).map { i ->
            StudentDto(id = classId * 100 + i, classId = classId, className = cls.className, firstName = firstNames[(i + classId) % firstNames.size], lastName = lastNames[(i * 7 + classId) % lastNames.size])
        }.sortedBy { it.lastName }
    }

    private val grades = mutableMapOf<Int, MutableList<GradeDto>>()
    private var nextGradeId = 5000

    fun grades(classId: Int): List<GradeDto> = grades.getOrPut(classId) {
        val r = Random(classId * 31)
        val today = LocalDate.now()
        val out = mutableListOf<GradeDto>()
        roster(classId).forEach { s ->
            for (back in 1..40) {
                val day = today.minusDays(back.toLong())
                if (day.dayOfWeek == DayOfWeek.SUNDAY || r.nextInt(100) < 70) continue
                out += GradeDto(nextGradeId++, s.id, SUBJECT, (5 + r.nextInt(6)).coerceAtMost(10), null, me.fullName, day, quarterOf(day))
            }
        }
        out.sortedByDescending { it.date }.toMutableList()
    }

    fun addGrade(studentId: Int, classId: Int, value: Int, comment: String?): GradeDto {
        val g = GradeDto(nextGradeId++, studentId, SUBJECT, value, comment, me.fullName, LocalDate.now(), quarterOf(LocalDate.now()))
        grades(classId); grades[classId]!!.add(0, g)
        return g
    }

    fun updateGrade(id: Int, value: Int?, comment: String?): GradeDto? {
        for (list in grades.values) {
            val i = list.indexOfFirst { it.id == id }
            if (i >= 0) { val g = list[i].copy(value = value ?: list[i].value, comment = comment ?: list[i].comment); list[i] = g; return g }
        }
        return null
    }

    fun deleteGrade(id: Int) { grades.values.forEach { it.removeAll { g -> g.id == id } } }

    fun absences(classId: Int): List<AbsenceDto> {
        val r = Random(classId * 17)
        val today = LocalDate.now()
        return roster(classId).flatMap { s ->
            (0..20).filter { r.nextInt(100) < 6 }.map { back -> AbsenceDto(s.id, SUBJECT, today.minusDays(back.toLong()), back) }
        }
    }

    private fun quarterOf(d: LocalDate): Int = when (d.monthValue) { 9, 10 -> 1; 11, 12 -> 2; 1, 2, 3 -> 3; else -> 4 }

    // ---- diary: the teacher's own lessons are editable, the others are colleagues'
    private val diaryEdits = mutableMapOf<Pair<Int, LocalDate>, Pair<String?, String?>>()

    fun diary(classId: Int, on: LocalDate): List<TeacherDiaryEntryDto> {
        if (on.dayOfWeek == DayOfWeek.SUNDAY) return emptyList()
        val r = Random(classId * 7919 + on.toEpochDay().toInt())
        val subjects = listOf(SUBJECT, "Забони тоҷикӣ", "Забони русӣ", "Забони англисӣ", "Таърих", "Биология")
        val picked = (listOf(SUBJECT) + subjects.drop(1).shuffled(r).take(4)).shuffled(r)
        return picked.mapIndexed { i, subject ->
            val mine = subject == SUBJECT
            val lessonId = classId * 10 + i
            val edit = diaryEdits[lessonId to on]
            TeacherDiaryEntryDto(
                lessonId = lessonId, subject = subject,
                startTime = "%02d:%02d".format(8 + (i * 50) / 60, (i * 50) % 60),
                durationMinutes = 45, room = "${101 + r.nextInt(30)}",
                teacherId = if (mine) me.id else 2 + i, teacherName = if (mine) me.fullName else "Шарипов Ф.",
                homework = edit?.first ?: if (mine && r.nextInt(100) < 50) "Саҳифаи ${20 + r.nextInt(80)}, машқи ${1 + r.nextInt(12)}" else null,
                teacherComment = edit?.second,
            )
        }
    }

    fun updateDiary(lessonId: Int, on: LocalDate, homework: String?, comment: String?): TeacherDiaryEntryDto? {
        val classId = lessonId / 10
        val current = diary(classId, on).firstOrNull { it.lessonId == lessonId } ?: return null
        diaryEdits[lessonId to on] = (homework ?: current.homework) to (comment ?: current.teacherComment)
        return diary(classId, on).first { it.lessonId == lessonId }
    }

    // ---- journal scan: a plausible read of a page, matched against the roster
    fun scan(classId: Int): List<ScanRowDto> {
        val roster = roster(classId)
        val r = Random(classId * 3)
        return roster.take(7).mapIndexed { i, s ->
            val full = "${s.lastName} ${s.firstName}"
            when (i) {
                3 -> ScanRowDto(full.dropLast(2) + "…", s.id, full, 0.62, false, 7)
                5 -> ScanRowDto(full, s.id, full, 0.97, true, null)
                else -> ScanRowDto(full, s.id, full, 0.9 + r.nextDouble(0.0, 0.09), false, 6 + r.nextInt(5))
            }
        } + ScanRowDto("Нохонда С.", null, null, 0.31, false, 8)
    }

    // ---- materials
    val materials = listOf(
        MaterialSummaryDto(1, "Касрҳо ва даҳиҳо", "Тести амалӣ аз рӯи мавзӯи гузашта", SUBJECT, 1, me.fullName, 5, 1, 7, 2, LocalDateTime.now().minusDays(2)),
        MaterialSummaryDto(2, "Муодилаҳои хаттӣ", null, SUBJECT, 1, me.fullName, 8, 2, 10, 1, LocalDateTime.now().minusDays(9)),
        MaterialSummaryDto(3, "Фоизҳо", "Масъалаҳои ҳаётӣ", SUBJECT, 1, me.fullName, 6, 1, 6, 0, LocalDateTime.now().minusDays(20)),
    )

    val assignments = listOf(
        TeacherAssignmentDto(1, 1, "Касрҳо ва даҳиҳо", SUBJECT, 51, "5А", "practice", LocalDateTime.now().plusDays(2), 3, LocalDateTime.now().minusDays(2), null, 5, 7, 11, 8, true),
        TeacherAssignmentDto(2, 1, "Касрҳо ва даҳиҳо", SUBJECT, 52, "5Б", "practice", LocalDateTime.now().plusDays(2), 3, LocalDateTime.now().minusDays(2), null, 5, 7, 12, 4, true),
        TeacherAssignmentDto(3, 2, "Муодилаҳои хаттӣ", SUBJECT, 82, "8Б", "control", LocalDateTime.now().plusDays(1), 1, LocalDateTime.now().minusDays(1), null, 8, 10, 10, 6, false),
    )

    private val transferred = mutableSetOf<Pair<Int, Int>>()

    fun results(id: Int): AssignmentResultsDto? {
        val a = assignments.firstOrNull { it.id == id } ?: return null
        val r = Random(id * 11)
        val rows = roster(a.classId).mapIndexed { i, s ->
            val did = i < a.submittedCount
            val score = if (did && a.resultsVisible) (a.maxScore * (45 + r.nextInt(56)) / 100) else null
            val pct = score?.let { it * 100 / a.maxScore }
            ResultRowDto(
                s.id, "${s.lastName} ${s.firstName}", if (did) LocalDateTime.now().minusHours((3 + i * 5).toLong()) else null,
                if (did) 1 + r.nextInt(2) else 0, score, if (score != null) a.maxScore else null, pct,
                pct?.let { (4 + it * 6 / 100).coerceIn(2, 10) }, transferred = (id to s.id) in transferred,
            )
        }
        return AssignmentResultsDto(a, a.resultsVisible, rows)
    }

    fun transfer(id: Int, studentIds: List<Int>): AssignmentResultsDto? {
        studentIds.forEach { transferred += id to it }
        return results(id)
    }

    fun calendar(): List<CalendarEventDto> = DemoData.calendar()

    fun announcements(): List<SchoolAnnouncementDto> = DemoData.announcements().map { SchoolAnnouncementDto(it.id, null, it.title, it.body, it.createdAt) }
}
