package tj.cict.smartflow.ui.achievements

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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.EventAvailable
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.MilitaryTech
import androidx.compose.material.icons.rounded.School
import androidx.compose.material.icons.rounded.TrendingUp
import androidx.compose.material.icons.rounded.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlin.math.roundToInt
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.data.dto.AnalyticsDto
import tj.cict.smartflow.data.repo.ParentRepository
import tj.cict.smartflow.ui.components.ChildDataViewModel
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.Illustration
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

class AchievementsViewModel(private val repo: ParentRepository) : ChildDataViewModel<AnalyticsDto>() {
    override suspend fun fetch(childId: Int): ApiResult<AnalyticsDto> = repo.analytics(childId, null)
}

data class Badge(val title: String, val hint: String, val icon: ImageVector, val earned: Boolean, val color: Color)

/**
 * Badges are derived, never stored: the same rating numbers that the
 * analytics screen shows, read as milestones. Nothing to sync, nothing to
 * get out of date.
 */
@Composable
fun badgesFor(a: AnalyticsDto): List<Badge> {
    val c = MaterialTheme.smart
    val avg = a.overallAverage ?: 0.0
    val cp = a.classRank.position
    val pp = a.parallelRank.position
    val top10 = pp != null && a.parallelRank.outOf > 0 && pp <= (a.parallelRank.outOf * 0.1).roundToInt().coerceAtLeast(1)
    val prev = a.trend.filter { it.quarter < a.quarter && it.overallAverage != null }.maxByOrNull { it.quarter }?.overallAverage
    val progress = prev != null && a.overallAverage != null && a.overallAverage - prev >= 1.0
    val best = a.subjects.maxByOrNull { it.average }
    return listOf(
        Badge(stringResource(R.string.ach_first_school), stringResource(R.string.ach_first_school_hint), Icons.Rounded.WorkspacePremium, a.schoolRank.position == 1, c.amber),
        Badge(stringResource(R.string.ach_top3), stringResource(R.string.ach_top3_hint), Icons.Rounded.MilitaryTech, cp != null && cp <= 3, c.coral),
        Badge(stringResource(R.string.ach_top10), stringResource(R.string.ach_top10_hint), Icons.Rounded.EmojiEvents, top10, c.brand),
        Badge(stringResource(R.string.ach_excellent), stringResource(R.string.ach_excellent_hint), Icons.Rounded.School, avg >= 9.0, c.mint),
        Badge(stringResource(R.string.ach_attendance), stringResource(R.string.ach_attendance_hint), Icons.Rounded.EventAvailable, (a.lessonAttendanceRate ?: 0.0) >= 95.0, c.sky),
        Badge(stringResource(R.string.ach_progress), stringResource(R.string.ach_progress_hint), Icons.Rounded.TrendingUp, progress, c.rose),
        Badge(
            if (best != null) stringResource(R.string.ach_subject, best.subject) else stringResource(R.string.ach_subject, "…"),
            stringResource(R.string.ach_subject_hint), Icons.Rounded.AutoAwesome, best != null && best.average >= 9.0, c.amber,
        ),
    )
}

@Composable
fun AchievementsScreen(childId: Int, childrenVm: ChildrenViewModel, onBack: () -> Unit, vm: AchievementsViewModel = koinViewModel()) {
    LaunchedEffect(childId) { vm.load(childId) }
    val state by vm.state.collectAsStateWithLifecycle()
    val children by childrenVm.ui.collectAsStateWithLifecycle()

    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.ach_title), subtitle = children.child(childId)?.fullName, onBack = onBack)
            when (val s = state) {
                UiState.Loading -> SkeletonList(rows = 4)
                is UiState.Failed -> {
                    if (s.error is ApiError.Detail && s.error.status == 404) {
                        EmptyState(R.drawable.ill_trophy, stringResource(R.string.ach_title), stringResource(R.string.ach_empty))
                    } else {
                        ErrorState(s.error.message(), onRetry = { vm.load(childId, force = true) })
                    }
                }
                is UiState.Ready -> Body(s.data)
            }
        }
    }
}

@Composable
private fun Body(a: AnalyticsDto) {
    val c = MaterialTheme.smart
    val badges = badgesFor(a)
    val earned = badges.count { it.earned }
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Box(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.xl)).background(Brush.linearGradient(listOf(c.amber, Color(0xFFE0891A)))),
            ) {
                Illustration(R.drawable.ill_trophy, Modifier.align(Alignment.CenterEnd).size(150.dp))
                Column(Modifier.padding(22.dp)) {
                    Text("$earned", style = MaterialTheme.typography.displayLarge, color = Color.White)
                    Text(stringResource(R.string.ach_subtitle, earned, badges.size), style = MaterialTheme.typography.titleMedium, color = Color.White.copy(alpha = 0.9f))
                }
            }
        }
        items(badges.size) { i -> BadgeRow(badges[i]) }
    }
}

@Composable
private fun BadgeRow(b: Badge) {
    val c = MaterialTheme.smart
    SoftCard(contentPadding = PaddingValues(14.dp), elevation = if (b.earned) 8.dp else 2.dp) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.alpha(if (b.earned) 1f else 0.55f)) {
            Box(
                Modifier.size(54.dp).clip(CircleShape).background(
                    if (b.earned) Brush.linearGradient(listOf(b.color, b.color.copy(alpha = 0.7f))) else Brush.linearGradient(listOf(c.surfaceSoft, c.surfaceSoft)),
                ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(if (b.earned) b.icon else Icons.Rounded.Lock, null, tint = if (b.earned) Color.White else c.inkTertiary, modifier = Modifier.size(26.dp))
            }
            HSpace(14.dp)
            Column(Modifier.weight(1f)) {
                Text(b.title, style = MaterialTheme.typography.titleMedium, color = c.ink)
                Text(b.hint, style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
            }
            HSpace(8.dp)
            Box(Modifier.clip(RoundedCornerShape(999.dp)).background(if (b.earned) c.mintSoft else c.surfaceSoft).padding(horizontal = 10.dp, vertical = 5.dp)) {
                Text(if (b.earned) stringResource(R.string.ach_earned) else stringResource(R.string.ach_locked), style = MaterialTheme.typography.labelSmall, color = if (b.earned) c.mint else c.inkTertiary)
            }
        }
    }
}
