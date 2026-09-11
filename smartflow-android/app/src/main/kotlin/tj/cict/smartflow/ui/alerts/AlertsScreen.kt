package tj.cict.smartflow.ui.alerts

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Campaign
import androidx.compose.material.icons.rounded.DirectionsWalk
import androidx.compose.material.icons.rounded.EventBusy
import androidx.compose.material.icons.rounded.Grade
import androidx.compose.material.icons.rounded.Login
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import java.time.LocalDate
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonth
import tj.cict.smartflow.core.util.hhmm
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.core.util.toUiState
import tj.cict.smartflow.data.dto.NotificationDto
import tj.cict.smartflow.data.repo.ParentRepository
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

class AlertsViewModel(private val repo: ParentRepository) : ViewModel() {
    private val _state = MutableStateFlow<UiState<List<NotificationDto>>>(UiState.Loading)
    val state: StateFlow<UiState<List<NotificationDto>>> = _state.asStateFlow()
    private val _refreshing = MutableStateFlow(false)
    val refreshing: StateFlow<Boolean> = _refreshing.asStateFlow()
    private var loaded = false

    fun load(parentId: Int, force: Boolean = false) {
        if (loaded && !force && _state.value is UiState.Ready) return
        loaded = true
        if (force) _refreshing.value = true else _state.value = UiState.Loading
        viewModelScope.launch {
            _state.value = repo.notifications(parentId).toUiState()
            _refreshing.value = false
        }
    }
}

@Composable
fun AlertsScreen(parentId: Int, childrenVm: ChildrenViewModel, bottomPadding: Dp, vm: AlertsViewModel = koinViewModel()) {
    LaunchedEffect(parentId) { vm.load(parentId) }
    val state by vm.state.collectAsStateWithLifecycle()
    val refreshing by vm.refreshing.collectAsStateWithLifecycle()
    val children by childrenVm.ui.collectAsStateWithLifecycle()
    val locale = currentLocale()

    Column(Modifier.fillMaxSize()) {
        ScreenHeader(stringResource(R.string.alerts_title))
        PullToRefreshBox(isRefreshing = refreshing, onRefresh = { vm.load(parentId, force = true) }, modifier = Modifier.fillMaxSize()) {
            when (val s = state) {
                UiState.Loading -> SkeletonList()
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = { vm.load(parentId, force = true) })
                is UiState.Ready -> {
                    if (s.data.isEmpty()) {
                        EmptyState(R.drawable.ill_bell, stringResource(R.string.alerts_title), stringResource(R.string.alerts_empty))
                    } else {
                        val byDay = s.data.groupBy { (it.sentAt ?: it.createdAt)?.toLocalDate() }
                        LazyColumn(
                            Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = bottomPadding + 16.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            byDay.forEach { (day, list) ->
                                item(key = "d$day") {
                                    val label = when (day) {
                                        null -> ""
                                        LocalDate.now() -> stringResource(R.string.today)
                                        else -> day.dayMonth(locale)
                                    }
                                    Text(label, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.smart.ink, modifier = Modifier.padding(top = 8.dp))
                                }
                                items(list, key = { it.id }) { n ->
                                    NotificationRow(n, childName = n.studentId?.let { id -> children.child(id)?.firstName })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NotificationRow(n: NotificationDto, childName: String?) {
    val c = MaterialTheme.smart
    val (icon, color, soft) = when (n.eventType) {
        "arrived", "present", "attendance_present" -> Triple(Icons.Rounded.Login, c.mint, c.mintSoft)
        "late", "attendance_late" -> Triple(Icons.Rounded.Schedule, c.amber, c.amberSoft)
        "absent", "attendance_absent" -> Triple(Icons.Rounded.EventBusy, c.rose, c.roseSoft)
        "left_school", "attendance_left_school" -> Triple(Icons.Rounded.DirectionsWalk, c.sky, c.skySoft)
        "grade", "new_grade" -> Triple(Icons.Rounded.Grade, c.brand, c.brandSoft)
        "announcement", "school_message" -> Triple(Icons.Rounded.Campaign, c.coral, c.coralSoft)
        else -> Triple(Icons.Rounded.Notifications, c.brand, c.brandSoft)
    }
    SoftCard(contentPadding = PaddingValues(14.dp), elevation = 5.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(44.dp).clip(RoundedCornerShape(Radius.sm)).background(soft), contentAlignment = Alignment.Center) {
                Icon(icon, null, tint = color)
            }
            HSpace(12.dp)
            Column(Modifier.weight(1f)) {
                Text(n.title, style = MaterialTheme.typography.titleSmall, color = c.ink)
                Text(n.body, style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
                val time = (n.sentAt ?: n.createdAt)?.hhmm()
                val meta = listOfNotNull(childName, time).joinToString(" · ")
                if (meta.isNotEmpty()) Text(meta, style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
            }
        }
    }
}
