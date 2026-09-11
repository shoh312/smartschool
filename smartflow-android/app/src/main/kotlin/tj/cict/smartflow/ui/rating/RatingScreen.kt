package tj.cict.smartflow.ui.rating

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import kotlin.math.roundToInt
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.formatAverage
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.data.dto.AnalyticsDto
import tj.cict.smartflow.data.dto.RankDto
import tj.cict.smartflow.data.repo.ParentRepository
import tj.cict.smartflow.ui.components.ChildSwitcher
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.Segment
import tj.cict.smartflow.ui.components.SegmentRow
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.TintPanel
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.grades.gradeColors
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

data class RatingUi(
    /** null = whatever quarter the server calls current. */
    val quarter: Int? = null,
    val data: UiState<AnalyticsDto> = UiState.Loading,
)

class RatingViewModel(private val repo: ParentRepository) : ViewModel() {
    private val _ui = MutableStateFlow(RatingUi())
    val ui: StateFlow<RatingUi> = _ui.asStateFlow()
    private var childId: Int? = null

    fun open(child: Int) {
        if (childId == child) return
        childId = child
        load()
    }

    fun pickQuarter(q: Int?) {
        if (_ui.value.quarter == q) return
        _ui.update { it.copy(quarter = q) }
        load()
    }

    fun load() {
        val id = childId ?: return
        val q = _ui.value.quarter
        _ui.update { it.copy(data = UiState.Loading) }
        viewModelScope.launch {
            val r = repo.analytics(id, q)
            if (_ui.value.quarter != q) return@launch
            _ui.update {
                it.copy(
                    data = when (r) {
                        is ApiResult.Ok -> UiState.Ready(r.value)
                        is ApiResult.Err -> UiState.Failed(r.error)
                    },
                )
            }
        }
    }
}

@Composable
fun RatingScreen(childrenVm: ChildrenViewModel, bottomPadding: Dp, vm: RatingViewModel = koinViewModel()) {
    val children by childrenVm.ui.collectAsStateWithLifecycle()
    val ui by vm.ui.collectAsStateWithLifecycle()
    val child = children.selected
    LaunchedEffect(child?.id) { child?.let { vm.open(it.id) } }

    Column(Modifier.fillMaxSize()) {
        ScreenHeader(stringResource(R.string.rating_title), subtitle = child?.fullName)
        ChildSwitcher(children.children.map { it.child }, child?.id, onSelect = childrenVm::select)
        if (children.children.size > 1) VSpace(10.dp)
        val current = (ui.data as? UiState.Ready)?.data?.quarter
        SegmentRow(Modifier.padding(horizontal = 20.dp)) {
            (1..4).forEach { q ->
                Segment(stringResource(R.string.quarter_short, q), selected = (ui.quarter ?: current) == q) { vm.pickQuarter(q) }
            }
        }
        VSpace(6.dp)

        when (val s = ui.data) {
            UiState.Loading -> SkeletonList(rows = 3, rowHeight = 140.dp)
            is UiState.Failed -> {
                // 404 here is not an error, it is "no grades yet this quarter".
                if (s.error is ApiError.Detail && s.error.status == 404) {
                    EmptyState(R.drawable.ill_trophy, stringResource(R.string.rating_title), stringResource(R.string.rating_empty))
                } else {
                    ErrorState(s.error.message(), vm::load)
                }
            }
            is UiState.Ready -> RatingBody(s.data, bottomPadding)
        }
    }
}

@Composable
private fun RatingBody(a: AnalyticsDto, bottomPadding: Dp) {
    val c = MaterialTheme.smart
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = bottomPadding + 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item { HeroCard(a) }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                RankCard(stringResource(R.string.rank_class), a.classRank, Modifier.weight(1f))
                RankCard(stringResource(R.string.rank_parallel), a.parallelRank, Modifier.weight(1f))
                RankCard(stringResource(R.string.rank_school), a.schoolRank, Modifier.weight(1f))
            }
        }
        if (a.overallAverage != null) {
            item {
                SoftCard {
                    Text(stringResource(R.string.compare_title), style = MaterialTheme.typography.titleMedium, color = c.ink)
                    VSpace(12.dp)
                    CompareRow(stringResource(R.string.compare_class), a.overallAverage, a.classAverage)
                    CompareRow(stringResource(R.string.compare_parallel), a.overallAverage, a.parallelAverage)
                    CompareRow(stringResource(R.string.compare_school), a.overallAverage, a.schoolAverage)
                }
            }
        }
        if (a.subjects.isNotEmpty()) {
            item {
                SoftCard {
                    Text(stringResource(R.string.subjects_title), style = MaterialTheme.typography.titleMedium, color = c.ink)
                    VSpace(12.dp)
                    a.subjects.sortedByDescending { it.average }.forEach { s ->
                        SubjectBar(s.subject, s.average, s.gradeCount, highlight = s.subject == a.strongestSubject, weak = s.subject == a.weakestSubject)
                        VSpace(10.dp)
                    }
                }
            }
        }
        if (a.trend.count { it.overallAverage != null } >= 1) {
            item {
                SoftCard {
                    Text(stringResource(R.string.trend_title), style = MaterialTheme.typography.titleMedium, color = c.ink)
                    VSpace(8.dp)
                    TrendChart(a.trend.map { it.quarter to it.overallAverage }, current = a.quarter)
                }
            }
        }
        a.lessonAttendanceRate?.let { rate ->
            item {
                SoftCard {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(stringResource(R.string.lesson_attendance), style = MaterialTheme.typography.titleMedium, color = c.ink)
                            VSpace(8.dp)
                            val color = when { rate >= 90 -> c.mint; rate >= 75 -> c.amber; else -> c.rose }
                            Box(Modifier.fillMaxWidth().height(10.dp).clip(RoundedCornerShape(5.dp)).background(c.surfaceSoft)) {
                                Box(Modifier.fillMaxWidth((rate / 100f).toFloat().coerceIn(0f, 1f)).fillMaxSize().background(color))
                            }
                        }
                        HSpace(16.dp)
                        Text("${rate.roundToInt()}%", style = MaterialTheme.typography.headlineMedium, color = c.ink)
                    }
                }
            }
        }
    }
}

/** Big number in a ring, badges underneath. */
@Composable
private fun HeroCard(a: AnalyticsDto) {
    val c = MaterialTheme.smart
    val avg = a.overallAverage
    val (color, soft) = gradeColors(avg ?: 0.0)
    val progress by animateFloatAsState(if (avg == null) 0f else (avg / 10f).toFloat().coerceIn(0f, 1f), tween(900), label = "ring")
    SoftCard(contentPadding = PaddingValues(20.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(120.dp), contentAlignment = Alignment.Center) {
                Canvas(Modifier.fillMaxSize()) {
                    val stroke = 12.dp.toPx()
                    val inset = stroke / 2
                    drawArc(soft, -90f, 360f, false, Offset(inset, inset), Size(size.width - stroke, size.height - stroke), style = Stroke(stroke, cap = StrokeCap.Round))
                    drawArc(color, -90f, 360f * progress, false, Offset(inset, inset), Size(size.width - stroke, size.height - stroke), style = Stroke(stroke, cap = StrokeCap.Round))
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(formatAverage(avg), style = MaterialTheme.typography.displayMedium, color = color)
                    Text("/ 10", style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
                }
            }
            HSpace(18.dp)
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.overall_average), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
                Text(stringResource(R.string.quarter_format, a.quarter), style = MaterialTheme.typography.titleLarge, color = c.ink)
                VSpace(10.dp)
                badgesFor(a).forEach { badge ->
                    Row(
                        Modifier.padding(bottom = 6.dp).clip(RoundedCornerShape(999.dp)).background(c.amberSoft).padding(horizontal = 10.dp, vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Rounded.EmojiEvents, null, tint = c.amber, modifier = Modifier.size(14.dp))
                        HSpace(5.dp)
                        Text(badge, style = MaterialTheme.typography.labelSmall, color = Color(0xFFB4700A))
                    }
                }
            }
        }
    }
}

@Composable
private fun badgesFor(a: AnalyticsDto): List<String> {
    val out = mutableListOf<String>()
    if (a.schoolRank.position == 1) out += stringResource(R.string.badge_first)
    val cp = a.classRank.position
    if (cp != null && cp <= 3) out += stringResource(R.string.badge_top3)
    else if (cp != null && a.classRank.outOf > 0 && cp <= (a.classRank.outOf * 0.1).roundToInt().coerceAtLeast(1)) out += stringResource(R.string.badge_top10)
    return out
}

@Composable
private fun RankCard(label: String, rank: RankDto, modifier: Modifier = Modifier) {
    val c = MaterialTheme.smart
    val pos = rank.position
    val medal = when (pos) { 1 -> c.amber; 2 -> Color(0xFF9CA3AF); 3 -> Color(0xFFC77B3F); else -> null }
    SoftCard(modifier, contentPadding = PaddingValues(12.dp), elevation = 6.dp) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = c.inkSecondary, maxLines = 1)
        VSpace(4.dp)
        Row(verticalAlignment = Alignment.Bottom) {
            Text(pos?.toString() ?: "—", style = MaterialTheme.typography.headlineMedium, color = medal ?: c.ink)
            HSpace(4.dp)
            Text(stringResource(R.string.rank_of, rank.outOf), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary, modifier = Modifier.padding(bottom = 4.dp))
        }
        if (medal != null) {
            Box(Modifier.padding(top = 4.dp).width(28.dp).height(3.dp).clip(RoundedCornerShape(2.dp)).background(medal))
        }
    }
}

/** Delta with an arrow -- an icon and a sign, so it survives colour-blindness. */
@Composable
private fun CompareRow(label: String, mine: Double, theirs: Double?) {
    val c = MaterialTheme.smart
    Row(Modifier.padding(vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = c.inkSecondary, modifier = Modifier.width(88.dp))
        Box(Modifier.weight(1f).height(8.dp).clip(RoundedCornerShape(4.dp)).background(c.surfaceSoft)) {
            if (theirs != null) Box(Modifier.fillMaxWidth((theirs / 10).toFloat().coerceIn(0f, 1f)).fillMaxSize().background(c.border))
            Box(Modifier.fillMaxWidth((mine / 10).toFloat().coerceIn(0f, 1f)).fillMaxSize().background(c.brand))
        }
        HSpace(10.dp)
        if (theirs == null) {
            Text("—", style = MaterialTheme.typography.labelMedium, color = c.inkTertiary)
        } else {
            val delta = mine - theirs
            val (icon, color) = when {
                delta > 0.05 -> Icons.Rounded.ArrowUpward to c.mint
                delta < -0.05 -> Icons.Rounded.ArrowDownward to c.rose
                else -> Icons.Rounded.Remove to c.inkTertiary
            }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.width(64.dp)) {
                Icon(icon, null, tint = color, modifier = Modifier.size(14.dp))
                Text(String.format(java.util.Locale.US, "%+.1f", delta), style = MaterialTheme.typography.labelMedium, color = color)
            }
        }
    }
}

@Composable
private fun SubjectBar(subject: String, average: Double, count: Int, highlight: Boolean, weak: Boolean) {
    val c = MaterialTheme.smart
    val (color, soft) = gradeColors(average)
    val fill by animateFloatAsState((average / 10).toFloat().coerceIn(0f, 1f), tween(700), label = "bar")
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(subject, style = MaterialTheme.typography.titleSmall, color = c.ink, modifier = Modifier.weight(1f), maxLines = 1)
            if (highlight) Tag(stringResource(R.string.strongest), c.mint, c.mintSoft)
            if (weak) Tag(stringResource(R.string.weakest), c.rose, c.roseSoft)
            HSpace(8.dp)
            Text(formatAverage(average), style = MaterialTheme.typography.titleSmall, color = color)
        }
        VSpace(5.dp)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f).height(10.dp).clip(RoundedCornerShape(5.dp)).background(soft)) {
                Box(Modifier.fillMaxWidth(fill).fillMaxSize().background(color))
            }
            HSpace(8.dp)
            Text(stringResource(R.string.grades_count, count), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary, modifier = Modifier.width(64.dp), textAlign = TextAlign.End)
        }
    }
}

@Composable
private fun Tag(text: String, color: Color, soft: Color) {
    Box(Modifier.padding(start = 4.dp).clip(RoundedCornerShape(999.dp)).background(soft).padding(horizontal = 8.dp, vertical = 3.dp)) {
        Text(text, style = MaterialTheme.typography.labelSmall, color = color)
    }
}

/**
 * Quarter-by-quarter line. A quarter with no grades is a gap in the line,
 * not a zero -- a zero would read as a collapse.
 */
@Composable
private fun TrendChart(points: List<Pair<Int, Double?>>, current: Int) {
    val c = MaterialTheme.smart
    val labels = points.map { it.first }
    Column {
        Canvas(Modifier.fillMaxWidth().height(150.dp).padding(top = 8.dp, bottom = 4.dp)) {
            val left = 28.dp.toPx(); val right = 8.dp.toPx(); val top = 10.dp.toPx(); val bottom = 8.dp.toPx()
            val w = size.width - left - right; val h = size.height - top - bottom
            fun x(i: Int) = left + if (points.size > 1) w * i / (points.size - 1) else w / 2
            fun y(v: Double) = top + h * (1 - (v / 10f).toFloat().coerceIn(0f, 1f))
            // grid at 2, 4, 6, 8, 10 -- dotted, quiet
            listOf(2.0, 4.0, 6.0, 8.0, 10.0).forEach { g ->
                drawLine(c.border, Offset(left, y(g)), Offset(size.width - right, y(g)), strokeWidth = 1.dp.toPx(), pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(6f, 8f)))
            }
            // line segments only between consecutive known points
            val path = Path(); var pen = false
            points.forEachIndexed { i, (_, v) ->
                if (v == null) { pen = false; return@forEachIndexed }
                val p = Offset(x(i), y(v))
                if (pen) path.lineTo(p.x, p.y) else path.moveTo(p.x, p.y)
                pen = true
            }
            drawPath(path, c.brand, style = Stroke(3.dp.toPx(), cap = StrokeCap.Round, join = androidx.compose.ui.graphics.StrokeJoin.Round))
            points.forEachIndexed { i, (q, v) ->
                if (v == null) return@forEachIndexed
                val p = Offset(x(i), y(v))
                drawCircle(Color.White, 7.dp.toPx(), p)
                drawCircle(if (q == current) c.coral else c.brand, 5.dp.toPx(), p)
            }
        }
        Row(Modifier.fillMaxWidth().padding(start = 28.dp, end = 8.dp)) {
            labels.forEachIndexed { i, q ->
                val v = points[i].second
                Column(Modifier.weight(1f), horizontalAlignment = when (i) { 0 -> Alignment.Start; labels.lastIndex -> Alignment.End; else -> Alignment.CenterHorizontally }) {
                    Text(formatAverage(v), style = MaterialTheme.typography.labelMedium, color = if (v == null) c.inkTertiary else c.ink, fontWeight = FontWeight.Bold)
                    Text(stringResource(R.string.quarter_short, q), style = MaterialTheme.typography.labelSmall, color = if (q == current) c.coral else c.inkTertiary)
                }
            }
        }
    }
}
