package tj.cict.smartflow.ui.teacher

import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.io.File
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.data.dto.ClassAssignmentDto
import tj.cict.smartflow.ui.components.Chip
import tj.cict.smartflow.ui.components.GhostButton
import tj.cict.smartflow.ui.components.Illustration
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.PrimaryButton
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.grades.gradeColors
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

private fun cameraUri(context: Context): Uri {
    val file = File(context.cacheDir, "journal_capture.jpg")
    return FileProvider.getUriForFile(context, "${context.packageName}.files", file)
}

/**
 * Photograph a page of the paper journal, let the server read it, review
 * the rows, save. Nothing is written until the teacher presses save.
 */
@Composable
fun ScanJournalScreen(
    classesVm: TeacherClassesViewModel,
    preselectedClassId: Int?,
    onBack: () -> Unit,
    vm: ScanJournalViewModel = koinViewModel(),
) {
    val c = MaterialTheme.smart
    val context = LocalContext.current
    val classes by classesVm.state.collectAsStateWithLifecycle()
    val list = (classes as? UiState.Ready)?.data.orEmpty()
    var chosen by remember(list) { mutableStateOf(list.firstOrNull { it.classId == preselectedClassId } ?: list.firstOrNull()) }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val captureUri = remember { cameraUri(context) }

    val takePhoto = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val cls = chosen
        if (ok && cls != null) vm.scan(context, captureUri, cls.classId, cls.subject.orEmpty())
    }
    val pickPhoto = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        val cls = chosen
        if (uri != null && cls != null) vm.scan(context, uri, cls.classId, cls.subject.orEmpty())
    }

    val savedText = ui.saved?.let { stringResource(R.string.scan_saved, it) }

    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.scan_title), subtitle = chosen?.let { "${it.className} · ${it.subject}" }, onBack = onBack)

            when (ui.phase) {
                ScanUi.Phase.Idle -> Column(Modifier.fillMaxSize().padding(horizontal = 20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Illustration(R.drawable.ill_notebook, Modifier.fillMaxWidth(0.7f))
                    Text(stringResource(R.string.scan_intro), style = MaterialTheme.typography.bodyLarge, color = c.inkSecondary, textAlign = TextAlign.Center)
                    VSpace(16.dp)
                    if (list.size > 1) {
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            itemsIndexed(list) { _, cls ->
                                val selected = cls.id == chosen?.id
                                ClassPill(cls, selected) { chosen = cls }
                            }
                        }
                        VSpace(16.dp)
                    }
                    if (savedText != null) {
                        Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.sm)).background(c.mintSoft).padding(12.dp)) {
                            Text(savedText, style = MaterialTheme.typography.bodyMedium, color = c.mint)
                        }
                        VSpace(12.dp)
                    }
                    PrimaryButton(stringResource(R.string.scan_take_photo), onClick = { takePhoto.launch(captureUri) }, enabled = chosen != null)
                    VSpace(6.dp)
                    GhostButton(stringResource(R.string.scan_pick_photo), onClick = { pickPhoto.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }, enabled = chosen != null)
                }
                ScanUi.Phase.Reading -> Column(Modifier.fillMaxSize().padding(40.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    CircularProgressIndicator(color = c.brand)
                    VSpace(16.dp)
                    Text(stringResource(R.string.scan_reading), style = MaterialTheme.typography.titleMedium, color = c.inkSecondary)
                }
                ScanUi.Phase.Review, ScanUi.Phase.Saving -> Review(ui, vm, chosen)
            }
        }
    }

    ui.error?.let { err ->
        AlertDialog(
            onDismissRequest = vm::clearError, containerColor = c.surface, shape = RoundedCornerShape(Radius.lg),
            text = { Text(err.message(), style = MaterialTheme.typography.bodyLarge) },
            confirmButton = { TextButton(onClick = vm::clearError) { Text(stringResource(R.string.done)) } },
        )
    }
}

@Composable
private fun ClassPill(cls: ClassAssignmentDto, selected: Boolean, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    Box(
        Modifier.clip(RoundedCornerShape(999.dp)).background(if (selected) c.brand else c.surface).border(1.dp, if (selected) c.brand else c.border, RoundedCornerShape(999.dp))
            .clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
    ) { Text("${cls.className} · ${cls.subject}", style = MaterialTheme.typography.labelMedium, color = if (selected) Color.White else c.ink) }
}

@Composable
private fun Review(ui: ScanUi, vm: ScanJournalViewModel, cls: ClassAssignmentDto?) {
    val c = MaterialTheme.smart
    if (ui.rows.isEmpty()) {
        Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Illustration(R.drawable.ill_empty_box, Modifier.fillMaxWidth(0.6f))
            Text(stringResource(R.string.scan_none), style = MaterialTheme.typography.bodyLarge, color = c.inkSecondary, textAlign = TextAlign.Center)
            VSpace(12.dp)
            GhostButton(stringResource(R.string.retry), onClick = vm::reset)
        }
        return
    }
    Column(Modifier.fillMaxSize()) {
        LazyColumn(
            Modifier.weight(1f),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item { Text(stringResource(R.string.scan_results, ui.rows.size), style = MaterialTheme.typography.titleMedium, color = c.ink) }
            itemsIndexed(ui.rows) { i, row -> ScanRowCard(row, onGrade = { vm.setGrade(i, it) }, onToggle = { vm.toggle(i) }) }
        }
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 20.dp)) {
            PrimaryButton(
                stringResource(R.string.scan_save_all, ui.toSave.size),
                onClick = { cls?.let { vm.saveAll(it.classId, it.subject.orEmpty()) } },
                enabled = ui.toSave.isNotEmpty(), loading = ui.phase == ScanUi.Phase.Saving,
            )
            VSpace(4.dp)
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { GhostButton(stringResource(R.string.cancel), onClick = vm::reset) }
        }
    }
}

@Composable
private fun ScanRowCard(row: ScanRow, onGrade: (Int?) -> Unit, onToggle: () -> Unit) {
    val c = MaterialTheme.smart
    val matched = row.raw.studentId != null
    val shaky = matched && row.raw.confidence < 0.75
    SoftCard(contentPadding = PaddingValues(12.dp), elevation = 5.dp) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.alpha(if (row.include) 1f else 0.5f)) {
            Box(
                Modifier.size(28.dp).clip(CircleShape).background(if (row.include) c.brand else c.surfaceSoft).border(1.dp, if (row.include) c.brand else c.border, CircleShape)
                    .clickable(enabled = matched, onClick = onToggle),
                contentAlignment = Alignment.Center,
            ) { if (row.include) androidx.compose.material3.Icon(Icons.Rounded.Check, null, tint = Color.White, modifier = Modifier.size(16.dp)) }
            Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Text(row.raw.matchedName ?: row.raw.rawName, style = MaterialTheme.typography.titleSmall, color = c.ink)
                when {
                    !matched -> Chip(stringResource(R.string.scan_unmatched), c.rose, c.roseSoft)
                    shaky -> Row(verticalAlignment = Alignment.CenterVertically) {
                        Chip(stringResource(R.string.scan_low_confidence), c.amber, c.amberSoft)
                        Text("  " + stringResource(R.string.scan_read_as, row.raw.rawName), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary, maxLines = 1)
                    }
                    else -> Unit
                }
            }
            if (row.absent) {
                Chip(stringResource(R.string.scan_absent), c.rose, c.roseSoft)
            }
        }
        if (matched) {
            VSpace(10.dp)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                itemsIndexed((1..10).toList()) { _, v ->
                    val (gc, gs) = gradeColors(v.toDouble())
                    val selected = row.grade == v && !row.absent
                    Box(
                        Modifier.size(36.dp).clip(RoundedCornerShape(9.dp)).background(if (selected) gc else gs).clickable { onGrade(if (selected) null else v) },
                        contentAlignment = Alignment.Center,
                    ) { Text("$v", style = MaterialTheme.typography.labelMedium, color = if (selected) Color.White else gc) }
                }
            }
        }
    }
}
