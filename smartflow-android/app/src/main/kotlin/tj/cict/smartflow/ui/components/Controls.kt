package tj.cict.smartflow.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

/** The one big button. Gradient pill, presses in slightly, shows a spinner. */
@Composable
fun PrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
) {
    val c = MaterialTheme.smart
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.97f else 1f, tween(120), label = "press")
    val active = enabled && !loading
    val shape = RoundedCornerShape(Radius.md)
    Box(
        modifier
            .fillMaxWidth()
            .height(56.dp)
            .scale(scale)
            .shadow(if (active) 14.dp else 0.dp, shape, spotColor = c.brand.copy(alpha = 0.35f), ambientColor = c.brand.copy(alpha = 0.2f))
            .clip(shape)
            .background(
                if (active) Brush.horizontalGradient(listOf(c.brand, c.brandDeep))
                else Brush.horizontalGradient(listOf(c.border, c.border)),
            )
            .clickable(enabled = active, interactionSource = interaction, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        AnimatedContent(loading, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "btn") { busy ->
            if (busy) {
                CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.5.dp)
            } else {
                Text(text, style = MaterialTheme.typography.labelLarge, color = if (active) Color.White else c.inkTertiary)
            }
        }
    }
}

/** Quiet text-only action ("send again", "sign out"). */
@Composable
fun GhostButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true, color: Color = MaterialTheme.smart.brand) {
    Box(
        modifier
            .clip(RoundedCornerShape(Radius.sm))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = MaterialTheme.typography.labelLarge, color = if (enabled) color else MaterialTheme.smart.inkTertiary)
    }
}

@Composable
fun AppTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    leading: ImageVector? = null,
    trailing: (@Composable () -> Unit)? = null,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    isError: Boolean = false,
    singleLine: Boolean = true,
) {
    val c = MaterialTheme.smart
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier.fillMaxWidth(),
        label = { Text(label) },
        leadingIcon = leading?.let { { Icon(it, contentDescription = null) } },
        trailingIcon = trailing,
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        visualTransformation = visualTransformation,
        isError = isError,
        singleLine = singleLine,
        shape = RoundedCornerShape(Radius.md),
        textStyle = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
        colors = OutlinedTextFieldDefaults.colors(
            focusedContainerColor = c.surface,
            unfocusedContainerColor = c.surface,
            errorContainerColor = c.surface,
            focusedBorderColor = c.brand,
            unfocusedBorderColor = c.border,
            errorBorderColor = c.rose,
            focusedLabelColor = c.brand,
            unfocusedLabelColor = c.inkTertiary,
            focusedLeadingIconColor = c.brand,
            unfocusedLeadingIconColor = c.inkTertiary,
            cursorColor = c.brand,
        ),
    )
}

/** Small round icon button used in top bars. */
@Composable
fun RoundIconButton(icon: ImageVector, contentDescription: String?, onClick: () -> Unit, modifier: Modifier = Modifier, tint: Color = MaterialTheme.smart.ink) {
    val c = MaterialTheme.smart
    Box(
        modifier
            .size(44.dp)
            .shadow(6.dp, CircleShape, spotColor = c.brandDeep.copy(alpha = 0.12f), ambientColor = c.brandDeep.copy(alpha = 0.08f))
            .clip(CircleShape)
            .background(c.surface)
            .border(1.dp, c.border, CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription, tint = tint, modifier = Modifier.size(22.dp))
    }
}

/** Pill selector -- quarters, "all", months. */
@Composable
fun SegmentRow(modifier: Modifier = Modifier, content: @Composable RowScope.() -> Unit) {
    Row(
        modifier
            .clip(RoundedCornerShape(Radius.md))
            .background(MaterialTheme.smart.surfaceSoft)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        content = content,
    )
}

@Composable
fun RowScope.Segment(text: String, selected: Boolean, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    Box(
        Modifier
            .weight(1f)
            .clip(RoundedCornerShape(Radius.sm))
            .then(if (selected) Modifier.shadow(4.dp, RoundedCornerShape(Radius.sm), spotColor = c.brandDeep.copy(alpha = 0.15f)).background(c.surface) else Modifier)
            .clickable(onClick = onClick)
            .padding(vertical = 9.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text,
            style = MaterialTheme.typography.labelMedium,
            color = if (selected) c.brandDeep else c.inkSecondary,
        )
    }
}
