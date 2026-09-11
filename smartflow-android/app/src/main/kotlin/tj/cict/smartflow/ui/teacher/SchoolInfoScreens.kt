package tj.cict.smartflow.ui.teacher

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.LocalDate
import java.time.YearMonth
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonthTime
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.core.util.monthYear
import tj.cict.smartflow.ui.calendar.EventCard
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.theme.smart

@Composable
fun TeacherCalendarScreen(onBack: () -> Unit, vm: SchoolInfoViewModel = koinViewModel()) {
    LaunchedEffect(Unit) { vm.loadCalendar() }
    val state by vm.calendar.collectAsStateWithLifecycle()
    val locale = currentLocale()
    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.school_calendar), onBack = onBack)
            when (val s = state) {
                UiState.Loading -> SkeletonList()
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = { vm.loadCalendar(force = true) })
                is UiState.Ready -> {
                    val today = LocalDate.now()
                    val upcoming = remember(s.data) { s.data.filter { (it.endDate ?: it.startDate) >= today }.sortedBy { it.startDate } }
                    if (upcoming.isEmpty()) { EmptyState(R.drawable.ill_calendar, stringResource(R.string.calendar_empty)); return@Column }
                    val byMonth = remember(upcoming) { upcoming.groupBy { YearMonth.from(it.startDate) } }
                    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        byMonth.forEach { (month, list) ->
                            item(key = "m$month") { Text(month.atDay(1).monthYear(locale), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.smart.ink, modifier = Modifier.padding(top = 8.dp)) }
                            items(list, key = { it.id }) { e -> EventCard(e, locale) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun TeacherAnnouncementsScreen(onBack: () -> Unit, vm: SchoolInfoViewModel = koinViewModel()) {
    LaunchedEffect(Unit) { vm.loadAnnouncements() }
    val state by vm.announcements.collectAsStateWithLifecycle()
    val locale = currentLocale()
    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.school_announcements), onBack = onBack)
            when (val s = state) {
                UiState.Loading -> SkeletonList()
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = { vm.loadAnnouncements(force = true) })
                is UiState.Ready -> if (s.data.isEmpty()) EmptyState(R.drawable.ill_megaphone, stringResource(R.string.announcements_empty)) else {
                    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        items(s.data, key = { it.id }) { a ->
                            SoftCard(contentPadding = PaddingValues(18.dp), elevation = 6.dp) {
                                a.createdAt?.let { Text(it.dayMonthTime(locale), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.smart.inkTertiary); VSpace(4.dp) }
                                Text(a.title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.smart.ink)
                                VSpace(6.dp)
                                Text(a.body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.smart.inkSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
