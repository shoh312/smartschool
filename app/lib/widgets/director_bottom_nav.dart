import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

import '../core/design_tokens.dart';
import '../providers/director_nav_provider.dart';

/// The director's persistent bottom navigation bar, Telegram-style: no
/// indicator pill, the selected icon pops with a spring bounce, and only
/// the selected tab's label is shown. Shared by MainScreen (where it
/// switches between tabs) and by AppShell (so it keeps showing on screens
/// pushed on top of MainScreen, e.g. a class or teacher detail page) --
/// tapping a destination there pops back to MainScreen and switches tabs.
class DirectorBottomNav extends StatelessWidget {
  const DirectorBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      _NavItemData.image('assets/icons/dashboard.png', l10n.dashboard),
      _NavItemData.image('assets/icons/live_stream.png', l10n.live),
      _NavItemData.image('assets/icons/management.png', l10n.manage),
      _NavItemData.image('assets/icons/settings_nav.png', l10n.settings),
      _NavItemData.image('assets/icons/alerts.png', l10n.alerts),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
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
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData(this.icon, this.selectedIcon, this.label) : imageAsset = null;
  const _NavItemData.image(this.imageAsset, this.label)
      : icon = null,
        selectedIcon = null;

  final IconData? icon;
  final IconData? selectedIcon;

  /// Full-color PNG tab artwork -- shown instead of [icon]/[selectedIcon]
  /// when set. These come pre-colored (no separate outlined/filled variant
  /// like Material icons), so selection is conveyed via opacity instead of
  /// swapping icon or color.
  final String? imageAsset;
  final String label;
}

class _TelegramNavItem extends StatefulWidget {
  const _TelegramNavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
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
              child: widget.data.imageAsset != null
                  ? AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: widget.selected ? 1.0 : 0.82,
                      child: Image.asset(
                        widget.data.imageAsset!,
                        width: 30,
                        height: 30,
                      ),
                    )
                  : Icon(
                      widget.selected
                          ? widget.data.selectedIcon
                          : widget.data.icon,
                      color: color,
                      size: 24,
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

/// Pops back to MainScreen (the director shell's root route) and switches
/// its bottom-nav tab -- used so tapping the bar works the same whether
/// you're on a tab page or a screen pushed on top of it.
void selectDirectorTab(BuildContext context, int index) {
  context.read<DirectorNavProvider>().setIndex(index);
  Navigator.of(context).popUntil((route) => route.isFirst);
}
