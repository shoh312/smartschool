package tj.cict.smartflow.ui.assignments

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlin.random.Random
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.util.UiState
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.dayMonthTime
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.data.dto.AssignmentDetailDto
import tj.cict.smartflow.data.dto.AttemptResultDto
import tj.cict.smartflow.data.dto.BlockDto
import tj.cict.smartflow.ui.components.AppTextField
import tj.cict.smartflow.ui.components.Chip
import tj.cict.smartflow.ui.components.ErrorState
import tj.cict.smartflow.ui.components.GhostButton
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.Illustration
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.PrimaryButton
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.TintPanel
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

@Composable
fun AssignmentPlayerScreen(childId: Int, assignmentId: Int, canAnswer: Boolean, onBack: () -> Unit, vm: PlayerViewModel = koinViewModel()) {
    LaunchedEffect(childId, assignmentId) { vm.load(childId, assignmentId) }
    val ui by vm.ui.collectAsStateWithLifecycle()

    PageBackground {
        when (val d = ui.detail) {
            UiState.Loading -> Column(Modifier.fillMaxSize()) { ScreenHeader("", onBack = onBack); SkeletonList(rows = 3) }
            is UiState.Failed -> Column(Modifier.fillMaxSize()) { ScreenHeader("", onBack = onBack); ErrorState(d.error.message(), onRetry = { vm.load(childId, assignmentId) }) }
            is UiState.Ready -> AnimatedContent(
                targetState = ui.phase,
                transitionSpec = { (slideInHorizontally(tween(280)) { it / 3 } + fadeIn()) togetherWith fadeOut(tween(160)) },
                contentKey = { it::class },
                label = "phase",
            ) { phase ->
                when (phase) {
                    Phase.Overview -> Overview(d.data, ui, canAnswer, onBack, vm::start)
                    is Phase.Playing -> Playing(d.data, ui, phase.index, vm, onExit = vm::backToOverview)
                    is Phase.Finished -> Result(d.data, ui, phase.result, onDone = { vm.backToOverview() }, onRetry = vm::start)
                }
            }
        }
    }

    ui.error?.let { err ->
        AlertDialog(
            onDismissRequest = vm::clearError,
            containerColor = MaterialTheme.smart.surface,
            shape = RoundedCornerShape(Radius.lg),
            text = { Text(err.message(), style = MaterialTheme.typography.bodyLarge) },
            confirmButton = { TextButton(onClick = vm::clearError) { Text(stringResource(R.string.done)) } },
        )
    }
}

// ============================================================== Overview

@Composable
private fun Overview(a: AssignmentDetailDto, ui: PlayerUi, canAnswer: Boolean, onBack: () -> Unit, onStart: () -> Unit) {
    val c = MaterialTheme.smart
    val locale = currentLocale()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(Modifier.fillMaxSize()) {
        ScreenHeader(a.subject, onBack = onBack)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            Illustration(R.drawable.ill_clipboard, Modifier.fillMaxWidth(0.6f).align(Alignment.CenterHorizontally))
            SoftCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(a.title, style = MaterialTheme.typography.headlineSmall, color = c.ink, modifier = Modifier.weight(1f))
                    HSpace(8.dp)
                    Chip(
                        if (a.mode == "control") stringResource(R.string.mode_control) else stringResource(R.string.mode_practice),
                        if (a.mode == "control") c.coral else c.sky, if (a.mode == "control") c.coralSoft else c.skySoft,
                    )
                }
                if (!a.description.isNullOrBlank()) {
                    VSpace(8.dp)
                    Text(a.description, style = MaterialTheme.typography.bodyMedium, color = c.inkSecondary)
                }
                VSpace(14.dp)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Fact(stringResource(R.string.assignment_questions, a.questionCount), Modifier.weight(1f))
                    Fact(stringResource(R.string.player_points, a.maxScore), Modifier.weight(1f))
                }
                VSpace(8.dp)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Fact(
                        when {
                            a.attemptsLeft == null -> stringResource(R.string.attempts_unlimited)
                            a.attemptsLeft <= 0 -> stringResource(R.string.no_attempts)
                            else -> stringResource(R.string.attempts_left, a.attemptsLeft)
                        },
                        Modifier.weight(1f),
                    )
                    a.dueAt?.let { Fact(stringResource(R.string.assignment_due, it.dayMonthTime(locale)), Modifier.weight(1f), warn = a.isOverdue) }
                }
                if (!a.teacherName.isNullOrBlank()) {
                    VSpace(10.dp)
                    Text(a.teacherName, style = MaterialTheme.typography.bodySmall, color = c.inkTertiary)
                }
            }
            if (a.submittedAt != null) {
                VSpace(12.dp)
                SoftCard {
                    if (a.scoreVisible && a.score != null) {
                        val pct = a.percent ?: if (a.maxScore > 0) a.score * 100 / a.maxScore else 0
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            ScoreRing(pct, 72.dp)
                            HSpace(16.dp)
                            Column {
                                Text(stringResource(R.string.result_title), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
                                Text(stringResource(R.string.result_score, a.score, a.maxScore), style = MaterialTheme.typography.titleLarge, color = c.ink)
                            }
                        }
                    } else {
                        Text(stringResource(R.string.result_hidden), style = MaterialTheme.typography.bodyMedium, color = c.inkSecondary)
                    }
                }
            }
            VSpace(16.dp)
        }
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = bottom + 16.dp)) {
            when {
                !canAnswer -> Text(stringResource(R.string.parent_view_only), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                a.isOverdue && a.attemptId == null -> Text(stringResource(R.string.overdue_cannot), style = MaterialTheme.typography.bodyMedium, color = c.rose, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                a.attemptId == null && a.attemptsLeft != null && a.attemptsLeft <= 0 -> Text(stringResource(R.string.no_attempts), style = MaterialTheme.typography.bodyMedium, color = c.inkSecondary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                else -> PrimaryButton(
                    if (a.attemptId != null) stringResource(R.string.assignment_continue) else stringResource(R.string.assignment_start),
                    onClick = onStart, loading = ui.busy, enabled = a.blocks.isNotEmpty(),
                )
            }
        }
    }
}

@Composable
private fun Fact(text: String, modifier: Modifier = Modifier, warn: Boolean = false) {
    val c = MaterialTheme.smart
    Box(modifier.clip(RoundedCornerShape(Radius.sm)).background(if (warn) c.roseSoft else c.surfaceSoft).padding(horizontal = 10.dp, vertical = 8.dp)) {
        Text(text, style = MaterialTheme.typography.labelMedium, color = if (warn) c.rose else c.inkSecondary, maxLines = 2)
    }
}

// =============================================================== Playing

@Composable
private fun Playing(a: AssignmentDetailDto, ui: PlayerUi, index: Int, vm: PlayerViewModel, onExit: () -> Unit) {
    val c = MaterialTheme.smart
    val blocks = a.blocks
    val block = blocks.getOrNull(index) ?: return
    val questions = ui.questions
    val qIndex = questions.indexOfFirst { it.id == block.id }
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    var confirm by remember { mutableStateOf(false) }
    val practice = a.mode != "control"
    val progress by animateFloatAsState(if (questions.isEmpty()) 0f else (questions.size - ui.unanswered) / questions.size.toFloat(), tween(400), label = "progress")

    Column(Modifier.fillMaxSize().imePadding()) {
        // Slim header: close, progress bar, counter.
        Row(Modifier.padding(top = top + 10.dp, start = 12.dp, end = 20.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(40.dp).clip(CircleShape).clickable(onClick = onExit), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Close, null, tint = c.inkSecondary)
            }
            HSpace(6.dp)
            Box(Modifier.weight(1f).height(8.dp).clip(RoundedCornerShape(4.dp)).background(c.surfaceSoft)) {
                Box(Modifier.fillMaxWidth(progress).fillMaxSize().background(c.brand))
            }
            HSpace(12.dp)
            Text("${questions.size - ui.unanswered}/${questions.size}", style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
        }

        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp)) {
            Text(
                if (block.blockType == "question") stringResource(R.string.player_question_n, qIndex + 1, questions.size) else stringResource(R.string.player_page),
                style = MaterialTheme.typography.labelMedium, color = c.brandDeep,
            )
            VSpace(6.dp)
            SoftCard {
                Text(block.body, style = if (block.blockType == "question") MaterialTheme.typography.titleLarge else MaterialTheme.typography.bodyLarge, color = c.ink)
                if (block.blockType == "question" && block.points > 1) {
                    VSpace(6.dp)
                    Text(stringResource(R.string.player_points, block.points), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
                }
            }
            if (block.blockType == "question") {
                VSpace(14.dp)
                val current = ui.answers[block.id]
                AnswerWidget(block, current, onAnswer = { vm.answer(block, it) })
                val fb = ui.feedback[block.id]
                AnimatedVisibility(practice && fb != null, enter = fadeIn(), exit = fadeOut()) {
                    val ok = fb == true
                    TintPanel(if (ok) c.mintSoft else c.roseSoft, Modifier.padding(top = 12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(if (ok) Icons.Rounded.Check else Icons.Rounded.Close, null, tint = if (ok) c.mint else c.rose)
                            HSpace(8.dp)
                            Text(if (ok) stringResource(R.string.answer_correct) else stringResource(R.string.answer_wrong), style = MaterialTheme.typography.titleSmall, color = if (ok) c.mint else c.rose)
                        }
                    }
                }
            }
            VSpace(16.dp)
        }

        Row(Modifier.padding(horizontal = 20.dp).padding(bottom = bottom + 14.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            if (index > 0) {
                Box(Modifier.weight(1f)) { GhostButton(stringResource(R.string.assignment_prev), onClick = { vm.goTo(index - 1) }, modifier = Modifier.fillMaxWidth().height(56.dp)) }
            }
            Box(Modifier.weight(2f)) {
                if (index < blocks.lastIndex) {
                    PrimaryButton(stringResource(R.string.assignment_next), onClick = { vm.goTo(index + 1) })
                } else {
                    PrimaryButton(stringResource(R.string.assignment_submit), onClick = { confirm = true }, loading = ui.busy)
                }
            }
        }
    }

    if (confirm) {
        AlertDialog(
            onDismissRequest = { confirm = false },
            containerColor = c.surface,
            shape = RoundedCornerShape(Radius.lg),
            title = { Text(stringResource(R.string.submit_confirm), style = MaterialTheme.typography.titleLarge) },
            text = { if (ui.unanswered > 0) Text(stringResource(R.string.unanswered_n, ui.unanswered), color = c.rose) },
            confirmButton = { TextButton(onClick = { confirm = false; vm.submit() }) { Text(stringResource(R.string.assignment_submit), style = MaterialTheme.typography.labelLarge) } },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text(stringResource(R.string.cancel), style = MaterialTheme.typography.labelLarge) } },
        )
    }
}

// ======================================================== Answer widgets

@Composable
private fun AnswerWidget(block: BlockDto, current: JsonElement?, onAnswer: (JsonElement) -> Unit) {
    when (block.questionType) {
        "single" -> SingleChoice(block, current, onAnswer)
        "truefalse" -> TrueFalse(current, onAnswer)
        "fill" -> FillIn(current, onAnswer)
        "match" -> Matching(block, current, onAnswer)
        "order" -> Ordering(block, current, onAnswer)
    }
}

private fun BlockDto.stringOptions(): List<String> =
    runCatching { options?.jsonArray?.map { it.jsonPrimitive.content } }.getOrNull().orEmpty()

@Composable
private fun OptionRow(text: String, selected: Boolean, onClick: () -> Unit, leading: (@Composable () -> Unit)? = null) {
    val c = MaterialTheme.smart
    val shape = RoundedCornerShape(Radius.md)
    Row(
        Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp)
            .clip(shape)
            .background(if (selected) c.brandTint else c.surface)
            .border(1.5.dp, if (selected) c.brand else c.border, shape)
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        leading?.invoke()
        Text(text, style = MaterialTheme.typography.bodyLarge, color = if (selected) c.brandDeep else c.ink, modifier = Modifier.weight(1f))
        if (selected) Icon(Icons.Rounded.Check, null, tint = c.brand)
    }
}

@Composable
private fun SingleChoice(block: BlockDto, current: JsonElement?, onAnswer: (JsonElement) -> Unit) {
    val chosen = current?.jsonObject?.get("index")?.jsonPrimitive?.intOrNull
    val c = MaterialTheme.smart
    Column {
        block.stringOptions().forEachIndexed { i, text ->
            OptionRow(text, chosen == i, onClick = { onAnswer(buildJsonObject { put("index", JsonPrimitive(i)) }) }) {
                Box(Modifier.size(28.dp).clip(CircleShape).background(if (chosen == i) c.brand else c.surfaceSoft), contentAlignment = Alignment.Center) {
                    Text(('A' + i).toString(), style = MaterialTheme.typography.labelMedium, color = if (chosen == i) Color.White else c.inkSecondary)
                }
                HSpace(12.dp)
            }
        }
    }
}

@Composable
private fun TrueFalse(current: JsonElement?, onAnswer: (JsonElement) -> Unit) {
    val chosen = current?.jsonObject?.get("value")?.jsonPrimitive?.booleanOrNull
    val c = MaterialTheme.smart
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        listOf(true to R.string.tf_true, false to R.string.tf_false).forEach { (v, label) ->
            val selected = chosen == v
            val color = if (v) c.mint else c.rose
            val shape = RoundedCornerShape(Radius.md)
            Box(
                Modifier
                    .weight(1f)
                    .height(64.dp)
                    .clip(shape)
                    .background(if (selected) color else c.surface)
                    .border(1.5.dp, if (selected) color else c.border, shape)
                    .clickable { onAnswer(buildJsonObject { put("value", JsonPrimitive(v)) }) },
                contentAlignment = Alignment.Center,
            ) {
                Text(stringResource(label), style = MaterialTheme.typography.titleMedium, color = if (selected) Color.White else c.ink)
            }
        }
    }
}

@Composable
private fun FillIn(current: JsonElement?, onAnswer: (JsonElement) -> Unit) {
    val saved = current?.jsonObject?.get("text")?.jsonPrimitive?.contentOrNull.orEmpty()
    var text by remember(saved) { mutableStateOf(saved) }
    val focus = LocalFocusManager.current
    fun commit() { if (text.isNotBlank() && text != saved) onAnswer(buildJsonObject { put("text", JsonPrimitive(text.trim())) }) }
    Column {
        AppTextField(
            value = text, onValueChange = { text = it }, label = stringResource(R.string.fill_hint),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { focus.clearFocus(); commit() }),
        )
        VSpace(8.dp)
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) {
            GhostButton(stringResource(R.string.done), onClick = { focus.clearFocus(); commit() }, enabled = text.isNotBlank() && text.trim() != saved)
        }
    }
}

/** Pairs kept by original index; the right column is shown shuffled. */
@Composable
private fun Matching(block: BlockDto, current: JsonElement?, onAnswer: (JsonElement) -> Unit) {
    val c = MaterialTheme.smart
    val left = runCatching { block.options!!.jsonObject["left"]!!.jsonArray.map { it.jsonPrimitive.content } }.getOrDefault(emptyList())
    val right = runCatching { block.options!!.jsonObject["right"]!!.jsonArray.map { it.jsonPrimitive.content } }.getOrDefault(emptyList())
    val order = remember(block.id) { right.indices.shuffled(Random(block.id)) }
    val pairs = remember(current) {
        runCatching { current!!.jsonObject["pairs"]!!.jsonArray.associate { it.jsonArray[0].jsonPrimitive.intOrNull!! to it.jsonArray[1].jsonPrimitive.intOrNull!! } }.getOrDefault(emptyMap())
    }
    var picked by remember(block.id) { mutableStateOf<Int?>(null) }
    val palette = listOf(c.brand, c.coral, c.mint, c.amber, c.sky, c.rose)
    fun send(map: Map<Int, Int>) = onAnswer(buildJsonObject {
        put("pairs", buildJsonArray { map.forEach { (l, r) -> add(buildJsonArray { add(JsonPrimitive(l)); add(JsonPrimitive(r)) }) } })
    })
    Column {
        Text(stringResource(R.string.match_hint), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary)
        VSpace(8.dp)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.weight(1f)) {
                left.forEachIndexed { li, text ->
                    val paired = pairs[li]
                    val color = paired?.let { palette[li % palette.size] }
                    MatchCell(text, active = picked == li, color = color, onClick = {
                        if (paired != null) send(pairs - li) else picked = if (picked == li) null else li
                    })
                }
            }
            Column(Modifier.weight(1f)) {
                order.forEach { ri ->
                    val li = pairs.entries.firstOrNull { it.value == ri }?.key
                    val color = li?.let { palette[it % palette.size] }
                    MatchCell(right[ri], active = false, color = color, onClick = {
                        val p = picked ?: return@MatchCell
                        val without = pairs.filterValues { it != ri }
                        send(without + (p to ri)); picked = null
                    })
                }
            }
        }
    }
}

@Composable
private fun MatchCell(text: String, active: Boolean, color: Color?, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    val shape = RoundedCornerShape(Radius.sm)
    Box(
        Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp)
            .clip(shape)
            .background(color?.copy(alpha = 0.15f) ?: if (active) c.brandTint else c.surface)
            .border(1.5.dp, color ?: if (active) c.brand else c.border, shape)
            .clickable(onClick = onClick)
            .padding(12.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        Text(text, style = MaterialTheme.typography.bodyMedium, color = c.ink)
    }
}

/** Shown shuffled; the answer is the original indices in the pupil's order. */
@Composable
private fun Ordering(block: BlockDto, current: JsonElement?, onAnswer: (JsonElement) -> Unit) {
    val c = MaterialTheme.smart
    val items = block.stringOptions()
    val saved = runCatching { current!!.jsonObject["order"]!!.jsonArray.map { it.jsonPrimitive.intOrNull!! } }.getOrNull()
    var order by remember(block.id) { mutableStateOf(saved?.takeIf { it.size == items.size } ?: items.indices.shuffled(Random(block.id))) }
    fun move(from: Int, to: Int) {
        if (to !in order.indices) return
        order = order.toMutableList().also { val t = it[from]; it[from] = it[to]; it[to] = t }
        onAnswer(buildJsonObject { put("order", buildJsonArray { order.forEach { add(JsonPrimitive(it)) } }) })
    }
    Column {
        Text(stringResource(R.string.order_hint), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary)
        VSpace(8.dp)
        order.forEachIndexed { pos, orig ->
            val shape = RoundedCornerShape(Radius.sm)
            Row(
                Modifier.fillMaxWidth().padding(bottom = 8.dp).clip(shape).background(c.surface).border(1.dp, c.border, shape).padding(start = 12.dp, end = 4.dp, top = 6.dp, bottom = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.size(26.dp).clip(CircleShape).background(c.brandSoft), contentAlignment = Alignment.Center) {
                    Text("${pos + 1}", style = MaterialTheme.typography.labelSmall, color = c.brandDeep)
                }
                HSpace(10.dp)
                Text(items[orig], style = MaterialTheme.typography.bodyMedium, color = c.ink, modifier = Modifier.weight(1f))
                Box(Modifier.size(36.dp).clip(CircleShape).clickable(enabled = pos > 0) { move(pos, pos - 1) }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.ArrowUpward, null, tint = if (pos > 0) c.brand else c.border, modifier = Modifier.size(20.dp))
                }
                Box(Modifier.size(36.dp).clip(CircleShape).clickable(enabled = pos < order.lastIndex) { move(pos, pos + 1) }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.ArrowDownward, null, tint = if (pos < order.lastIndex) c.brand else c.border, modifier = Modifier.size(20.dp))
                }
            }
        }
        if (saved == null) {
            // Nothing sent yet: the shuffled order on screen is an answer too.
            LaunchedEffect(block.id) { onAnswer(buildJsonObject { put("order", buildJsonArray { order.forEach { add(JsonPrimitive(it)) } }) }) }
        }
    }
}

// ================================================================ Result

@Composable
private fun Result(a: AssignmentDetailDto, ui: PlayerUi, r: AttemptResultDto, onDone: () -> Unit, onRetry: () -> Unit) {
    val c = MaterialTheme.smart
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val pct = r.percent ?: if (r.score != null && r.maxScore != null && r.maxScore > 0) r.score * 100 / r.maxScore else null
    Column(Modifier.fillMaxSize().padding(top = top)) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            VSpace(12.dp)
            Illustration(R.drawable.ill_trophy, Modifier.fillMaxWidth(0.62f))
            if (r.scoreVisible && pct != null) {
                ScoreRing(pct, 150.dp)
                VSpace(12.dp)
                Text(
                    when { pct >= 85 -> stringResource(R.string.result_great); pct >= 60 -> stringResource(R.string.result_good); else -> stringResource(R.string.result_keep) },
                    style = MaterialTheme.typography.headlineMedium, color = c.ink,
                )
                Text(stringResource(R.string.result_score, r.score ?: 0, r.maxScore ?: 0), style = MaterialTheme.typography.bodyLarge, color = c.inkSecondary)
                r.perQuestion?.let { per ->
                    VSpace(18.dp)
                    SoftCard(Modifier.fillMaxWidth()) {
                        ui.questions.forEachIndexed { i, q ->
                            val ok = per[q.id.toString()] == true
                            Row(Modifier.padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                                Box(Modifier.size(26.dp).clip(CircleShape).background(if (ok) c.mintSoft else c.roseSoft), contentAlignment = Alignment.Center) {
                                    Icon(if (ok) Icons.Rounded.Check else Icons.Rounded.Close, null, tint = if (ok) c.mint else c.rose, modifier = Modifier.size(16.dp))
                                }
                                HSpace(10.dp)
                                Text("${i + 1}. ${q.body}", style = MaterialTheme.typography.bodyMedium, color = c.ink, maxLines = 2, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            } else {
                VSpace(8.dp)
                Text(stringResource(R.string.result_title), style = MaterialTheme.typography.headlineMedium, color = c.ink)
                VSpace(6.dp)
                Text(stringResource(R.string.result_hidden), style = MaterialTheme.typography.bodyLarge, color = c.inkSecondary, textAlign = TextAlign.Center)
            }
            VSpace(16.dp)
        }
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = bottom + 14.dp)) {
            PrimaryButton(stringResource(R.string.done), onClick = onDone)
            val canRetry = !a.isOverdue && (a.attemptsLeft == null || a.attemptsLeft > 0)
            if (canRetry) {
                VSpace(4.dp)
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { GhostButton(stringResource(R.string.assignment_retry), onClick = onRetry) }
            }
        }
    }
}

@Composable
private fun ScoreRing(pct: Int, size: androidx.compose.ui.unit.Dp) {
    val c = MaterialTheme.smart
    val color = when { pct >= 80 -> c.mint; pct >= 60 -> c.amber; else -> c.rose }
    val soft = when { pct >= 80 -> c.mintSoft; pct >= 60 -> c.amberSoft; else -> c.roseSoft }
    val sweep by animateFloatAsState(pct / 100f, tween(900), label = "ring")
    Box(Modifier.size(size), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val stroke = (size.value * 0.1f).dp.toPx()
            val inset = stroke / 2
            drawArc(soft, -90f, 360f, false, Offset(inset, inset), Size(this.size.width - stroke, this.size.height - stroke), style = Stroke(stroke, cap = StrokeCap.Round))
            drawArc(color, -90f, 360f * sweep, false, Offset(inset, inset), Size(this.size.width - stroke, this.size.height - stroke), style = Stroke(stroke, cap = StrokeCap.Round))
        }
        Text("$pct%", style = if (size > 100.dp) MaterialTheme.typography.displayMedium else MaterialTheme.typography.titleLarge, color = color)
    }
}
