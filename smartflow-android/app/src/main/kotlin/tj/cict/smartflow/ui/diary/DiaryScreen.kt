package tj.cict.smartflow.ui.diary

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonth
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.core.util.monthYear
import tj.cict.smartflow.core.util.parseTime
import tj.cict.smartflow.core.util.toUiState
import tj.cict.smartflow.core.util.weekdayLong
import tj.cict.smartflow.core.util.weekdayShort
import tj.cict.smartflow.data.dto.DiaryEntryDto
import tj.cict.smartflow.data.repo.ParentRepository
import tj.cict.smartflow.ui.components.ChildSwitcher
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.RoundIconButton
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.TintPanel
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.grades.gradeColors
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

data class DiaryUi(
    val date: LocalDate = LocalDate.now(),
    val lessons: UiState<List<DiaryEntryDto>> = UiState.Loading,
)

class DiaryViewModel(private val repo: ParentRepository) : ViewModel() {
    private val _ui = MutableStateFlow(DiaryUi())
    val ui: StateFlow<DiaryUi> = _ui.asStateFlow()
    private var childId: Int? = null

    fun open(child: Int) {
        if (childId == child) return
        childId = child
        load()
    }

    fun pick(date: LocalDate) {
        if (_ui.value.date == date) return
        _ui.update { it.copy(date = date) }
        load()
    }

    fun shiftWeek(delta: Long) = pick(_ui.value.date.plusWeeks(delta))

    fun load() {
        val id = childId ?: return
        val date = _ui.value.date
        _ui.update { it.copy(lessons = UiState.Loading) }
        viewModelScope.launch {
            val result = repo.diary(id, date).toUiState()
            // Only the answer for the date still on screen counts.
            if (_ui.value.date == date) _ui.update { it.copy(lessons = result) }
        }
    }
}

@Composable
fun DiaryScreen(childrenVm: ChildrenViewModel, bottomPadding: Dp, vm: DiaryViewModel = koinViewModel()) {
    val children by childrenVm.ui.collectAsStateWithLifecycle()
    val ui by vm.ui.collectAsStateWithLifecycle()
    val child = children.selected
    LaunchedEffect(child?.id) { child?.let { vm.open(it.id) } }
    val locale = currentLocale()

    Column(Modifier.fillMaxSize()) {
        ScreenHeader(
            stringResource(R.string.diary_title),
            subtitle = ui.date.monthYear(locale),
            trailing = {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    RoundIconButton(Icons.Rounded.ChevronLeft, null, { vm.shiftWeek(-1) })
                    RoundIconButton(Icons.Rounded.ChevronRight, null, { vm.shiftWeek(1) })
                }
            },
        )
        ChildSwitcher(children.children.map { it.child }, child?.id, onSelect = childrenVm::select)
        if (children.children.size > 1) VSpace(10.dp)
        WeekStrip(ui.date, onPick = vm::pick, locale = locale)
        VSpace(6.dp)

        when (val s = ui.lessons) {
            UiState.Loading -> SkeletonList(rows = 3)
            is UiState.Failed -> ErrorState(s.error.message(), vm::load)
            is UiState.Ready -> {
                if (child == null) {
                    EmptyState(R.drawable.ill_backpack, stringResource(R.string.home_no_children_title))
                } else if (s.data.isEmpty()) {
                    EmptyState(R.drawable.ill_book, stringResource(R.string.diary_empty), "${ui.date.weekdayLong(locale)}, ${ui.date.dayMonth(locale)}")
                } else {
                    LazyColumn(
                        Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = bottomPadding + 16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        itemsIndexed(s.data, key = { i, e -> "${e.lessonId}-$i" }) { index, entry ->
                            LessonCard(index + 1, entry)
                        }
                    }
                }
            }
        }
    }
}

/** Monday to Saturday of the week that holds [selected]. Sunday is not a school day here. */
@Composable
private fun WeekStrip(selected: LocalDate, onPick: (LocalDate) -> Unit, locale: java.util.Locale) {
    val c = MaterialTheme.smart
    val monday = selected.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
    val today = LocalDate.now()
    Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        (0..5).forEach { offset ->
            val day = monday.plusDays(offset.toLong())
            val active = day == selected
            val isToday = day == today
            Column(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(Radius.md))
                    .background(if (active) c.brand else c.surface)
                    .border(1.dp, if (active) c.brand else c.border, RoundedCornerShape(Radius.md))
                    .clickable { onPick(day) }
                    .padding(vertical = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(day.weekdayShort(locale).take(2), style = MaterialTheme.typography.labelSmall, color = if (active) Color.White.copy(alpha = 0.8f) else c.inkTertiary)
                Text("${day.dayOfMonth}", style = MaterialTheme.typography.titleMedium, color = if (active) Color.White else c.ink)
                Box(Modifier.padding(top = 3.dp).size(5.dp).clip(CircleShape).background(if (isToday) (if (active) Color.White else c.coral) else Color.Transparent))
            }
        }
    }
}

@Composable
private fun LessonCard(index: Int, entry: DiaryEntryDto) {
    val c = MaterialTheme.smart
    val start = parseTime(entry.startTime)
    val end = start?.plusMinutes(entry.durationMinutes.toLong())
    SoftCard(contentPadding = PaddingValues(16.dp), elevation = 6.dp) {
        Row {
            Column(Modifier.width(52.dp)) {
                Text(start?.let { String.format("%02d:%02d", it.hour, it.minute) } ?: entry.startTime.take(5), style = MaterialTheme.typography.titleSmall, color = c.ink)
                Text(end?.let { String.format("%02d:%02d", it.hour, it.minute) } ?: "", style = MaterialTheme.typography.bodySmall, color = c.inkTertiary)
            }
            Box(Modifier.padding(horizontal = 10.dp).width(3.dp).height(40.dp).clip(RoundedCornerShape(2.dp)).background(subjectColor(index)))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(entry.subject, style = MaterialTheme.typography.titleMedium, color = c.ink, modifier = Modifier.weight(1f))
                    entry.grade?.let { g ->
                        val (gc, gs) = gradeColors(g.toDouble())
                        Box(Modifier.size(30.dp).clip(RoundedCornerShape(9.dp)).background(gs), contentAlignment = Alignment.Center) {
                            Text("$g", style = MaterialTheme.typography.titleSmall, color = gc)
                        }
                    }
                }
                val meta = listOfNotNull(entry.teacherName?.takeIf { it.isNotBlank() }, entry.room?.let { stringResource(R.string.room_label, it) })
                if (meta.isNotEmpty()) {
                    Text(meta.joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
                }
            }
        }
        if (!entry.homework.isNullOrBlank()) {
            VSpace(12.dp)
            TintPanel(c.brandTint) {
                Text(stringResource(R.string.homework_label), style = MaterialTheme.typography.labelSmall, color = c.brandDeep)
                VSpace(2.dp)
                Text(entry.homework, style = MaterialTheme.typography.bodyMedium, color = c.ink)
            }
        }
        if (!entry.teacherComment.isNullOrBlank()) {
            VSpace(8.dp)
            TintPanel(c.amberSoft) {
                Text(stringResource(R.string.teacher_comment), style = MaterialTheme.typography.labelSmall, color = c.amber)
                VSpace(2.dp)
                Text(entry.teacherComment, style = MaterialTheme.typography.bodyMedium, color = c.ink)
            }
        }
    }
}

@Composable
fun subjectColor(index: Int): Color {
    val c = MaterialTheme.smart
    val palette = listOf(c.brand, c.coral, c.sky, c.mint, c.amber, c.rose)
    return palette[Math.floorMod(index, palette.size)]
}
