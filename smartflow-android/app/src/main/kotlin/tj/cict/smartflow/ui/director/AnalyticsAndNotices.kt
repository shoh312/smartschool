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
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Size
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import kotlin.math.roundToInt
import tj.cict.smartflow.data.dto.DailyTrendDto
import tj.cict.smartflow.ui.components.GhostButton
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.formatDateInput
import tj.cict.smartflow.core.util.dayMonthTime
import tj.cict.smartflow.core.util.formatAverage
import tj.cict.smartflow.core.util.formatMetric
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
import tj.cict.smartflow.ui.grades.metricColors
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

// ================================================================= Analytics

/** The analytics tab: school summary + top three, the attendance trend, classes. */
@Composable
fun DirectorAnalyticsScreen(schoolVm: SchoolViewModel, bottomPadding: Dp, onOpenStudent: (Int, String) -> Unit, onOpenRanking: () -> Unit, vm: DirectorAnalyticsViewModel = koinViewModel()) {
    LaunchedEffect(Unit) { vm.reload() }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val school by schoolVm.ui.collectAsStateWithLifecycle()
    Column(Modifier.fillMaxSize()) {
        ScreenHeader(stringResource(R.string.analytics_title))
        val board = (ui.schoolRanking as? UiState.Ready)?.data.orEmpty()
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = bottomPadding + 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            when (val r = ui.schoolRanking) {
                UiState.Loading -> item { SkeletonList(rows = 3, rowHeight = 60.dp) }
                is UiState.Failed -> item { ErrorState(r.error.message(), onRetry = vm::reload) }
                is UiState.Ready -> if (board.isNotEmpty()) item {
                    AnalyticsBlock(board, school.groupMode, onDetails = onOpenRanking, onOpenStudent = onOpenStudent)
                }
            }
            (ui.trend as? UiState.Ready)?.data?.let { days -> item { AttendanceTrendCard(days) } }
            val byClass = board.filter { it.overallAverage != null }.groupBy { it.className ?: "—" }
                .map { (k, v) -> k to v.mapNotNull { it.overallAverage }.average() }.sortedByDescending { it.second }
            if (byClass.isNotEmpty()) item { ClassAveragesCard(byClass, school.groupMode) }
        }
    }
}

/** "Details": the full ranking and the needs-attention list, two tabs. */
@Composable
fun DirectorRankingScreen(schoolVm: SchoolViewModel, onBack: () -> Unit, onOpenStudent: (Int, String) -> Unit, vm: DirectorAnalyticsViewModel = koinViewModel()) {
    LaunchedEffect(Unit) { vm.load() }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val school by schoolVm.ui.collectAsStateWithLifecycle()
    val c = MaterialTheme.smart
    val bottomPadding = 0.dp
    var tab by rememberSaveable { mutableStateOf(0) }

    PageBackground { Column(Modifier.fillMaxSize()) {
        ScreenHeader(stringResource(R.string.action_ranking), onBack = onBack)
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
                        items(s.data, key = { it.studentId }) { e -> RankRow(e, onClick = { onOpenStudent(e.studentId, "${e.lastName} ${e.firstName}") }, groupMode = school.groupMode) }
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
                                SoftCard(contentPadding = PaddingValues(10.dp), elevation = 4.dp, onClick = { onOpenStudent(e.studentId, "${e.lastName} ${e.firstName}") }) {
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
                            items(d.bottomPerformers, key = { "b${it.studentId}" }) { e -> RankRow(e, onClick = { onOpenStudent(e.studentId, "${e.lastName} ${e.firstName}") }, groupMode = school.groupMode) }
                        }
                    }
                }
            }
        }
    } }
}

@Composable
private fun Pill(text: String, selected: Boolean, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    Box(
        Modifier.clip(RoundedCornerShape(999.dp)).background(if (selected) c.brand else c.surface).border(1.dp, if (selected) c.brand else c.border, RoundedCornerShape(999.dp)).clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
    ) { Text(text, style = MaterialTheme.typography.labelMedium, color = if (selected) Color.White else c.ink) }
}

@Composable
private fun RankRow(e: LeaderboardEntryDto, onClick: () -> Unit, groupMode: Boolean = false) {
    val c = MaterialTheme.smart
    val medal = when (e.position) { 1 -> c.amber; 2 -> Color(0xFF9CA3AF); 3 -> Color(0xFFC77B3F); else -> null }
    SoftCard(contentPadding = PaddingValues(10.dp), elevation = 4.dp, onClick = onClick) {
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
                val (gc, gs) = metricColors(avg, groupMode)
                Box(Modifier.clip(RoundedCornerShape(999.dp)).background(gs).padding(horizontal = 10.dp, vertical = 5.dp)) { Text(formatMetric(avg, groupMode), style = MaterialTheme.typography.titleSmall, color = gc) }
            }
        }
    }
}

/** School-wide summary + the top three; "Details" opens the full ranking. */
@Composable
private fun AnalyticsBlock(
    board: List<LeaderboardEntryDto>,
    groupMode: Boolean,
    onDetails: () -> Unit,
    onOpenStudent: (Int, String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = MaterialTheme.smart
    val scored = board.mapNotNull { it.overallAverage }
    val avg = scored.takeIf { it.isNotEmpty() }?.average()
    SoftCard(modifier, contentPadding = PaddingValues(16.dp), elevation = 6.dp, onClick = onDetails) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.home_analytics), style = MaterialTheme.typography.titleMedium, color = c.ink)
                Text(stringResource(R.string.home_ranked, scored.size), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
            }
            GhostButton(stringResource(R.string.action_details), onClick = onDetails)
        }
        VSpace(12.dp)
        if (avg != null) {
            val (gc, gs) = metricColors(avg, groupMode)
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.md)).background(gs).padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(if (groupMode) R.string.home_school_att else R.string.home_school_avg),
                    style = MaterialTheme.typography.labelMedium, color = c.inkSecondary, modifier = Modifier.weight(1f),
                )
                Text(formatMetric(avg, groupMode), style = MaterialTheme.typography.titleLarge, color = gc)
            }
            VSpace(12.dp)
        }
        Text(stringResource(R.string.home_top3), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
        VSpace(6.dp)
        board.take(3).forEach { e ->
            val medal = when (e.position) { 1 -> c.amber; 2 -> Color(0xFF9CA3AF); else -> Color(0xFFC77B3F) }
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.sm)).clickable { onOpenStudent(e.studentId, "${e.lastName} ${e.firstName}") }.padding(vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.size(28.dp).clip(CircleShape).background(medal.copy(alpha = 0.18f)), contentAlignment = Alignment.Center) {
                    Text("${e.position}", style = MaterialTheme.typography.labelLarge, color = medal)
                }
                HSpace(10.dp)
                ChildAvatar(Child(e.studentId, e.firstName, e.lastName, e.className), 32.dp); HSpace(10.dp)
                Column(Modifier.weight(1f)) {
                    Text("${e.lastName} ${e.firstName}", style = MaterialTheme.typography.titleSmall, color = c.ink, maxLines = 1)
                    e.className?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = c.inkTertiary) }
                }
                e.overallAverage?.let { v ->
                    val (gc, gs) = metricColors(v, groupMode)
                    Box(Modifier.clip(RoundedCornerShape(999.dp)).background(gs).padding(horizontal = 10.dp, vertical = 4.dp)) {
                        Text(formatMetric(v, groupMode), style = MaterialTheme.typography.labelLarge, color = gc)
                    }
                }
            }
        }
    }
}


/** Share of pupils who came / were absent, day by day -- the director's pulse. */
@Composable
private fun AttendanceTrendCard(days: List<DailyTrendDto>) {
    val c = MaterialTheme.smart
    val pts = days.mapNotNull { d ->
        val total = d.present + d.late + d.absent
        if (total == 0) null else Triple(d.date, (d.present + d.late) * 100f / total, d.absent * 100f / total)
    }
    if (pts.size < 2) return
    val last = pts.last().second
    val delta = last - pts[pts.size - 2].second
    val fmt = java.time.format.DateTimeFormatter.ofPattern("dd.MM")
    val brand = c.brand
    val rose = c.rose
    val grid = c.border
    val measurer = rememberTextMeasurer()
    SoftCard(contentPadding = PaddingValues(16.dp), elevation = 6.dp) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.att_trend_title), style = MaterialTheme.typography.titleMedium, color = c.ink)
                Text(stringResource(R.string.att_trend_sub), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
            }
            Column(horizontalAlignment = Alignment.End) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("${last.roundToInt()}%", style = MaterialTheme.typography.headlineMedium, color = c.ink)
                    HSpace(6.dp)
                    val up = delta >= 0
                    Box(Modifier.clip(RoundedCornerShape(999.dp)).background(if (up) c.mintSoft else c.roseSoft).padding(horizontal = 8.dp, vertical = 3.dp)) {
                        Text((if (up) "▲ +" else "▼ ") + "${delta.roundToInt()}%", style = MaterialTheme.typography.labelSmall, color = if (up) c.mint else c.rose)
                    }
                }
                Text(stringResource(R.string.att_trend_last), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
            }
        }
        VSpace(14.dp)
        Row(Modifier.fillMaxWidth().height(170.dp)) {
            Column(Modifier.fillMaxHeight().padding(end = 6.dp), verticalArrangement = Arrangement.SpaceBetween) {
                listOf(100, 75, 50, 25, 0).forEach { Text("$it%", style = MaterialTheme.typography.labelSmall, color = c.inkTertiary) }
            }
            Canvas(Modifier.weight(1f).fillMaxHeight().padding(vertical = 7.dp)) {
                val w = size.width
                val h = size.height
                for (i in 0..4) {
                    val y = h * i / 4f
                    drawLine(grid, Offset(0f, y), Offset(w, y), strokeWidth = 1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 6f)))
                }
                fun xy(i: Int, v: Float) = Offset(w * i / (pts.size - 1), h - h * v / 100f)
                fun smooth(values: List<Float>): Path = Path().apply {
                    values.forEachIndexed { i, v ->
                        val p = xy(i, v)
                        if (i == 0) moveTo(p.x, p.y) else {
                            val prev = xy(i - 1, values[i - 1])
                            val mx = (prev.x + p.x) / 2
                            cubicTo(mx, prev.y, mx, p.y, p.x, p.y)
                        }
                    }
                }
                val came = pts.map { it.second }
                val line = smooth(came)
                val area = Path().apply { addPath(line); lineTo(w, h); lineTo(0f, h); close() }
                drawPath(area, Brush.verticalGradient(listOf(brand.copy(alpha = 0.22f), brand.copy(alpha = 0.02f))))
                drawPath(line, brand, style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round))
                drawPath(
                    smooth(pts.map { it.third }), rose.copy(alpha = 0.75f),
                    style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(12f, 9f))),
                )
                val end = xy(pts.size - 1, came.last())
                // marker: dashed drop line, the dot, and a dark bubble with today's value
                drawLine(brand.copy(alpha = 0.45f), Offset(end.x, end.y), Offset(end.x, h), strokeWidth = 1.5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 6f)))
                drawCircle(Color.White, 6.dp.toPx(), end)
                drawCircle(brand, 4.dp.toPx(), end)
                val label = measurer.measure("${last.roundToInt()}%", TextStyle(color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold))
                val bw = label.size.width + 14.dp.toPx()
                val bh = label.size.height + 6.dp.toPx()
                val bx = (end.x - bw / 2).coerceIn(0f, w - bw)
                val by = (end.y - bh - 10.dp.toPx()).coerceAtLeast(0f)
                drawRoundRect(Color(0xFF1F2937), Offset(bx, by), Size(bw, bh), CornerRadius(bh / 2, bh / 2))
                drawText(label, topLeft = Offset(bx + (bw - label.size.width) / 2, by + (bh - label.size.height) / 2))
            }
        }
        Row(Modifier.fillMaxWidth().padding(start = 34.dp, top = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            val step = ((pts.size - 1) / 4).coerceAtLeast(1)
            pts.indices.filter { it % step == 0 || it == pts.size - 1 }.distinct().forEach { i ->
                Text(pts[i].first.format(fmt), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
            }
        }
        VSpace(10.dp)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(10.dp).clip(CircleShape).background(brand)); HSpace(6.dp)
            Text(stringResource(R.string.legend_came), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
            HSpace(18.dp)
            Box(Modifier.size(10.dp).clip(CircleShape).background(rose)); HSpace(6.dp)
            Text(stringResource(R.string.legend_absent), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
        }
    }
}

/** Every class (or group) by its average -- grade, or attendance % in group mode. */
@Composable
private fun ClassAveragesCard(rows: List<Pair<String, Double>>, groupMode: Boolean) {
    val c = MaterialTheme.smart
    val scale = if (groupMode) 100.0 else 10.0
    SoftCard(contentPadding = PaddingValues(16.dp), elevation = 6.dp) {
        Text(stringResource(R.string.class_averages), style = MaterialTheme.typography.titleMedium, color = c.ink)
        VSpace(12.dp)
        rows.take(12).forEach { (name, v) ->
            val (gc, gs) = metricColors(v, groupMode)
            Row(Modifier.padding(vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(name, style = MaterialTheme.typography.labelMedium, color = c.ink, maxLines = 1, modifier = Modifier.width(96.dp))
                Box(Modifier.weight(1f).height(10.dp).clip(RoundedCornerShape(5.dp)).background(c.surfaceSoft)) {
                    Box(Modifier.fillMaxWidth((v / scale).toFloat().coerceIn(0f, 1f)).fillMaxHeight().clip(RoundedCornerShape(5.dp)).background(gc))
                }
                HSpace(10.dp)
                Box(Modifier.width(52.dp).clip(RoundedCornerShape(999.dp)).background(gs).padding(vertical = 3.dp), contentAlignment = Alignment.Center) {
                    Text(formatMetric(v, groupMode), style = MaterialTheme.typography.labelMedium, color = gc)
                }
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
                Box(Modifier.weight(1f)) { AppTextField(start, { start = formatDateInput(it) }, stringResource(R.string.event_start), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), isError = startDate == null) }
                Box(Modifier.weight(1f)) { AppTextField(end, { end = formatDateInput(it) }, stringResource(R.string.event_end), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), isError = end.isNotBlank() && endDate == null) }
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
                    Toggle(stringResource(R.string.setting_attn), stringResource(R.string.setting_attn_hint), d.attendanceNotificationsEnabled) { vm.update(SchoolSettingsUpdate(attendanceNotificationsEnabled = it)) }
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
