package tj.cict.smartflow.ui.announcements

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonthTime
import tj.cict.smartflow.data.dto.AnnouncementDto
import tj.cict.smartflow.data.repo.ParentRepository
import tj.cict.smartflow.ui.components.ChildDataViewModel
import tj.cict.smartflow.ui.components.DetailScaffold
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.theme.smart

class AnnouncementsViewModel(private val repo: ParentRepository) : ChildDataViewModel<List<AnnouncementDto>>() {
    override suspend fun fetch(childId: Int): ApiResult<List<AnnouncementDto>> = repo.announcements(childId)
}

@Composable
fun AnnouncementsScreen(childId: Int, childrenVm: ChildrenViewModel, onBack: () -> Unit, vm: AnnouncementsViewModel = koinViewModel()) {
    LaunchedEffect(childId) { vm.load(childId) }
    val state by vm.state.collectAsStateWithLifecycle()
    val children by childrenVm.ui.collectAsStateWithLifecycle()
    val locale = currentLocale()

    DetailScaffold(
        title = stringResource(R.string.announcements_title),
        subtitle = children.child(childId)?.fullName,
        state = state,
        onBack = onBack,
        onRetry = { vm.load(childId, force = true) },
    ) { list ->
        if (list.isEmpty()) {
            EmptyState(R.drawable.ill_megaphone, stringResource(R.string.announcements_empty))
            return@DetailScaffold
        }
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(list, key = { it.id }) { a ->
                SoftCard(contentPadding = PaddingValues(18.dp), elevation = 6.dp) {
                    a.createdAt?.let {
                        Text(it.dayMonthTime(locale), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.smart.inkTertiary)
                        VSpace(4.dp)
                    }
                    Text(a.title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.smart.ink)
                    VSpace(6.dp)
                    Text(a.body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.smart.inkSecondary)
                }
            }
        }
    }
}
