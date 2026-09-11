package tj.cict.smartflow.ui.director

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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.LocalDate
import java.time.YearMonth
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonthTime
import tj.cict.smartflow.core.util.formatAverage
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.core.util.monthYear
import tj.cict.smartflow.data.dto.LeaderboardEntryDto
import tj.cict.smartflow.data.dto.SchoolSettingsUpdate
import tj.cict.smartflow.domain.Child
import tj.cict.smartflow.ui.calendar.EventCard
import tj.cict.smartflow.ui.components.AppTextField
import tj.cict.smartflow.ui.components.ChildAvatar
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.PrimaryButton
import tj.cict.smartflow.ui.components.RoundIconButton
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.Segment
import tj.cict.smartflow.ui.components.SegmentRow
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.grades.gradeColors
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

// ================================================================= Analytics

@Composable
fun DirectorAnalyticsScreen(schoolVm: SchoolViewModel, bottomPadding: Dp, vm: DirectorAnalyticsViewModel = koinViewModel()) {
    LaunchedEffect(Unit) { vm.load() }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val school by schoolVm.ui.collectAsStateWithLifecycle()
    val c = MaterialTheme.smart
    var tab by rememberSaveable { mutableStateOf(0) }

    Column(Modifier.fillMaxSize()) {
        ScreenHeader(stringResource(R.string.analytics_title))
        SegmentRow(Modifier.padding(horizontal = 20.dp)) {
            Segment(stringResource(R.string.action_ranking), tab == 0) { tab = 0 }
            Segment(stringResource(R.string.attention_title), tab == 1) { tab = 1 }
        }
        VSpace(8.dp)
        if (tab == 0) {
            LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                item { Pill(stringResource(R.string.ranking_school), ui.classId == null) { vm.pickClass(null) } }
                items(school.classList, key = { it.id }) { cls -> Pill(cls.name, ui.classId == cls.id) { vm.pickClass(cls.id) } }
            }
            VSpace(8.dp)
            when (val s = ui.ranking) {
                UiState.Loading -> SkeletonList(rows = 6, rowHeight = 60.dp)
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = { vm.pickClass(ui.classId) })
                is UiState.Ready -> if (s.data.isEmpty()) EmptyState(R.drawable.ill_trophy, stringResource(R.string.rating_empty)) else {
                    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = bottomPadding + 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(s.data, key = { it.studentId }) { e -> RankRow(e) }
                    }
                }
            }
        } else {
            when (val s = ui.attention) {
                UiState.Loading -> SkeletonList(rows = 4)
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = vm::load)
                is UiState.Ready -> {
                    val d = s.data
                    if (d.bottomPerformers.isEmpty() && d.biggestDecliners.isEmpty()) { EmptyState(R.drawable.ill_trophy, stringResource(R.string.attention_none)); return@Column }
                    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = bottomPadding + 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (d.biggestDecliners.isNotEmpty()) {
                            item { Text(stringResource(R.string.attention_decline), style = MaterialTheme.typography.titleMedium, color = c.ink, modifier = Modifier.padding(top = 6.dp)) }
                            items(d.biggestDecliners, key = { "d${it.studentId}" }) { e ->
                                SoftCard(contentPadding = PaddingValues(10.dp), elevation = 4.dp) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        ChildAvatar(Child(e.studentId, e.firstName, e.lastName, e.className), 38.dp); HSpace(12.dp)
                                        Column(Modifier.weight(1f)) {
                                            Text("${e.lastName} ${e.firstName}", style = MaterialTheme.typography.titleSmall, color = c.ink)
                                            Text(listOfNotNull(e.className, stringResource(R.string.was_now, formatAverage(e.previousAverage), formatAverage(e.currentAverage))).joinToString(" · "), style = MaterialTheme.typography.labelSmall, color = c.inkSecondary)
                                        }
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Rounded.ArrowDownward, null, tint = c.rose, modifier = Modifier.size(16.dp))
                                            Text(String.format(java.util.Locale.US, "%.1f", e.delta), style = MaterialTheme.typography.titleSmall, color = c.rose)
                                        }
                                    }
                                }
                            }
                        }
                        if (d.bottomPerformers.isNotEmpty()) {
                            item { Text(stringResource(R.string.attention_bottom), style = MaterialTheme.typography.titleMedium, color = c.ink, modifier = Modifier.padding(top = 10.dp)) }
                            items(d.bottomPerformers, key = { "b${it.studentId}" }) { e -> RankRow(e) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Pill(text: String, selected: Boolean, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    Box(
        Modifier.clip(RoundedCornerShape(999.dp)).background(if (selected) c.brand else c.surface).border(1.dp, if (selected) c.brand else c.border, RoundedCornerShape(999.dp)).clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
    ) { Text(text, style = MaterialTheme.typography.labelMedium, color = if (selected) Color.White else c.ink) }
}

@Composable
private fun RankRow(e: LeaderboardEntryDto) {
    val c = MaterialTheme.smart
    val medal = when (e.position) { 1 -> c.amber; 2 -> Color(0xFF9CA3AF); 3 -> Color(0xFFC77B3F); else -> null }
    SoftCard(contentPadding = PaddingValues(10.dp), elevation = 4.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(34.dp).clip(CircleShape).background(medal?.copy(alpha = 0.18f) ?: c.surfaceSoft), contentAlignment = Alignment.Center) {
                Text("${e.position}", style = MaterialTheme.typography.labelLarge, color = medal ?: c.inkSecondary)
            }
            HSpace(10.dp)
            ChildAvatar(Child(e.studentId, e.firstName, e.lastName, e.className), 36.dp); HSpace(10.dp)
            Column(Modifier.weight(1f)) {
                Text("${e.lastName} ${e.firstName}", style = MaterialTheme.typography.titleSmall, color = c.ink, maxLines = 1)
                e.className?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = c.inkTertiary) }
            }
            e.overallAverage?.let { avg ->
                val (gc, gs) = gradeColors(avg)
                Box(Modifier.clip(RoundedCornerShape(999.dp)).background(gs).padding(horizontal = 10.dp, vertical = 5.dp)) { Text(formatAverage(avg), style = MaterialTheme.typography.titleSmall, color = gc) }
            }
        }
    }
}

// ============================================================ Announcements

@Composable
fun DirectorAnnouncementsScreen(schoolVm: SchoolViewModel, onBack: () -> Unit, vm: DirectorNoticesViewModel = koinViewModel()) {
    LaunchedEffect(Unit) { vm.loadAnnouncements() }
    val state by vm.announcements.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val school by schoolVm.ui.collectAsStateWithLifecycle()
    val locale = currentLocale()
    val c = MaterialTheme.smart
    var adding by remember { mutableStateOf(false) }
    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.school_announcements), onBack = onBack, trailing = { RoundIconButton(Icons.Rounded.Add, stringResource(R.string.new_announcement), { adding = true }) })
            when (val s = state) {
                UiState.Loading -> SkeletonList()
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = vm::loadAnnouncements)
                is UiState.Ready -> if (s.data.isEmpty()) EmptyState(R.drawable.ill_megaphone, stringResource(R.string.announcements_empty)) else {
                    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        items(s.data, key = { it.id }) { a ->
                            SoftCard(contentPadding = PaddingValues(16.dp), elevation = 5.dp) {
                                Row(verticalAlignment = Alignment.Top) {
                                    Column(Modifier.weight(1f)) {
                                        Text(listOfNotNull(a.createdAt?.dayMonthTime(locale), school.classList.firstOrNull { it.id == a.classId }?.name ?: stringResource(R.string.whole_school)).joinToString(" · "), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
                                        VSpace(4.dp)
                                        Text(a.title, style = MaterialTheme.typography.titleMedium, color = c.ink)
                                        VSpace(4.dp)
                                        Text(a.body, style = MaterialTheme.typography.bodyMedium, color = c.inkSecondary)
                                    }
                                    Box(Modifier.size(34.dp).clip(CircleShape).clickable { vm.deleteAnnouncement(a.id) }, contentAlignment = Alignment.Center) { Icon(Icons.Outlined.Delete, null, tint = c.inkTertiary, modifier = Modifier.size(18.dp)) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (adding) {
        var title by remember { mutableStateOf("") }; var body by remember { mutableStateOf("") }; var classId by remember { mutableStateOf<Int?>(null) }
        FormSheet(onDismiss = { adding = false }) {
            Text(stringResource(R.string.new_announcement), style = MaterialTheme.typography.titleLarge); VSpace(14.dp)
            AppTextField(title, { title = it }, stringResource(R.string.ann_title)); VSpace(10.dp)
            AppTextField(body, { body = it }, stringResource(R.string.ann_body), singleLine = false); VSpace(10.dp)
            Text(stringResource(R.string.ann_for), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary); VSpace(6.dp)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                item { Pill(stringResource(R.string.whole_school), classId == null) { classId = null } }
                items(school.classList, key = { it.id }) { cls -> Pill(cls.name, classId == cls.id) { classId = cls.id } }
            }
            VSpace(16.dp)
            PrimaryButton(stringResource(R.string.publish), onClick = { vm.createAnnouncement(title.trim(), body.trim(), classId) { adding = false } }, enabled = title.isNotBlank() && body.isNotBlank(), loading = busy)
        }
    }
}

// ================================================================= Calendar

private val eventTypes = listOf("event" to R.string.event_other, "holiday" to R.string.event_holiday, "exam" to R.string.event_exam, "meeting" to R.string.event_meeting)

@Composable
fun DirectorCalendarScreen(schoolVm: SchoolViewModel, onBack: () -> Unit, vm: DirectorNoticesViewModel = koinViewModel()) {
    LaunchedEffect(Unit) { vm.loadEvents() }
    val state by vm.events.collectAsStateWithLifecycle()
    val busy by vm.busy.collectAsStateWithLifecycle()
    val school by schoolVm.ui.collectAsStateWithLifecycle()
    val locale = currentLocale()
    val c = MaterialTheme.smart
    var adding by remember { mutableStateOf(false) }
    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.school_calendar), onBack = onBack, trailing = { RoundIconButton(Icons.Rounded.Add, stringResource(R.string.new_event), { adding = true }) })
            when (val s = state) {
                UiState.Loading -> SkeletonList()
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = vm::loadEvents)
                is UiState.Ready -> {
                    val today = LocalDate.now()
                    val upcoming = s.data.filter { (it.endDate ?: it.startDate) >= today }.sortedBy { it.startDate }
                    if (upcoming.isEmpty()) { EmptyState(R.drawable.ill_calendar, stringResource(R.string.calendar_empty)); return@Column }
                    val byMonth = upcoming.groupBy { YearMonth.from(it.startDate) }
                    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        byMonth.forEach { (month, list) ->
                            item(key = "m$month") { Text(month.atDay(1).monthYear(locale), style = MaterialTheme.typography.titleMedium, color = c.ink, modifier = Modifier.padding(top = 8.dp)) }
                            items(list, key = { it.id }) { e ->
                                Box {
                                    EventCard(e, locale)
                                    Box(Modifier.align(Alignment.BottomEnd).padding(6.dp).size(30.dp).clip(CircleShape).clickable { vm.deleteEvent(e.id) }, contentAlignment = Alignment.Center) { Icon(Icons.Outlined.Delete, null, tint = c.inkTertiary, modifier = Modifier.size(16.dp)) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (adding) {
        var title by remember { mutableStateOf("") }; var desc by remember { mutableStateOf("") }; var type by remember { mutableStateOf("event") }
        var start by remember { mutableStateOf(LocalDate.now().plusDays(1).toString()) }; var end by remember { mutableStateOf("") }; var classId by remember { mutableStateOf<Int?>(null) }
        val startDate = runCatching { LocalDate.parse(start.trim()) }.getOrNull()
        val endDate = runCatching { LocalDate.parse(end.trim()) }.getOrNull()
        FormSheet(onDismiss = { adding = false }) {
            Text(stringResource(R.string.new_event), style = MaterialTheme.typography.titleLarge); VSpace(14.dp)
            AppTextField(title, { title = it }, stringResource(R.string.event_title)); VSpace(10.dp)
            AppTextField(desc, { desc = it }, stringResource(R.string.event_desc), singleLine = false); VSpace(10.dp)
            Text(stringResource(R.string.event_type), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary); VSpace(6.dp)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) { items(eventTypes) { (key, label) -> Pill(stringResource(label), type == key) { type = key } } }
            VSpace(10.dp)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { AppTextField(start, { start = it }, stringResource(R.string.event_start), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), isError = startDate == null) }
                Box(Modifier.weight(1f)) { AppTextField(end, { end = it }, stringResource(R.string.event_end), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), isError = end.isNotBlank() && endDate == null) }
            }
            Text(stringResource(R.string.date_format_hint), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary); VSpace(10.dp)
            Text(stringResource(R.string.ann_for), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary); VSpace(6.dp)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                item { Pill(stringResource(R.string.whole_school), classId == null) { classId = null } }
                items(school.classList, key = { it.id }) { cls -> Pill(cls.name, classId == cls.id) { classId = cls.id } }
            }
            VSpace(16.dp)
            PrimaryButton(
                stringResource(R.string.create),
                onClick = { vm.createEvent(title.trim(), desc.trim().ifBlank { null }, type, startDate!!, endDate, classId) { adding = false } },
                enabled = title.isNotBlank() && startDate != null && (end.isBlank() || endDate != null), loading = busy,
            )
        }
    }
}

@Composable
private fun FormSheet(onDismiss: () -> Unit, content: @Composable () -> Unit) {
    val c = MaterialTheme.smart
    ModalBottomSheet(
        onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = c.surface,
        shape = RoundedCornerShape(topStart = Radius.xl, topEnd = Radius.xl),
        dragHandle = { Box(Modifier.padding(top = 12.dp, bottom = 4.dp).size(width = 40.dp, height = 4.dp).clip(RoundedCornerShape(2.dp)).background(c.border)) },
    ) {
        Column(Modifier.imePadding().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(bottom = 28.dp)) { content() }
    }
}

// ================================================================= Settings

@Composable
fun SettingsScreen(onBack: () -> Unit, vm: SettingsViewModel = koinViewModel()) {
    LaunchedEffect(Unit) { vm.load() }
    val state by vm.state.collectAsStateWithLifecycle()
    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.settings_title), onBack = onBack)
            when (val s = state) {
                UiState.Loading -> SkeletonList(rows = 4, rowHeight = 80.dp)
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = vm::load)
                is UiState.Ready -> Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    val d = s.data
                    Toggle(stringResource(R.string.setting_live), stringResource(R.string.setting_live_hint), d.liveVideoEnabled) { vm.update(SchoolSettingsUpdate(liveVideoEnabled = it)) }
                    Toggle(stringResource(R.string.setting_group), stringResource(R.string.setting_group_hint), d.groupMode) { vm.update(SchoolSettingsUpdate(groupMode = it)) }
                    Toggle(stringResource(R.string.setting_sms), stringResource(R.string.setting_sms_hint), d.smsEnabled) { vm.update(SchoolSettingsUpdate(smsEnabled = it)) }
                    Toggle(stringResource(R.string.setting_active), stringResource(R.string.setting_active_hint), d.isActive) { vm.update(SchoolSettingsUpdate(isActive = it)) }
                }
            }
        }
    }
}

@Composable
private fun Toggle(title: String, hint: String, value: Boolean, onChange: (Boolean) -> Unit) {
    val c = MaterialTheme.smart
    SoftCard(contentPadding = PaddingValues(14.dp), elevation = 4.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium, color = c.ink)
                Text(hint, style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
            }
            HSpace(12.dp)
            Switch(value, onChange, colors = SwitchDefaults.colors(checkedTrackColor = c.brand))
        }
    }
}
