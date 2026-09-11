package tj.cict.smartflow.ui.components

import androidx.annotation.DrawableRes
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import tj.cict.smartflow.R
import tj.cict.smartflow.domain.AttendanceStatus
import tj.cict.smartflow.domain.Child
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

@Composable
fun Illustration(@DrawableRes res: Int, modifier: Modifier = Modifier) {
    Image(painterResource(res), contentDescription = null, modifier = modifier)
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier, trailing: (@Composable () -> Unit)? = null) {
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(text, style = MaterialTheme.typography.titleLarge, color = MaterialTheme.smart.ink, modifier = Modifier.weight(1f))
        trailing?.invoke()
    }
}

/** Initials on a soft gradient. No photos reach the public server, on purpose. */
@Composable
fun ChildAvatar(child: Child, size: Dp = 48.dp, modifier: Modifier = Modifier) {
    val c = MaterialTheme.smart
    val palettes = listOf(
        listOf(c.brand, c.brandDeep),
        listOf(c.coral, Color(0xFFE85F3F)),
        listOf(c.sky, Color(0xFF2B7FCB)),
        listOf(c.mint, Color(0xFF1F9A5F)),
        listOf(c.amber, Color(0xFFD98B0F)),
    )
    val colors = palettes[Math.floorMod(child.id, palettes.size)]
    Box(
        modifier.size(size).clip(CircleShape).background(Brush.linearGradient(colors)),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            child.initials,
            color = Color.White,
            fontWeight = FontWeight.ExtraBold,
            fontSize = (size.value * 0.38f).sp,
            style = MaterialTheme.typography.titleMedium,
        )
    }
}

data class StatusLook(val label: String, val color: Color, val soft: Color)

@Composable
fun AttendanceStatus.look(): StatusLook {
    val c = MaterialTheme.smart
    return when (this) {
        AttendanceStatus.PRESENT -> StatusLook(stringResource(R.string.status_present), c.mint, c.mintSoft)
        AttendanceStatus.LATE -> StatusLook(stringResource(R.string.status_late), c.amber, c.amberSoft)
        AttendanceStatus.ABSENT -> StatusLook(stringResource(R.string.status_absent), c.rose, c.roseSoft)
        AttendanceStatus.LEFT_SCHOOL -> StatusLook(stringResource(R.string.status_left), c.sky, c.skySoft)
        AttendanceStatus.UNKNOWN -> StatusLook(stringResource(R.string.status_unknown), c.inkTertiary, c.surfaceSoft)
    }
}

/** Colour plus a word, never colour alone. */
@Composable
fun StatusPill(status: AttendanceStatus, modifier: Modifier = Modifier, compact: Boolean = false) {
    val look = status.look()
    Row(
        modifier
            .clip(RoundedCornerShape(999.dp))
            .background(look.soft)
            .padding(horizontal = if (compact) 8.dp else 12.dp, vertical = if (compact) 4.dp else 7.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(Modifier.size(7.dp).clip(CircleShape).background(look.color))
        Text(look.label, style = if (compact) MaterialTheme.typography.labelSmall else MaterialTheme.typography.labelMedium, color = look.color)
    }
}

@Composable
fun Chip(text: String, color: Color, soft: Color, modifier: Modifier = Modifier) {
    Box(
        modifier.clip(RoundedCornerShape(999.dp)).background(soft).padding(horizontal = 10.dp, vertical = 5.dp),
    ) {
        Text(text, style = MaterialTheme.typography.labelSmall, color = color)
    }
}

@Composable
fun EmptyState(@DrawableRes illustration: Int, title: String, body: String? = null, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxWidth().padding(horizontal = 32.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Illustration(illustration, Modifier.fillMaxWidth(0.72f))
        Spacer(Modifier.height(8.dp))
        Text(title, style = MaterialTheme.typography.titleLarge, color = MaterialTheme.smart.ink, textAlign = TextAlign.Center)
        if (body != null) {
            Spacer(Modifier.height(6.dp))
            Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.smart.inkSecondary, textAlign = TextAlign.Center)
        }
    }
}

@Composable
fun ErrorState(message: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxWidth().padding(horizontal = 32.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Illustration(R.drawable.ill_empty_box, Modifier.fillMaxWidth(0.6f))
        Spacer(Modifier.height(8.dp))
        Text(message, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.smart.inkSecondary, textAlign = TextAlign.Center)
        Spacer(Modifier.height(10.dp))
        GhostButton(stringResource(R.string.retry), onRetry)
    }
}

/** Breathing placeholder blocks while a list loads -- calmer than a spinner. */
@Composable
fun SkeletonList(rows: Int = 4, rowHeight: Dp = 84.dp, modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "skeleton")
    val alpha by transition.animateFloat(
        0.35f, 0.9f,
        infiniteRepeatable(tween(900), RepeatMode.Reverse),
        label = "alpha",
    )
    Column(modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        repeat(rows) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(rowHeight)
                    .alpha(alpha)
                    .clip(RoundedCornerShape(Radius.lg))
                    .background(MaterialTheme.smart.surfaceSoft),
            )
        }
    }
}

@Composable
fun VSpace(height: Dp) = Spacer(Modifier.height(height))

@Composable
fun HSpace(width: Dp) = Spacer(Modifier.width(width))
