package tj.cict.smartflow.ui.calendar

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.LocalDate
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonth
import tj.cict.smartflow.core.util.monthYear
import tj.cict.smartflow.data.dto.CalendarEventDto
import tj.cict.smartflow.data.repo.ParentRepository
import tj.cict.smartflow.ui.components.Chip
import tj.cict.smartflow.ui.components.ChildDataViewModel
import tj.cict.smartflow.ui.components.DetailScaffold
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

class CalendarViewModel(private val repo: ParentRepository) : ChildDataViewModel<List<CalendarEventDto>>() {
    override suspend fun fetch(childId: Int): ApiResult<List<CalendarEventDto>> = repo.calendar(childId)
}

@Composable
fun CalendarScreen(childId: Int, childrenVm: ChildrenViewModel, onBack: () -> Unit, vm: CalendarViewModel = koinViewModel()) {
    LaunchedEffect(childId) { vm.load(childId) }
    val state by vm.state.collectAsStateWithLifecycle()
    val children by childrenVm.ui.collectAsStateWithLifecycle()
    val locale = currentLocale()

    DetailScaffold(
        title = stringResource(R.string.calendar_title),
        subtitle = children.child(childId)?.fullName,
        state = state,
        onBack = onBack,
        onRetry = { vm.load(childId, force = true) },
    ) { events ->
        val today = LocalDate.now()
        // Past events fall away; what is coming is what a parent opens this for.
        val upcoming = remember(events) { events.filter { (it.endDate ?: it.startDate) >= today }.sortedBy { it.startDate } }
        if (upcoming.isEmpty()) {
            EmptyState(R.drawable.ill_calendar, stringResource(R.string.calendar_empty))
            return@DetailScaffold
        }
        val byMonth = remember(upcoming) { upcoming.groupBy { java.time.YearMonth.from(it.startDate) } }
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            byMonth.forEach { (month, list) ->
                item(key = "m$month") {
                    Text(month.atDay(1).monthYear(locale), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.smart.ink, modifier = Modifier.padding(top = 8.dp))
                }
                items(list, key = { it.id }) { e -> EventCard(e, locale) }
            }
        }
    }
}

@Composable
fun EventCard(e: CalendarEventDto, locale: java.util.Locale) {
    val c = MaterialTheme.smart
    val (label, color, soft) = when (e.eventType.lowercase()) {
        "holiday", "vacation" -> Triple(stringResource(R.string.event_holiday), c.mint, c.mintSoft)
        "exam", "test", "control" -> Triple(stringResource(R.string.event_exam), c.coral, c.coralSoft)
        "meeting" -> Triple(stringResource(R.string.event_meeting), c.sky, c.skySoft)
        else -> Triple(stringResource(R.string.event_other), c.brand, c.brandSoft)
    }
    SoftCard(contentPadding = PaddingValues(14.dp), elevation = 6.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(
                Modifier.width(56.dp).clip(RoundedCornerShape(Radius.sm)).background(soft).padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("${e.startDate.dayOfMonth}", style = MaterialTheme.typography.headlineSmall, color = color)
                Text(e.startDate.dayMonth(locale).substringAfter(' ').take(3), style = MaterialTheme.typography.labelSmall, color = color)
            }
            HSpace(14.dp)
            Column(Modifier.weight(1f)) {
                Text(e.title, style = MaterialTheme.typography.titleMedium, color = c.ink)
                val range = if (e.endDate != null && e.endDate != e.startDate) "${e.startDate.dayMonth(locale)} — ${e.endDate.dayMonth(locale)}" else e.startDate.dayMonth(locale)
                Text(range, style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
                if (!e.description.isNullOrBlank()) {
                    VSpace(4.dp)
                    Text(e.description, style = MaterialTheme.typography.bodySmall, color = c.inkSecondary, maxLines = 3)
                }
            }
            HSpace(8.dp)
            Chip(label, color, soft)
        }
    }
}
