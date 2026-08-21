import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/nav_provider.dart';
import 'nav_destinations.dart';

const double _pillHeight = 62.0;
const double _bottomMargin = 20.0;

/// How much of the screen the floating nav actually covers.
///
/// The body extends behind the bar (Scaffold.extendBody), which is what
/// makes content fade out underneath it instead of stopping at a hard
/// edge -- but it also means nothing reserves this space, so a scroll
/// view's last item ends up stranded under the pill with no way to scroll
/// it into view. Scrollables under this nav add it to their bottom
/// padding; taking it from here rather than a hand-tuned number keeps them
/// from drifting apart when the bar changes, and follows the gesture inset
/// across devices.
double bottomNavOverlay(BuildContext context) =>
    _pillHeight + _bottomMargin + MediaQuery.viewPaddingOf(context).bottom;

/// The app's persistent bottom navigation bar, Telegram-style: no
/// indicator pill, the selected icon pops with a spring bounce, and only
/// the selected tab's label is shown. Shared by MainScreen (where it
/// switches between tabs) and by AppShell (so it keeps showing on screens
/// pushed on top of MainScreen, e.g. a class or teacher detail page) --
/// tapping a destination there pops back to MainScreen and switches tabs.
///
/// Its destinations come from the signed-in role (see navDestinationsFor):
/// a teacher's three working areas are not a director's five.
///
/// Always a detached floating pill (rounded, shadowed, margin from the
/// screen edge) at every window size, phone included -- same look on every
/// platform instead of a plain edge-to-edge strip on narrow screens.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = navDestinationsFor(context.watch<AuthProvider>().role, l10n);

    final bar = Container(
      height: _pillHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.raised,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _TelegramNavItem(
                data: items[i],
                selected: i == selectedIndex,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onDestinationSelected(i);
                },
              ),
            ),
        ],
      ),
    );

    // Detached from the screen edges -- the area around it shows the page
    // background instead of a bar stretched full width, so it reads as a
    // floating pill rather than a stretched-out phone bar.
    //
    // Scaffold measures bottomNavigationBar with a LOOSE constraint up to
    // the full screen height (it doesn't know in advance how tall the bar
    // wants to be). Align does not shrink-wrap under loose-but-bounded
    // constraints -- it fills constraints.maxHeight -- so without this
    // explicit SizedBox, Align would report almost the whole screen height
    // back to Scaffold, which would then reserve all of it for the nav bar
    // and leave zero height for the body (a real bug hit while building
    // this: the body silently rendered nothing, no error, just zero size).
    const bottomMargin = _bottomMargin;
    // Handled manually rather than with SafeArea so the fade reaches the
    // real bottom edge of the screen: with SafeArea the faded region stopped
    // above the gesture inset, leaving a crisp sliver of content showing
    // underneath it.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final background = Theme.of(context).scaffoldBackgroundColor;

    return SizedBox(
      // The extra 26 above the pill is fade lead-in: the scrim needs room to
      // ramp up from fully transparent, otherwise the top of the faded band
      // reads as a hard-edged rectangle sitting behind the pill.
      height: _pillHeight + bottomMargin + bottomInset + 26,
      child: Stack(
        children: [
          // Content scrolling underneath dissolves into the page background
          // instead of being cut off mid-card. A gradient (rather than a
          // BackdropFilter) because a blur's own bounds are a visible
          // rectangle -- a fade has no edge to notice.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.55, 1.0],
                    colors: [
                      background.withOpacity(0.0),
                      background.withOpacity(0.88),
                      background.withOpacity(0.97),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomMargin + bottomInset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: bar,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelegramNavItem extends StatefulWidget {
  const _TelegramNavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final NavDestinationData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TelegramNavItem> createState() => _TelegramNavItemState();
}

class _TelegramNavItemState extends State<_TelegramNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        weight: 40,
        tween: Tween(
          begin: 1.0,
          end: 1.24,
        ).chain(CurveTween(curve: Curves.easeOut)),
      ),
      TweenSequenceItem(
        weight: 60,
        tween: Tween(
          begin: 1.24,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticIn)),
      ),
    ]).animate(_bounceController);
  }

  @override
  void didUpdateWidget(covariant _TelegramNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? context.colors.primary : context.colors.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: widget.onTap,
        radius: 36,
        highlightShape: BoxShape.rectangle,
        containedInkWell: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Icon(
                widget.selected ? widget.data.activeIcon : widget.data.icon,
                size: 25,
                color: color,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: widget.selected
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.data.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox(height: 4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pops back to MainScreen (the shell's root route) and switches its
/// bottom-nav tab -- used so tapping the bar works the same whether you're
/// on a tab page or a screen pushed on top of it.
void selectNavTab(BuildContext context, int index) {
  context.read<NavProvider>().setIndex(index);
  Navigator.of(context).popUntil((route) => route.isFirst);
}
