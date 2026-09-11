package tj.cict.smartflow.data.repo

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import kotlin.random.Random
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import tj.cict.smartflow.data.dto.AnalyticsDto
import tj.cict.smartflow.data.dto.AnswerResponse
import tj.cict.smartflow.data.dto.AssignmentDetailDto
import tj.cict.smartflow.data.dto.AttemptResultDto
import tj.cict.smartflow.data.dto.BlockDto
import tj.cict.smartflow.data.dto.AnnouncementDto
import tj.cict.smartflow.data.dto.AssignmentDto
import tj.cict.smartflow.data.dto.CalendarEventDto
import tj.cict.smartflow.data.dto.DiaryEntryDto
import tj.cict.smartflow.data.dto.GradeDto
import tj.cict.smartflow.data.dto.NotificationDto
import tj.cict.smartflow.data.dto.QuarterPointDto
import tj.cict.smartflow.data.dto.RankDto
import tj.cict.smartflow.data.dto.SubjectAverageDto
import tj.cict.smartflow.domain.AttendanceDay
import tj.cict.smartflow.domain.AttendanceStatus
import tj.cict.smartflow.domain.Child

/**
 * A whole family, offline. Signing in with the demo number gets this
 * instead of the server, so the app can be shown -- to a jury, to a
 * school, to a parent -- with the school server switched off.
 *
 * Deterministic: the same numbers every launch, generated relative to
 * today so "this morning" is always this morning.
 */
object DemoData {
    const val PHONE = "992000000000"
    const val TOKEN = "demo"
    const val PARENT_ID = 0
    const val PARENT_NAME = "Раҳимова Мадина"
    const val STUDENT_USERNAME = "demo"

    val children = listOf(
        Child(1, "Амина", "Раҳимова", "5А"),
        Child(2, "Далер", "Раҳимов", "8Б"),
    )

    private val subjects = listOf("Математика", "Забони тоҷикӣ", "Забони русӣ", "Забони англисӣ", "Таърих", "Биология", "Физика", "Информатика")
    private val teachers = listOf("Назарова М.", "Шарипов Ф.", "Каримова Н.", "Олимов Р.", "Саидова З.")

    private fun rnd(childId: Int, salt: Int) = Random(childId * 1000 + salt)

    fun attendance(childId: Int): List<AttendanceDay> {
        val r = rnd(childId, 1)
        val today = LocalDate.now()
        val out = mutableListOf<AttendanceDay>()
        for (back in 0..45) {
            val day = today.minusDays(back.toLong())
            if (day.dayOfWeek == DayOfWeek.SUNDAY) continue
            val roll = r.nextInt(100)
            val status = when {
                back == 0 -> if (childId == 1) AttendanceStatus.PRESENT else AttendanceStatus.LATE
                roll < 78 -> AttendanceStatus.PRESENT
                roll < 90 -> AttendanceStatus.LATE
                else -> AttendanceStatus.ABSENT
            }
            val timeIn = when (status) {
                AttendanceStatus.PRESENT -> day.atTime(7, 40 + r.nextInt(18))
                AttendanceStatus.LATE -> day.atTime(8, 12 + r.nextInt(30))
                else -> null
            }
            val timeOut = if (timeIn != null && back > 0) day.atTime(13, 5 + r.nextInt(40)) else null
            out += AttendanceDay(day, status, timeIn, timeOut, timeIn)
        }
        return out
    }

    fun grades(childId: Int): List<GradeDto> {
        val r = rnd(childId, 2)
        val today = LocalDate.now()
        val bias = if (childId == 1) 1 else 0
        val out = mutableListOf<GradeDto>()
        var id = 1
        for (back in 0..70) {
            val day = today.minusDays(back.toLong())
            if (day.dayOfWeek == DayOfWeek.SUNDAY || r.nextInt(100) < 45) continue
            val subject = subjects[r.nextInt(subjects.size)]
            val value = (6 + bias + r.nextInt(4)).coerceAtMost(10)
            val comment = if (r.nextInt(100) < 18) listOf("Хуб ҷавоб дод", "Вазифаро пурра иҷро кард", "Фаъол буд", "Бештар машқ лозим")[r.nextInt(4)] else null
            out += GradeDto(id++, childId, subject, value, comment, teachers[r.nextInt(teachers.size)], day, quarterOf(day))
        }
        return out.sortedByDescending { it.date }
    }

    private fun quarterOf(d: LocalDate): Int = when (d.monthValue) {
        9, 10 -> 1; 11, 12 -> 2; 1, 2, 3 -> 3; else -> 4
    }

    fun diary(childId: Int, on: LocalDate): List<DiaryEntryDto> {
        if (on.dayOfWeek == DayOfWeek.SUNDAY) return emptyList()
        val r = Random(childId * 7919 + on.toEpochDay().toInt())
        val gradesToday = grades(childId).filter { it.date == on }.associateBy { it.subject }
        val count = 5 + r.nextInt(2)
        val picked = subjects.shuffled(r).take(count)
        return picked.mapIndexed { i, subject ->
            val start = LocalTime.of(8, 0).plusMinutes((i * 50).toLong())
            val homework = when (r.nextInt(3)) {
                0 -> "Саҳифаи ${20 + r.nextInt(80)}, машқи ${1 + r.nextInt(12)}"
                1 -> "Мавзӯи навро хонед ва нақл кунед"
                else -> null
            }
            DiaryEntryDto(
                lessonId = i + 1,
                subject = subject,
                room = "${101 + r.nextInt(30)}",
                teacherName = teachers[r.nextInt(teachers.size)],
                startTime = start.toString(),
                durationMinutes = 45,
                date = on,
                homework = homework,
                teacherComment = if (r.nextInt(100) < 12) "Дар дарс фаъол буд" else null,
                grade = gradesToday[subject]?.value,
            )
        }
    }

    fun homework(childId: Int): List<DiaryEntryDto> {
        val today = LocalDate.now()
        return (-2..5).flatMap { d -> diary(childId, today.plusDays(d.toLong())).filter { !it.homework.isNullOrBlank() } }
            .sortedWith(compareByDescending<DiaryEntryDto> { it.date }.thenBy { it.startTime })
    }

    fun assignments(childId: Int): List<AssignmentDto> {
        val now = LocalDateTime.now()
        return listOf(
            AssignmentDto(1, "Касрҳо ва даҳиҳо", "Тести амалӣ аз рӯи мавзӯи гузашта", "Математика", "Назарова М.", "practice", now.plusDays(2).withHour(18).withMinute(0), 5, 7, 1, now.minusDays(1), false, 5, 71, true),
            AssignmentDto(2, "Present Simple", null, "Забони англисӣ", "Каримова Н.", "control", now.plusDays(4).withHour(20).withMinute(0), 3, 3, 0, null, false, null, null, false),
            AssignmentDto(3, "Ҳуҷайра ва бофтаҳо", "Саволҳои санҷишӣ", "Биология", "Саидова З.", "practice", now.minusDays(3), 8, 8, 0, null, true, null, null, false),
            AssignmentDto(4, "Ҷанги Бузурги Ватанӣ", null, "Таърих", "Шарипов Ф.", "control", now.minusDays(6), 12, 12, 1, now.minusDays(7), false, 11, 92, true),
        )
    }

    fun calendar(): List<CalendarEventDto> {
        val today = LocalDate.now()
        return listOf(
            CalendarEventDto(1, "Ҷамъомади волидайн", "Синфхонаи 204, соати 17:00", "meeting", today.plusDays(3), null),
            CalendarEventDto(2, "Олимпиадаи математика", "Даври мактабӣ", "exam", today.plusDays(9), null),
            CalendarEventDto(3, "Таътили тирамоҳӣ", null, "holiday", today.plusDays(20), today.plusDays(27)),
            CalendarEventDto(4, "Рӯзи муаллим", "Консерти идона", "event", today.plusDays(14), null),
        )
    }

    fun announcements(): List<AnnouncementDto> {
        val now = LocalDateTime.now()
        return listOf(
            AnnouncementDto(1, "Ҷадвали нав аз душанбе", "Аз душанбеи оянда дарсҳо аз соати 8:00 оғоз мешаванд. Лутфан, фарзандонро сари вақт биёред.", now.minusHours(5)),
            AnnouncementDto(2, "Либоси мактабӣ", "Ёдрас мекунем: рӯзи душанбе либоси расмии мактабӣ ҳатмист.", now.minusDays(2)),
            AnnouncementDto(3, "Санҷиши тиббӣ", "Санҷиши тиббии солона рӯзи чоршанбе баргузор мегардад.", now.minusDays(6)),
        )
    }

    fun notifications(): List<NotificationDto> {
        val now = LocalDateTime.now()
        val today = LocalDate.now()
        return listOf(
            NotificationDto(1, 1, "arrived", "Амина ба мактаб омад", "Соати 07:52 дар синфхона дида шуд", "sent", today.atTime(7, 52), today.atTime(7, 52)),
            NotificationDto(2, 2, "late", "Далер дер монд", "Соати 08:27 ба мактаб омад", "sent", today.atTime(8, 27), today.atTime(8, 27)),
            NotificationDto(3, 1, "grade", "Баҳои нав: Математика — 9", "Назарова М.: Хуб ҷавоб дод", "sent", now.minusDays(1).withHour(11), now.minusDays(1).withHour(11)),
            NotificationDto(4, null, "announcement", "Ҷадвали нав аз душанбе", "Дарсҳо аз соати 8:00 оғоз мешаванд", "sent", now.minusDays(1).withHour(9), now.minusDays(1).withHour(9)),
            NotificationDto(5, 2, "absent", "Далер имрӯз ба мактаб наомад", "То соати 08:45 дида нашуд", "sent", now.minusDays(3).withHour(8).withMinute(45), now.minusDays(3).withHour(8).withMinute(45)),
            NotificationDto(6, 1, "left_school", "Амина аз мактаб рафт", "Соати 13:20", "sent", now.minusDays(3).withHour(13).withMinute(20), now.minusDays(3).withHour(13).withMinute(20)),
        )
    }

    fun analytics(childId: Int, quarter: Int?): AnalyticsDto {
        val child = children.first { it.id == childId }
        val q = quarter ?: quarterOf(LocalDate.now())
        val r = rnd(childId, 40 + q)
        val base = if (childId == 1) 8.6 else 7.3
        val subs = subjects.map { s -> SubjectAverageDto(s, (base + r.nextDouble(-1.4, 1.2)).coerceIn(4.0, 10.0).round1(), 4 + r.nextInt(9)) }
        val overall = subs.map { it.average }.average().round1()
        val trend = (1..4).map { t ->
            QuarterPointDto(t, if (t > q) null else (overall + (t - q) * 0.25 + r.nextDouble(-0.2, 0.2)).coerceIn(4.0, 10.0).round1())
        }
        return AnalyticsDto(
            studentId = childId,
            firstName = child.firstName,
            lastName = child.lastName,
            quarter = q,
            schoolYear = LocalDate.now().year,
            overallAverage = overall,
            classRank = RankDto(if (childId == 1) 2 else 9, 28),
            parallelRank = RankDto(if (childId == 1) 5 else 31, 84),
            schoolRank = RankDto(if (childId == 1) 14 else 118, 412),
            classAverage = (overall - if (childId == 1) 1.1 else 0.2).round1(),
            parallelAverage = (overall - if (childId == 1) 1.0 else 0.1).round1(),
            schoolAverage = (overall - if (childId == 1) 1.3 else 0.3).round1(),
            subjects = subs,
            strongestSubject = subs.maxBy { it.average }.subject,
            weakestSubject = subs.minBy { it.average }.subject,
            lessonAttendanceRate = if (childId == 1) 96.5 else 87.0,
            trend = trend,
        )
    }

    private fun Double.round1() = Math.round(this * 10) / 10.0

    // ------------------------------------------------------------ player

    private data class Key(val questionType: String, val correct: JsonElement)

    private fun strList(vararg items: String): JsonElement = buildJsonArray { items.forEach { add(JsonPrimitive(it)) } }
    private fun index(i: Int): JsonElement = buildJsonObject { put("index", JsonPrimitive(i)) }
    private fun bool(b: Boolean): JsonElement = buildJsonObject { put("value", JsonPrimitive(b)) }
    private fun answers(vararg a: String): JsonElement = buildJsonObject { put("answers", buildJsonArray { a.forEach { add(JsonPrimitive(it)) } }) }
    private fun identityPairs(n: Int): JsonElement = buildJsonObject { put("pairs", buildJsonArray { for (i in 0 until n) add(buildJsonArray { add(JsonPrimitive(i)); add(JsonPrimitive(i)) }) }) }
    private fun identityOrder(n: Int): JsonElement = buildJsonObject { put("order", buildJsonArray { for (i in 0 until n) add(JsonPrimitive(i)) }) }

    /** Question blocks with their keys. The key never leaves this object. */
    private val demoBlocks: Map<Int, List<Pair<BlockDto, Key?>>> = mapOf(
        1 to listOf(
            BlockDto(101, 0, "page", "Каср ин як қисми бутун аст. Масалан, 1/2 нисфи чизе аст, 3/4 се чоряки он.\n\nБарои ҷамъ кардани касрҳо махраҷҳо бояд якхела бошанд.", null, null, 0) to null,
            BlockDto(102, 1, "question", "1/2 + 1/4 = ?", "single", strList("1/6", "3/4", "2/6", "1/8"), 1) to Key("single", index(1)),
            BlockDto(103, 2, "question", "0,5 ва 1/2 ба ҳам баробаранд.", "truefalse", null, 1) to Key("truefalse", bool(true)),
            BlockDto(104, 3, "question", "3/4 ҳамчун даҳӣ: ...", "fill", null, 1) to Key("fill", answers("0,75", "0.75")),
            BlockDto(105, 4, "question", "Касрро бо даҳии он пайваст кунед", "match", buildJsonObject {
                put("left", strList("1/2", "1/4", "1/5")); put("right", strList("0,5", "0,25", "0,2"))
            }, 2) to Key("match", identityPairs(3)),
            BlockDto(106, 5, "question", "Аз хурд ба калон ҷойгир кунед", "order", strList("1/8", "1/4", "1/2", "3/4"), 2) to Key("order", identityOrder(4)),
        ),
        2 to listOf(
            BlockDto(201, 0, "page", "Present Simple is used for habits and facts.\n\nI play. She plays. They play.", null, null, 0) to null,
            BlockDto(202, 1, "question", "She ___ to school every day.", "single", strList("go", "goes", "going", "gone"), 1) to Key("single", index(1)),
            BlockDto(203, 2, "question", "\"I am play football\" is correct.", "truefalse", null, 1) to Key("truefalse", bool(false)),
            BlockDto(204, 3, "question", "They ___ (not) like tea. Write the missing word.", "fill", null, 1) to Key("fill", answers("do not", "don't", "dont")),
        ),
    )

    /** One open attempt per assignment, held in memory for the session. */
    private val attempts = mutableMapOf<Int, MutableMap<String, JsonElement>>()

    fun assignmentDetail(childId: Int, id: Int): AssignmentDetailDto? {
        val a = assignments(childId).firstOrNull { it.id == id } ?: return null
        val blocks = demoBlocks[id]?.map { it.first } ?: emptyList()
        val open = attempts[id]
        return AssignmentDetailDto(
            id = a.id, title = a.title, description = a.description, subject = a.subject, teacherName = a.teacherName,
            mode = a.mode, dueAt = a.dueAt, maxAttempts = 3, questionCount = blocks.count { it.blockType == "question" },
            maxScore = blocks.sumOf { it.points }, attemptsUsed = a.attemptsUsed, attemptsLeft = 3 - a.attemptsUsed,
            submittedAt = a.submittedAt, isOverdue = a.isOverdue, canStart = !a.isOverdue && blocks.isNotEmpty(),
            score = a.score, percent = a.percent, scoreVisible = a.scoreVisible,
            blocks = blocks, attemptId = if (open != null) 1000 + id else null, savedAnswers = open ?: emptyMap(),
        )
    }

    fun startAttempt(childId: Int, id: Int): AssignmentDetailDto? {
        attempts.getOrPut(id) { mutableMapOf() }
        return assignmentDetail(childId, id)
    }

    fun answer(attemptId: Int, blockId: Int, answer: JsonElement): AnswerResponse {
        val id = attemptId - 1000
        attempts.getOrPut(id) { mutableMapOf() }[blockId.toString()] = answer
        val mode = assignments(1).firstOrNull { it.id == id }?.mode
        val key = demoBlocks[id]?.firstOrNull { it.first.id == blockId }?.second
        return AnswerResponse(saved = true, correct = if (mode == "control" || key == null) null else grade(key, answer))
    }

    fun submit(attemptId: Int): AttemptResultDto {
        val id = attemptId - 1000
        val given = attempts[id].orEmpty()
        val questions = demoBlocks[id].orEmpty().filter { it.second != null }
        val per = questions.associate { (b, k) -> b.id.toString() to (given[b.id.toString()]?.let { grade(k!!, it) } ?: false) }
        val score = questions.filter { per[it.first.id.toString()] == true }.sumOf { it.first.points }
        val max = questions.sumOf { it.first.points }
        val control = assignments(1).firstOrNull { it.id == id }?.mode == "control"
        attempts.remove(id)
        return AttemptResultDto(
            attemptId, scoreVisible = !control, score = if (control) null else score, maxScore = if (control) null else max,
            percent = if (control || max == 0) null else score * 100 / max, perQuestion = if (control) null else per,
        )
    }

    /** Same rules as the servers' material_grading, for the demo only. */
    private fun grade(key: Key, answer: JsonElement): Boolean = runCatching {
        val a = answer.jsonObject
        val c = key.correct.jsonObject
        when (key.questionType) {
            "single" -> a["index"]?.jsonPrimitive?.intOrNull == c["index"]?.jsonPrimitive?.intOrNull
            "truefalse" -> a["value"]?.jsonPrimitive?.booleanOrNull == c["value"]?.jsonPrimitive?.booleanOrNull
            "fill" -> {
                val g = norm(a["text"]?.jsonPrimitive?.contentOrNull.orEmpty())
                g.isNotEmpty() && c["answers"]!!.jsonArray.any { norm(it.jsonPrimitive.content) == g }
            }
            "match" -> {
                val g = a["pairs"]!!.jsonArray.map { it.jsonArray[0].jsonPrimitive.int to it.jsonArray[1].jsonPrimitive.int }.toSet()
                val w = c["pairs"]!!.jsonArray.map { it.jsonArray[0].jsonPrimitive.int to it.jsonArray[1].jsonPrimitive.int }.toSet()
                w.isNotEmpty() && g == w
            }
            "order" -> a["order"]!!.jsonArray.map { it.jsonPrimitive.int } == c["order"]!!.jsonArray.map { it.jsonPrimitive.int }
            else -> false
        }
    }.getOrDefault(false)

    private fun norm(s: String) = s.trim().lowercase().replace(Regex("[.,!?;:\"'`´’()\\[\\]{}]+"), " ").replace(Regex("\\s+"), " ").trim()
}
