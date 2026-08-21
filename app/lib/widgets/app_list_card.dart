import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

/// The app's standard tappable list row: a leading badge, a title with an
/// optional subtitle, and either a caller-supplied trailing widget or a
/// chevron.
///
/// Exists because nearly every list in the app was hand-rolling the same
/// `Container(decoration:) > Material > InkWell > ListTile` sandwich, each
/// with slightly different padding, radius and leading size -- so lists that
/// should have looked identical didn't. Material's own `ListTile` isn't used
/// directly: its metrics and text styles are fixed by the Material spec and
/// visibly clash with the rest of this app's cards.
class AppListCard extends StatelessWidget {
  const AppListCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.subtitleMaxLines = 1,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// One line keeps a list of names scannable; rows whose subtitle is real
  /// prose (a notification body, say) can ask for more.
  final int subtitleMaxLines;

  /// Ignored when [trailing] is supplied.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 12.5,
                        height: subtitleMaxLines > 1 ? 1.3 : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (showChevron && onTap != null)
            Icon(Icons.chevron_right_rounded, size: 20, color: context.colors.textMuted),
        ],
      ),
    );

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.lgRadius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// A plain surface panel -- the container the app's forms and grouped
/// content sit in. Same border and radius as [AppListCard] so a form and
/// the list beneath it read as one family rather than two.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );
  }
}

/// The square, tinted initial/icon badge used as [AppListCard.leading]
/// throughout the app, so every list uses the same 38px badge instead of
/// each screen inventing its own avatar size and shape.
class AppListBadge extends StatelessWidget {
  const AppListBadge({super.key, this.text, this.icon, this.color});

  final String? text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.primary;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: AppGradients.tint(tint),
        borderRadius: AppRadius.mdRadius,
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: tint, size: 19)
          // Scaled to fit: badges usually hold a one-or-two character
          // initial, but some lists put a whole start time ("08:00") in
          // here, which would otherwise overflow the 38px square.
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                child: Text(
                  (text == null || text!.isEmpty) ? '?' : text!,
                  style: TextStyle(color: tint, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
    );
  }
}
