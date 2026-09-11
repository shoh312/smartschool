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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.util.currentLocale
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.data.dto.BlockInDto
import tj.cict.smartflow.data.repo.TeacherRepository
import tj.cict.smartflow.ui.components.AppTextField
import tj.cict.smartflow.ui.components.Chip
import tj.cict.smartflow.ui.components.GhostButton
import tj.cict.smartflow.ui.components.HSpace
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.PrimaryButton
import tj.cict.smartflow.ui.components.ScreenHeader
import tj.cict.smartflow.ui.components.SkeletonList
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

// ------------------------------------------------------------- model

/**
 * A block the way the editor holds it: plain lists and indices, converted
 * to the server's JSON shapes only on the way out. The server keeps the
 * same shapes in material_grading.py on both boxes.
 */
data class EditBlock(
    val kind: String,                       // "page" or a question type
    val body: String = "",
    val points: Int = 1,
    val options: List<String> = emptyList(),   // single / order items
    val correctIndex: Int = 0,                 // single
    val correctBool: Boolean = true,           // truefalse
    val answers: List<String> = emptyList(),   // fill
    val left: List<String> = emptyList(),      // match
    val right: List<String> = emptyList(),
) {
    val isQuestion: Boolean get() = kind != "page"

    val valid: Boolean get() = body.isNotBlank() && when (kind) {
        "page" -> true
        "single" -> options.count { it.isNotBlank() } >= 2 && correctIndex in options.indices
        "truefalse" -> true
        "fill" -> answers.any { it.isNotBlank() }
        "match" -> left.size >= 2 && left.size == right.size && left.all { it.isNotBlank() } && right.all { it.isNotBlank() }
        "order" -> options.count { it.isNotBlank() } >= 2
        else -> false
    }

    fun toDto(): BlockInDto {
        fun arr(items: List<String>) = buildJsonArray { items.forEach { add(JsonPrimitive(it.trim())) } }
        return when (kind) {
            "page" -> BlockInDto("page", body.trim(), null, null, null, 0)
            "single" -> BlockInDto("question", body.trim(), "single", arr(options), buildJsonObject { put("index", JsonPrimitive(correctIndex)) }, points)
            "truefalse" -> BlockInDto("question", body.trim(), "truefalse", null, buildJsonObject { put("value", JsonPrimitive(correctBool)) }, points)
            "fill" -> BlockInDto("question", body.trim(), "fill", null, buildJsonObject { put("answers", arr(answers.filter { it.isNotBlank() })) }, points)
            "match" -> BlockInDto(
                "question", body.trim(), "match", buildJsonObject { put("left", arr(left)); put("right", arr(right)) },
                buildJsonObject { put("pairs", buildJsonArray { left.indices.forEach { i -> add(buildJsonArray { add(JsonPrimitive(i)); add(JsonPrimitive(i)) }) } }) }, points,
            )
            else -> BlockInDto("question", body.trim(), "order", arr(options), buildJsonObject { put("order", buildJsonArray { options.indices.forEach { add(JsonPrimitive(it)) } }) }, points)
        }
    }

    companion object {
        fun from(d: BlockInDto): EditBlock {
            fun strings(e: JsonElement?): List<String> = runCatching { e!!.jsonArray.map { it.jsonPrimitive.content } }.getOrDefault(emptyList())
            if (d.blockType == "page") return EditBlock("page", d.body, 0)
            val c = d.correct?.let { runCatching { it.jsonObject }.getOrNull() }
            return when (d.questionType) {
                "single" -> EditBlock("single", d.body, d.points, options = strings(d.options), correctIndex = c?.get("index")?.jsonPrimitive?.intOrNull ?: 0)
                "truefalse" -> EditBlock("truefalse", d.body, d.points, correctBool = c?.get("value")?.jsonPrimitive?.booleanOrNull ?: true)
                "fill" -> EditBlock("fill", d.body, d.points, answers = strings(c?.get("answers")))
                "match" -> {
                    val o = d.options?.let { runCatching { it.jsonObject }.getOrNull() }
                    val left = strings(o?.get("left")); val right = strings(o?.get("right"))
                    // Pairs are stored as index pairs; re-order the right side so row i matches row i.
                    val pairs = runCatching { c!!["pairs"]!!.jsonArray.map { it.jsonArray[0].jsonPrimitive.intOrNull!! to it.jsonArray[1].jsonPrimitive.intOrNull!! } }.getOrDefault(emptyList())
                    val aligned = if (pairs.size == left.size) left.indices.map { li -> right.getOrElse(pairs.firstOrNull { it.first == li }?.second ?: li) { "" } } else right
                    EditBlock("match", d.body, d.points, left = left, right = aligned)
                }
                "order" -> {
                    val items = strings(d.options)
                    val order = runCatching { c!!["order"]!!.jsonArray.map { it.jsonPrimitive.intOrNull!! } }.getOrDefault(items.indices.toList())
                    EditBlock("order", d.body, d.points, options = order.mapNotNull { items.getOrNull(it) }.ifEmpty { items })
                }
                else -> EditBlock("page", d.body, 0)
            }
        }
    }
}

data class EditorUi(
    val loading: Boolean = false,
    val title: String = "",
    val description: String = "",
    val blocks: List<EditBlock> = emptyList(),
    val saving: Boolean = false,
    val generating: Boolean = false,
    val saved: Boolean = false,
    val dropped: Int? = null,
    val error: ApiError? = null,
)

class MaterialEditorViewModel(private val repo: TeacherRepository) : ViewModel() {
    private val _ui = MutableStateFlow(EditorUi())
    val ui: StateFlow<EditorUi> = _ui.asStateFlow()
    private var materialId: Int? = null
    private var loaded = false

    fun open(id: Int?) {
        if (loaded) return
        loaded = true
        materialId = id
        if (id == null) return
        _ui.update { it.copy(loading = true) }
        viewModelScope.launch {
            when (val r = repo.material(id)) {
                is ApiResult.Ok -> _ui.update { it.copy(loading = false, title = r.value.title, description = r.value.description.orEmpty(), blocks = r.value.blocks.sortedBy { b -> b.position }.map(EditBlock::from)) }
                is ApiResult.Err -> _ui.update { it.copy(loading = false, error = r.error) }
            }
        }
    }

    fun setTitle(v: String) = _ui.update { it.copy(title = v) }
    fun setDescription(v: String) = _ui.update { it.copy(description = v) }
    fun add(block: EditBlock) = _ui.update { it.copy(blocks = it.blocks + block) }
    fun replace(index: Int, block: EditBlock) = _ui.update { it.copy(blocks = it.blocks.toMutableList().also { l -> l[index] = block }) }
    fun remove(index: Int) = _ui.update { it.copy(blocks = it.blocks.filterIndexed { i, _ -> i != index }) }
    fun move(index: Int, delta: Int) = _ui.update { s ->
        val to = index + delta
        if (to !in s.blocks.indices) s else s.copy(blocks = s.blocks.toMutableList().also { l -> val t = l[index]; l[index] = l[to]; l[to] = t })
    }

    fun save() {
        val s = _ui.value
        if (s.saving || s.title.isBlank() || s.blocks.isEmpty() || s.blocks.any { !it.valid }) return
        _ui.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.saveMaterial(materialId, s.title.trim(), s.description.trim().ifBlank { null }, s.blocks.map { it.toDto() })) {
                is ApiResult.Ok -> { materialId = r.value.id; _ui.update { it.copy(saving = false, saved = true) } }
                is ApiResult.Err -> _ui.update { it.copy(saving = false, error = r.error) }
            }
        }
    }

    fun generate(context: Context, kind: String, topic: String, sourceText: String, photo: Uri?, questions: Int, pages: Int, types: List<String>, difficulty: String, language: String) {
        if (_ui.value.generating) return
        _ui.update { it.copy(generating = true, error = null, dropped = null) }
        viewModelScope.launch {
            val file = photo?.let { uri ->
                withContext(Dispatchers.IO) { File(context.cacheDir, "ai_source.jpg").also { out -> context.contentResolver.openInputStream(uri)?.use { it.copyTo(out.outputStream()) } } }
            }
            val mime = photo?.let { context.contentResolver.getType(it) ?: "image/jpeg" }
            when (val r = repo.aiGenerate(kind, topic, sourceText, questions, pages, types, difficulty, language, file, mime)) {
                is ApiResult.Ok -> _ui.update { s ->
                    s.copy(
                        generating = false, dropped = r.value.droppedCount,
                        title = s.title.ifBlank { r.value.title },
                        description = s.description.ifBlank { r.value.description.orEmpty() },
                        blocks = s.blocks + r.value.blocks.sortedBy { it.position }.map(EditBlock::from),
                    )
                }
                is ApiResult.Err -> _ui.update { it.copy(generating = false, error = r.error) }
            }
        }
    }

    fun clearFlags() = _ui.update { it.copy(error = null, dropped = null) }
}

// ------------------------------------------------------------ screen

private val questionKinds = listOf("single" to R.string.q_single, "truefalse" to R.string.q_truefalse, "fill" to R.string.q_fill, "match" to R.string.q_match, "order" to R.string.q_order)

@Composable
fun kindLabel(kind: String): String = when (kind) {
    "page" -> stringResource(R.string.q_page)
    else -> stringResource(questionKinds.firstOrNull { it.first == kind }?.second ?: R.string.q_single)
}

@Composable
fun MaterialEditorScreen(materialId: Int?, onBack: () -> Unit, onSaved: () -> Unit, vm: MaterialEditorViewModel = koinViewModel()) {
    LaunchedEffect(materialId) { vm.open(materialId) }
    val ui by vm.ui.collectAsStateWithLifecycle()
    val c = MaterialTheme.smart
    var editing by remember { mutableStateOf<Int?>(null) }      // index in blocks, or -1 for a new one
    var newKind by remember { mutableStateOf<String?>(null) }
    var aiOpen by remember { mutableStateOf(false) }
    LaunchedEffect(ui.saved) { if (ui.saved) onSaved() }
    // Must sit above the early return below: while the AI flow is showing, the
    // editor body is not composed, so an effect placed there would never fire
    // and the flow would fall back to its form once generation ended.
    LaunchedEffect(ui.dropped, ui.error) { if (ui.dropped != null || ui.error != null) aiOpen = false }

    if (aiOpen) {
        AiDraftFlow(
            generating = ui.generating,
            onCancel = { aiOpen = false },
            onGenerate = { ctx, kind, topic, text, photo, q, p, types, diff, lang -> vm.generate(ctx, kind, topic, text, photo, q, p, types, diff, lang) },
        )
        return
    }

    PageBackground {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(if (materialId == null) stringResource(R.string.material_new) else stringResource(R.string.material_edit), onBack = onBack)
            if (ui.loading) { SkeletonList(rows = 4); return@Column }
            LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                item {
                    AppTextField(ui.title, vm::setTitle, stringResource(R.string.material_title))
                    VSpace(8.dp)
                    AppTextField(ui.description, vm::setDescription, stringResource(R.string.material_desc), singleLine = false)
                }
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        ActionPill(stringResource(R.string.add_page), Icons.Rounded.Add, Modifier.weight(1f)) { newKind = "page"; editing = -1 }
                        ActionPill(stringResource(R.string.add_question), Icons.Rounded.Add, Modifier.weight(1f)) { newKind = "single"; editing = -1 }
                        ActionPill(stringResource(R.string.ai_short), Icons.Rounded.AutoAwesome, Modifier.weight(1f), accent = true) { aiOpen = true }
                    }
                }
                itemsIndexed(ui.blocks) { i, b ->
                    BlockCard(i, b, ui.blocks.size, onEdit = { editing = i }, onUp = { vm.move(i, -1) }, onDown = { vm.move(i, 1) }, onDelete = { vm.remove(i) })
                }
                if (ui.blocks.isEmpty()) item { Text(stringResource(R.string.material_empty_hint), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary) }
            }
            Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 20.dp)) {
                val questions = ui.blocks.count { it.isQuestion }
                Text(stringResource(R.string.material_meta, questions, ui.blocks.filter { it.isQuestion }.sumOf { it.points }), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
                VSpace(6.dp)
                PrimaryButton(stringResource(R.string.save), onClick = vm::save, loading = ui.saving, enabled = ui.title.isNotBlank() && ui.blocks.isNotEmpty() && ui.blocks.all { it.valid })
            }
        }
    }

    editing?.let { index ->
        val initial = if (index >= 0) ui.blocks[index] else EditBlock(newKind ?: "single", options = if (newKind == "single" || newKind == "order") listOf("", "") else emptyList(), left = if (newKind == "match") listOf("", "") else emptyList(), right = if (newKind == "match") listOf("", "") else emptyList(), answers = if (newKind == "fill") listOf("") else emptyList())
        BlockSheet(initial, onDismiss = { editing = null }, onSave = { b -> if (index >= 0) vm.replace(index, b) else vm.add(b); editing = null })
    }
    if (ui.error != null || ui.dropped != null) {
        AlertDialog(
            onDismissRequest = vm::clearFlags, containerColor = c.surface, shape = RoundedCornerShape(Radius.lg),
            text = { Text(ui.error?.message() ?: stringResource(R.string.ai_done, ui.dropped ?: 0), style = MaterialTheme.typography.bodyLarge) },
            confirmButton = { TextButton(onClick = vm::clearFlags) { Text(stringResource(R.string.done)) } },
        )
    }
}

/** Three equal buttons in one row: same height, one line each. */
@Composable
private fun ActionPill(text: String, icon: androidx.compose.ui.graphics.vector.ImageVector, modifier: Modifier = Modifier, accent: Boolean = false, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    Row(
        modifier.height(44.dp).clip(RoundedCornerShape(Radius.md)).background(if (accent) c.brand else c.surface).border(1.dp, if (accent) c.brand else c.border, RoundedCornerShape(Radius.md)).clickable(onClick = onClick).padding(horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center,
    ) {
        Icon(icon, null, tint = if (accent) Color.White else c.brand, modifier = Modifier.size(16.dp)); HSpace(6.dp)
        Text(text, style = MaterialTheme.typography.labelMedium, color = if (accent) Color.White else c.ink, maxLines = 1)
    }
}

@Composable
private fun BlockCard(index: Int, b: EditBlock, count: Int, onEdit: () -> Unit, onUp: () -> Unit, onDown: () -> Unit, onDelete: () -> Unit) {
    val c = MaterialTheme.smart
    SoftCard(contentPadding = PaddingValues(12.dp), elevation = 4.dp, onClick = onEdit) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(28.dp).clip(CircleShape).background(if (b.valid) c.brandSoft else c.roseSoft), contentAlignment = Alignment.Center) {
                Text("${index + 1}", style = MaterialTheme.typography.labelSmall, color = if (b.valid) c.brandDeep else c.rose)
            }
            HSpace(10.dp)
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Chip(kindLabel(b.kind), if (b.isQuestion) c.brandDeep else c.inkSecondary, if (b.isQuestion) c.brandSoft else c.surfaceSoft)
                    if (b.isQuestion) { HSpace(6.dp); Text(stringResource(R.string.player_points, b.points), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary) }
                }
                VSpace(4.dp)
                Text(b.body.ifBlank { "…" }, style = MaterialTheme.typography.bodyMedium, color = c.ink, maxLines = 2)
            }
            Column {
                Box(Modifier.size(30.dp).clip(CircleShape).clickable(enabled = index > 0, onClick = onUp), contentAlignment = Alignment.Center) { Icon(Icons.Rounded.ArrowUpward, null, tint = if (index > 0) c.inkSecondary else c.border, modifier = Modifier.size(16.dp)) }
                Box(Modifier.size(30.dp).clip(CircleShape).clickable(enabled = index < count - 1, onClick = onDown), contentAlignment = Alignment.Center) { Icon(Icons.Rounded.ArrowDownward, null, tint = if (index < count - 1) c.inkSecondary else c.border, modifier = Modifier.size(16.dp)) }
            }
            Box(Modifier.size(34.dp).clip(CircleShape).clickable(onClick = onDelete), contentAlignment = Alignment.Center) { Icon(Icons.Outlined.Delete, null, tint = c.inkTertiary, modifier = Modifier.size(18.dp)) }
        }
    }
}

// ------------------------------------------------------- block sheet

@Composable
private fun EditorSheet(onDismiss: () -> Unit, content: @Composable () -> Unit) {
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
private fun BlockSheet(initial: EditBlock, onDismiss: () -> Unit, onSave: (EditBlock) -> Unit) {
    val c = MaterialTheme.smart
    var b by remember(initial) { mutableStateOf(initial) }
    EditorSheet(onDismiss) {
        Text(kindLabel(b.kind), style = MaterialTheme.typography.titleLarge, color = c.ink); VSpace(12.dp)
        if (b.isQuestion) {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(questionKinds) { (k, label) -> Pill(stringResource(label), b.kind == k) { b = b.copy(kind = k, options = if ((k == "single" || k == "order") && b.options.isEmpty()) listOf("", "") else b.options, left = if (k == "match" && b.left.isEmpty()) listOf("", "") else b.left, right = if (k == "match" && b.right.isEmpty()) listOf("", "") else b.right, answers = if (k == "fill" && b.answers.isEmpty()) listOf("") else b.answers) } }
            }
            VSpace(12.dp)
        }
        AppTextField(b.body, { b = b.copy(body = it) }, if (b.isQuestion) stringResource(R.string.q_body) else stringResource(R.string.page_body), singleLine = false)
        VSpace(12.dp)
        when (b.kind) {
            "single" -> ListEditor(stringResource(R.string.q_options), b.options, onChange = { b = b.copy(options = it, correctIndex = b.correctIndex.coerceIn(0, (it.size - 1).coerceAtLeast(0))) }, selected = b.correctIndex, onSelect = { b = b.copy(correctIndex = it) }, selectHint = stringResource(R.string.q_mark_correct))
            "truefalse" -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Pill(stringResource(R.string.tf_true), b.correctBool) { b = b.copy(correctBool = true) }
                Pill(stringResource(R.string.tf_false), !b.correctBool) { b = b.copy(correctBool = false) }
            }
            "fill" -> ListEditor(stringResource(R.string.q_answers), b.answers, onChange = { b = b.copy(answers = it) })
            "match" -> PairEditor(b.left, b.right) { l, r -> b = b.copy(left = l, right = r) }
            "order" -> ListEditor(stringResource(R.string.q_order_items), b.options, onChange = { b = b.copy(options = it) })
        }
        if (b.isQuestion) {
            VSpace(12.dp)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.q_points), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary, modifier = Modifier.weight(1f))
                listOf(1, 2, 3, 5).forEach { p -> HSpace(6.dp); Pill("$p", b.points == p) { b = b.copy(points = p) } }
            }
        }
        VSpace(18.dp)
        PrimaryButton(stringResource(R.string.done), onClick = { onSave(b) }, enabled = b.valid)
    }
}

@Composable
private fun Pill(text: String, selected: Boolean, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    Box(
        Modifier.clip(RoundedCornerShape(999.dp)).background(if (selected) c.brand else c.surfaceSoft).border(1.dp, if (selected) c.brand else c.border, RoundedCornerShape(999.dp)).clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 8.dp),
    ) { Text(text, style = MaterialTheme.typography.labelMedium, color = if (selected) Color.White else c.ink) }
}

/** A list of short strings with add/remove; optionally one row marked as the right one. */
@Composable
private fun ListEditor(title: String, items: List<String>, onChange: (List<String>) -> Unit, selected: Int? = null, onSelect: ((Int) -> Unit)? = null, selectHint: String? = null) {
    val c = MaterialTheme.smart
    Text(title, style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
    selectHint?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = c.inkTertiary) }
    VSpace(6.dp)
    items.forEachIndexed { i, v ->
        Row(Modifier.padding(bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            if (onSelect != null) {
                Box(Modifier.size(28.dp).clip(CircleShape).background(if (selected == i) c.mint else c.surfaceSoft).border(1.dp, if (selected == i) c.mint else c.border, CircleShape).clickable { onSelect(i) }, contentAlignment = Alignment.Center) {
                    if (selected == i) Icon(Icons.Rounded.Check, null, tint = Color.White, modifier = Modifier.size(16.dp))
                }
                HSpace(8.dp)
            }
            Box(Modifier.weight(1f)) { AppTextField(v, { onChange(items.toMutableList().also { l -> l[i] = it }) }, "${i + 1}") }
            Box(Modifier.size(34.dp).clip(CircleShape).clickable(enabled = items.size > 1) { onChange(items.filterIndexed { j, _ -> j != i }) }, contentAlignment = Alignment.Center) { Icon(Icons.Outlined.Delete, null, tint = c.inkTertiary, modifier = Modifier.size(18.dp)) }
        }
    }
    GhostButton(stringResource(R.string.add_item), onClick = { onChange(items + "") })
}

@Composable
private fun PairEditor(left: List<String>, right: List<String>, onChange: (List<String>, List<String>) -> Unit) {
    val c = MaterialTheme.smart
    Text(stringResource(R.string.q_pairs), style = MaterialTheme.typography.labelMedium, color = c.inkSecondary)
    Text(stringResource(R.string.q_pairs_hint), style = MaterialTheme.typography.labelSmall, color = c.inkTertiary)
    VSpace(6.dp)
    left.indices.forEach { i ->
        Row(Modifier.padding(bottom = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Box(Modifier.weight(1f)) { AppTextField(left[i], { onChange(left.toMutableList().also { l -> l[i] = it }, right) }, "A${i + 1}") }
            Text("=", color = c.inkTertiary)
            Box(Modifier.weight(1f)) { AppTextField(right.getOrElse(i) { "" }, { onChange(left, right.toMutableList().also { l -> while (l.size <= i) l += ""; l[i] = it }) }, "B${i + 1}") }
            Box(Modifier.size(30.dp).clip(CircleShape).clickable(enabled = left.size > 2) { onChange(left.filterIndexed { j, _ -> j != i }, right.filterIndexed { j, _ -> j != i }) }, contentAlignment = Alignment.Center) { Icon(Icons.Outlined.Delete, null, tint = c.inkTertiary, modifier = Modifier.size(16.dp)) }
        }
    }
    GhostButton(stringResource(R.string.add_item), onClick = { onChange(left + "", right + "") })
}
