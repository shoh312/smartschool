package tj.cict.smartflow.ui.assignments

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonthTime
import tj.cict.smartflow.data.dto.AssignmentDto
import tj.cict.smartflow.data.repo.ParentRepository
import tj.cict.smartflow.ui.components.Chip
import tj.cict.smartflow.ui.components.ChildDataViewModel
import tj.cict.smartflow.ui.components.DetailScaffold
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.theme.smart

class AssignmentsViewModel(private val repo: ParentRepository) : ChildDataViewModel<List<AssignmentDto>>() {
    override suspend fun fetch(childId: Int): ApiResult<List<AssignmentDto>> = repo.assignments(childId)
}

@Composable
fun AssignmentsScreen(
    childId: Int,
    childrenVm: ChildrenViewModel,
    onBack: (() -> Unit)?,
    onOpen: (Int) -> Unit,
    bottomPadding: Dp = 0.dp,
    vm: AssignmentsViewModel = koinViewModel(),
) {
    LaunchedEffect(childId) { vm.load(childId) }
    val state by vm.state.collectAsStateWithLifecycle()
    val children by childrenVm.ui.collectAsStateWithLifecycle()
    val locale = currentLocale()

    DetailScaffold(
        title = stringResource(R.string.assignments_title),
        subtitle = if (onBack != null) children.child(childId)?.fullName else null,
        state = state,
        onBack = onBack,
        onRetry = { vm.load(childId, force = true) },
    ) { list ->
        if (list.isEmpty()) {
            EmptyState(R.drawable.ill_clipboard, stringResource(R.string.assignments_empty))
            return@DetailScaffold
        }
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = bottomPadding + 32.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(list, key = { it.id }) { a -> AssignmentCard(a, locale, onClick = { onOpen(a.id) }) }
        }
    }
}

/** A parent watches: title, subject, due, and the score once the school lets it show. */
@Composable
private fun AssignmentCard(a: AssignmentDto, locale: java.util.Locale, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    val submitted = a.submittedAt != null
    val (stateLabel, stateColor, stateSoft) = when {
        submitted -> Triple(stringResource(R.string.assignment_submitted), c.mint, c.mintSoft)
        a.isOverdue -> Triple(stringResource(R.string.assignment_overdue), c.rose, c.roseSoft)
        else -> Triple(stringResource(R.string.assignment_not_started), c.inkSecondary, c.surfaceSoft)
    }
    SoftCard(contentPadding = PaddingValues(16.dp), elevation = 6.dp, onClick = onClick) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(a.subject, style = MaterialTheme.typography.labelSmall, color = c.brandDeep)
                Text(a.title, style = MaterialTheme.typography.titleMedium, color = c.ink)
            }
            HSpace(10.dp)
            Chip(
                if (a.mode == "control") stringResource(R.string.mode_control) else stringResource(R.string.mode_practice),
                if (a.mode == "control") c.coral else c.sky,
                if (a.mode == "control") c.coralSoft else c.skySoft,
            )
        }
        if (!a.description.isNullOrBlank()) {
            VSpace(6.dp)
            Text(a.description, style = MaterialTheme.typography.bodyMedium, color = c.inkSecondary, maxLines = 3)
        }
        VSpace(12.dp)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Chip(stateLabel, stateColor, stateSoft)
            HSpace(8.dp)
            Text(stringResource(R.string.assignment_questions, a.questionCount), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary)
            a.dueAt?.let {
                Text("  ·  " + stringResource(R.string.assignment_due, it.dayMonthTime(locale)), style = MaterialTheme.typography.bodySmall, color = if (a.isOverdue && !submitted) c.rose else c.inkTertiary)
            }
        }
        if (submitted) {
            VSpace(12.dp)
            if (a.scoreVisible && a.score != null) {
                val pct = a.percent ?: if (a.maxScore > 0) a.score * 100 / a.maxScore else 0
                val bar = when { pct >= 80 -> c.mint; pct >= 60 -> c.amber; else -> c.rose }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.weight(1f).height(8.dp).clip(RoundedCornerShape(4.dp)).background(c.surfaceSoft)) {
                        Box(Modifier.fillMaxWidth(pct / 100f).fillMaxSize().background(bar))
                    }
                    HSpace(12.dp)
                    Text("${a.score} / ${a.maxScore}", style = MaterialTheme.typography.titleSmall, color = bar)
                    HSpace(6.dp)
                    Text("$pct%", style = MaterialTheme.typography.bodySmall, color = c.inkTertiary)
                }
            } else {
                Text(stringResource(R.string.assignment_score_hidden), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary)
            }
        }
    }
}
