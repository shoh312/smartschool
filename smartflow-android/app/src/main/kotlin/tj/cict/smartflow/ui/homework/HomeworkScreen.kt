package tj.cict.smartflow.ui.homework

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
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
import tj.cict.smartflow.core.util.weekdayLong
import tj.cict.smartflow.data.dto.DiaryEntryDto
import tj.cict.smartflow.data.repo.ParentRepository
import tj.cict.smartflow.ui.components.ChildDataViewModel
import tj.cict.smartflow.ui.components.DetailScaffold
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.diary.subjectColor
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.theme.smart

class HomeworkViewModel(private val repo: ParentRepository) : ChildDataViewModel<List<DiaryEntryDto>>() {
    override suspend fun fetch(childId: Int): ApiResult<List<DiaryEntryDto>> = repo.homework(childId)
}

@Composable
fun HomeworkScreen(childId: Int, childrenVm: ChildrenViewModel, onBack: () -> Unit, vm: HomeworkViewModel = koinViewModel()) {
    LaunchedEffect(childId) { vm.load(childId) }
    val state by vm.state.collectAsStateWithLifecycle()
    val children by childrenVm.ui.collectAsStateWithLifecycle()
    val locale = currentLocale()
    val today = LocalDate.now()

    DetailScaffold(
        title = stringResource(R.string.homework_title),
        subtitle = children.child(childId)?.fullName,
        state = state,
        onBack = onBack,
        onRetry = { vm.load(childId, force = true) },
    ) { entries ->
        if (entries.isEmpty()) {
            EmptyState(R.drawable.ill_homework, stringResource(R.string.homework_empty))
            return@DetailScaffold
        }
        val byDay = remember(entries) { entries.groupBy { it.date }.toSortedMap(compareByDescending { it }) }
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            byDay.forEach { (date, list) ->
                item(key = "d$date") {
                    val label = if (date == today) stringResource(R.string.today) else date.weekdayLong(locale)
                    Row(Modifier.padding(top = 8.dp, bottom = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(label, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.smart.ink)
                        Text("  ·  ${date.dayMonth(locale)}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.smart.inkTertiary)
                    }
                }
                itemsIndexed(list, key = { i, e -> "$date-${e.lessonId}-$i" }) { index, entry ->
                    SoftCard(contentPadding = PaddingValues(16.dp), elevation = 6.dp) {
                        Row {
                            Box(Modifier.width(4.dp).height(22.dp).clip(RoundedCornerShape(2.dp)).background(subjectColor(index)))
                            Column(Modifier.padding(start = 12.dp)) {
                                Text(entry.subject, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.smart.brandDeep)
                                VSpace(4.dp)
                                Text(entry.homework.orEmpty(), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.smart.ink)
                                if (!entry.teacherName.isNullOrBlank()) {
                                    VSpace(4.dp)
                                    Text(entry.teacherName, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.smart.inkTertiary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
