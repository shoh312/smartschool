package tj.cict.smartflow.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.LocalDate
import java.time.LocalTime
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonth
import tj.cict.smartflow.core.util.hhmm
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.core.util.weekdayLong
import tj.cict.smartflow.domain.AttendanceStatus
import tj.cict.smartflow.domain.Child
import tj.cict.smartflow.ui.components.ActionTile
import tj.cict.smartflow.ui.components.ChildAvatar
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.Illustration
import tj.cict.smartflow.ui.components.RoundIconButton
import tj.cict.smartflow.ui.components.SectionTitle
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.StatusPill
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.profile.ProfileSheet
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

/**
 * The pupil's own front page. Same data as a parent sees for one child,
 * but addressed to them: "you arrived at 7:52", not "Amina arrived".
 */
@Composable
fun StudentHomeScreen(
    childrenVm: ChildrenViewModel,
    studentId: Int,
    name: String,
    className: String?,
    bottomPadding: Dp,
    onSignOut: () -> Unit,
    onAttendance: (Int) -> Unit,
    onGrades: (Int) -> Unit,
    onHomework: (Int) -> Unit,
    onAchievements: (Int) -> Unit,
    onCalendar: (Int) -> Unit,
    onAnnouncements: (Int) -> Unit,
) {
    val ui by childrenVm.ui.collectAsStateWithLifecycle()
    var profileOpen by remember { mutableStateOf(false) }
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val locale = currentLocale()
    val today = LocalDate.now()
    val me = ui.children.firstOrNull { it.child.id == studentId } ?: ui.children.firstOrNull()

    PullToRefreshBox(isRefreshing = ui.refreshing, onRefresh = childrenVm::refresh, modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = top + 14.dp, bottom = bottomPadding + 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                Row(Modifier.padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(greeting(), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.smart.inkSecondary)
                        Text(
                            (me?.child?.firstName ?: name).ifBlank { stringResource(R.string.app_name) },
                            style = MaterialTheme.typography.headlineMedium,
                            color = MaterialTheme.smart.ink,
                            maxLines = 1,
                        )
                    }
                    RoundIconButton(Icons.Outlined.Person, stringResource(R.string.profile_title), onClick = { profileOpen = true })
                }
            }

            when {
                ui.loading -> item { SkeletonList(rows = 3, rowHeight = 120.dp) }
                ui.error != null && ui.children.isEmpty() -> item { ErrorState(ui.error!!.message(), childrenVm::refresh) }
                else -> {
                    val child = me?.child ?: Child(studentId, name.substringBefore(' '), name.substringAfter(' ', ""), className)
                    item {
                        MyDayCard(
                            child = child,
                            status = me?.status ?: AttendanceStatus.UNKNOWN,
                            arrivedAt = me?.today?.arrivedAt?.hhmm(),
                            dateLine = "${today.weekdayLong(locale)}, ${today.dayMonth(locale)}",
                            modifier = Modifier.padding(horizontal = 20.dp),
                        )
                    }
                    item { SectionTitle(stringResource(R.string.home_quick), Modifier.padding(horizontal = 20.dp, vertical = 2.dp)) }
                    item {
                        val tiles = listOf(
                            Triple(R.drawable.ill_homework, R.string.action_homework) { onHomework(child.id) },
                            Triple(R.drawable.ill_notebook, R.string.action_grades) { onGrades(child.id) },
                            Triple(R.drawable.ill_trophy, R.string.action_achievements) { onAchievements(child.id) },
                            Triple(R.drawable.ill_door_check, R.string.action_attendance) { onAttendance(child.id) },
                            Triple(R.drawable.ill_calendar, R.string.action_calendar) { onCalendar(child.id) },
                            Triple(R.drawable.ill_megaphone, R.string.action_announcements) { onAnnouncements(child.id) },
                        )
                        Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            tiles.chunked(2).forEach { pair ->
                                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                    pair.forEach { (ill, label, action) -> ActionTile(ill, stringResource(label), action, Modifier.weight(1f)) }
                                    if (pair.size == 1) Box(Modifier.weight(1f))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (profileOpen) {
        ProfileSheet(parentName = name, onDismiss = { profileOpen = false }, onSignOut = onSignOut)
    }
}

@Composable
private fun greeting(): String {
    val hour = LocalTime.now().hour
    return stringResource(
        when {
            hour < 12 -> R.string.greeting_morning
            hour < 18 -> R.string.greeting_afternoon
            else -> R.string.greeting_evening
        },
    )
}

@Composable
private fun MyDayCard(child: Child, status: AttendanceStatus, arrivedAt: String?, dateLine: String, modifier: Modifier = Modifier) {
    val c = MaterialTheme.smart
    val shape = RoundedCornerShape(Radius.xl)
    Box(
        modifier.fillMaxWidth().clip(shape).background(Brush.linearGradient(listOf(c.brand, c.brandDeep))),
    ) {
        Illustration(R.drawable.ill_backpack, Modifier.align(Alignment.TopEnd).size(150.dp))
        Column(Modifier.padding(20.dp)) {
            Text(stringResource(R.string.today), style = MaterialTheme.typography.labelMedium, color = Color.White.copy(alpha = 0.8f))
            Text(dateLine, style = MaterialTheme.typography.titleLarge, color = Color.White)
            VSpace(56.dp)
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.md)).background(c.surface).padding(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                ChildAvatar(child, 44.dp)
                HSpace(12.dp)
                Column(Modifier.weight(1f)) {
                    Text(child.fullName, style = MaterialTheme.typography.titleMedium, color = c.ink, maxLines = 1)
                    val detail = when {
                        arrivedAt != null && status.arrived -> stringResource(R.string.arrived_at, arrivedAt)
                        child.className != null -> stringResource(R.string.class_label, child.className)
                        else -> ""
                    }
                    if (detail.isNotEmpty()) Text(detail, style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
                }
                StatusPill(status, compact = true)
            }
        }
    }
}
