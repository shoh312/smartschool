package tj.cict.smartflow.ui.director

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.Segment
import tj.cict.smartflow.ui.components.SegmentRow
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.rating.RatingBody

/** The parent's rating page, opened by the director on any pupil. */
@Composable
fun StudentRatingScreen(studentId: Int, name: String, onBack: () -> Unit, vm: StudentRatingViewModel = koinViewModel()) {
    LaunchedEffect(studentId) { vm.load(studentId) }
    val state by vm.state.collectAsStateWithLifecycle()
    val quarter by vm.quarter.collectAsStateWithLifecycle()
    val current = (state as? UiState.Ready)?.data?.quarter

    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.rating_title), subtitle = name, onBack = onBack)
            SegmentRow(Modifier.padding(horizontal = 20.dp)) {
                (1..4).forEach { q -> Segment(stringResource(R.string.quarter_short, q), selected = (quarter ?: current) == q) { vm.pickQuarter(q) } }
            }
            VSpace(6.dp)
            when (val s = state) {
                UiState.Loading -> SkeletonList(rows = 3, rowHeight = 140.dp)
                is UiState.Failed -> if (s.error is ApiError.Detail && s.error.status == 404) {
                    EmptyState(R.drawable.ill_trophy, stringResource(R.string.rating_title), stringResource(R.string.rating_empty))
                } else {
                    ErrorState(s.error.message(), onRetry = { vm.pickQuarter(quarter ?: current ?: 1) })
                }
                is UiState.Ready -> RatingBody(s.data, bottomPadding = 0.dp)
            }
        }
    }
}
