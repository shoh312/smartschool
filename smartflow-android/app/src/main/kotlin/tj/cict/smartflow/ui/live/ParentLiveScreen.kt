package tj.cict.smartflow.ui.live

import android.app.Activity
import android.content.pm.ActivityInfo
import android.graphics.BitmapFactory
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Fullscreen
import androidx.compose.material.icons.rounded.FullscreenExit
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.BuildConfig
import tj.cict.smartflow.R
import tj.cict.smartflow.core.session.SessionStore
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.director.VideoState
import tj.cict.smartflow.ui.director.VideoSurface
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

/**
 * A parent watching their child's lesson. The socket goes to the public
 * server (`/parent/live`), which checks the child is theirs and tunnels to
 * the school; the school only ever shows the camera of the class whose
 * lesson is running now, so outside a lesson there is nothing to watch.
 */
class ParentLiveViewModel(private val session: SessionStore, private val client: OkHttpClient) : ViewModel() {
    private val _state = MutableStateFlow<VideoState>(VideoState.Idle)
    val state: StateFlow<VideoState> = _state.asStateFlow()
    private var socket: WebSocket? = null
    private var silence: Job? = null
    private var childId = 0

    fun connect(childId: Int) {
        this.childId = childId
        disconnect()
        viewModelScope.launch {
            val s = session.current() ?: run { _state.value = VideoState.Failed("closed"); return@launch }
            _state.value = VideoState.Connecting
            silence?.cancel()
            silence = viewModelScope.launch {
                delay(8_000)
                if (_state.value is VideoState.Connecting) _state.value = VideoState.Silent(null)
            }
            val url = BuildConfig.PUBLIC_SERVER_URL.replaceFirst("http", "ws") + "parent/live?student_id=$childId&token=${s.token}"
            socket = client.newWebSocket(
                Request.Builder().url(url).build(),
                object : WebSocketListener() {
                    override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                        val bmp = BitmapFactory.decodeByteArray(bytes.toByteArray(), 0, bytes.size) ?: return
                        silence?.cancel()
                        _state.value = VideoState.Streaming(bmp)
                    }
                    override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                        silence?.cancel()
                        _state.value = VideoState.Failed(reason.ifBlank { "closed" })
                    }
                    override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                        silence?.cancel()
                        _state.value = VideoState.Failed(reason.ifBlank { "closed" })
                        webSocket.close(1000, null)
                    }
                    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                        silence?.cancel()
                        _state.value = VideoState.Failed("closed")
                    }
                },
            )
        }
    }

    fun reconnect() = connect(childId)

    fun disconnect() {
        silence?.cancel()
        socket?.close(1000, null)
        socket = null
        if (_state.value !is VideoState.Failed) _state.value = VideoState.Idle
    }

    override fun onCleared() { disconnect() }
}

@Composable
fun ParentLiveScreen(childId: Int, childrenVm: ChildrenViewModel, onBack: () -> Unit, vm: ParentLiveViewModel = koinViewModel()) {
    LaunchedEffect(childId) { vm.connect(childId) }
    DisposableEffect(Unit) { onDispose { vm.disconnect() } }
    val state by vm.state.collectAsStateWithLifecycle()
    val children by childrenVm.ui.collectAsStateWithLifecycle()
    val child = children.child(childId)
    val c = MaterialTheme.smart
    var fullscreen by remember { mutableStateOf(false) }
    val activity = LocalContext.current as? Activity

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

    val reasonText: String? = (state as? VideoState.Failed)?.reason?.let {
        when (it) {
            "no_lesson" -> stringResource(R.string.live_no_lesson)
            "school_offline" -> stringResource(R.string.live_school_offline)
            "live_video_disabled" -> stringResource(R.string.video_disabled)
            "forbidden" -> stringResource(R.string.live_forbidden)
            else -> null
        }
    }

    if (fullscreen) {
        Box(Modifier.fillMaxSize().background(Color.Black)) {
            VideoSurface(state, onReconnect = vm::reconnect, modifier = Modifier.fillMaxSize())
            Box(Modifier.align(Alignment.TopEnd).padding(12.dp).size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.2f)).clickable { fullscreen = false }, contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.FullscreenExit, null, tint = Color.White)
            }
        }
        return
    }

    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.live_lesson_title), subtitle = child?.fullName, onBack = onBack)
            Box(Modifier.padding(horizontal = 20.dp).fillMaxWidth().aspectRatio(16f / 9f).clip(RoundedCornerShape(Radius.lg)).background(Color(0xFF14161F))) {
                if (reasonText != null) {
                    Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
                        Text(reasonText, color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.bodyMedium, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                    }
                } else {
                    VideoSurface(state, onReconnect = vm::reconnect, modifier = Modifier.fillMaxSize())
                }
                if (state is VideoState.Streaming) {
                    Box(Modifier.align(Alignment.BottomEnd).padding(10.dp).size(40.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.45f)).clickable { fullscreen = true }, contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.Fullscreen, stringResource(R.string.video_fullscreen), tint = Color.White)
                    }
                }
            }
            VSpace(14.dp)
            Box(Modifier.padding(horizontal = 20.dp)) {
                SoftCard(elevation = 4.dp) {
                    Text(stringResource(R.string.live_parent_hint), style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
                }
            }
        }
    }
}
