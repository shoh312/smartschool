package tj.cict.smartflow.ui.profile

import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Logout
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.os.LocaleListCompat
import tj.cict.smartflow.R
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

private val languages = listOf("tg" to R.string.lang_tg, "ru" to R.string.lang_ru, "en" to R.string.lang_en)

@Composable
fun ProfileSheet(parentName: String, onDismiss: () -> Unit, onSignOut: () -> Unit) {
    val c = MaterialTheme.smart
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var confirm by remember { mutableStateOf(false) }
    val currentLang = AppCompatDelegate.getApplicationLocales()[0]?.language
        ?: java.util.Locale.getDefault().language

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheet,
        containerColor = c.surface,
        shape = RoundedCornerShape(topStart = Radius.xl, topEnd = Radius.xl),
        dragHandle = {
            Box(Modifier.padding(top = 12.dp, bottom = 4.dp).size(width = 40.dp, height = 4.dp).clip(RoundedCornerShape(2.dp)).background(c.border))
        },
    ) {
        Column(Modifier.padding(horizontal = 24.dp).padding(bottom = 28.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(52.dp).clip(CircleShape).background(c.brandSoft), contentAlignment = Alignment.Center) {
                    Icon(Icons.Outlined.Person, null, tint = c.brandDeep)
                }
                HSpace(14.dp)
                Column {
                    Text(parentName.ifBlank { stringResource(R.string.profile_title) }, style = MaterialTheme.typography.titleLarge, color = c.ink)
                }
            }
            VSpace(22.dp)
            Text(stringResource(R.string.language), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
            VSpace(8.dp)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                languages.forEach { (tag, label) ->
                    val selected = tag == currentLang
                    Box(
                        Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(Radius.sm))
                            .background(if (selected) c.brand else c.surfaceSoft)
                            .border(1.dp, if (selected) c.brand else c.border, RoundedCornerShape(Radius.sm))
                            .clickable { AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(tag)) }
                            .padding(vertical = 12.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(stringResource(label), style = MaterialTheme.typography.labelMedium, color = if (selected) Color.White else c.ink)
                    }
                }
            }
            VSpace(22.dp)
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(Radius.md))
                    .background(c.roseSoft)
                    .clickable { confirm = true }
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.AutoMirrored.Outlined.Logout, null, tint = c.rose)
                HSpace(12.dp)
                Text(stringResource(R.string.logout), style = MaterialTheme.typography.labelLarge, color = c.rose)
            }
        }
    }

    if (confirm) {
        AlertDialog(
            onDismissRequest = { confirm = false },
            containerColor = c.surface,
            shape = RoundedCornerShape(Radius.lg),
            title = { Text(stringResource(R.string.logout_confirm), style = MaterialTheme.typography.titleLarge) },
            confirmButton = {
                TextButton(onClick = { confirm = false; onDismiss(); onSignOut() }) {
                    Text(stringResource(R.string.logout), color = c.rose, style = MaterialTheme.typography.labelLarge)
                }
            },
            dismissButton = {
                TextButton(onClick = { confirm = false }) { Text(stringResource(R.string.cancel), style = MaterialTheme.typography.labelLarge) }
            },
        )
    }
}
