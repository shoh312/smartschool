package tj.cict.smartflow.ui.grades

import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
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
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import tj.cict.smartflow.ui.components.GradeInfoSheet
import tj.cict.smartflow.ui.components.JournalCell
import tj.cict.smartflow.ui.components.JournalRowSpec
import tj.cict.smartflow.ui.components.JournalGrid
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonth
import tj.cict.smartflow.core.util.formatAverage
import tj.cict.smartflow.data.dto.GradeDto
import tj.cict.smartflow.data.repo.ParentRepository
import tj.cict.smartflow.ui.components.ChildDataViewModel
import tj.cict.smartflow.ui.components.DetailScaffold
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.Segment
import tj.cict.smartflow.ui.components.SegmentRow
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

class GradesViewModel(private val repo: ParentRepository) : ChildDataViewModel<List<GradeDto>>() {
    override suspend fun fetch(childId: Int): ApiResult<List<GradeDto>> = repo.grades(childId)
}

/** 1-10 scale: green from 8, amber from 6, red below. Same tiers as the rating. */
@Composable
fun gradeColors(value: Double): Pair<Color, Color> {
    val c = MaterialTheme.smart
    return when {
        value >= 8 -> c.mint to c.mintSoft
        value >= 6 -> c.amber to c.amberSoft
        else -> c.rose to c.roseSoft
    }
}

@Composable
fun GradesScreen(childId: Int, childrenVm: ChildrenViewModel, onBack: () -> Unit, vm: GradesViewModel = koinViewModel()) {
    LaunchedEffect(childId) { vm.load(childId) }
    val state by vm.state.collectAsStateWithLifecycle()
    val children by childrenVm.ui.collectAsStateWithLifecycle()
    val child = children.child(childId)
    val locale = currentLocale()
    // 0 = all, 1..4 = a quarter
    var quarter by rememberSaveable { mutableStateOf(0) }

    DetailScaffold(
        title = stringResource(R.string.grades_title),
        subtitle = child?.fullName,
        state = state,
        onBack = onBack,
        onRetry = { vm.load(childId, force = true) },
        belowHeader = {
            SegmentRow(Modifier.padding(horizontal = 20.dp, vertical = 6.dp)) {
                Segment(stringResource(R.string.quarter_all), quarter == 0) { quarter = 0 }
                (1..4).forEach { q -> Segment(stringResource(R.string.quarter_short, q), quarter == q) { quarter = q } }
            }
        },
    ) { all ->
        val grades = remember(all, quarter) { if (quarter == 0) all else all.filter { it.quarter == quarter } }
        if (grades.isEmpty()) {
            EmptyState(R.drawable.ill_notebook, stringResource(R.string.grades_empty))
            return@DetailScaffold
        }
        val subjects = remember(grades) { grades.groupBy { it.subject }.keys.sortedBy { it } }
        val dates = remember(grades) { grades.map { it.date }.distinct().sorted() }
        val overall = grades.map { it.value }.average()
        var info by remember { mutableStateOf<Pair<List<GradeDto>, String>?>(null) }
        info?.let { (list, subject) -> GradeInfoSheet(list, fallback = subject, title = child?.fullName ?: "", onDismiss = { info = null }) }

        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp),
        ) {
            val (color, soft) = gradeColors(overall)
            SoftCard(contentPadding = PaddingValues(18.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(stringResource(R.string.average), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.smart.inkSecondary)
                        Text(formatAverage(overall), style = MaterialTheme.typography.displayMedium, color = color)
                        Text(stringResource(R.string.grades_count, grades.size), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.smart.inkTertiary)
                    }
                    Box(Modifier.size(64.dp).clip(RoundedCornerShape(Radius.md)).background(soft), contentAlignment = Alignment.Center) {
                        Text("${grades.maxOf { it.value }}", style = MaterialTheme.typography.headlineMedium, color = color)
                    }
                }
            }
            VSpace(12.dp)
            // Subjects down the side, lesson dates across: tap a mark to see who gave it and why.
            JournalGrid(
                rows = subjects.map { sub -> JournalRowSpec(sub, sub, stringResource(R.string.grades_count, grades.count { it.subject == sub })) },
                dates = dates,
                cellOf = { sub, d -> JournalCell(grades.filter { it.subject == sub && it.date == d }) },
                onCell = { sub, _, cell -> if (cell.grades.isNotEmpty()) info = cell.grades to sub },
            )
        }
    }
}
