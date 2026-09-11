package tj.cict.smartflow.ui.teacher

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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material3.Icon
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
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonth
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.core.util.weekdayLong
import tj.cict.smartflow.data.dto.ClassAssignmentDto
import tj.cict.smartflow.ui.components.ActionTile
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.Illustration
import tj.cict.smartflow.ui.components.RoundIconButton
import tj.cict.smartflow.ui.components.SectionTitle
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.profile.ProfileSheet
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

@Composable
fun TeacherHomeScreen(
    classesVm: TeacherClassesViewModel,
    name: String,
    subject: String?,
    bottomPadding: Dp,
    onSignOut: () -> Unit,
    onOpenClass: (ClassAssignmentDto) -> Unit,
    onScan: () -> Unit,
    onMaterials: () -> Unit,
    onCalendar: () -> Unit,
    onAnnouncements: () -> Unit,
) {
    val state by classesVm.state.collectAsStateWithLifecycle()
    val refreshing by classesVm.refreshing.collectAsStateWithLifecycle()
    var profileOpen by remember { mutableStateOf(false) }
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val locale = currentLocale()
    val today = LocalDate.now()
    val c = MaterialTheme.smart

    PullToRefreshBox(isRefreshing = refreshing, onRefresh = { classesVm.load(force = true) }, modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = top + 14.dp, bottom = bottomPadding + 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                Row(Modifier.padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(greeting(), style = MaterialTheme.typography.bodyMedium, color = c.inkSecondary)
                        Text(name.ifBlank { stringResource(R.string.app_name) }, style = MaterialTheme.typography.headlineMedium, color = c.ink, maxLines = 1)
                    }
                    RoundIconButton(Icons.Outlined.Person, stringResource(R.string.profile_title), onClick = { profileOpen = true })
                }
            }
            item {
                Box(Modifier.padding(horizontal = 20.dp).fillMaxWidth().clip(RoundedCornerShape(Radius.xl)).background(Brush.linearGradient(listOf(c.brand, c.brandDeep)))) {
                    Illustration(R.drawable.ill_book, Modifier.align(Alignment.CenterEnd).size(150.dp))
                    Column(Modifier.padding(20.dp)) {
                        Text(stringResource(R.string.today), style = MaterialTheme.typography.labelMedium, color = Color.White.copy(alpha = 0.8f))
                        Text("${today.weekdayLong(locale)}, ${today.dayMonth(locale)}", style = MaterialTheme.typography.titleLarge, color = Color.White)
                        VSpace(28.dp)
                        if (!subject.isNullOrBlank()) {
                            Box(Modifier.clip(RoundedCornerShape(999.dp)).background(Color.White.copy(alpha = 0.18f)).padding(horizontal = 12.dp, vertical = 6.dp)) {
                                Text(subject, style = MaterialTheme.typography.labelMedium, color = Color.White)
                            }
                        }
                    }
                }
            }
            item { SectionTitle(stringResource(R.string.home_quick), Modifier.padding(horizontal = 20.dp, vertical = 2.dp)) }
            item {
                Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        ActionTile(R.drawable.ill_notebook, stringResource(R.string.action_scan), onScan, Modifier.weight(1f))
                        ActionTile(R.drawable.ill_clipboard, stringResource(R.string.action_materials), onMaterials, Modifier.weight(1f))
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        ActionTile(R.drawable.ill_calendar, stringResource(R.string.action_calendar), onCalendar, Modifier.weight(1f))
                        ActionTile(R.drawable.ill_megaphone, stringResource(R.string.action_announcements), onAnnouncements, Modifier.weight(1f))
                    }
                }
            }
            item { SectionTitle(stringResource(R.string.my_classes), Modifier.padding(horizontal = 20.dp, vertical = 2.dp)) }
            when (val s = state) {
                UiState.Loading -> item { SkeletonList(rows = 3, rowHeight = 72.dp) }
                is UiState.Failed -> item { ErrorState(s.error.message(), onRetry = { classesVm.load(force = true) }) }
                is UiState.Ready -> if (s.data.isEmpty()) {
                    item { EmptyState(R.drawable.ill_backpack, stringResource(R.string.no_classes), stringResource(R.string.no_classes_body)) }
                } else {
                    items(s.data, key = { it.id }) { cls -> ClassCard(cls, Modifier.padding(horizontal = 20.dp), onClick = { onOpenClass(cls) }) }
                }
            }
        }
    }

    if (profileOpen) ProfileSheet(parentName = name, onDismiss = { profileOpen = false }, onSignOut = onSignOut)
}

@Composable
fun ClassCard(cls: ClassAssignmentDto, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    val palette = listOf(c.brand, c.coral, c.sky, c.mint, c.amber)
    val color = palette[Math.floorMod(cls.classId, palette.size)]
    SoftCard(modifier, contentPadding = PaddingValues(14.dp), elevation = 6.dp, onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(52.dp).clip(RoundedCornerShape(Radius.md)).background(color.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Groups, null, tint = color, modifier = Modifier.size(28.dp))
            }
            HSpace(14.dp)
            Column(Modifier.weight(1f)) {
                Text(cls.className ?: "", style = MaterialTheme.typography.titleMedium, color = c.ink)
                if (!cls.subject.isNullOrBlank() && cls.subject != cls.className) Text(cls.subject, style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
            }
        }
    }
}

@Composable
private fun greeting(): String {
    val hour = LocalTime.now().hour
    return stringResource(when { hour < 12 -> R.string.greeting_morning; hour < 18 -> R.string.greeting_afternoon; else -> R.string.greeting_evening })
}
