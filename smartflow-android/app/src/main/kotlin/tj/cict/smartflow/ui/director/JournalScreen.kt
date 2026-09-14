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
import tj.cict.smartflow.ui.components.JournalGrid
import tj.cict.smartflow.ui.components.JournalRowSpec
import tj.cict.smartflow.ui.components.JournalCell
import tj.cict.smartflow.ui.components.GradeInfoSheet
import tj.cict.smartflow.data.dto.GradeDto
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import tj.cict.smartflow.ui.grades.gradeColors
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

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
    var info by remember { mutableStateOf<Pair<List<GradeDto>, String>?>(null) }

    info?.let { (grades, name) -> GradeInfoSheet(grades, fallback = className, title = name, onDismiss = { info = null }) }

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
                            val byStudent = grades.groupBy { it.studentId }
                            val absentBy = absences.groupBy { it.studentId }
                            JournalGrid(
                                rows = pupils.map { p -> JournalRowSpec(p.id, p.lastName, p.firstName) { ChildAvatar(Child(p.id, p.firstName, p.lastName, p.className), 28.dp) } },
                                dates = dates,
                                cellOf = { id, d -> JournalCell(byStudent[id].orEmpty().filter { it.date == d }, absentBy[id].orEmpty().any { it.date == d }) },
                                onCell = { id, _, cell -> if (cell.grades.isNotEmpty()) info = cell.grades to pupils.first { it.id == id }.let { "${it.lastName} ${it.firstName}" } },
                                onRow = { id -> pupils.first { it.id == id }.let { onOpenStudent(it.id, "${it.lastName} ${it.firstName}") } },
                            )
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
