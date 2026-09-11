package tj.cict.smartflow.ui.teacher

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.border
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import tj.cict.smartflow.core.util.formatDateInput
import tj.cict.smartflow.core.util.formatTimeInput
import tj.cict.smartflow.data.dto.ClassAssignmentDto
import tj.cict.smartflow.ui.components.AppTextField
import tj.cict.smartflow.ui.components.GhostButton
import tj.cict.smartflow.ui.components.RoundIconButton
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonthTime
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.data.dto.MaterialSummaryDto
import tj.cict.smartflow.data.dto.ResultRowDto
import tj.cict.smartflow.data.dto.TeacherAssignmentDto
import tj.cict.smartflow.ui.components.Chip
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.PrimaryButton
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.Segment
import tj.cict.smartflow.ui.components.SegmentRow
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.grades.gradeColors
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

@Composable
fun MaterialsScreen(bottomPadding: Dp, onBack: (() -> Unit)?, onOpenResults: (Int) -> Unit, onCreate: () -> Unit, onEdit: (Int) -> Unit, classesVm: TeacherClassesViewModel, vm: MaterialsViewModel = koinViewModel()) {
    // Re-fetch on every entry: coming back from the editor must show the material just saved.
    LaunchedEffect(Unit) { vm.load(force = true) }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()
    val classes by classesVm.state.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableStateOf(0) }
    var assigning by remember { mutableStateOf<MaterialSummaryDto?>(null) }
    var deleting by remember { mutableStateOf<MaterialSummaryDto?>(null) }
    val locale = currentLocale()

    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.materials_title), onBack = onBack, trailing = { RoundIconButton(Icons.Rounded.Add, stringResource(R.string.material_new), onCreate) })
            SegmentRow(Modifier.padding(horizontal = 20.dp)) {
                Segment(stringResource(R.string.materials_assigned), tab == 0) { tab = 0 }
                Segment(stringResource(R.string.materials_mine), tab == 1) { tab = 1 }
            }
            VSpace(6.dp)
            if (tab == 0) {
                when (val s = ui.assignments) {
                    UiState.Loading -> SkeletonList(rows = 3)
                    is UiState.Failed -> ErrorState(s.error.message(), onRetry = { vm.load(force = true) })
                    is UiState.Ready -> if (s.data.isEmpty()) EmptyState(R.drawable.ill_clipboard, stringResource(R.string.materials_empty)) else {
                        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = bottomPadding + 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            items(s.data, key = { it.id }) { a -> AssignmentRow(a, locale) { onOpenResults(a.id) } }
                        }
                    }
                }
            } else {
                when (val s = ui.materials) {
                    UiState.Loading -> SkeletonList(rows = 3)
                    is UiState.Failed -> ErrorState(s.error.message(), onRetry = { vm.load(force = true) })
                    is UiState.Ready -> if (s.data.isEmpty()) EmptyState(R.drawable.ill_clipboard, stringResource(R.string.materials_empty)) else {
                        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = bottomPadding + 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            items(s.data, key = { it.id }) { m -> MaterialRow(m, onEdit = { onEdit(m.id) }, onAssign = { assigning = m }, onDelete = { deleting = m }) }
                        }
                    }
                }
            }
        }
    }

    assigning?.let { m ->
        AssignSheet(m, (classes as? UiState.Ready)?.data.orEmpty(), busy, onDismiss = { assigning = null }, onAssign = { ids, mode, due, att -> vm.assign(m.id, ids, mode, due, att) { assigning = null } })
    }
    deleting?.let { m ->
        AlertDialog(
            onDismissRequest = { deleting = null }, containerColor = MaterialTheme.smart.surface, shape = RoundedCornerShape(Radius.lg),
            title = { Text(stringResource(R.string.delete_material_confirm, m.title), style = MaterialTheme.typography.titleMedium) },
            confirmButton = { TextButton(onClick = { vm.delete(m.id); deleting = null }) { Text(stringResource(R.string.delete), color = MaterialTheme.smart.rose) } },
            dismissButton = { TextButton(onClick = { deleting = null }) { Text(stringResource(R.string.cancel)) } },
        )
    }
    error?.let { err ->
        AlertDialog(
            onDismissRequest = vm::clearError, containerColor = MaterialTheme.smart.surface, shape = RoundedCornerShape(Radius.lg),
            text = { Text(err.message(), style = MaterialTheme.typography.bodyLarge) },
            confirmButton = { TextButton(onClick = vm::clearError) { Text(stringResource(R.string.done)) } },
        )
    }
}

@Composable
private fun MaterialRow(m: MaterialSummaryDto, onEdit: () -> Unit, onAssign: () -> Unit, onDelete: () -> Unit) {
    val c = MaterialTheme.smart
    SoftCard(contentPadding = PaddingValues(14.dp), elevation = 5.dp, onClick = onEdit) {
        Text(m.subject, style = MaterialTheme.typography.labelSmall, color = c.brandDeep)
        Text(m.title, style = MaterialTheme.typography.titleMedium, color = c.ink)
        if (!m.description.isNullOrBlank()) Text(m.description, style = MaterialTheme.typography.bodySmall, color = c.inkSecondary, maxLines = 2)
        VSpace(8.dp)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.material_meta, m.questionCount, m.maxScore), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary)
            HSpace(10.dp)
            if (m.assignedClassCount > 0) Chip(stringResource(R.string.assigned_to_n, m.assignedClassCount), c.mint, c.mintSoft)
        }
        VSpace(8.dp)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
            GhostButton(stringResource(R.string.delete), onClick = onDelete, color = c.inkTertiary)
            GhostButton(stringResource(R.string.edit), onClick = onEdit)
            GhostButton(stringResource(R.string.assign_material), onClick = onAssign)
        }
    }
}

@Composable
private fun AssignmentRow(a: TeacherAssignmentDto, locale: java.util.Locale, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    val control = a.mode == "control"
    SoftCard(contentPadding = PaddingValues(14.dp), elevation = 5.dp, onClick = onClick) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text("${a.className} · ${a.subject}", style = MaterialTheme.typography.labelSmall, color = c.brandDeep)
                Text(a.materialTitle, style = MaterialTheme.typography.titleMedium, color = c.ink)
            }
            Chip(if (control) stringResource(R.string.mode_control) else stringResource(R.string.mode_practice), if (control) c.coral else c.sky, if (control) c.coralSoft else c.skySoft)
        }
        VSpace(10.dp)
        val frac = if (a.studentCount > 0) a.submittedCount / a.studentCount.toFloat() else 0f
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f).height(8.dp).clip(RoundedCornerShape(4.dp)).background(c.surfaceSoft)) {
                Box(Modifier.fillMaxWidth(frac).fillMaxSize().background(if (frac >= 1f) c.mint else c.brand))
            }
            HSpace(10.dp)
            Text(stringResource(R.string.submitted_of, a.submittedCount, a.studentCount), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
        }
        a.dueAt?.let {
            VSpace(6.dp)
            Text(stringResource(R.string.assignment_due, it.dayMonthTime(locale)), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary)
        }
        if (a.gradesTransferredAt != null) {
            VSpace(6.dp)
            Chip(stringResource(R.string.results_transferred), c.mint, c.mintSoft)
        }
    }
}

@Composable
private fun AssignSheet(m: MaterialSummaryDto, classes: List<ClassAssignmentDto>, busy: Boolean, onDismiss: () -> Unit, onAssign: (List<Int>, String, String?, Int?) -> Unit) {
    val c = MaterialTheme.smart
    val distinct = remember(classes) { classes.distinctBy { it.classId } }
    var picked by remember { mutableStateOf(setOf<Int>()) }
    var mode by remember { mutableStateOf("practice") }
    var date by remember { mutableStateOf("") }
    var time by remember { mutableStateOf("") }
    var attempts by remember { mutableStateOf<Int?>(null) }
    val dateOk = date.isBlank() || runCatching { java.time.LocalDate.parse(date) }.isSuccess
    val timeOk = time.isBlank() || Regex("^([01]?\\d|2[0-3]):[0-5]\\d$").matches(time)
    ModalBottomSheet(
        onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = c.surface,
        shape = RoundedCornerShape(topStart = Radius.xl, topEnd = Radius.xl),
        dragHandle = { Box(Modifier.padding(top = 12.dp, bottom = 4.dp).size(width = 40.dp, height = 4.dp).clip(RoundedCornerShape(2.dp)).background(c.border)) },
    ) {
        Column(Modifier.imePadding().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(bottom = 28.dp)) {
            Text(m.title, style = MaterialTheme.typography.titleLarge, color = c.ink)
            Text(stringResource(R.string.assign_material), style = MaterialTheme.typography.bodySmall, color = c.inkSecondary); VSpace(14.dp)
            Text(stringResource(R.string.assign_classes), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary); VSpace(6.dp)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(distinct, key = { it.classId }) { cls -> TogglePill(cls.className ?: "#${cls.classId}", cls.classId in picked) { picked = if (cls.classId in picked) picked - cls.classId else picked + cls.classId } }
            }
            VSpace(12.dp)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TogglePill(stringResource(R.string.mode_practice), mode == "practice") { mode = "practice" }
                TogglePill(stringResource(R.string.mode_control), mode == "control") { mode = "control" }
            }
            VSpace(12.dp)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { AppTextField(date, { date = formatDateInput(it) }, stringResource(R.string.assign_due_date), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), isError = !dateOk) }
                Box(Modifier.weight(1f)) { AppTextField(time, { time = formatTimeInput(it) }, stringResource(R.string.assign_due_time), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), isError = !timeOk) }
            }
            Text(stringResource(R.string.assign_due_hint), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary); VSpace(12.dp)
            Text(stringResource(R.string.assign_attempts), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary); VSpace(6.dp)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TogglePill(stringResource(R.string.attempts_unlimited), attempts == null) { attempts = null }
                listOf(1, 2, 3).forEach { n -> TogglePill("$n", attempts == n) { attempts = n } }
            }
            VSpace(18.dp)
            PrimaryButton(
                stringResource(R.string.assign_material),
                onClick = {
                    val due = if (date.isNotBlank()) date + "T" + (time.ifBlank { "23:59" }) + ":00" else null
                    onAssign(picked.toList(), mode, due, attempts)
                },
                enabled = picked.isNotEmpty() && dateOk && timeOk, loading = busy,
            )
        }
    }
}

@Composable
private fun TogglePill(text: String, selected: Boolean, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    Box(
        Modifier.clip(RoundedCornerShape(999.dp)).background(if (selected) c.brand else c.surfaceSoft).border(1.dp, if (selected) c.brand else c.border, RoundedCornerShape(999.dp)).clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 8.dp),
    ) { Text(text, style = MaterialTheme.typography.labelMedium, color = if (selected) Color.White else c.ink) }
}

// =============================================================== Results

@Composable
fun ResultsScreen(assignmentId: Int, onBack: () -> Unit, vm: ResultsViewModel = koinViewModel()) {
    LaunchedEffect(assignmentId) { vm.load(assignmentId) }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val c = MaterialTheme.smart
    var confirm by remember { mutableStateOf(false) }

    PageBackground {
        Column(Modifier.fillMaxSize()) {
            val a = (ui.data as? UiState.Ready)?.data?.assignment
            ScreenHeader(stringResource(R.string.results_title), subtitle = a?.let { "${it.className} · ${it.materialTitle}" }, onBack = onBack)
            when (val s = ui.data) {
                UiState.Loading -> SkeletonList(rows = 5, rowHeight = 64.dp)
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = { vm.load(assignmentId) })
                is UiState.Ready -> {
                    val d = s.data
                    LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (!d.resultsVisible) {
                            item {
                                Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.sm)).background(c.amberSoft).padding(12.dp)) {
                                    Text(stringResource(R.string.results_hidden), style = MaterialTheme.typography.bodyMedium, color = c.amber)
                                }
                            }
                        }
                        items(d.rows, key = { it.studentId }) { row ->
                            ResultRow(row, visible = d.resultsVisible, mark = ui.marks[row.studentId], onMark = { vm.setMark(row.studentId, it) })
                        }
                    }
                    if (d.resultsVisible && ui.marks.isNotEmpty()) {
                        Box(Modifier.padding(horizontal = 20.dp).padding(bottom = 20.dp)) {
                            PrimaryButton(stringResource(R.string.results_transfer, ui.marks.size), onClick = { confirm = true }, loading = ui.saving)
                        }
                    }
                }
            }
        }
    }

    if (confirm) {
        AlertDialog(
            onDismissRequest = { confirm = false }, containerColor = c.surface, shape = RoundedCornerShape(Radius.lg),
            title = { Text(stringResource(R.string.results_transfer, ui.marks.size), style = MaterialTheme.typography.titleLarge) },
            confirmButton = { TextButton(onClick = { confirm = false; vm.transfer() }) { Text(stringResource(R.string.save)) } },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text(stringResource(R.string.cancel)) } },
        )
    }
    if (ui.done || ui.error != null) {
        AlertDialog(
            onDismissRequest = vm::clearFlags, containerColor = c.surface, shape = RoundedCornerShape(Radius.lg),
            text = { Text(ui.error?.message() ?: stringResource(R.string.results_transfer_done), style = MaterialTheme.typography.bodyLarge) },
            confirmButton = { TextButton(onClick = vm::clearFlags) { Text(stringResource(R.string.done)) } },
        )
    }
}

@Composable
private fun ResultRow(row: ResultRowDto, visible: Boolean, mark: Int?, onMark: (Int?) -> Unit) {
    val c = MaterialTheme.smart
    val submitted = row.submittedAt != null
    SoftCard(contentPadding = PaddingValues(12.dp), elevation = 4.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(row.studentName, style = MaterialTheme.typography.titleSmall, color = c.ink)
                when {
                    !submitted -> Text(stringResource(R.string.results_not_submitted), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
                    visible && row.percent != null -> Text("${row.score} / ${row.maxScore} · ${row.percent}%", style = MaterialTheme.typography.labelSmall, color = c.inkSecondary)
                    else -> Text(stringResource(R.string.assignment_submitted), style = MaterialTheme.typography.labelSmall, color = c.mint)
                }
            }
            if (row.transferred) {
                Chip(stringResource(R.string.results_transferred), c.mint, c.mintSoft)
            } else if (visible && submitted) {
                MarkPicker(mark, onMark)
            }
        }
    }
}

/** A compact 1-10 strip; the suggested mark is preselected. */
@Composable
private fun MarkPicker(mark: Int?, onMark: (Int?) -> Unit) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.fillMaxWidth(0.62f)) {
        items((1..10).toList()) { v ->
            val (gc, gs) = gradeColors(v.toDouble())
            val selected = mark == v
            Box(
                Modifier.size(30.dp).clip(RoundedCornerShape(8.dp)).background(if (selected) gc else gs).clickable { onMark(if (selected) null else v) },
                contentAlignment = Alignment.Center,
            ) { Text("$v", style = MaterialTheme.typography.labelSmall, color = if (selected) Color.White else gc) }
        }
    }
}
