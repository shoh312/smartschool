package tj.cict.smartflow.ui.onboarding

import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.animation.core.animateDpAsState
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
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.os.LocaleListCompat
import kotlinx.coroutines.launch
import tj.cict.smartflow.R
import tj.cict.smartflow.ui.components.GhostButton
import tj.cict.smartflow.ui.components.Illustration
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.PrimaryButton
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

private data class Lang(val tag: String, val name: String, val native: String)

private val languages = listOf(
    Lang("tg", "Tajik", "Тоҷикӣ"),
    Lang("ru", "Russian", "Русский"),
    Lang("en", "English", "English"),
)

/**
 * Three pages on the first launch only: pick a language, then two pages
 * saying what the app is for. Picking a language applies it on the spot, so
 * the next two pages already read in the chosen one.
 */
@Composable
fun OnboardingScreen(onDone: () -> Unit) {
    val c = MaterialTheme.smart
    val pager = rememberPagerState(pageCount = { 3 })
    val scope = rememberCoroutineScope()
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    var chosen by remember { mutableStateOf(AppCompatDelegate.getApplicationLocales()[0]?.language ?: java.util.Locale.getDefault().language) }
    val last = pager.currentPage == 2

    PageBackground {
        Column(Modifier.fillMaxSize().padding(top = top, bottom = bottom)) {
            Box(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp), contentAlignment = Alignment.CenterEnd) {
                if (!last) GhostButton(stringResource(R.string.onb_skip), onClick = onDone, color = c.inkTertiary)
            }
            HorizontalPager(pager, Modifier.weight(1f)) { page ->
                when (page) {
                    0 -> LanguagePage(chosen) { tag ->
                        chosen = tag
                        AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(tag))
                    }
                    1 -> IntroPage(R.drawable.ill_school, stringResource(R.string.onb_two_title), stringResource(R.string.onb_two_body))
                    else -> IntroPage(R.drawable.ill_family, stringResource(R.string.onb_three_title), stringResource(R.string.onb_three_body))
                }
            }
            Row(Modifier.fillMaxWidth().padding(bottom = 18.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                repeat(3) { i ->
                    val w by animateDpAsState(if (i == pager.currentPage) 22.dp else 8.dp, label = "dot")
                    Box(Modifier.padding(horizontal = 3.dp).height(8.dp).width(w).clip(RoundedCornerShape(4.dp)).background(if (i == pager.currentPage) c.brand else c.border))
                }
            }
            Box(Modifier.padding(horizontal = 24.dp).padding(bottom = 20.dp)) {
                PrimaryButton(
                    if (last) stringResource(R.string.onb_start) else stringResource(R.string.assignment_next),
                    onClick = { if (last) onDone() else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) } },
                )
            }
        }
    }
}

@Composable
private fun LanguagePage(chosen: String, onPick: (String) -> Unit) {
    val c = MaterialTheme.smart
    Column(Modifier.fillMaxSize().padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Illustration(R.drawable.ill_book, Modifier.fillMaxWidth(0.7f))
        Text(stringResource(R.string.onb_lang_title), style = MaterialTheme.typography.headlineMedium, color = c.ink, textAlign = TextAlign.Center)
        VSpace(6.dp)
        Text(stringResource(R.string.onb_lang_body), style = MaterialTheme.typography.bodyLarge, color = c.inkSecondary, textAlign = TextAlign.Center)
        VSpace(22.dp)
        languages.forEach { lang ->
            val selected = lang.tag == chosen
            val shape = RoundedCornerShape(Radius.md)
            Row(
                Modifier.fillMaxWidth().padding(bottom = 10.dp).clip(shape).background(if (selected) c.brandTint else c.surface)
                    .border(1.5.dp, if (selected) c.brand else c.border, shape).clickable { onPick(lang.tag) }.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.size(40.dp).clip(CircleShape).background(if (selected) c.brand else c.surfaceSoft), contentAlignment = Alignment.Center) {
                    Text(lang.tag.uppercase(), style = MaterialTheme.typography.labelLarge, color = if (selected) Color.White else c.inkSecondary)
                }
                Column(Modifier.weight(1f).padding(start = 14.dp)) {
                    Text(lang.native, style = MaterialTheme.typography.titleMedium, color = c.ink)
                    Text(lang.name, style = MaterialTheme.typography.bodySmall, color = c.inkTertiary)
                }
                if (selected) Icon(Icons.Rounded.Check, null, tint = c.brand)
            }
        }
    }
}

@Composable
private fun IntroPage(illustration: Int, title: String, body: String) {
    val c = MaterialTheme.smart
    Column(Modifier.fillMaxSize().padding(horizontal = 28.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Illustration(illustration, Modifier.fillMaxWidth(0.9f))
        VSpace(12.dp)
        Text(title, style = MaterialTheme.typography.headlineMedium, color = c.ink, textAlign = TextAlign.Center)
        VSpace(10.dp)
        Text(body, style = MaterialTheme.typography.bodyLarge, color = c.inkSecondary, textAlign = TextAlign.Center)
    }
}
