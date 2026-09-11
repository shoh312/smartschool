package tj.cict.smartflow.ui.director

import android.app.Activity
import android.content.pm.ActivityInfo
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.rounded.Fullscreen
import androidx.compose.material.icons.rounded.FullscreenExit
import androidx.compose.material.icons.rounded.Videocam
import androidx.compose.material.icons.rounded.VideocamOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.LocalDate
import java.time.LocalTime
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonth
import tj.cict.smartflow.core.util.hhmm
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.core.util.weekdayLong
import tj.cict.smartflow.data.dto.CameraStatusDto
import tj.cict.smartflow.data.dto.LiveStatusDto
import tj.cict.smartflow.domain.AttendanceStatus
import tj.cict.smartflow.domain.Child
import tj.cict.smartflow.ui.components.ActionTile
import tj.cict.smartflow.ui.components.ChildAvatar
import tj.cict.smartflow.ui.components.Chip
import tj.cict.smartflow.ui.components.EmptyState
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.GhostButton
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.Illustration
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.RoundIconButton
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SectionTitle
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.StatusPill
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.components.look
import tj.cict.smartflow.ui.profile.ProfileSheet
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

@Composable
fun DirectorHomeScreen(
    liveVm: LiveViewModel,
    name: String,
    bottomPadding: Dp,
    onSignOut: () -> Unit,
    onVideo: () -> Unit,
    onClasses: () -> Unit,
    onStudents: () -> Unit,
    onTeachers: () -> Unit,
    onCameras: () -> Unit,
    onAnnouncements: () -> Unit,
    onCalendar: () -> Unit,
    onSettings: () -> Unit,
) {
    DisposableEffect(Unit) { liveVm.start(); onDispose { liveVm.stop() } }
    val ui by liveVm.ui.collectAsStateWithLifecycle()
    var profileOpen by remember { mutableStateOf(false) }
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val locale = currentLocale()
    val today = LocalDate.now()
    val c = MaterialTheme.smart

    PullToRefreshBox(isRefreshing = ui.refreshing && ui.rows is UiState.Ready, onRefresh = liveVm::refresh, modifier = Modifier.fillMaxSize()) {
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(top = top + 14.dp, bottom = bottomPadding + 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            item {
                Row(Modifier.padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(greeting(), style = MaterialTheme.typography.bodyMedium, color = c.inkSecondary)
                        Text(name.ifBlank { stringResource(R.string.app_name) }, style = MaterialTheme.typography.headlineMedium, color = c.ink, maxLines = 1)
                    }
                    RoundIconButton(Icons.Outlined.Person, stringResource(R.string.profile_title), onClick = { profileOpen = true })
                }
            }
            item { TodayCard(ui, "${today.weekdayLong(locale)}, ${today.dayMonth(locale)}", Modifier.padding(horizontal = 20.dp)) }
            if (ui.cameras.isNotEmpty()) {
                item { SectionTitle(stringResource(R.string.cameras_title), Modifier.padding(horizontal = 20.dp, vertical = 2.dp), trailing = { GhostButton(stringResource(R.string.action_live_video), onClick = onVideo) }) }
                item {
                    LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        items(ui.cameras, key = { it.cameraId }) { cam -> CameraChip(cam, onClick = onVideo) }
                    }
                }
            }
            item { SectionTitle(stringResource(R.string.home_quick), Modifier.padding(horizontal = 20.dp, vertical = 2.dp)) }
            item {
                val tiles = listOf(
                    Triple(R.drawable.ill_phone_sms, R.string.action_live_video, onVideo),
                    Triple(R.drawable.ill_book, R.string.action_classes, onClasses),
                    Triple(R.drawable.ill_family, R.string.action_students, onStudents),
                    Triple(R.drawable.ill_notebook, R.string.action_teachers, onTeachers),
                    Triple(R.drawable.ill_door_check, R.string.action_cameras, onCameras),
                    Triple(R.drawable.ill_megaphone, R.string.action_announcements, onAnnouncements),
                    Triple(R.drawable.ill_calendar, R.string.action_calendar, onCalendar),
                    Triple(R.drawable.ill_shield, R.string.action_settings, onSettings),
                )
                Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    tiles.chunked(2).forEach { pair ->
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            pair.forEach { (ill, label, action) -> ActionTile(ill, stringResource(label), action, Modifier.weight(1f)) }
                        }
                    }
                }
            }
        }
    }
    if (profileOpen) ProfileSheet(parentName = name, onDismiss = { profileOpen = false }, onSignOut = onSignOut)
}

@Composable
private fun greeting(): String {
    val hour = LocalTime.now().hour
    return stringResource(when { hour < 12 -> R.string.greeting_morning; hour < 18 -> R.string.greeting_afternoon; else -> R.string.greeting_evening })
}

/** Four counts and a stacked bar; the number everyone asks first is "how many are in". */
@Composable
private fun TodayCard(ui: LiveUi, dateLine: String, modifier: Modifier = Modifier) {
    val c = MaterialTheme.smart
    val present = ui.count(AttendanceStatus.PRESENT) + ui.count(AttendanceStatus.LEFT_SCHOOL)
    val late = ui.count(AttendanceStatus.LATE)
    val absent = ui.count(AttendanceStatus.ABSENT)
    val waiting = ui.waiting
    val total = ui.list.size
    Box(modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.xl)).background(Brush.linearGradient(listOf(c.brand, c.brandDeep)))) {
        Illustration(R.drawable.ill_school, Modifier.align(Alignment.TopEnd).size(160.dp))
        Column(Modifier.padding(20.dp)) {
            Text(stringResource(R.string.today_at_school), style = MaterialTheme.typography.labelMedium, color = Color.White.copy(alpha = 0.8f))
            Text(dateLine, style = MaterialTheme.typography.titleLarge, color = Color.White)
            VSpace(44.dp)
            if (ui.rows is UiState.Loading) {
                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(22.dp))
            } else {
                Row(verticalAlignment = Alignment.Bottom) {
                    Text("${present + late}", style = MaterialTheme.typography.displayMedium, color = Color.White)
                    HSpace(8.dp)
                    Text(stringResource(R.string.of_pupils, total), style = MaterialTheme.typography.bodyMedium, color = Color.White.copy(alpha = 0.85f), modifier = Modifier.padding(bottom = 8.dp))
                }
                VSpace(10.dp)
                Row(Modifier.fillMaxWidth().height(10.dp).clip(RoundedCornerShape(5.dp)).background(Color.White.copy(alpha = 0.2f))) {
                    if (present > 0) Box(Modifier.weight(present.toFloat()).fillMaxSize().background(c.mint))
                    if (late > 0) Box(Modifier.weight(late.toFloat()).fillMaxSize().background(c.amber))
                    if (absent > 0) Box(Modifier.weight(absent.toFloat()).fillMaxSize().background(c.rose))
                    if (waiting > 0) Box(Modifier.weight(waiting.toFloat()).fillMaxSize().background(Color.Transparent))
                }
                VSpace(12.dp)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Stat(present, stringResource(R.string.status_present), c.mint, Modifier.weight(1f))
                    Stat(late, stringResource(R.string.late_days), c.amber, Modifier.weight(1f))
                    Stat(absent, stringResource(R.string.absent_days), c.rose, Modifier.weight(1f))
                    Stat(waiting, stringResource(R.string.waiting_short), Color.White.copy(alpha = 0.7f), Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun Stat(n: Int, label: String, color: Color, modifier: Modifier = Modifier) {
    Column(modifier.clip(RoundedCornerShape(Radius.sm)).background(Color.White.copy(alpha = 0.12f)).padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(7.dp).clip(CircleShape).background(color)); HSpace(5.dp)
            Text("$n", style = MaterialTheme.typography.titleLarge, color = Color.White)
        }
        Text(label, style = MaterialTheme.typography.labelSmall, color = Color.White.copy(alpha = 0.8f), maxLines = 1)
    }
}

@Composable
fun CameraChip(cam: CameraStatusDto, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    val (label, color) = cameraLook(cam)
    SoftCard(contentPadding = PaddingValues(12.dp), elevation = 5.dp, onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(36.dp).clip(RoundedCornerShape(10.dp)).background(color.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                Icon(if (cam.connected) Icons.Rounded.Videocam else Icons.Rounded.VideocamOff, null, tint = color, modifier = Modifier.size(20.dp))
            }
            HSpace(10.dp)
            Column {
                Text(cam.cameraName ?: "#${cam.cameraId}", style = MaterialTheme.typography.titleSmall, color = c.ink, maxLines = 1)
                Text(listOfNotNull(cam.className, label).joinToString(" · "), style = MaterialTheme.typography.labelSmall, color = color, maxLines = 1)
            }
        }
    }
}

@Composable
fun cameraLook(cam: CameraStatusDto): Pair<String, Color> {
    val c = MaterialTheme.smart
    fun mmss(s: Int) = "%d:%02d".format(s / 60, s % 60)
    return when {
        cam.phase == "off" -> stringResource(R.string.cam_off) to c.inkTertiary
        !cam.connected -> stringResource(R.string.cam_offline) to c.rose
        cam.rollCall -> stringResource(R.string.cam_roll_call) to c.coral
        cam.detecting -> stringResource(R.string.cam_detecting) to c.mint
        cam.secondsToDetect != null -> stringResource(R.string.cam_waiting, mmss(cam.secondsToDetect)) to c.amber
        cam.className == null -> stringResource(R.string.cam_idle) to c.inkTertiary
        else -> stringResource(R.string.cam_connected) to c.sky
    }
}

// ========================================================= Live attendance

@Composable
fun LiveAttendanceScreen(liveVm: LiveViewModel, bottomPadding: Dp) {
    DisposableEffect(Unit) { liveVm.start(); onDispose { liveVm.stop() } }
    val ui by liveVm.ui.collectAsStateWithLifecycle()
    val c = MaterialTheme.smart
    var filter by remember { mutableStateOf<Int?>(null) }
    val classes = remember(ui.list) { ui.list.mapNotNull { r -> r.classId?.let { it to (r.className ?: "?") } }.distinct().sortedBy { it.second } }

    Column(Modifier.fillMaxSize()) {
        ScreenHeader(stringResource(R.string.live_title), subtitle = ui.updatedAt?.let { stringResource(R.string.live_updated, it.hhmm()) })
        LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            item { FilterPill(stringResource(R.string.live_all), filter == null) { filter = null } }
            items(classes, key = { it.first }) { (id, name) -> FilterPill(name, filter == id) { filter = id } }
        }
        VSpace(8.dp)
        when (val s = ui.rows) {
            UiState.Loading -> SkeletonList(rows = 6, rowHeight = 64.dp)
            is UiState.Failed -> ErrorState(s.error.message(), onRetry = liveVm::refresh)
            is UiState.Ready -> {
                val rows = s.data.filter { filter == null || it.classId == filter }
                if (rows.isEmpty()) { EmptyState(R.drawable.ill_door_check, stringResource(R.string.no_students)); return@Column }
                val grouped = rows.groupBy { it.className ?: "—" }.toSortedMap()
                LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = bottomPadding + 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    grouped.forEach { (cls, list) ->
                        item(key = "h$cls") {
                            val state = list.firstOrNull()?.classLessonState
                            val arrived = list.count { AttendanceStatus.fromApi(it.status).arrived }
                            Row(Modifier.padding(top = 10.dp, bottom = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text(cls, style = MaterialTheme.typography.titleLarge, color = c.ink)
                                HSpace(8.dp)
                                Text("$arrived/${list.size}", style = MaterialTheme.typography.labelMedium, color = c.inkSecondary, modifier = Modifier.weight(1f))
                                when (state) {
                                    "running" -> Chip(stringResource(R.string.lesson_running), c.mint, c.mintSoft)
                                    "upcoming" -> Chip(stringResource(R.string.lesson_upcoming), c.inkTertiary, c.surfaceSoft)
                                    "finished" -> Chip(stringResource(R.string.lesson_finished), c.sky, c.skySoft)
                                }
                            }
                        }
                        items(list.sortedWith(compareBy({ statusOrder(it.status) }, { it.lastName })), key = { it.studentId }) { r -> LiveRow(r) }
                    }
                }
            }
        }
    }
}

private fun statusOrder(s: String) = when (s) { "absent" -> 0; "late" -> 1; "not_detected" -> 2; else -> 3 }

@Composable
private fun FilterPill(text: String, selected: Boolean, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    Box(
        Modifier.clip(RoundedCornerShape(999.dp)).background(if (selected) c.brand else c.surface).border(1.dp, if (selected) c.brand else c.border, RoundedCornerShape(999.dp)).clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
    ) { Text(text, style = MaterialTheme.typography.labelMedium, color = if (selected) Color.White else c.ink) }
}

@Composable
private fun LiveRow(r: LiveStatusDto) {
    val c = MaterialTheme.smart
    val status = AttendanceStatus.fromApi(r.status)
    val upcoming = r.classLessonState == "upcoming" && status == AttendanceStatus.UNKNOWN
    SoftCard(contentPadding = PaddingValues(10.dp), elevation = 4.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ChildAvatar(Child(r.studentId, r.firstName, r.lastName, r.className), 38.dp)
            HSpace(12.dp)
            Column(Modifier.weight(1f)) {
                Text("${r.lastName} ${r.firstName}", style = MaterialTheme.typography.titleSmall, color = c.ink, maxLines = 1)
                (r.timeIn ?: r.lastSeen)?.let { Text(stringResource(R.string.arrived_at, it.hhmm()), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary) }
            }
            if (upcoming) Chip(stringResource(R.string.waiting_short), c.inkTertiary, c.surfaceSoft) else StatusPill(status, compact = true)
        }
    }
}

// ============================================================ Live video

@Composable
fun LiveVideoScreen(onBack: () -> Unit, vm: LiveVideoViewModel = koinViewModel()) {
    LaunchedEffect(Unit) { vm.load() }
    DisposableEffect(Unit) { onDispose { vm.disconnect() } }
    val state by vm.state.collectAsStateWithLifecycle()
    val cameras by vm.cameras.collectAsStateWithLifecycle()
    val selected by vm.selected.collectAsStateWithLifecycle()
    val c = MaterialTheme.smart
    var fullscreen by remember { mutableStateOf(false) }
    val activity = LocalContext.current as? Activity

    // Landscape and no bars while full screen; back to portrait on the way out,
    // including when the screen is left by the system back gesture.
    DisposableEffect(fullscreen) {
        val window = activity?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, it.decorView) }
        if (fullscreen) {
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            controller?.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller?.hide(WindowInsetsCompat.Type.systemBars())
        } else {
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            controller?.show(WindowInsetsCompat.Type.systemBars())
        }
        onDispose {
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            controller?.show(WindowInsetsCompat.Type.systemBars())
        }
    }
    BackHandler(enabled = fullscreen) { fullscreen = false }

    val list = (cameras as? UiState.Ready)?.data.orEmpty()

    if (fullscreen) {
        Box(Modifier.fillMaxSize().background(Color.Black)) {
            VideoSurface(state, onReconnect = vm::reconnect, modifier = Modifier.fillMaxSize())
            Row(Modifier.align(Alignment.TopEnd).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                list.forEach { cam -> if (list.size > 1) FilterPill(cam.name, selected == cam.id) { vm.select(cam.id) } }
                Box(Modifier.size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.2f)).clickable { fullscreen = false }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.FullscreenExit, null, tint = Color.White)
                }
            }
        }
        return
    }

    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.video_title), onBack = onBack)
            LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(list, key = { it.id }) { cam -> FilterPill(cam.name, selected == cam.id) { vm.select(cam.id) } }
            }
            VSpace(12.dp)
            Box(Modifier.padding(horizontal = 20.dp).fillMaxWidth().aspectRatio(16f / 9f).clip(RoundedCornerShape(Radius.lg)).background(Color(0xFF14161F))) {
                VideoSurface(state, onReconnect = vm::reconnect, modifier = Modifier.fillMaxSize(), emptyHint = if (list.isEmpty() && cameras is UiState.Ready) stringResource(R.string.no_cameras) else stringResource(R.string.video_pick_camera))
                if (state is VideoState.Streaming) {
                    Box(Modifier.align(Alignment.BottomEnd).padding(10.dp).size(40.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.45f)).clickable { fullscreen = true }, contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.Fullscreen, stringResource(R.string.video_fullscreen), tint = Color.White)
                    }
                }
            }
            VSpace(12.dp)
            list.firstOrNull { it.id == selected }?.let { cam ->
                Column(Modifier.padding(horizontal = 20.dp)) {
                    Text(cam.name, style = MaterialTheme.typography.titleMedium, color = c.ink)
                    Text(listOfNotNull(cam.ipAddress, cam.rtspUrl).joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary)
                }
            }
        }
    }
}

/** The frame, or whatever stands in for it while there is none. */
@Composable
private fun VideoSurface(state: VideoState, onReconnect: () -> Unit, modifier: Modifier = Modifier, emptyHint: String = "") {
    Box(modifier, contentAlignment = Alignment.Center) {
        when (state) {
            is VideoState.Streaming -> Image(state.frame.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
            VideoState.Connecting -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                CircularProgressIndicator(color = Color.White); VSpace(10.dp)
                Text(stringResource(R.string.video_connecting), color = Color.White.copy(alpha = 0.8f), style = MaterialTheme.typography.bodySmall)
            }
            is VideoState.Failed -> Column(Modifier.clickable(onClick = onReconnect).padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Rounded.VideocamOff, null, tint = Color.White.copy(alpha = 0.7f), modifier = Modifier.size(36.dp)); VSpace(8.dp)
                Text(
                    if (state.reason == "live_video_disabled") stringResource(R.string.video_disabled) else stringResource(R.string.video_lost),
                    color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center,
                )
            }
            is VideoState.Silent -> Column(Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Rounded.Videocam, null, tint = Color.White.copy(alpha = 0.6f), modifier = Modifier.size(36.dp)); VSpace(8.dp)
                Text(stringResource(R.string.video_silent), color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
                state.phase?.let { Text(it, color = Color.White.copy(alpha = 0.6f), style = MaterialTheme.typography.labelSmall) }
            }
            VideoState.Idle -> Text(emptyHint, color = Color.White.copy(alpha = 0.7f))
        }
    }
}
