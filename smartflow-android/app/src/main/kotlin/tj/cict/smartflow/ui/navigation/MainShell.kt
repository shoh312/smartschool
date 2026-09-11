package tj.cict.smartflow.ui.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoStories
import androidx.compose.material.icons.outlined.Checklist
import androidx.compose.material.icons.outlined.EmojiEvents
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Insights
import androidx.compose.material.icons.outlined.School
import androidx.compose.material.icons.outlined.Sensors
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.rounded.AutoStories
import androidx.compose.material.icons.rounded.Checklist
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Insights
import androidx.compose.material.icons.rounded.School
import androidx.compose.material.icons.rounded.Sensors
import androidx.compose.material.icons.rounded.MenuBook
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.currentBackStackEntryAsState
import tj.cict.smartflow.R
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.theme.smart

data class Tab(val route: Any, val label: Int, val icon: ImageVector, val iconActive: ImageVector)

/** A parent watches: home, diary, rating, and what the school sent them. */
val parentTabs = listOf(
    Tab(HomeRoute, R.string.nav_home, Icons.Outlined.Home, Icons.Rounded.Home),
    Tab(DiaryRoute, R.string.nav_diary, Icons.Outlined.AutoStories, Icons.Rounded.AutoStories),
    Tab(RatingRoute, R.string.nav_rating, Icons.Outlined.EmojiEvents, Icons.Rounded.EmojiEvents),
    Tab(AlertsRoute, R.string.nav_alerts, Icons.Outlined.Notifications, Icons.Rounded.Notifications),
)

/** A teacher: journal and diary are the work, materials the rest. */
val teacherTabs = listOf(
    Tab(HomeRoute, R.string.nav_home, Icons.Outlined.Home, Icons.Rounded.Home),
    Tab(JournalRoute, R.string.nav_journal, Icons.Outlined.MenuBook, Icons.Rounded.MenuBook),
    Tab(DiaryRoute, R.string.nav_diary, Icons.Outlined.AutoStories, Icons.Rounded.AutoStories),
    Tab(MaterialsRoute, R.string.nav_materials, Icons.Outlined.Checklist, Icons.Rounded.Checklist),
)

/** A director watches and runs the place. */
val directorTabs = listOf(
    Tab(HomeRoute, R.string.nav_home, Icons.Outlined.Home, Icons.Rounded.Home),
    Tab(LiveRoute, R.string.nav_live, Icons.Outlined.Sensors, Icons.Rounded.Sensors),
    Tab(SchoolRoute, R.string.nav_school, Icons.Outlined.School, Icons.Rounded.School),
    Tab(AnalyticsRoute, R.string.nav_analytics, Icons.Outlined.Insights, Icons.Rounded.Insights),
)

/** A pupil works: the tasks tab replaces the parent's inbox. */
val studentTabs = listOf(
    Tab(HomeRoute, R.string.nav_home, Icons.Outlined.Home, Icons.Rounded.Home),
    Tab(DiaryRoute, R.string.nav_diary, Icons.Outlined.AutoStories, Icons.Rounded.AutoStories),
    Tab(TasksRoute, R.string.nav_tasks, Icons.Outlined.Checklist, Icons.Rounded.Checklist),
    Tab(RatingRoute, R.string.nav_rating, Icons.Outlined.EmojiEvents, Icons.Rounded.EmojiEvents),
)

/** How much a scrolling tab must leave free at the bottom for the floating bar. */
val BottomBarClearance: Dp = 96.dp

/**
 * The tabbed shell: content underneath, a floating pill bar on top. Detail
 * pages hide the bar so they get the whole screen.
 */
@Composable
fun MainShell(nav: NavHostController, tabs: List<Tab>, content: @Composable (bottomPadding: Dp) -> Unit) {
    val entry by nav.currentBackStackEntryAsState()
    val destination = entry?.destination
    val current = tabs.firstOrNull { tab -> destination?.hierarchy?.any { it.hasRoute(tab.route::class) } == true }
    val showBar = current != null
    val navInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    PageBackground {
        Box(Modifier.fillMaxSize()) {
            content(if (showBar) BottomBarClearance + navInset else 0.dp)

            AnimatedVisibility(
                visible = showBar,
                modifier = Modifier.align(Alignment.BottomCenter),
                enter = slideInVertically { it } + fadeIn(),
                exit = slideOutVertically { it } + fadeOut(),
            ) {
                FloatingTabBar(
                    tabs = tabs,
                    selected = current,
                    onSelect = { tab ->
                        nav.navigate(tab.route) {
                            popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                    modifier = Modifier.padding(bottom = navInset + 14.dp, start = 20.dp, end = 20.dp),
                )
            }
        }
    }
}

@Composable
private fun FloatingTabBar(tabs: List<Tab>, selected: Tab?, onSelect: (Tab) -> Unit, modifier: Modifier = Modifier) {
    val c = MaterialTheme.smart
    val shape = RoundedCornerShape(28.dp)
    Row(
        modifier
            .fillMaxWidth()
            .height(68.dp)
            .shadow(18.dp, shape, spotColor = c.brandDeep.copy(alpha = 0.18f), ambientColor = c.brandDeep.copy(alpha = 0.10f))
            .clip(shape)
            .background(c.surface)
            .border(1.dp, c.border, shape)
            .padding(horizontal = 8.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        tabs.forEach { tab ->
            val active = tab == selected
            TabItem(tab, active, Modifier.weight(1f)) { onSelect(tab) }
        }
    }
}

@Composable
private fun TabItem(tab: Tab, active: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val c = MaterialTheme.smart
    val pillWidth by animateDpAsState(if (active) 22.dp else 0.dp, spring(dampingRatio = 0.7f), label = "pill")
    val interaction = remember { MutableInteractionSource() }
    Column(
        modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(20.dp))
            .background(if (active) c.brandTint else c.surface)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            if (active) tab.iconActive else tab.icon,
            contentDescription = stringResource(tab.label),
            tint = if (active) c.brandDeep else c.inkTertiary,
            modifier = Modifier.size(24.dp),
        )
        Text(
            stringResource(tab.label),
            style = MaterialTheme.typography.labelSmall,
            color = if (active) c.brandDeep else c.inkTertiary,
            maxLines = 1,
        )
        Box(Modifier.padding(top = 2.dp).height(3.dp).width(pillWidth).clip(RoundedCornerShape(2.dp)).background(c.brand))
    }
}
