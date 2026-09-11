package tj.cict.smartflow.ui.director

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoStories
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.formatAverage
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.core.util.weekdayLong
import tj.cict.smartflow.data.dto.StudentDto
import tj.cict.smartflow.domain.Child
import tj.cict.smartflow.ui.components.ChildAvatar
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.grades.gradeColors
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

private val NAME_COL = 132.dp
private val CELL = 42.dp
private val ROW_H = 46.dp

/** The gold "open the journal" button in a class header. */
@Composable
fun JournalButton(onClick: () -> Unit) {
    Box(
        Modifier
            .shadow(8.dp, CircleShape, ambientColor = Color(0x66E08A00), spotColor = Color(0x66E08A00))
            .size(44.dp).clip(CircleShape)
            .background(Brush.linearGradient(listOf(Color(0xFFFFC94D), Color(0xFFE08A00))))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.Rounded.AutoStories, stringResource(R.string.journal_title), tint = Color.White, modifier = Modifier.size(22.dp))
    }
}

/**
 * The class register the director reads: one subject at a time, pupils down
 * the side, lesson dates across the top, a mark or an "absent" in each cell.
 * The name column stays put while the dates scroll sideways.
 */
@Composable
fun DirectorJournalScreen(classId: Int, className: String, schoolVm: SchoolViewModel, onBack: () -> Unit, onOpenStudent: (Int, String) -> Unit, vm: DirectorJournalViewModel = koinViewModel()) {
    LaunchedEffect(classId) { vm.load(classId) }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val school by schoolVm.ui.collectAsStateWithLifecycle()
    val c = MaterialTheme.smart
    val pupils = (school.students as? UiState.Ready)?.data.orEmpty().filter { it.classId == classId }.sortedBy { it.lastName }

    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.journal_title), subtitle = className, onBack = onBack)
            when (val s = ui.data) {
                UiState.Loading -> SkeletonList(rows = 6, rowHeight = 46.dp)
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = { vm.load(classId, force = true) })
                is UiState.Ready -> {
                    val subjects = s.data.subjects
                    if (subjects.isEmpty()) {
                        EmptyState(R.drawable.ill_notebook, stringResource(R.string.journal_empty), stringResource(R.string.journal_empty_body))
                        return@Column
                    }
                    val subject = ui.subject ?: subjects.first()
                    Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        subjects.forEach { sub ->
                            val on = sub == subject
                            Box(
                                Modifier.clip(RoundedCornerShape(999.dp)).background(if (on) c.ink else c.surface).border(1.dp, if (on) c.ink else c.border, RoundedCornerShape(999.dp))
                                    .clickable { vm.select(sub) }.padding(horizontal = 14.dp, vertical = 8.dp),
                            ) { Text(sub, style = MaterialTheme.typography.labelMedium, color = if (on) Color.White else c.ink) }
                        }
                    }
                    VSpace(12.dp)
                    val grades = s.data.grades.filter { it.subject == subject }
                    val absences = s.data.absences.filter { it.subject == subject }
                    val dates = (grades.map { it.date } + absences.map { it.date }).distinct().sorted()
                    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 32.dp)) {
                        SummaryCard(grades.map { it.value }, absences.size)
                        VSpace(12.dp)
                        if (dates.isEmpty() || pupils.isEmpty()) {
                            EmptyState(R.drawable.ill_notebook, stringResource(R.string.journal_empty), stringResource(R.string.journal_empty_body))
                        } else {
                            Grid(pupils, dates, grades.groupBy { it.studentId }, absences.groupBy { it.studentId }, onOpenStudent)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SummaryCard(values: List<Int>, absences: Int) {
    val c = MaterialTheme.smart
    val avg = values.takeIf { it.isNotEmpty() }?.average()
    val (gc, gs) = gradeColors(avg ?: 0.0)
    SoftCard(contentPadding = PaddingValues(14.dp), elevation = 6.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(52.dp).clip(RoundedCornerShape(Radius.md)).background(if (avg != null) gs else c.border), contentAlignment = Alignment.Center) {
                Text(formatAverage(avg), style = MaterialTheme.typography.titleLarge, color = if (avg != null) gc else c.inkTertiary, fontWeight = FontWeight.Bold)
            }
            HSpace(14.dp)
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.average), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
                Text(
                    stringResource(R.string.journal_marks_count, values.size) + " · " + stringResource(R.string.journal_absences_count, absences),
                    style = MaterialTheme.typography.bodySmall, color = c.inkTertiary,
                )
            }
        }
    }
}

@Composable
private fun Grid(
    pupils: List<StudentDto>,
    dates: List<LocalDate>,
    gradesBy: Map<Int, List<tj.cict.smartflow.data.dto.GradeDto>>,
    absencesBy: Map<Int, List<tj.cict.smartflow.data.dto.AbsenceDto>>,
    onOpenStudent: (Int, String) -> Unit,
) {
    val c = MaterialTheme.smart
    val locale = currentLocale()
    val today = LocalDate.now()
    val fmt = DateTimeFormatter.ofPattern("dd.MM")
    SoftCard(contentPadding = PaddingValues(0.dp), elevation = 6.dp) {
        Row {
            // Frozen name column
            Column(Modifier.width(NAME_COL)) {
                Box(Modifier.height(ROW_H).fillMaxWidth().padding(start = 12.dp), contentAlignment = Alignment.CenterStart) {
                    Text(stringResource(R.string.students_title), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
                }
                pupils.forEach { p ->
                    val own = gradesBy[p.id].orEmpty()
                    val avg = own.takeIf { it.isNotEmpty() }?.map { it.value }?.average()
                    Row(
                        Modifier.height(ROW_H).fillMaxWidth().clickable { onOpenStudent(p.id, "${p.lastName} ${p.firstName}") }.padding(start = 8.dp, end = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        ChildAvatar(Child(p.id, p.firstName, p.lastName, p.className), 28.dp)
                        HSpace(8.dp)
                        Column(Modifier.weight(1f)) {
                            Text(p.lastName, style = MaterialTheme.typography.labelMedium, color = c.ink, maxLines = 1)
                            Text(
                                if (avg != null) formatAverage(avg) else p.firstName,
                                style = MaterialTheme.typography.labelSmall,
                                color = if (avg != null) gradeColors(avg).first else c.inkTertiary, maxLines = 1,
                            )
                        }
                    }
                }
            }
            // Dates scroll sideways
            Column(Modifier.weight(1f).horizontalScroll(rememberScrollState())) {
                Row {
                    dates.forEach { d ->
                        val isToday = d == today
                        Column(Modifier.width(CELL).height(ROW_H), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                            Text(d.format(fmt), style = MaterialTheme.typography.labelSmall, color = if (isToday) c.brand else c.inkSecondary, fontWeight = if (isToday) FontWeight.Bold else null)
                            Text(d.weekdayLong(locale).take(2), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
                        }
                    }
                }
                pupils.forEach { p ->
                    val byDate = gradesBy[p.id].orEmpty().groupBy { it.date }
                    val absentDates = absencesBy[p.id].orEmpty().map { it.date }.toSet()
                    Row {
                        dates.forEach { d ->
                            val marks = byDate[d].orEmpty()
                            val absent = d in absentDates
                            Box(Modifier.width(CELL).height(ROW_H).padding(3.dp), contentAlignment = Alignment.Center) {
                                when {
                                    marks.isNotEmpty() -> {
                                        val (gc, gs) = gradeColors(marks.first().value.toDouble())
                                        Box(
                                            Modifier.fillMaxSize().clip(RoundedCornerShape(8.dp)).background(gs)
                                                .then(if (absent) Modifier.border(1.5.dp, c.rose, RoundedCornerShape(8.dp)) else Modifier),
                                            contentAlignment = Alignment.Center,
                                        ) {
                                            Text(marks.joinToString("/") { "${it.value}" }, style = MaterialTheme.typography.labelMedium, color = gc, fontWeight = FontWeight.Bold, maxLines = 1, textAlign = TextAlign.Center)
                                        }
                                    }
                                    absent -> Box(Modifier.fillMaxSize().clip(RoundedCornerShape(8.dp)).background(c.roseSoft), contentAlignment = Alignment.Center) {
                                        Text(stringResource(R.string.journal_absent_short), style = MaterialTheme.typography.labelMedium, color = c.rose, fontWeight = FontWeight.Bold)
                                    }
                                    else -> Box(Modifier.size(4.dp).clip(CircleShape).background(c.border))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    VSpace(10.dp)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.size(14.dp).clip(RoundedCornerShape(4.dp)).background(c.roseSoft), contentAlignment = Alignment.Center) {
            Text(stringResource(R.string.journal_absent_short), style = MaterialTheme.typography.labelSmall, color = c.rose)
        }
        Text(stringResource(R.string.journal_legend_absent), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
    }
}
