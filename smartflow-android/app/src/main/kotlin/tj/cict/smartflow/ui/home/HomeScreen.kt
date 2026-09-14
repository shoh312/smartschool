package tj.cict.smartflow.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.LocalTime
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.hhmm
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.core.util.weekdayLong
import tj.cict.smartflow.core.util.dayMonth
import tj.cict.smartflow.domain.AttendanceStatus
import tj.cict.smartflow.ui.components.ActionTile
import tj.cict.smartflow.ui.components.ChildAvatar
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.Illustration
import tj.cict.smartflow.ui.components.RoundIconButton
import tj.cict.smartflow.ui.components.SectionTitle
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.StatusPill
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.components.look
import tj.cict.smartflow.ui.profile.ProfileSheet
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

@Composable
fun HomeScreen(
    childrenVm: ChildrenViewModel,
    parentName: String,
    bottomPadding: Dp,
    onSignOut: () -> Unit,
    onAttendance: (Int) -> Unit,
    onLive: (Int) -> Unit = {},
    onGrades: (Int) -> Unit,
    onHomework: (Int) -> Unit,
    onAssignments: (Int) -> Unit,
    onCalendar: (Int) -> Unit,
    onAnnouncements: (Int) -> Unit,
) {
    val ui by childrenVm.ui.collectAsStateWithLifecycle()
    var profileOpen by remember { mutableStateOf(false) }
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val locale = currentLocale()
    val today = java.time.LocalDate.now()

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
                            parentName.ifBlank { stringResource(R.string.app_name) },
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
                ui.children.isEmpty() -> item {
                    EmptyState(R.drawable.ill_backpack, stringResource(R.string.home_no_children_title), stringResource(R.string.home_no_children_body))
                }
                else -> {
                    item {
                        TodayCard(
                            rows = ui.children,
                            selectedId = ui.selected?.id,
                            dateLine = "${today.weekdayLong(locale)}, ${today.dayMonth(locale)}",
                            onSelect = { childrenVm.select(it.child) },
                            modifier = Modifier.padding(horizontal = 20.dp),
                        )
                    }
                    val focus = ui.selected
                    if (focus != null) {
                        item {
                            SectionTitle(
                                stringResource(R.string.home_quick),
                                Modifier.padding(horizontal = 20.dp, vertical = 2.dp),
                                trailing = if (ui.children.size > 1) {
                                    {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            ChildAvatar(focus, 22.dp); HSpace(6.dp)
                                            Text(focus.firstName, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.smart.inkSecondary)
                                        }
                                    }
                                } else null,
                            )
                        }
                        item {
                            ActionGrid(
                                listOf(
                                    Triple(R.drawable.ill_door_check, R.string.action_attendance) { onAttendance(focus.id) },
                                    Triple(R.drawable.ill_notebook, R.string.action_grades) { onGrades(focus.id) },
                                    Triple(R.drawable.ill_homework, R.string.action_homework) { onHomework(focus.id) },
                                    Triple(R.drawable.ill_clipboard, R.string.action_assignments) { onAssignments(focus.id) },
                                    Triple(R.drawable.ill_calendar, R.string.action_calendar) { onCalendar(focus.id) },
                                    Triple(R.drawable.ill_megaphone, R.string.action_announcements) { onAnnouncements(focus.id) },
                                    Triple(R.drawable.ill_school, R.string.action_live) { onLive(focus.id) },
                                ),
                            )
                        }
                    }
                }
            }
        }
    }

    if (profileOpen) {
        ProfileSheet(parentName = parentName, onDismiss = { profileOpen = false }, onSignOut = onSignOut)
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

/**
 * The hero: today, per child. A gradient card with the family illustration
 * peeking from the corner and one row per child; the row in focus is white.
 */
@Composable
private fun TodayCard(rows: List<ChildToday>, selectedId: Int?, dateLine: String, onSelect: (ChildToday) -> Unit, modifier: Modifier = Modifier) {
    val c = MaterialTheme.smart
    val shape = RoundedCornerShape(Radius.xl)
    Box(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Brush.linearGradient(listOf(c.brand, c.brandDeep))),
    ) {
        Illustration(
            R.drawable.ill_family,
            Modifier
                .align(Alignment.TopEnd)
                .size(150.dp)
                .padding(end = 0.dp, top = 0.dp),
        )
        Column(Modifier.padding(20.dp)) {
            Text(stringResource(R.string.today), style = MaterialTheme.typography.labelMedium, color = Color.White.copy(alpha = 0.8f))
            Text(dateLine, style = MaterialTheme.typography.titleLarge, color = Color.White)
            VSpace(60.dp)
            rows.forEach { row ->
                val selected = row.child.id == selectedId
                ChildRow(row, selected, onClick = { onSelect(row) })
                VSpace(8.dp)
            }
        }
    }
}

@Composable
private fun ChildRow(row: ChildToday, selected: Boolean, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    val shape = RoundedCornerShape(Radius.md)
    val look = row.status.look()
    Row(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(if (selected) c.surface else Color.White.copy(alpha = 0.14f))
            .border(1.dp, if (selected) c.surface else Color.White.copy(alpha = 0.25f), shape)
            .clickable(onClick = onClick)
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ChildAvatar(row.child, 44.dp)
        HSpace(12.dp)
        Column(Modifier.weight(1f)) {
            Text(
                row.child.fullName,
                style = MaterialTheme.typography.titleMedium,
                color = if (selected) c.ink else Color.White,
                maxLines = 1,
            )
            val detail = when {
                row.today?.arrivedAt != null && row.status.arrived -> stringResource(R.string.arrived_at, row.today.arrivedAt!!.hhmm())
                row.child.className != null -> stringResource(R.string.class_label, row.child.className)
                else -> ""
            }
            if (detail.isNotEmpty()) {
                Text(detail, style = MaterialTheme.typography.bodySmall, color = if (selected) c.inkSecondary else Color.White.copy(alpha = 0.8f))
            }
        }
        if (selected) {
            StatusPill(row.status, compact = true)
        } else {
            Box(Modifier.size(10.dp).clip(RoundedCornerShape(5.dp)).background(if (row.status == AttendanceStatus.UNKNOWN) Color.White.copy(alpha = 0.5f) else look.color))
        }
    }
}

@Composable
private fun ActionGrid(items: List<Triple<Int, Int, () -> Unit>>) {
    Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        items.chunked(2).forEach { pair ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                pair.forEach { (ill, label, action) ->
                    ActionTile(ill, stringResource(label), action, Modifier.weight(1f))
                }
                if (pair.size == 1) Box(Modifier.weight(1f))
            }
        }
    }
}
