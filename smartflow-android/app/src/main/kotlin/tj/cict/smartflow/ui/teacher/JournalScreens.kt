package tj.cict.smartflow.ui.teacher

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonth
import tj.cict.smartflow.core.util.formatAverage
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.data.dto.ClassAssignmentDto
import tj.cict.smartflow.data.dto.GradeDto
import tj.cict.smartflow.data.dto.StudentDto
import tj.cict.smartflow.domain.Child
import tj.cict.smartflow.ui.components.AppTextField
import tj.cict.smartflow.ui.components.ChildAvatar
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.GhostButton
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.PrimaryButton
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.grades.gradeColors
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

/** The journal tab: pick a class, then the sheet for it. */
@Composable
fun JournalClassesScreen(classesVm: TeacherClassesViewModel, bottomPadding: Dp, onOpenClass: (ClassAssignmentDto) -> Unit) {
    val state by classesVm.state.collectAsStateWithLifecycle()
    Column(Modifier.fillMaxSize()) {
        ScreenHeader(stringResource(R.string.journal_title), subtitle = stringResource(R.string.journal_pick_class))
        when (val s = state) {
            UiState.Loading -> SkeletonList(rows = 3, rowHeight = 72.dp)
            is UiState.Failed -> ErrorState(s.error.message(), onRetry = { classesVm.load(force = true) })
            is UiState.Ready -> if (s.data.isEmpty()) {
                EmptyState(R.drawable.ill_backpack, stringResource(R.string.no_classes), stringResource(R.string.no_classes_body))
            } else {
                LazyColumn(
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = bottomPadding + 16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    items(s.data, key = { it.id }) { cls -> ClassCard(cls, onClick = { onOpenClass(cls) }) }
                }
            }
        }
    }
}

/** One class, one subject: every pupil, their recent marks, and a tap to give one. */
@Composable
fun ClassJournalScreen(classId: Int, subject: String, className: String, onBack: () -> Unit, onScan: () -> Unit, vm: ClassJournalViewModel = koinViewModel()) {
    LaunchedEffect(classId, subject) { vm.open(classId, subject) }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val locale = currentLocale()
    var editing by remember { mutableStateOf<JournalRow?>(null) }
    val snackbar = remember { SnackbarHostState() }
    val savedText = stringResource(R.string.grade_saved)
    LaunchedEffect(ui.toast) { if (ui.toast != null) { snackbar.showSnackbar(savedText); vm.clearToast() } }
    val errorText = ui.error?.message()
    LaunchedEffect(errorText) { if (errorText != null) { snackbar.showSnackbar(errorText); vm.clearToast() } }

    PageBackground {
        Box(Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize()) {
                ScreenHeader(
                    "$className · $subject", onBack = onBack,
                    trailing = { GhostButton(stringResource(R.string.action_scan), onClick = onScan) },
                )
                when (val s = ui.rows) {
                    UiState.Loading -> SkeletonList(rows = 6, rowHeight = 76.dp)
                    is UiState.Failed -> ErrorState(s.error.message(), onRetry = vm::load)
                    is UiState.Ready -> LazyColumn(
                        Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 32.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(s.data, key = { it.student.id }) { row -> PupilRow(row, onClick = { editing = row }) }
                    }
                }
            }
            SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter).padding(16.dp))
        }
    }

    editing?.let { row ->
        GradeSheet(
            row = row,
            saving = ui.saving,
            onDismiss = { editing = null },
            onSave = { value, comment -> vm.give(row.student, value, comment, row.today); editing = null },
            onDelete = { g -> vm.delete(g); editing = null },
            locale = locale,
        )
    }
}

@Composable
private fun PupilRow(row: JournalRow, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    val child = Child(row.student.id, row.student.firstName, row.student.lastName, row.student.className)
    SoftCard(contentPadding = PaddingValues(12.dp), elevation = 5.dp, onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ChildAvatar(child, 42.dp)
            HSpace(12.dp)
            Column(Modifier.weight(1f)) {
                Text("${row.student.lastName} ${row.student.firstName}", style = MaterialTheme.typography.titleSmall, color = c.ink, maxLines = 1)
                if (row.absentToday) {
                    Text(stringResource(R.string.journal_absent_today), style = MaterialTheme.typography.labelSmall, color = c.rose)
                } else {
                    row.average?.let { Text("${stringResource(R.string.average)} ${formatAverage(it)}", style = MaterialTheme.typography.labelSmall, color = c.inkTertiary) }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                row.grades.take(4).reversed().forEach { g ->
                    val (gc, gs) = gradeColors(g.value.toDouble())
                    val today = g.date == java.time.LocalDate.now()
                    Box(
                        Modifier.size(30.dp).clip(RoundedCornerShape(8.dp)).background(gs).then(if (today) Modifier.border(1.5.dp, gc, RoundedCornerShape(8.dp)) else Modifier),
                        contentAlignment = Alignment.Center,
                    ) { Text("${g.value}", style = MaterialTheme.typography.labelMedium, color = gc, fontWeight = FontWeight.Bold) }
                }
            }
        }
    }
}

/** Ten big buttons, a comment, save. Editing today's mark or giving a new one. */
@Composable
private fun GradeSheet(row: JournalRow, saving: Boolean, onDismiss: () -> Unit, onSave: (Int, String?) -> Unit, onDelete: (GradeDto) -> Unit, locale: java.util.Locale) {
    val c = MaterialTheme.smart
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val existing = row.today
    var value by remember(row) { mutableStateOf(existing?.value) }
    var comment by remember(row) { mutableStateOf(existing?.comment.orEmpty()) }

    ModalBottomSheet(
        onDismissRequest = onDismiss, sheetState = sheet, containerColor = c.surface,
        shape = RoundedCornerShape(topStart = Radius.xl, topEnd = Radius.xl),
        dragHandle = { Box(Modifier.padding(top = 12.dp, bottom = 4.dp).size(width = 40.dp, height = 4.dp).clip(RoundedCornerShape(2.dp)).background(c.border)) },
    ) {
        Column(Modifier.padding(horizontal = 24.dp).padding(bottom = 28.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                ChildAvatar(Child(row.student.id, row.student.firstName, row.student.lastName, null), 44.dp)
                HSpace(12.dp)
                Column(Modifier.weight(1f)) {
                    Text("${row.student.lastName} ${row.student.firstName}", style = MaterialTheme.typography.titleLarge, color = c.ink)
                    Text(if (existing != null) stringResource(R.string.grade_today) else stringResource(R.string.give_grade), style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
                }
                if (existing != null) {
                    Box(Modifier.size(40.dp).clip(CircleShape).clickable { onDelete(existing) }, contentAlignment = Alignment.Center) {
                        Icon(Icons.Outlined.Delete, stringResource(R.string.delete), tint = c.rose)
                    }
                }
            }
            VSpace(18.dp)
            Text(stringResource(R.string.grade_value), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
            VSpace(8.dp)
            (1..10).chunked(5).forEach { rowValues ->
                Row(Modifier.fillMaxWidth().padding(bottom = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    rowValues.forEach { v ->
                        val (gc, gs) = gradeColors(v.toDouble())
                        val selected = value == v
                        Box(
                            Modifier.weight(1f).size(54.dp).clip(RoundedCornerShape(Radius.sm))
                                .background(if (selected) gc else gs)
                                .border(1.5.dp, if (selected) gc else Color.Transparent, RoundedCornerShape(Radius.sm))
                                .clickable { value = v },
                            contentAlignment = Alignment.Center,
                        ) { Text("$v", style = MaterialTheme.typography.titleLarge, color = if (selected) Color.White else gc) }
                    }
                }
            }
            VSpace(4.dp)
            AppTextField(value = comment, onValueChange = { comment = it }, label = stringResource(R.string.grade_comment), singleLine = false)
            if (row.grades.isNotEmpty()) {
                VSpace(14.dp)
                Text(stringResource(R.string.journal_last_marks), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
                VSpace(6.dp)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    row.grades.take(8).forEach { g ->
                        val (gc, gs) = gradeColors(g.value.toDouble())
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Box(Modifier.size(32.dp).clip(RoundedCornerShape(8.dp)).background(gs), contentAlignment = Alignment.Center) { Text("${g.value}", style = MaterialTheme.typography.labelMedium, color = gc) }
                            Text(g.date.dayMonth(locale).take(6), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary, maxLines = 1)
                        }
                    }
                }
            }
            VSpace(18.dp)
            PrimaryButton(stringResource(R.string.save), onClick = { value?.let { onSave(it, comment.takeIf { c -> c.isNotBlank() }) } }, enabled = value != null, loading = saving)
        }
    }
}
