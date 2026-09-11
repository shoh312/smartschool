package tj.cict.smartflow.ui.director

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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Videocam
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.io.File
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.formatAverage
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.data.dto.CameraCreateRequest
import tj.cict.smartflow.data.dto.CameraDto
import tj.cict.smartflow.data.dto.ClassDto
import tj.cict.smartflow.data.dto.StudentDto
import tj.cict.smartflow.data.dto.TeacherDto
import tj.cict.smartflow.data.repo.StudentEdit
import tj.cict.smartflow.domain.Child
import tj.cict.smartflow.ui.components.AppTextField
import tj.cict.smartflow.ui.components.ChildAvatar
import tj.cict.smartflow.ui.components.Chip
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.GhostButton
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.PrimaryButton
import tj.cict.smartflow.ui.components.RoundIconButton
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.grades.gradeColors
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

// ------------------------------------------------------------ shared bits

@Composable
private fun Sheet(onDismiss: () -> Unit, content: @Composable () -> Unit) {
    val c = MaterialTheme.smart
    ModalBottomSheet(
        onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = c.surface,
        shape = RoundedCornerShape(topStart = Radius.xl, topEnd = Radius.xl),
        dragHandle = { Box(Modifier.padding(top = 12.dp, bottom = 4.dp).size(width = 40.dp, height = 4.dp).clip(RoundedCornerShape(2.dp)).background(c.border)) },
    ) {
        Column(Modifier.imePadding().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(bottom = 28.dp)) { content() }
    }
}

@Composable
private fun ConfirmDialog(text: String, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    val c = MaterialTheme.smart
    AlertDialog(
        onDismissRequest = onDismiss, containerColor = c.surface, shape = RoundedCornerShape(Radius.lg),
        title = { Text(text, style = MaterialTheme.typography.titleMedium) },
        confirmButton = { TextButton(onClick = { onDismiss(); onConfirm() }) { Text(stringResource(R.string.delete), color = c.rose) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}

@Composable
private fun ErrorDialog(vm: SchoolViewModel) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    ui.error?.let { err ->
        AlertDialog(
            onDismissRequest = vm::clearError, containerColor = MaterialTheme.smart.surface, shape = RoundedCornerShape(Radius.lg),
            text = { Text(err.message(), style = MaterialTheme.typography.bodyLarge) },
            confirmButton = { TextButton(onClick = vm::clearError) { Text(stringResource(R.string.done)) } },
        )
    }
}

/** Horizontal class picker used by every form that needs one. */
@Composable
fun ClassPicker(classes: List<ClassDto>, selected: Int?, allowNone: Boolean = false, onPick: (Int?) -> Unit) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        if (allowNone) item { PickPill(stringResource(R.string.none_option), selected == null) { onPick(null) } }
        items(classes, key = { it.id }) { cls -> PickPill(cls.name, selected == cls.id) { onPick(cls.id) } }
    }
}

@Composable
private fun PickPill(text: String, selected: Boolean, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    Box(
        Modifier.clip(RoundedCornerShape(999.dp)).background(if (selected) c.brand else c.surfaceSoft).border(1.dp, if (selected) c.brand else c.border, RoundedCornerShape(999.dp)).clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
    ) { Text(text, style = MaterialTheme.typography.labelMedium, color = if (selected) Color.White else c.ink) }
}

// ================================================================= School hub

@Composable
fun SchoolHubScreen(vm: SchoolViewModel, bottomPadding: Dp, onClasses: () -> Unit, onStudents: () -> Unit, onTeachers: () -> Unit, onCameras: () -> Unit) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    Column(Modifier.fillMaxSize()) {
        ScreenHeader(stringResource(R.string.school_title))
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = bottomPadding + 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { HubRow(R.drawable.ill_book, stringResource(R.string.classes_title), (ui.classes as? UiState.Ready)?.data?.size, onClasses) }
            item { HubRow(R.drawable.ill_family, stringResource(R.string.students_title), (ui.students as? UiState.Ready)?.data?.size, onStudents) }
            item { HubRow(R.drawable.ill_notebook, stringResource(R.string.teachers_title), (ui.teachers as? UiState.Ready)?.data?.size, onTeachers) }
            item { HubRow(R.drawable.ill_door_check, stringResource(R.string.cameras_title), (ui.cameras as? UiState.Ready)?.data?.size, onCameras) }
        }
    }
}

@Composable
private fun HubRow(ill: Int, title: String, count: Int?, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    SoftCard(contentPadding = PaddingValues(12.dp), onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            tj.cict.smartflow.ui.components.Illustration(ill, Modifier.size(width = 96.dp, height = 72.dp))
            HSpace(12.dp)
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleLarge, color = c.ink)
                if (count != null) Text("$count", style = MaterialTheme.typography.bodyMedium, color = c.inkSecondary)
            }
        }
    }
}

// =================================================================== Classes

@Composable
fun ClassesScreen(vm: SchoolViewModel, onBack: () -> Unit, onOpen: (ClassDto) -> Unit) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    var adding by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf<ClassDto?>(null) }
    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.classes_title), onBack = onBack, trailing = { RoundIconButton(Icons.Rounded.Add, stringResource(R.string.add_class), { adding = true }) })
            when (val s = ui.classes) {
                UiState.Loading -> SkeletonList(rows = 5, rowHeight = 64.dp)
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = vm::loadAll)
                is UiState.Ready -> if (s.data.isEmpty()) EmptyState(R.drawable.ill_book, stringResource(R.string.no_classes)) else {
                    val counts = (ui.students as? UiState.Ready)?.data.orEmpty().groupingBy { it.classId }.eachCount()
                    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(s.data, key = { it.id }) { cls ->
                            val c = MaterialTheme.smart
                            SoftCard(contentPadding = PaddingValues(12.dp), elevation = 4.dp, onClick = { onOpen(cls) }) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(Modifier.size(46.dp).clip(RoundedCornerShape(Radius.sm)).background(c.brandSoft), contentAlignment = Alignment.Center) { Text(cls.name, style = MaterialTheme.typography.titleMedium, color = c.brandDeep) }
                                    HSpace(12.dp)
                                    Column(Modifier.weight(1f)) {
                                        Text(stringResource(R.string.pupils_count, counts[cls.id] ?: 0), style = MaterialTheme.typography.bodyMedium, color = c.ink)
                                        Text(listOfNotNull(cls.startTime, cls.endTime).joinToString(" – "), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
                                    }
                                    Box(Modifier.size(36.dp).clip(CircleShape).clickable { deleting = cls }, contentAlignment = Alignment.Center) { Icon(Icons.Outlined.Delete, null, tint = c.inkTertiary, modifier = Modifier.size(20.dp)) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (adding) {
        var name by remember { mutableStateOf("") }
        var grade by remember { mutableStateOf("") }
        Sheet(onDismiss = { adding = false }) {
            Text(stringResource(R.string.add_class), style = MaterialTheme.typography.titleLarge); VSpace(14.dp)
            AppTextField(name, { name = it; grade = it.filter(Char::isDigit) }, stringResource(R.string.class_name)); VSpace(10.dp)
            AppTextField(grade, { grade = it.filter(Char::isDigit) }, stringResource(R.string.class_grade), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)); VSpace(18.dp)
            PrimaryButton(stringResource(R.string.create), onClick = { vm.createClass(name.trim(), grade.toIntOrNull()); adding = false }, enabled = name.isNotBlank(), loading = ui.busy)
        }
    }
    deleting?.let { cls -> ConfirmDialog(stringResource(R.string.delete_class_confirm, cls.name), onConfirm = { vm.deleteClass(cls.id) }, onDismiss = { deleting = null }) }
    ErrorDialog(vm)
}

@Composable
fun ClassDetailScreen(cls: ClassDto, schoolVm: SchoolViewModel, onBack: () -> Unit, vm: ClassDetailViewModel = koinViewModel()) {
    LaunchedEffect(cls.id) { vm.load(cls.id) }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val school by schoolVm.ui.collectAsStateWithLifecycle()
    val c = MaterialTheme.smart
    val pupils = (school.students as? UiState.Ready)?.data.orEmpty().filter { it.classId == cls.id }
    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(cls.name, subtitle = stringResource(R.string.pupils_count, pupils.size), onBack = onBack)
            LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                (ui.averages as? UiState.Ready)?.data?.takeIf { it.isNotEmpty() }?.let { subs ->
                    item {
                        SoftCard {
                            Text(stringResource(R.string.class_subjects_title), style = MaterialTheme.typography.titleMedium, color = c.ink); VSpace(10.dp)
                            subs.forEach { s ->
                                val (gc, gs) = gradeColors(s.average)
                                Row(Modifier.padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Text(s.subject, style = MaterialTheme.typography.bodyMedium, color = c.ink, modifier = Modifier.weight(1f), maxLines = 1)
                                    Box(Modifier.weight(1f).height(8.dp).clip(RoundedCornerShape(4.dp)).background(gs)) { Box(Modifier.fillMaxWidth((s.average / 10).toFloat().coerceIn(0f, 1f)).fillMaxSize().background(gc)) }
                                    HSpace(10.dp)
                                    Text(formatAverage(s.average), style = MaterialTheme.typography.titleSmall, color = gc)
                                }
                            }
                        }
                    }
                }
                (ui.subjects as? UiState.Ready)?.data?.takeIf { it.isNotEmpty() }?.let { subs ->
                    item {
                        SoftCard {
                            Text(stringResource(R.string.teachers_title), style = MaterialTheme.typography.titleMedium, color = c.ink); VSpace(8.dp)
                            subs.forEach { s ->
                                Row(Modifier.padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Text(s.subject ?: "", style = MaterialTheme.typography.bodyMedium, color = c.ink, modifier = Modifier.weight(1f))
                                    Text(s.teacherName, style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
                                }
                            }
                        }
                    }
                }
                item { Text(stringResource(R.string.students_title), style = MaterialTheme.typography.titleLarge, color = c.ink, modifier = Modifier.padding(top = 6.dp)) }
                val ranks = (ui.ranking as? UiState.Ready)?.data.orEmpty().associateBy { it.studentId }
                items(pupils.sortedBy { it.lastName }, key = { it.id }) { s ->
                    SoftCard(contentPadding = PaddingValues(10.dp), elevation = 4.dp) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            ChildAvatar(Child(s.id, s.firstName, s.lastName, s.className), 38.dp); HSpace(12.dp)
                            Text("${s.lastName} ${s.firstName}", style = MaterialTheme.typography.titleSmall, color = c.ink, modifier = Modifier.weight(1f))
                            ranks[s.id]?.let { r -> r.overallAverage?.let { avg -> val (gc, gs) = gradeColors(avg); Chip("#${r.position} · ${formatAverage(avg)}", gc, gs) } }
                        }
                    }
                }
            }
        }
    }
}

// ================================================================== Students

@Composable
fun StudentsScreen(vm: SchoolViewModel, onBack: () -> Unit) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    val c = MaterialTheme.smart
    var query by remember { mutableStateOf("") }
    var adding by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<StudentDto?>(null) }
    var deleting by remember { mutableStateOf<StudentDto?>(null) }
    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.students_title), onBack = onBack, trailing = { RoundIconButton(Icons.Rounded.Add, stringResource(R.string.add_student), { adding = true }) })
            Box(Modifier.padding(horizontal = 20.dp)) { AppTextField(query, { query = it }, stringResource(R.string.search), leading = Icons.Outlined.Search) }
            VSpace(8.dp)
            when (val s = ui.students) {
                UiState.Loading -> SkeletonList(rows = 6, rowHeight = 60.dp)
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = vm::loadAll)
                is UiState.Ready -> {
                    val q = query.trim().lowercase()
                    val rows = s.data.filter { q.isEmpty() || "${it.firstName} ${it.lastName} ${it.className}".lowercase().contains(q) }.sortedWith(compareBy({ it.className }, { it.lastName }))
                    if (rows.isEmpty()) { EmptyState(R.drawable.ill_backpack, stringResource(R.string.no_students)); return@Column }
                    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(rows, key = { it.id }) { st ->
                            SoftCard(contentPadding = PaddingValues(10.dp), elevation = 4.dp, onClick = { editing = st }) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    ChildAvatar(Child(st.id, st.firstName, st.lastName, st.className), 38.dp); HSpace(12.dp)
                                    Column(Modifier.weight(1f)) {
                                        Text("${st.lastName} ${st.firstName}", style = MaterialTheme.typography.titleSmall, color = c.ink, maxLines = 1)
                                        Text(listOfNotNull(st.className?.let { stringResource(R.string.class_label, it) }, st.parentPhone).joinToString(" · "), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary, maxLines = 1)
                                    }
                                    Box(Modifier.size(36.dp).clip(CircleShape).clickable { deleting = st }, contentAlignment = Alignment.Center) { Icon(Icons.Outlined.Delete, null, tint = c.inkTertiary, modifier = Modifier.size(20.dp)) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (adding) AddStudentSheet(vm, ui.classList, ui.busy, onDismiss = { adding = false })
    editing?.let { st -> EditStudentSheet(st, vm, ui.classList, ui.busy, onDismiss = { editing = null }, onDelete = { deleting = st; editing = null }) }
    deleting?.let { st -> ConfirmDialog(stringResource(R.string.delete_student_confirm, "${st.firstName} ${st.lastName}"), onConfirm = { vm.deleteStudent(st.id) }, onDismiss = { deleting = null }) }
    ErrorDialog(vm)
}

@Composable
private fun AddStudentSheet(vm: SchoolViewModel, classes: List<ClassDto>, busy: Boolean, onDismiss: () -> Unit) {
    val c = MaterialTheme.smart
    val context = LocalContext.current
    var first by remember { mutableStateOf("") }
    var last by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("+992 ") }
    var parent by remember { mutableStateOf("") }
    var classId by remember { mutableStateOf(classes.firstOrNull()?.id) }
    var photo by remember { mutableStateOf<Uri?>(null) }
    val captureUri = remember { FileProvider.getUriForFile(context, "${context.packageName}.files", File(context.cacheDir, "student_capture.jpg")) }
    val take = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok -> if (ok) photo = captureUri }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri -> if (uri != null) photo = uri }
    Sheet(onDismiss) {
        Text(stringResource(R.string.add_student), style = MaterialTheme.typography.titleLarge); VSpace(14.dp)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.weight(1f)) { AppTextField(first, { first = it }, stringResource(R.string.first_name)) }
            Box(Modifier.weight(1f)) { AppTextField(last, { last = it }, stringResource(R.string.last_name)) }
        }
        VSpace(10.dp)
        ClassPicker(classes, classId) { classId = it }
        VSpace(10.dp)
        AppTextField(phone, { phone = it }, stringResource(R.string.parent_phone), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone)); VSpace(10.dp)
        AppTextField(parent, { parent = it }, stringResource(R.string.parent_name)); VSpace(14.dp)
        Text(stringResource(R.string.student_photo), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
        Text(stringResource(R.string.student_photo_hint), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary); VSpace(8.dp)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            GhostButton(stringResource(R.string.scan_take_photo), onClick = { take.launch(captureUri) })
            GhostButton(stringResource(R.string.scan_pick_photo), onClick = { pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) })
            if (photo != null) Chip(stringResource(R.string.photo_taken), c.mint, c.mintSoft)
        }
        VSpace(18.dp)
        PrimaryButton(
            stringResource(R.string.create),
            onClick = { vm.createStudent(context, first.trim(), last.trim(), classId!!, phone, parent.trim(), photo!!); onDismiss() },
            enabled = first.isNotBlank() && last.isNotBlank() && classId != null && phone.filter(Char::isDigit).length >= 9 && photo != null, loading = busy,
        )
    }
}

/** Everything about one pupil, editable: name, class, parent, login, a fresh face photo. */
@Composable
private fun EditStudentSheet(st: StudentDto, vm: SchoolViewModel, classes: List<ClassDto>, busy: Boolean, onDismiss: () -> Unit, onDelete: () -> Unit) {
    val c = MaterialTheme.smart
    val context = LocalContext.current
    var first by remember(st) { mutableStateOf(st.firstName) }
    var last by remember(st) { mutableStateOf(st.lastName) }
    var phone by remember(st) { mutableStateOf(st.parentPhone.orEmpty()) }
    var classId by remember(st) { mutableStateOf(st.classId ?: classes.firstOrNull()?.id) }
    var username by remember(st) { mutableStateOf(st.username.orEmpty()) }
    var password by remember(st) { mutableStateOf("") }
    var photo by remember(st) { mutableStateOf<Uri?>(null) }
    val captureUri = remember { FileProvider.getUriForFile(context, "${context.packageName}.files", File(context.cacheDir, "student_capture.jpg")) }
    val take = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok -> if (ok) photo = captureUri }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri -> if (uri != null) photo = uri }
    Sheet(onDismiss) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ChildAvatar(Child(st.id, st.firstName, st.lastName, st.className), 48.dp)
            HSpace(12.dp)
            Column(Modifier.weight(1f)) {
                Text("${st.lastName} ${st.firstName}", style = MaterialTheme.typography.titleLarge, color = c.ink)
                st.className?.let { Text(stringResource(R.string.class_label, it), style = MaterialTheme.typography.bodySmall, color = c.inkSecondary) }
            }
            Box(Modifier.size(40.dp).clip(CircleShape).clickable(onClick = onDelete), contentAlignment = Alignment.Center) { Icon(Icons.Outlined.Delete, stringResource(R.string.delete), tint = c.rose) }
        }
        VSpace(16.dp)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.weight(1f)) { AppTextField(first, { first = it }, stringResource(R.string.first_name)) }
            Box(Modifier.weight(1f)) { AppTextField(last, { last = it }, stringResource(R.string.last_name)) }
        }
        VSpace(10.dp)
        ClassPicker(classes, classId) { classId = it }
        VSpace(10.dp)
        AppTextField(phone, { phone = it }, stringResource(R.string.parent_phone), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone))
        VSpace(14.dp)
        Text(stringResource(R.string.student_login_title), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
        Text(stringResource(R.string.student_login_hint_dir), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary)
        VSpace(8.dp)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.weight(1f)) { AppTextField(username, { username = it }, stringResource(R.string.username_label), keyboardOptions = KeyboardOptions(autoCorrectEnabled = false)) }
            Box(Modifier.weight(1f)) { AppTextField(password, { password = it }, stringResource(R.string.setup_password)) }
        }
        VSpace(14.dp)
        Text(stringResource(R.string.student_photo), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
        VSpace(6.dp)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            GhostButton(stringResource(R.string.scan_take_photo), onClick = { take.launch(captureUri) })
            GhostButton(stringResource(R.string.scan_pick_photo), onClick = { pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) })
            if (photo != null) Chip(stringResource(R.string.photo_taken), c.mint, c.mintSoft)
        }
        VSpace(18.dp)
        PrimaryButton(
            stringResource(R.string.save),
            onClick = {
                vm.updateStudent(context, st.id, StudentEdit(first.trim(), last.trim(), classId!!, phone.trim().ifBlank { null }, username.trim().ifBlank { null }, password.ifBlank { null }), photo)
                onDismiss()
            },
            enabled = first.isNotBlank() && last.isNotBlank() && classId != null, loading = busy,
        )
    }
}

// ================================================================== Teachers

@Composable
fun TeachersScreen(vm: SchoolViewModel, onBack: () -> Unit) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    val c = MaterialTheme.smart
    var adding by remember { mutableStateOf(false) }
    var assigning by remember { mutableStateOf<TeacherDto?>(null) }
    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.teachers_title), onBack = onBack, trailing = { RoundIconButton(Icons.Rounded.Add, stringResource(R.string.add_teacher), { adding = true }) })
            when (val s = ui.teachers) {
                UiState.Loading -> SkeletonList(rows = 4, rowHeight = 68.dp)
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = vm::loadAll)
                is UiState.Ready -> if (s.data.isEmpty()) EmptyState(R.drawable.ill_notebook, stringResource(R.string.no_teachers)) else {
                    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(s.data, key = { it.id }) { t ->
                            SoftCard(contentPadding = PaddingValues(12.dp), elevation = 4.dp) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    ChildAvatar(Child(t.id, t.fullName.substringBefore(' '), t.fullName.substringAfter(' ', ""), null), 40.dp); HSpace(12.dp)
                                    Column(Modifier.weight(1f)) {
                                        Text(t.fullName, style = MaterialTheme.typography.titleSmall, color = c.ink)
                                        Text(listOfNotNull(t.subject, t.email).joinToString(" · "), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary, maxLines = 1)
                                    }
                                    GhostButton(stringResource(R.string.assign_class), onClick = { assigning = t })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (adding) {
        var name by remember { mutableStateOf("") }; var email by remember { mutableStateOf("") }; var pw by remember { mutableStateOf("") }; var subject by remember { mutableStateOf("") }
        Sheet(onDismiss = { adding = false }) {
            Text(stringResource(R.string.add_teacher), style = MaterialTheme.typography.titleLarge); VSpace(14.dp)
            AppTextField(name, { name = it }, stringResource(R.string.teacher_name)); VSpace(10.dp)
            AppTextField(subject, { subject = it }, stringResource(R.string.teacher_subject)); VSpace(10.dp)
            AppTextField(email, { email = it }, stringResource(R.string.email_label), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)); VSpace(10.dp)
            AppTextField(pw, { pw = it }, stringResource(R.string.password_label)); VSpace(4.dp)
            Text(stringResource(R.string.teacher_password_hint), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary); VSpace(16.dp)
            PrimaryButton(stringResource(R.string.create), onClick = { vm.createTeacher(name.trim(), email.trim(), pw, subject.trim()); adding = false }, enabled = name.isNotBlank() && email.contains('@') && pw.length >= 4, loading = ui.busy)
        }
    }
    assigning?.let { t ->
        var classId by remember(t) { mutableStateOf(ui.classList.firstOrNull()?.id) }
        var subject by remember(t) { mutableStateOf(t.subject.orEmpty()) }
        Sheet(onDismiss = { assigning = null }) {
            Text(t.fullName, style = MaterialTheme.typography.titleLarge); Text(stringResource(R.string.assign_class), style = MaterialTheme.typography.bodySmall, color = c.inkSecondary); VSpace(14.dp)
            ClassPicker(ui.classList, classId) { classId = it }; VSpace(10.dp)
            AppTextField(subject, { subject = it }, stringResource(R.string.teacher_subject)); VSpace(16.dp)
            PrimaryButton(stringResource(R.string.save), onClick = { vm.assignClass(t.id, classId!!, subject.trim()); assigning = null }, enabled = classId != null && subject.isNotBlank(), loading = ui.busy)
        }
    }
    ErrorDialog(vm)
}

// =================================================================== Cameras

@Composable
fun CamerasScreen(vm: SchoolViewModel, liveVm: LiveViewModel, onBack: () -> Unit) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    val live by liveVm.ui.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { liveVm.refresh() }
    val c = MaterialTheme.smart
    var editing by remember { mutableStateOf<CameraDto?>(null) }
    var adding by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf<CameraDto?>(null) }
    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.cameras_title), onBack = onBack, trailing = { RoundIconButton(Icons.Rounded.Add, stringResource(R.string.add_camera), { adding = true }) })
            when (val s = ui.cameras) {
                UiState.Loading -> SkeletonList(rows = 3, rowHeight = 72.dp)
                is UiState.Failed -> ErrorState(s.error.message(), onRetry = vm::loadAll)
                is UiState.Ready -> if (s.data.isEmpty()) EmptyState(R.drawable.ill_door_check, stringResource(R.string.no_cameras)) else {
                    val statuses = live.cameras.associateBy { it.cameraId }
                    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 6.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(s.data, key = { it.id }) { cam ->
                            val st = statuses[cam.id]
                            val (label, color) = if (st != null) cameraLook(st) else (if (cam.isActive) stringResource(R.string.cam_offline) else stringResource(R.string.cam_off)) to c.inkTertiary
                            SoftCard(contentPadding = PaddingValues(12.dp), elevation = 4.dp, onClick = { editing = cam }) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(Modifier.size(42.dp).clip(RoundedCornerShape(Radius.sm)).background(color.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Videocam, null, tint = color) }
                                    HSpace(12.dp)
                                    Column(Modifier.weight(1f)) {
                                        Text(cam.name, style = MaterialTheme.typography.titleSmall, color = c.ink)
                                        Text(listOfNotNull(ui.classList.firstOrNull { it.id == cam.classId }?.name ?: stringResource(R.string.cam_unassigned), cam.ipAddress).joinToString(" · "), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary, maxLines = 1)
                                    }
                                    Chip(label, color, color.copy(alpha = 0.15f))
                                    HSpace(4.dp)
                                    Box(Modifier.size(34.dp).clip(CircleShape).clickable { deleting = cam }, contentAlignment = Alignment.Center) { Icon(Icons.Outlined.Delete, null, tint = c.inkTertiary, modifier = Modifier.size(18.dp)) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if (adding || editing != null) {
        val cam = editing
        var name by remember(cam) { mutableStateOf(cam?.name.orEmpty()) }
        var ip by remember(cam) { mutableStateOf(cam?.ipAddress.orEmpty()) }
        var rtsp by remember(cam) { mutableStateOf(cam?.rtspUrl.orEmpty()) }
        var classId by remember(cam) { mutableStateOf(cam?.classId) }
        var active by remember(cam) { mutableStateOf(cam?.isActive ?: true) }
        Sheet(onDismiss = { adding = false; editing = null }) {
            Text(if (cam == null) stringResource(R.string.add_camera) else stringResource(R.string.edit_camera), style = MaterialTheme.typography.titleLarge); VSpace(14.dp)
            AppTextField(name, { name = it }, stringResource(R.string.camera_name)); VSpace(10.dp)
            AppTextField(ip, { ip = it }, stringResource(R.string.camera_ip), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri)); VSpace(10.dp)
            AppTextField(rtsp, { rtsp = it }, stringResource(R.string.camera_rtsp), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri)); VSpace(10.dp)
            Text(stringResource(R.string.camera_class), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary); VSpace(6.dp)
            ClassPicker(ui.classList, classId, allowNone = true) { classId = it }; VSpace(10.dp)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.camera_active), style = MaterialTheme.typography.bodyLarge, color = c.ink, modifier = Modifier.weight(1f))
                Switch(active, { active = it }, colors = SwitchDefaults.colors(checkedTrackColor = c.brand))
            }
            VSpace(14.dp)
            PrimaryButton(
                stringResource(R.string.save),
                onClick = { vm.saveCamera(cam?.id, CameraCreateRequest(classId, name.trim(), ip.trim().ifBlank { null }, rtsp.trim().ifBlank { null }, active)); adding = false; editing = null },
                enabled = name.isNotBlank(), loading = ui.busy,
            )
        }
    }
    deleting?.let { cam -> ConfirmDialog(stringResource(R.string.delete_camera_confirm, cam.name), onConfirm = { vm.deleteCamera(cam.id) }, onDismiss = { deleting = null }) }
    ErrorDialog(vm)
}
