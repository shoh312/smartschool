package tj.cict.smartflow.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * A white app. Surfaces are white on a barely-tinted page; colour is spent
 * on one brand hue and four meanings (arrived / late / absent / info), and
 * the pastel versions of those carry the illustrations.
 */
@Immutable
data class SmartColors(
    val page: Color = Color(0xFFF7F8FC),
    val surface: Color = Color.White,
    val surfaceSoft: Color = Color(0xFFF2F3F9),
    val border: Color = Color(0xFFECEEF5),
    val ink: Color = Color(0xFF14161F),
    val inkSecondary: Color = Color(0xFF636A78),
    val inkTertiary: Color = Color(0xFF9AA1AF),

    val brand: Color = Color(0xFF5B5BD6),
    val brandDeep: Color = Color(0xFF3F3FB8),
    val brandSoft: Color = Color(0xFFE7E7FB),
    val brandTint: Color = Color(0xFFF1F1FD),

    val coral: Color = Color(0xFFFF7A59),
    val coralSoft: Color = Color(0xFFFFE3D9),
    val mint: Color = Color(0xFF2BB673),
    val mintSoft: Color = Color(0xFFD9F5E6),
    val amber: Color = Color(0xFFF5A524),
    val amberSoft: Color = Color(0xFFFFF0D0),
    val sky: Color = Color(0xFF3B9DF2),
    val skySoft: Color = Color(0xFFDCEEFF),
    val rose: Color = Color(0xFFF0506E),
    val roseSoft: Color = Color(0xFFFFE0E6),
)

val LocalSmartColors = staticCompositionLocalOf { SmartColors() }
