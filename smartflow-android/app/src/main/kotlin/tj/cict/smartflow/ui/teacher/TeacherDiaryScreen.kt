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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.core.util.monthYear
import tj.cict.smartflow.core.util.weekdayShort
import tj.cict.smartflow.data.dto.TeacherDiaryEntryDto
import tj.cict.smartflow.ui.components.AppTextField
import tj.cict.smartflow.ui.components.Chip
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.PrimaryButton
import tj.cict.smartflow.ui.components.RoundIconButton
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.TintPanel
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.diary.subjectColor
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

/**
 * The diary tab for a teacher: the class's day, with the teacher's own
 * lessons editable and colleagues' lessons shown for context.
 */
@Composable
fun TeacherDiaryScreen(classesVm: TeacherClassesViewModel, teacherId: Int, bottomPadding: Dp, vm: TeacherDiaryViewModel = koinViewModel()) {
    val classes by classesVm.state.collectAsStateWithLifecycle()
    val ui by vm.ui.collectAsStateWithLifecycle()
    val locale = currentLocale()
    val c = MaterialTheme.smart
    val list = (classes as? UiState.Ready)?.data.orEmpty().distinctBy { it.classId }
    LaunchedEffect(list) { if (ui.classId == null) list.firstOrNull()?.let { vm.openClass(it.classId) } }
    var editing by remember { mutableStateOf<TeacherDiaryEntryDto?>(null) }

    Column(Modifier.fillMaxSize()) {
        ScreenHeader(
            stringResource(R.string.diary_title), subtitle = ui.date.monthYear(locale),
            trailing = {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    RoundIconButton(Icons.Rounded.ChevronLeft, null, { vm.shiftWeek(-1) })
                    RoundIconButton(Icons.Rounded.ChevronRight, null, { vm.shiftWeek(1) })
                }
            },
        )
        if (list.size > 1) {
            LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(list, key = { it.classId }) { cls ->
                    val selected = cls.classId == ui.classId
                    Box(
                        Modifier.clip(RoundedCornerShape(999.dp)).background(if (selected) c.brand else c.surface).border(1.dp, if (selected) c.brand else c.border, RoundedCornerShape(999.dp))
                            .clickable { vm.openClass(cls.classId) }.padding(horizontal = 16.dp, vertical = 8.dp),
                    ) { Text(cls.className ?: "", style = MaterialTheme.typography.labelMedium, color = if (selected) Color.White else c.ink) }
                }
            }
            VSpace(10.dp)
        }
        WeekStrip(ui.date, onPick = vm::pick, locale = locale)
        VSpace(6.dp)
        when (val s = ui.entries) {
            UiState.Loading -> if (ui.classId == null && classes is UiState.Ready) EmptyState(R.drawable.ill_backpack, stringResource(R.string.no_classes)) else SkeletonList(rows = 3)
            is UiState.Failed -> ErrorState(s.error.message(), onRetry = vm::load)
            is UiState.Ready -> if (s.data.isEmpty()) {
                EmptyState(R.drawable.ill_book, stringResource(R.string.diary_empty))
            } else {
                LazyColumn(
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = bottomPadding + 16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    item { Text(stringResource(R.string.diary_edit_hint), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary) }
                    items(s.data, key = { it.lessonId }) { e ->
                        val mine = e.teacherId == teacherId
                        LessonRow(e, mine, index = s.data.indexOf(e), onClick = { if (mine) editing = e })
                    }
                }
            }
        }
    }

    editing?.let { e ->
        DiaryEditSheet(e, saving = ui.saving, onDismiss = { editing = null }, onSave = { hw, cm -> vm.save(e.lessonId, hw, cm) { editing = null } })
    }
}

@Composable
private fun WeekStrip(selected: LocalDate, onPick: (LocalDate) -> Unit, locale: java.util.Locale) {
    val c = MaterialTheme.smart
    val monday = selected.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
    val today = LocalDate.now()
    Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        (0..5).forEach { offset ->
            val day = monday.plusDays(offset.toLong())
            val active = day == selected
            Column(
                Modifier.weight(1f).clip(RoundedCornerShape(Radius.md)).background(if (active) c.brand else c.surface)
                    .border(1.dp, if (active) c.brand else c.border, RoundedCornerShape(Radius.md)).clickable { onPick(day) }.padding(vertical = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(day.weekdayShort(locale).take(2), style = MaterialTheme.typography.labelSmall, color = if (active) Color.White.copy(alpha = 0.8f) else c.inkTertiary)
                Text("${day.dayOfMonth}", style = MaterialTheme.typography.titleMedium, color = if (active) Color.White else c.ink)
                Box(Modifier.padding(top = 3.dp).size(5.dp).clip(CircleShape).background(if (day == today) (if (active) Color.White else c.coral) else Color.Transparent))
            }
        }
    }
}

@Composable
private fun LessonRow(e: TeacherDiaryEntryDto, mine: Boolean, index: Int, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    SoftCard(contentPadding = PaddingValues(14.dp), elevation = if (mine) 7.dp else 3.dp, onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(e.startTime.take(5), style = MaterialTheme.typography.titleSmall, color = c.ink, modifier = Modifier.width(48.dp))
            Box(Modifier.padding(horizontal = 8.dp).width(3.dp).height(34.dp).clip(RoundedCornerShape(2.dp)).background(subjectColor(index)))
            Column(Modifier.weight(1f)) {
                Text(e.subject, style = MaterialTheme.typography.titleMedium, color = c.ink)
                Text(listOfNotNull(e.teacherName, e.room?.let { stringResource(R.string.room_label, it) }).joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
            }
            HSpace(8.dp)
            if (mine) Chip(stringResource(R.string.diary_my_lesson), c.brandDeep, c.brandSoft) else Chip(stringResource(R.string.diary_not_mine), c.inkTertiary, c.surfaceSoft)
        }
        if (!e.homework.isNullOrBlank()) {
            VSpace(10.dp)
            TintPanel(c.brandTint) {
                Text(stringResource(R.string.homework_label), style = MaterialTheme.typography.labelSmall, color = c.brandDeep)
                Text(e.homework, style = MaterialTheme.typography.bodyMedium, color = c.ink)
            }
        }
        if (!e.teacherComment.isNullOrBlank()) {
            VSpace(8.dp)
            TintPanel(c.amberSoft) {
                Text(stringResource(R.string.teacher_comment), style = MaterialTheme.typography.labelSmall, color = c.amber)
                Text(e.teacherComment, style = MaterialTheme.typography.bodyMedium, color = c.ink)
            }
        }
    }
}

@Composable
private fun DiaryEditSheet(e: TeacherDiaryEntryDto, saving: Boolean, onDismiss: () -> Unit, onSave: (String, String) -> Unit) {
    val c = MaterialTheme.smart
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var homework by remember(e) { mutableStateOf(e.homework.orEmpty()) }
    var comment by remember(e) { mutableStateOf(e.teacherComment.orEmpty()) }
    ModalBottomSheet(
        onDismissRequest = onDismiss, sheetState = sheet, containerColor = c.surface,
        shape = RoundedCornerShape(topStart = Radius.xl, topEnd = Radius.xl),
        dragHandle = { Box(Modifier.padding(top = 12.dp, bottom = 4.dp).size(width = 40.dp, height = 4.dp).clip(RoundedCornerShape(2.dp)).background(c.border)) },
    ) {
        Column(Modifier.imePadding().padding(horizontal = 24.dp).padding(bottom = 28.dp)) {
            Text(e.subject, style = MaterialTheme.typography.titleLarge, color = c.ink)
            Text(e.startTime.take(5), style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
            VSpace(16.dp)
            AppTextField(value = homework, onValueChange = { homework = it }, label = stringResource(R.string.homework_edit), singleLine = false)
            VSpace(10.dp)
            AppTextField(value = comment, onValueChange = { comment = it }, label = stringResource(R.string.comment_edit), singleLine = false)
            VSpace(18.dp)
            PrimaryButton(stringResource(R.string.save), onClick = { onSave(homework.trim(), comment.trim()) }, loading = saving)
        }
    }
}
