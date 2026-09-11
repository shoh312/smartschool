package tj.cict.smartflow.data.repo

import java.time.LocalDate
import kotlin.random.Random
import tj.cict.smartflow.data.dto.CameraDto
import tj.cict.smartflow.data.dto.CameraStatusDto
import tj.cict.smartflow.data.dto.ClassDto
import tj.cict.smartflow.data.dto.ClassSubjectAverageDto
import tj.cict.smartflow.data.dto.ClassSubjectDto
import tj.cict.smartflow.data.dto.DeclinerDto
import tj.cict.smartflow.data.dto.LeaderboardEntryDto
import tj.cict.smartflow.data.dto.LiveStatusDto
import tj.cict.smartflow.data.dto.NeedsAttentionDto
import tj.cict.smartflow.data.dto.SchoolSettingsDto
import tj.cict.smartflow.data.dto.StudentDto
import tj.cict.smartflow.data.dto.TeacherDto

/**
 * A whole school, offline: six classes, seventy pupils, four teachers, three
 * cameras, and a morning already half-way through. Writes stay in memory.
 */
object DemoDirector {
    const val EMAIL = "demo@director"
    const val TOKEN = "demo-director"
    const val NAME = "Раҳмонов Фирдавс"

    val classes = mutableListOf(
        ClassDto(51, "5А", 5, "08:00", "13:00"), ClassDto(52, "5Б", 5, "08:00", "13:00"),
        ClassDto(61, "6А", 6, "08:00", "13:30"), ClassDto(71, "7А", 7, "08:00", "14:00"),
        ClassDto(82, "8Б", 8, "08:00", "14:00"), ClassDto(91, "9А", 9, "08:00", "14:30"),
    )

    val teachers = mutableListOf(
        DemoTeacher.me,
        TeacherDto(2, "Шарипов Фаррух", "sharipov@school", "Таърих", true),
        TeacherDto(3, "Каримова Нигора", "karimova@school", "Забони англисӣ", true),
        TeacherDto(4, "Саидова Зарина", "saidova@school", "Биология", true),
    )

    val cameras = mutableListOf(
        CameraDto(1, 51, "Синфхонаи 101", "192.168.0.64", "rtsp://192.168.0.64:554/stream1", true),
        CameraDto(2, 82, "Синфхонаи 204", "192.168.0.65", "rtsp://192.168.0.65:554/stream1", true),
        CameraDto(3, 91, "Синфхонаи 301", "192.168.0.66", "rtsp://192.168.0.66:554/stream1", false),
    )

    private val extraStudents = mutableListOf<StudentDto>()
    private val removed = mutableSetOf<Int>()
    private var nextStudentId = 9000

    fun students(): List<StudentDto> =
        (classes.flatMap { cls -> DemoTeacher.roster(cls.id).ifEmpty { fallbackRoster(cls) } } + extraStudents).filter { it.id !in removed }

    private fun fallbackRoster(cls: ClassDto): List<StudentDto> {
        val r = Random(cls.id)
        val first = listOf("Амина", "Далер", "Фирӯза", "Сӯҳроб", "Нигора", "Баҳром", "Мадина", "Умед", "Зарина", "Фаррух", "Шаҳноза", "Комрон")
        val last = listOf("Раҳимова", "Шарипов", "Каримова", "Олимов", "Саидова", "Назаров", "Ҳакимова", "Юсупов", "Икромова", "Мирзоев", "Қосимова", "Сафаров")
        return (0 until 10 + r.nextInt(3)).map { i ->
            StudentDto(id = cls.id * 100 + i, classId = cls.id, className = cls.name, firstName = first[(i + cls.id) % first.size], lastName = last[(i * 7 + cls.id) % last.size])
        }.sortedBy { it.lastName }
    }

    fun addStudent(firstName: String, lastName: String, classId: Int): StudentDto {
        val cls = classes.first { it.id == classId }
        return StudentDto(id = nextStudentId++, classId = classId, className = cls.name, firstName = firstName, lastName = lastName).also { extraStudents += it }
    }

    fun removeStudent(id: Int) { removed += id }

    fun addClass(name: String, grade: Int?): ClassDto = ClassDto(200 + classes.size, name, grade).also { classes += it }
    fun removeClass(id: Int) { classes.removeAll { it.id == id } }

    fun addTeacher(name: String, email: String, subject: String?): TeacherDto = TeacherDto(10 + teachers.size, name, email, subject, true).also { teachers += it }

    fun subjectsOf(classId: Int): List<ClassSubjectDto> = teachers.mapIndexed { i, t -> ClassSubjectDto(classId * 10 + i, t.subject, t.id, t.fullName) }

    fun addCamera(c: tj.cict.smartflow.data.dto.CameraCreateRequest): CameraDto = CameraDto(10 + cameras.size, c.classId, c.name, c.ipAddress, c.rtspUrl, c.isActive).also { cameras += it }
    fun updateCamera(id: Int, c: tj.cict.smartflow.data.dto.CameraCreateRequest): CameraDto? {
        val i = cameras.indexOfFirst { it.id == id }; if (i < 0) return null
        return CameraDto(id, c.classId, c.name, c.ipAddress, c.rtspUrl, c.isActive).also { cameras[i] = it }
    }
    fun removeCamera(id: Int) { cameras.removeAll { it.id == id } }

    fun cameraStatus(): List<CameraStatusDto> = cameras.map { cam ->
        val cls = classes.firstOrNull { it.id == cam.classId }
        when {
            !cam.isActive -> CameraStatusDto(cam.id, cam.name, cls?.name, connected = false, detecting = false, phase = "off", staleSeconds = 3600)
            cam.id == 1 -> CameraStatusDto(cam.id, cam.name, cls?.name, connected = true, detecting = true, phase = "qidirilmoqda", detectingFor = 4, staleSeconds = 1)
            else -> CameraStatusDto(cam.id, cam.name, cls?.name, connected = true, detecting = false, phase = "kutish", secondsToDetect = 612, staleSeconds = 2)
        }
    }

    /** Today at ~10 a.m.: most arrived, a few late, a handful missing, one class not started. */
    fun liveStatus(): List<LiveStatusDto> {
        val r = Random(LocalDate.now().toEpochDay().toInt())
        val today = LocalDate.now()
        return students().map { s ->
            val cls = classes.firstOrNull { it.id == s.classId }
            val notStarted = s.classId == 91
            val roll = r.nextInt(100)
            val status = when {
                notStarted -> "not_detected"
                roll < 80 -> "present"
                roll < 90 -> "late"
                roll < 97 -> "absent"
                else -> "not_detected"
            }
            val timeIn = when (status) { "present" -> today.atTime(7, 38 + r.nextInt(20)); "late" -> today.atTime(8, 10 + r.nextInt(35)); else -> null }
            LiveStatusDto(s.id, s.firstName, s.lastName, s.classId, cls?.name, if (notStarted) "upcoming" else "running", status, timeIn, timeIn, timeIn)
        }
    }

    var settings = SchoolSettingsDto(liveVideoEnabled = true, groupMode = false, smsEnabled = true, isActive = true)

    fun ranking(classId: Int?): List<LeaderboardEntryDto> {
        val pool = students().filter { classId == null || it.classId == classId }
        val r = Random(classId ?: 7)
        val scored = pool.map { it to (6.0 + r.nextDouble() * 4).let { v -> Math.round(v * 10) / 10.0 } }.sortedByDescending { it.second }
        return scored.mapIndexed { i, (s, avg) -> LeaderboardEntryDto(s.id, s.firstName, s.lastName, s.classId, s.className, avg, i + 1, scored.size) }
    }

    fun needsAttention(): NeedsAttentionDto {
        val all = ranking(null)
        val r = Random(99)
        return NeedsAttentionDto(
            bottomPerformers = all.takeLast(6).reversed(),
            biggestDecliners = all.shuffled(r).take(5).map { e ->
                val prev = (e.overallAverage ?: 7.0) + 0.8 + r.nextDouble() * 1.2
                DeclinerDto(e.studentId, e.firstName, e.lastName, e.className, e.overallAverage ?: 7.0, Math.round(prev * 10) / 10.0, Math.round(((e.overallAverage ?: 7.0) - prev) * 10) / 10.0)
            }.sortedBy { it.delta },
        )
    }

    fun classSubjects(classId: Int): List<ClassSubjectAverageDto> {
        val r = Random(classId * 5)
        val n = students().count { it.classId == classId }
        return listOf("Математика", "Забони тоҷикӣ", "Забони русӣ", "Забони англисӣ", "Таърих", "Биология", "Физика")
            .map { ClassSubjectAverageDto(it, Math.round((6.2 + r.nextDouble() * 3.3) * 10) / 10.0, 40 + r.nextInt(80), n) }
            .sortedByDescending { it.average }
    }
}
