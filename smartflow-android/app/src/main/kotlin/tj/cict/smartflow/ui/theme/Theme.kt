package tj.cict.smartflow.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

object Radius {
    val sm = 12.dp
    val md = 18.dp
    val lg = 24.dp
    val xl = 32.dp
}

private val SmartShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(Radius.sm),
    medium = RoundedCornerShape(Radius.md),
    large = RoundedCornerShape(Radius.lg),
    extraLarge = RoundedCornerShape(Radius.xl),
)

/** `MaterialTheme.smart` -- the app's own palette, next to Material's. */
val MaterialTheme.smart: SmartColors
    @Composable @ReadOnlyComposable get() = LocalSmartColors.current

@Composable
fun SmartFlowTheme(content: @Composable () -> Unit) {
    val c = SmartColors()
    // Material's scheme is filled from the same palette so the few stock
    // widgets we use (text fields, ripples, sheets) match the custom ones.
    val scheme = lightColorScheme(
        primary = c.brand,
        onPrimary = Color.White,
        primaryContainer = c.brandSoft,
        onPrimaryContainer = c.brandDeep,
        secondary = c.coral,
        onSecondary = Color.White,
        secondaryContainer = c.coralSoft,
        background = c.page,
        onBackground = c.ink,
        surface = c.surface,
        onSurface = c.ink,
        surfaceVariant = c.surfaceSoft,
        onSurfaceVariant = c.inkSecondary,
        outline = c.border,
        outlineVariant = c.border,
        error = c.rose,
        onError = Color.White,
        errorContainer = c.roseSoft,
        surfaceContainer = c.surface,
        surfaceContainerLow = c.surface,
        surfaceContainerHigh = c.surfaceSoft,
        surfaceContainerHighest = c.surfaceSoft,
    )
    CompositionLocalProvider(LocalSmartColors provides c) {
        MaterialTheme(colorScheme = scheme, typography = SmartTypography, shapes = SmartShapes, content = content)
    }
}
