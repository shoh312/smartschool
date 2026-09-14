package tj.cict.smartflow.ui.components

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
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonth
import tj.cict.smartflow.core.util.formatAverage
import tj.cict.smartflow.core.util.weekdayLong
import tj.cict.smartflow.data.dto.GradeDto
import tj.cict.smartflow.ui.grades.gradeColors
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

private val NAME_COL = 132.dp
private val CELL = 42.dp
private val ROW_H = 46.dp

/** One line of the register: a pupil for a teacher or director, a subject for a parent. */
data class JournalRowSpec<K>(
    val key: K,
    val title: String,
    val subtitle: String? = null,
    val avatar: (@Composable () -> Unit)? = null,
)

/** What sits in one cell: the marks given that day and whether the pupil was absent. */
data class JournalCell(val grades: List<GradeDto> = emptyList(), val absent: Boolean = false)

/**
 * The register as a grid: rows down the side, lesson dates across the top,
 * a mark or an "absent" in each cell. The row column stays put while the
 * dates scroll sideways; the average column closes each row. Every cell with
 * a mark is tappable so whoever is looking can see who gave it and why.
 *
 * `todayEditable` adds today's column even when empty and hands taps on it to
 * `onCell` regardless of content, so a teacher can give a mark from the grid.
 */
@Composable
fun <K : Any> JournalGrid(
    rows: List<JournalRowSpec<K>>,
    dates: List<LocalDate>,
    cellOf: (K, LocalDate) -> JournalCell,
    onCell: (K, LocalDate, JournalCell) -> Unit,
    todayEditable: Boolean = false,
    onRow: ((K) -> Unit)? = null,
) {
    val c = MaterialTheme.smart
    val locale = currentLocale()
    val today = LocalDate.now()
    val fmt = DateTimeFormatter.ofPattern("dd.MM")
    val columns = if (todayEditable && today !in dates) (dates + today).sorted() else dates
    SoftCard(contentPadding = PaddingValues(0.dp), elevation = 6.dp) {
        Row {
            // Frozen row-title column
            Column(Modifier.width(NAME_COL)) {
                Box(Modifier.height(ROW_H).fillMaxWidth().padding(start = 12.dp), contentAlignment = Alignment.CenterStart) {
                    Text(stringResource(R.string.journal_rows), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
                }
                rows.forEach { r ->
                    val all = columns.flatMap { cellOf(r.key, it).grades }
                    val avg = all.takeIf { it.isNotEmpty() }?.map { it.value }?.average()
                    Row(
                        Modifier.height(ROW_H).fillMaxWidth().then(if (onRow != null) Modifier.clickable { onRow(r.key) } else Modifier).padding(start = 8.dp, end = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        r.avatar?.let { it(); HSpace(8.dp) }
                        Column(Modifier.weight(1f)) {
                            Text(r.title, style = MaterialTheme.typography.labelMedium, color = c.ink, maxLines = 1)
                            Text(
                                if (avg != null) formatAverage(avg) else r.subtitle.orEmpty(),
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
                    columns.forEach { d ->
                        val isToday = d == today
                        Column(
                            Modifier.width(CELL).height(ROW_H).then(if (isToday) Modifier.background(c.brandTint) else Modifier),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
                        ) {
                            Text(d.format(fmt), style = MaterialTheme.typography.labelSmall, color = if (isToday) c.brand else c.inkSecondary, fontWeight = if (isToday) FontWeight.Bold else null)
                            Text(d.weekdayLong(locale).take(2), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
                        }
                    }
                }
                rows.forEach { r ->
                    Row {
                        columns.forEach { d ->
                            val cell = cellOf(r.key, d)
                            val isToday = d == today
                            val tappable = cell.grades.isNotEmpty() || (todayEditable && isToday)
                            Box(
                                Modifier.width(CELL).height(ROW_H).then(if (isToday) Modifier.background(c.brandTint) else Modifier).padding(3.dp)
                                    .then(if (tappable) Modifier.clip(RoundedCornerShape(8.dp)).clickable { onCell(r.key, d, cell) } else Modifier),
                                contentAlignment = Alignment.Center,
                            ) {
                                when {
                                    cell.grades.isNotEmpty() -> {
                                        val (gc, gs) = gradeColors(cell.grades.first().value.toDouble())
                                        Box(
                                            Modifier.fillMaxSize().clip(RoundedCornerShape(8.dp)).background(gs)
                                                .then(if (cell.absent) Modifier.border(1.5.dp, c.rose, RoundedCornerShape(8.dp)) else Modifier),
                                            contentAlignment = Alignment.Center,
                                        ) {
                                            Text(cell.grades.joinToString("/") { "${it.value}" }, style = MaterialTheme.typography.labelMedium, color = gc, fontWeight = FontWeight.Bold, maxLines = 1, textAlign = TextAlign.Center)
                                            if (cell.grades.any { !it.comment.isNullOrBlank() }) {
                                                Box(Modifier.align(Alignment.TopEnd).padding(3.dp).size(5.dp).clip(CircleShape).background(c.brand))
                                            }
                                        }
                                    }
                                    cell.absent -> Box(Modifier.fillMaxSize().clip(RoundedCornerShape(8.dp)).background(c.roseSoft), contentAlignment = Alignment.Center) {
                                        Text(stringResource(R.string.journal_absent_short), style = MaterialTheme.typography.labelMedium, color = c.rose, fontWeight = FontWeight.Bold)
                                    }
                                    todayEditable && isToday -> Box(Modifier.fillMaxSize().clip(RoundedCornerShape(8.dp)).border(1.5.dp, c.brandSoft, RoundedCornerShape(8.dp)), contentAlignment = Alignment.Center) {
                                        Text("+", style = MaterialTheme.typography.labelMedium, color = c.brand)
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
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(14.dp).clip(RoundedCornerShape(4.dp)).background(c.roseSoft), contentAlignment = Alignment.Center) {
            Text(stringResource(R.string.journal_absent_short), style = MaterialTheme.typography.labelSmall, color = c.rose)
        }
        Text(stringResource(R.string.journal_legend_absent), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
        HSpace(6.dp)
        Box(Modifier.size(6.dp).clip(CircleShape).background(c.brand))
        Text(stringResource(R.string.journal_legend_comment), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
    }
}

/**
 * Tapping a mark: who gave it, for what, when, and the comment. `fallback`
 * (the group name) stands in when the mark carries no subject.
 */
@Composable
fun GradeInfoSheet(grades: List<GradeDto>, fallback: String, title: String, onDismiss: () -> Unit) {
    val c = MaterialTheme.smart
    val locale = currentLocale()
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss, sheetState = sheet, containerColor = c.surface,
        shape = RoundedCornerShape(topStart = Radius.xl, topEnd = Radius.xl),
        dragHandle = { Box(Modifier.padding(top = 12.dp, bottom = 4.dp).size(width = 40.dp, height = 4.dp).clip(RoundedCornerShape(2.dp)).background(c.border)) },
    ) {
        Column(Modifier.padding(horizontal = 24.dp).padding(bottom = 28.dp)) {
            Text(title, style = MaterialTheme.typography.titleLarge, color = c.ink)
            grades.forEach { g ->
                val (gc, gs) = gradeColors(g.value.toDouble())
                VSpace(14.dp)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(56.dp).clip(RoundedCornerShape(Radius.md)).background(gs), contentAlignment = Alignment.Center) {
                        Text("${g.value}", style = MaterialTheme.typography.headlineMedium, color = gc, fontWeight = FontWeight.Bold)
                    }
                    HSpace(14.dp)
                    Column(Modifier.weight(1f)) {
                        Text(g.subject.ifBlank { fallback }, style = MaterialTheme.typography.titleMedium, color = c.ink)
                        Text("${g.date.weekdayLong(locale)}, ${g.date.dayMonth(locale)}", style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
                        Text(
                            if (!g.teacherName.isNullOrBlank()) stringResource(R.string.grade_given_by, g.teacherName) else stringResource(R.string.grade_given_by_unknown),
                            style = MaterialTheme.typography.bodySmall, color = c.inkTertiary,
                        )
                    }
                }
                VSpace(10.dp)
                Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.sm)).background(c.surfaceSoft).padding(12.dp)) {
                    Text(
                        if (g.comment.isNullOrBlank()) stringResource(R.string.grade_no_comment) else "“${g.comment}”",
                        style = MaterialTheme.typography.bodyMedium, color = if (g.comment.isNullOrBlank()) c.inkTertiary else c.ink,
                    )
                }
            }
        }
    }
}
