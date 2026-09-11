package tj.cict.smartflow.ui.attendance

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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.YearMonth
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.hhmm
import tj.cict.smartflow.core.util.monthYear
import tj.cict.smartflow.core.util.weekdayShort
import tj.cict.smartflow.data.repo.ParentRepository
import tj.cict.smartflow.domain.AttendanceDay
import tj.cict.smartflow.domain.AttendanceStatus
import tj.cict.smartflow.ui.components.ChildDataViewModel
import tj.cict.smartflow.ui.components.DetailScaffold
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.StatusPill
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.components.look
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

class AttendanceViewModel(private val repo: ParentRepository) : ChildDataViewModel<List<AttendanceDay>>() {
    override suspend fun fetch(childId: Int): ApiResult<List<AttendanceDay>> = repo.attendance(childId)
}

@Composable
fun AttendanceScreen(childId: Int, childrenVm: ChildrenViewModel, onBack: () -> Unit, vm: AttendanceViewModel = koinViewModel()) {
    LaunchedEffect(childId) { vm.load(childId) }
    val state by vm.state.collectAsStateWithLifecycle()
    val children by childrenVm.ui.collectAsStateWithLifecycle()
    val child = children.child(childId)
    val locale = currentLocale()

    DetailScaffold(
        title = stringResource(R.string.attendance_title),
        subtitle = child?.fullName,
        state = state,
        onBack = onBack,
        onRetry = { vm.load(childId, force = true) },
    ) { days ->
        if (days.isEmpty()) {
            EmptyState(R.drawable.ill_door_check, stringResource(R.string.attendance_empty))
            return@DetailScaffold
        }
        val byMonth = remember(days) { days.sortedByDescending { it.date }.groupBy { YearMonth.from(it.date) } }
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            byMonth.forEach { (month, rows) ->
                item(key = "m$month") {
                    MonthHeader(month.atDay(1).monthYear(locale), rows)
                }
                items(rows, key = { it.date.toString() }) { day -> DayRow(day, locale) }
            }
        }
    }
}

/** Month name, then three counts as a stacked bar -- present / late / absent. */
@Composable
private fun MonthHeader(title: String, rows: List<AttendanceDay>) {
    val c = MaterialTheme.smart
    val present = rows.count { it.status == AttendanceStatus.PRESENT || it.status == AttendanceStatus.LEFT_SCHOOL }
    val late = rows.count { it.status == AttendanceStatus.LATE }
    val absent = rows.count { it.status == AttendanceStatus.ABSENT }
    val total = (present + late + absent).coerceAtLeast(1)
    Column(Modifier.padding(top = 10.dp, bottom = 4.dp)) {
        Text(title, style = MaterialTheme.typography.titleLarge, color = c.ink)
        VSpace(8.dp)
        Row(Modifier.fillMaxWidth().height(10.dp).clip(RoundedCornerShape(5.dp)).background(c.surfaceSoft)) {
            if (present > 0) Box(Modifier.weight(present.toFloat()).fillMaxSize().background(c.mint))
            if (late > 0) Box(Modifier.weight(late.toFloat()).fillMaxSize().background(c.amber))
            if (absent > 0) Box(Modifier.weight(absent.toFloat()).fillMaxSize().background(c.rose))
            if (present + late + absent < total) Box(Modifier.weight(1f).fillMaxSize())
        }
        VSpace(8.dp)
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Legend(c.mint, stringResource(R.string.present_days), present)
            Legend(c.amber, stringResource(R.string.late_days), late)
            Legend(c.rose, stringResource(R.string.absent_days), absent)
        }
    }
}

@Composable
private fun Legend(color: Color, label: String, count: Int) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(8.dp).clip(RoundedCornerShape(4.dp)).background(color))
        HSpace(6.dp)
        Text("$count", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.smart.ink)
        HSpace(4.dp)
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.smart.inkSecondary)
    }
}

@Composable
private fun DayRow(day: AttendanceDay, locale: java.util.Locale) {
    val c = MaterialTheme.smart
    val look = day.status.look()
    SoftCard(contentPadding = PaddingValues(14.dp), elevation = 6.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(
                Modifier.width(52.dp).clip(RoundedCornerShape(Radius.sm)).background(look.soft).padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("${day.date.dayOfMonth}", style = MaterialTheme.typography.headlineSmall, color = look.color)
                Text(day.date.weekdayShort(locale), style = MaterialTheme.typography.labelSmall, color = look.color)
            }
            HSpace(14.dp)
            Column(Modifier.weight(1f)) {
                StatusPill(day.status)
                val timeIn = day.arrivedAt
                val timeOut = day.timeOut
                if (timeIn != null || timeOut != null) {
                    VSpace(6.dp)
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        if (timeIn != null) TimeCell(stringResource(R.string.time_in), timeIn.hhmm())
                        if (timeOut != null) TimeCell(stringResource(R.string.time_out), timeOut.hhmm())
                    }
                }
            }
        }
    }
}

@Composable
private fun TimeCell(label: String, value: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.smart.inkTertiary)
        HSpace(4.dp)
        Text(value, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.smart.ink, fontWeight = FontWeight.Bold)
    }
}
