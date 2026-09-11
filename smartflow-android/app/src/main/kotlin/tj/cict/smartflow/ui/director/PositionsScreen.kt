package tj.cict.smartflow.ui.director

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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.DayOfWeek
import java.time.format.TextStyle
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.formatTimeInput
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.data.dto.CameraPositionCreateRequest
import tj.cict.smartflow.data.dto.CameraPositionDto
import tj.cict.smartflow.ui.components.AppTextField
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.PrimaryButton
import tj.cict.smartflow.ui.components.RoundIconButton
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

private val TIME = Regex("^([01]?\\d|2[0-3]):[0-5]\\d$")

/**
 * A camera's timetable in group mode: which group is in front of it and
 * when. Without these the camera has nobody to look for -- it reports
 * "not lesson time" all day.
 */
@Composable
fun PositionsScreen(cameraId: Int, cameraName: String, schoolVm: SchoolViewModel, onBack: () -> Unit, vm: PositionsViewModel = koinViewModel()) {
    LaunchedEffect(cameraId) { vm.load(cameraId) }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val school by schoolVm.ui.collectAsStateWithLifecycle()
    val c = MaterialTheme.smart
    val locale = currentLocale()
    var adding by remember { mutableStateOf(false) }

    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.positions_title), subtitle = cameraName, onBack = onBack, trailing = { RoundIconButton(Icons.Rounded.Add, stringResource(R.string.add_position), { adding = true }) })
            when (val s = ui.rows) {
                UiState.Loading -> SkeletonList(rows = 4, rowHeight = 64.dp)
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = { vm.load(cameraId) })
                is UiState.Ready -> if (s.data.isEmpty()) {
                    EmptyState(R.drawable.ill_calendar, stringResource(R.string.positions_empty), stringResource(R.string.positions_hint))
                } else {
                    val sorted = s.data.sortedWith(compareBy({ it.dayOfWeek ?: -1 }, { it.startTime }))
                    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        item { Text(stringResource(R.string.positions_hint), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary) }
                        items(sorted, key = { it.id }) { p ->
                            SoftCard(contentPadding = PaddingValues(12.dp), elevation = 4.dp) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Column(Modifier.width(96.dp)) {
                                        Text("${p.startTime}–${p.endTime}", style = MaterialTheme.typography.titleSmall, color = c.ink)
                                        Text(dayLabel(p.dayOfWeek, locale), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
                                    }
                                    HSpace(10.dp)
                                    Column(Modifier.weight(1f)) {
                                        Text(p.className ?: "#${p.classId}", style = MaterialTheme.typography.titleMedium, color = c.ink)
                                        if (!p.subject.isNullOrBlank() && p.subject != p.className) Text(p.subject, style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
                                    }
                                    Box(Modifier.size(36.dp).clip(CircleShape).clickable { vm.delete(p.id) }, contentAlignment = Alignment.Center) { Icon(Icons.Outlined.Delete, null, tint = c.inkTertiary, modifier = Modifier.size(20.dp)) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (adding) {
        var classId by remember { mutableStateOf(school.classList.firstOrNull()?.id) }
        var start by remember { mutableStateOf("") }
        var end by remember { mutableStateOf("") }
        var subject by remember { mutableStateOf("") }
        var day by remember { mutableStateOf<Int?>(null) }
        ModalBottomSheet(
            onDismissRequest = { adding = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = c.surface,
            shape = RoundedCornerShape(topStart = Radius.xl, topEnd = Radius.xl),
            dragHandle = { Box(Modifier.padding(top = 12.dp, bottom = 4.dp).size(width = 40.dp, height = 4.dp).clip(RoundedCornerShape(2.dp)).background(c.border)) },
        ) {
            Column(Modifier.imePadding().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(bottom = 28.dp)) {
                Text(stringResource(R.string.add_position), style = MaterialTheme.typography.titleLarge); VSpace(14.dp)
                Text(stringResource(R.string.position_group), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary); VSpace(6.dp)
                ClassPicker(school.classList, classId) { classId = it }; VSpace(12.dp)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.weight(1f)) { AppTextField(start, { start = formatTimeInput(it) }, stringResource(R.string.position_start), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), isError = start.isNotBlank() && !TIME.matches(start.trim())) }
                    Box(Modifier.weight(1f)) { AppTextField(end, { end = formatTimeInput(it) }, stringResource(R.string.position_end), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), isError = end.isNotBlank() && !TIME.matches(end.trim())) }
                }
                Text(stringResource(R.string.position_time_hint), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary); VSpace(12.dp)
                Text(stringResource(R.string.position_day), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary); VSpace(6.dp)
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    item { DayPill(stringResource(R.string.position_every_day), day == null) { day = null } }
                    items((0..6).toList()) { d -> DayPill(dayLabel(d, locale), day == d) { day = d } }
                }
                VSpace(12.dp)
                AppTextField(subject, { subject = it }, stringResource(R.string.position_subject)); VSpace(16.dp)
                val ok = classId != null && TIME.matches(start.trim()) && TIME.matches(end.trim())
                PrimaryButton(
                    stringResource(R.string.create),
                    onClick = { vm.add(CameraPositionCreateRequest(classId!!, start.trim(), end.trim(), subject.trim().ifBlank { null }, day)); adding = false },
                    enabled = ok, loading = ui.busy,
                )
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
private fun dayLabel(day: Int?, locale: java.util.Locale): String =
    if (day == null) stringResource(R.string.position_every_day)
    else DayOfWeek.of(day + 1).getDisplayName(TextStyle.SHORT, locale).replaceFirstChar { it.titlecase(locale) }

@Composable
private fun DayPill(text: String, selected: Boolean, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    Box(
        Modifier.clip(RoundedCornerShape(999.dp)).background(if (selected) c.brand else c.surfaceSoft).border(1.dp, if (selected) c.brand else c.border, RoundedCornerShape(999.dp)).clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 8.dp),
    ) { Text(text, style = MaterialTheme.typography.labelMedium, color = if (selected) Color.White else c.ink) }
}

