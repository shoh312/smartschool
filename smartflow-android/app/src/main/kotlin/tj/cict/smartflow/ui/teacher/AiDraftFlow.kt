package tj.cict.smartflow.ui.teacher

import android.content.Context
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Lightbulb
import androidx.compose.material.icons.rounded.Notes
import androidx.compose.material.icons.rounded.PhotoCamera
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import java.io.File
import kotlin.math.cos
import kotlin.math.sin
import kotlinx.coroutines.delay
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.ui.components.AppTextField
import tj.cict.smartflow.ui.components.Chip
import tj.cict.smartflow.ui.components.GhostButton
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.PrimaryButton
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

enum class AiSource { TOPIC, PHOTO, TEXT }

/**
 * The whole AI drafting flow, full screen: pick where the material comes
 * from, fill that one thing in, watch it being made. Lives inside the
 * editor so the draft lands straight in the same view-model.
 */
@Composable
fun AiDraftFlow(
    generating: Boolean,
    onCancel: () -> Unit,
    onGenerate: (Context, String, String, String, Uri?, Int, Int, List<String>, String, String) -> Unit,
) {
    var source by remember { mutableStateOf<AiSource?>(null) }
    BackHandler(enabled = !generating) { if (source == null) onCancel() else source = null }

    AnimatedContent(
        targetState = when { generating -> 2; source == null -> 0; else -> 1 },
        transitionSpec = { (slideInVertically(tween(320)) { it / 6 } + fadeIn(tween(320))) togetherWith fadeOut(tween(180)) },
        label = "ai",
    ) { step ->
        when (step) {
            0 -> SourcePicker(onBack = onCancel, onPick = { source = it })
            1 -> SourceForm(source!!, onBack = { source = null }, onGenerate = onGenerate)
            else -> GeneratingScreen()
        }
    }
}

// ------------------------------------------------------------ step 1

@Composable
private fun SourcePicker(onBack: () -> Unit, onPick: (AiSource) -> Unit) {
    val c = MaterialTheme.smart
    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.ai_draft), subtitle = stringResource(R.string.ai_how), onBack = onBack)
            Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SourceCard(Icons.Rounded.Lightbulb, c.brand, c.brandSoft, stringResource(R.string.ai_src_topic), stringResource(R.string.ai_src_topic_hint)) { onPick(AiSource.TOPIC) }
                SourceCard(Icons.Rounded.PhotoCamera, c.coral, c.coralSoft, stringResource(R.string.ai_src_photo), stringResource(R.string.ai_src_photo_hint)) { onPick(AiSource.PHOTO) }
                SourceCard(Icons.Rounded.Notes, c.mint, c.mintSoft, stringResource(R.string.ai_src_text), stringResource(R.string.ai_src_text_hint)) { onPick(AiSource.TEXT) }
            }
        }
    }
}

@Composable
private fun SourceCard(icon: ImageVector, color: Color, soft: Color, title: String, hint: String, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    SoftCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp), onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(56.dp).clip(RoundedCornerShape(Radius.md)).background(soft), contentAlignment = Alignment.Center) { Icon(icon, null, tint = color, modifier = Modifier.size(28.dp)) }
            HSpace(14.dp)
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium, color = c.ink)
                Text(hint, style = MaterialTheme.typography.bodySmall, color = c.inkSecondary)
            }
        }
    }
}

// ------------------------------------------------------------ step 2

private val kinds = listOf("single" to R.string.q_single, "truefalse" to R.string.q_truefalse, "fill" to R.string.q_fill, "match" to R.string.q_match, "order" to R.string.q_order)

@Composable
private fun SourceForm(source: AiSource, onBack: () -> Unit, onGenerate: (Context, String, String, String, Uri?, Int, Int, List<String>, String, String) -> Unit) {
    val c = MaterialTheme.smart
    val context = LocalContext.current
    val locale = currentLocale()
    var kind by remember { mutableStateOf("lesson") }
    var topic by remember { mutableStateOf("") }
    var text by remember { mutableStateOf("") }
    var photo by remember { mutableStateOf<Uri?>(null) }
    var questions by remember { mutableStateOf(8) }
    var difficulty by remember { mutableStateOf("medium") }
    var types by remember { mutableStateOf(setOf("single", "truefalse")) }
    val captureUri = remember { FileProvider.getUriForFile(context, "${context.packageName}.files", File(context.cacheDir, "ai_capture.jpg")) }
    val take = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok -> if (ok) photo = captureUri }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri -> if (uri != null) photo = uri }
    val language = when (locale.language) { "ru" -> "русский"; "en" -> "english"; else -> "tojik (kirill)" }
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val ready = when (source) { AiSource.TOPIC -> topic.isNotBlank(); AiSource.PHOTO -> photo != null; AiSource.TEXT -> text.isNotBlank() }
    val title = when (source) { AiSource.TOPIC -> R.string.ai_src_topic; AiSource.PHOTO -> R.string.ai_src_photo; AiSource.TEXT -> R.string.ai_src_text }

    PageBackground {
        Column(Modifier.fillMaxSize().imePadding()) {
            ScreenHeader(stringResource(title), onBack = onBack)
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
                when (source) {
                    AiSource.TOPIC -> AppTextField(topic, { topic = it }, stringResource(R.string.ai_topic))
                    AiSource.TEXT -> AppTextField(text, { text = it }, stringResource(R.string.ai_source_text), singleLine = false)
                    AiSource.PHOTO -> Column {
                        Text(stringResource(R.string.ai_src_photo_hint), style = MaterialTheme.typography.bodyMedium, color = c.inkSecondary); VSpace(10.dp)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            GhostButton(stringResource(R.string.scan_take_photo), onClick = { take.launch(captureUri) })
                            GhostButton(stringResource(R.string.scan_pick_photo), onClick = { pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) })
                            if (photo != null) Chip(stringResource(R.string.photo_taken), c.mint, c.mintSoft)
                        }
                        VSpace(8.dp)
                        AppTextField(topic, { topic = it }, stringResource(R.string.ai_topic_optional))
                    }
                }
                VSpace(16.dp)
                Label(stringResource(R.string.ai_kind))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Pill(stringResource(R.string.ai_kind_lesson), kind == "lesson") { kind = "lesson" }
                    Pill(stringResource(R.string.ai_kind_test), kind == "test") { kind = "test" }
                }
                VSpace(14.dp)
                Label(stringResource(R.string.ai_questions))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { listOf(5, 8, 10, 15).forEach { n -> Pill("$n", questions == n) { questions = n } } }
                VSpace(14.dp)
                Label(stringResource(R.string.ai_types))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(kinds) { (k, label) -> Pill(stringResource(label), k in types) { types = if (k in types && types.size > 1) types - k else types + k } }
                }
                VSpace(14.dp)
                Label(stringResource(R.string.ai_difficulty))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Pill(stringResource(R.string.diff_easy), difficulty == "easy") { difficulty = "easy" }
                    Pill(stringResource(R.string.diff_medium), difficulty == "medium") { difficulty = "medium" }
                    Pill(stringResource(R.string.diff_hard), difficulty == "hard") { difficulty = "hard" }
                }
                VSpace(16.dp)
            }
            Box(Modifier.padding(horizontal = 20.dp).padding(bottom = bottom + 16.dp)) {
                PrimaryButton(
                    stringResource(R.string.ai_generate),
                    onClick = { onGenerate(context, kind, topic, text, photo, questions, if (kind == "test") 0 else 2, types.toList(), difficulty, language) },
                    enabled = ready,
                )
            }
        }
    }
}

@Composable
private fun Label(text: String) {
    Text(text, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.smart.inkSecondary)
    VSpace(6.dp)
}

@Composable
private fun Pill(text: String, selected: Boolean, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    Box(
        Modifier.clip(RoundedCornerShape(999.dp)).background(if (selected) c.brand else c.surfaceSoft).border(1.dp, if (selected) c.brand else c.border, RoundedCornerShape(999.dp)).clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 8.dp),
    ) { Text(text, style = MaterialTheme.typography.labelMedium, color = if (selected) Color.White else c.ink) }
}

// ------------------------------------------------------------ step 3

/** Something visibly alive while the model works: orbiting dots, a breathing core, rotating status lines. */
@Composable
private fun GeneratingScreen() {
    val c = MaterialTheme.smart
    val t = rememberInfiniteTransition(label = "gen")
    val angle by t.animateFloat(0f, 360f, infiniteRepeatable(tween(2400, easing = LinearEasing)), label = "angle")
    val breathe by t.animateFloat(0.92f, 1.08f, infiniteRepeatable(tween(1100), RepeatMode.Reverse), label = "breathe")
    val sweep by t.animateFloat(0f, 1f, infiniteRepeatable(tween(1600, easing = LinearEasing)), label = "sweep")
    val steps = listOf(R.string.ai_step_reading, R.string.ai_step_writing, R.string.ai_step_checking, R.string.ai_step_polishing)
    var step by remember { mutableStateOf(0) }
    LaunchedEffect(Unit) { while (true) { delay(2600); step = (step + 1) % steps.size } }
    val palette = listOf(c.brand, c.coral, c.mint, c.amber, c.sky)

    PageBackground(tint = c.brandSoft, accent = c.amberSoft) {
        Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Box(Modifier.size(220.dp), contentAlignment = Alignment.Center) {
                Canvas(Modifier.fillMaxSize()) {
                    val r = size.minDimension / 2
                    // soft halo
                    drawCircle(Brush.radialGradient(listOf(c.brand.copy(alpha = 0.18f), Color.Transparent)), radius = r)
                    // orbit ring
                    drawCircle(c.brand.copy(alpha = 0.15f), radius = r * 0.72f, style = androidx.compose.ui.graphics.drawscope.Stroke(2.dp.toPx()))
                    // five dots on the orbit, staggered
                    palette.forEachIndexed { i, col ->
                        val a = Math.toRadians((angle + i * 72).toDouble())
                        val p = Offset(center.x + r * 0.72f * cos(a).toFloat(), center.y + r * 0.72f * sin(a).toFloat())
                        drawCircle(col, radius = (6 + (i % 3) * 2).dp.toPx(), center = p)
                    }
                }
                Box(Modifier.size(92.dp).scale(breathe).clip(CircleShape).background(Brush.linearGradient(listOf(c.brand, c.brandDeep))), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.AutoAwesome, null, tint = Color.White, modifier = Modifier.size(44.dp))
                }
            }
            VSpace(28.dp)
            Text(stringResource(R.string.ai_generating_title), style = MaterialTheme.typography.headlineMedium, color = c.ink, textAlign = TextAlign.Center)
            VSpace(10.dp)
            AnimatedContent(step, transitionSpec = { fadeIn(tween(400)) togetherWith fadeOut(tween(300)) }, label = "step") { s ->
                Text(stringResource(steps[s]), style = MaterialTheme.typography.bodyLarge, color = c.inkSecondary, textAlign = TextAlign.Center)
            }
            VSpace(28.dp)
            // indeterminate bar: a bright segment sweeping along a soft track
            Box(Modifier.fillMaxWidth(0.7f).height(6.dp).clip(RoundedCornerShape(3.dp)).background(c.brandSoft)) {
                Canvas(Modifier.fillMaxSize()) {
                    val w = size.width * 0.35f
                    val x = -w + (size.width + w) * sweep
                    drawRoundRect(Brush.horizontalGradient(listOf(Color.Transparent, c.brand, Color.Transparent)), topLeft = Offset(x, 0f), size = androidx.compose.ui.geometry.Size(w, size.height))
                }
            }
            VSpace(18.dp)
            Text(stringResource(R.string.ai_generating_hint), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary, textAlign = TextAlign.Center)
        }
    }
}
