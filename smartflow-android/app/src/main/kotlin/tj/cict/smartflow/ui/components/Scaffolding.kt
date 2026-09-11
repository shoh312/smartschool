package tj.cict.smartflow.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import tj.cict.smartflow.R
import tj.cict.smartflow.domain.Child
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

/** Big-title header with an optional back button. Sits under the status bar. */
@Composable
fun ScreenHeader(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    onBack: (() -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    Column(modifier.fillMaxWidth().padding(top = top + 10.dp, start = 20.dp, end = 20.dp, bottom = 8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (onBack != null) {
                RoundIconButton(Icons.AutoMirrored.Rounded.ArrowBack, stringResource(R.string.back), onBack)
                HSpace(14.dp)
            }
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.smart.ink)
                if (subtitle != null) {
                    Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.smart.inkSecondary)
                }
            }
            trailing?.invoke()
        }
    }
}

/** Horizontal row of children; hidden entirely when there is only one. */
@Composable
fun ChildSwitcher(children: List<Child>, selectedId: Int?, onSelect: (Child) -> Unit, modifier: Modifier = Modifier) {
    if (children.size < 2) return
    val c = MaterialTheme.smart
    LazyRow(
        modifier.fillMaxWidth(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(children, key = { it.id }) { child ->
            val selected = child.id == selectedId
            Row(
                Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(if (selected) c.brand else c.surface)
                    .border(1.dp, if (selected) c.brand else c.border, RoundedCornerShape(999.dp))
                    .clickable { onSelect(child) }
                    .padding(start = 4.dp, end = 14.dp, top = 4.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                ChildAvatar(child, size = 30.dp)
                Text(
                    child.firstName,
                    style = MaterialTheme.typography.labelMedium,
                    color = if (selected) androidx.compose.ui.graphics.Color.White else c.ink,
                )
            }
        }
    }
}

/** A quick-action tile: illustration on top, label under, whole thing tappable. */
@Composable
fun ActionTile(illustration: Int, label: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    SoftCard(
        modifier = modifier,
        shape = RoundedCornerShape(Radius.lg),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp),
        onClick = onClick,
    ) {
        Illustration(illustration, Modifier.fillMaxWidth())
        Text(
            label,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.smart.ink,
            modifier = Modifier.padding(start = 4.dp, top = 6.dp, bottom = 2.dp),
            maxLines = 1,
        )
    }
}
