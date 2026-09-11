package tj.cict.smartflow.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

/**
 * The page: off-white with two pastel washes in the corners. Every screen
 * sits on this, so the whiteness reads as a choice rather than an absence.
 */
@Composable
fun PageBackground(
    modifier: Modifier = Modifier,
    tint: Color = MaterialTheme.smart.brandSoft,
    accent: Color = MaterialTheme.smart.coralSoft,
    content: @Composable () -> Unit,
) {
    val page = MaterialTheme.smart.page
    Box(modifier.fillMaxSize().background(page)) {
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(
                brush = Brush.radialGradient(listOf(tint.copy(alpha = 0.9f), page.copy(alpha = 0f))),
                radius = size.width * 0.55f,
                center = Offset(size.width * 0.05f, -size.height * 0.02f),
            )
            drawCircle(
                brush = Brush.radialGradient(listOf(accent.copy(alpha = 0.7f), page.copy(alpha = 0f))),
                radius = size.width * 0.45f,
                center = Offset(size.width * 1.02f, size.height * 0.18f),
            )
        }
        content()
    }
}

/** A white card with a soft, brand-tinted shadow instead of a grey one. */
@Composable
fun SoftCard(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(Radius.lg),
    color: Color = MaterialTheme.smart.surface,
    elevation: Dp = 10.dp,
    contentPadding: PaddingValues = PaddingValues(18.dp),
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shadowTint = MaterialTheme.smart.brandDeep
    val border = MaterialTheme.smart.border
    Column(
        modifier
            .shadow(
                elevation = elevation,
                shape = shape,
                ambientColor = shadowTint.copy(alpha = 0.10f),
                spotColor = shadowTint.copy(alpha = 0.14f),
            )
            .clip(shape)
            .background(color)
            .border(1.dp, border.copy(alpha = 0.7f), shape)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(contentPadding),
        content = content,
    )
}

/** A flat pastel panel -- no shadow, for things nested inside a card. */
@Composable
fun TintPanel(
    color: Color,
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(Radius.md),
    contentPadding: PaddingValues = PaddingValues(14.dp),
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier
            .clip(shape)
            .background(color)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(contentPadding),
        content = content,
    )
}
