import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

/// A "create new …" form that stays folded away until asked for.
///
/// The management screens used to render their add-form permanently open
/// above the list, so the thing you came to look at -- the students, classes,
/// cameras or teachers you already have -- started halfway down the screen.
/// Here the form collapses to a single "+" row and expands on tap.
///
/// [expanded] is controlled by the caller so that starting an edit can open
/// the form without the user tapping anything.
class CollapsibleFormCard extends StatelessWidget {
  const CollapsibleFormCard({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: expanded ? 0.125 : 0, // + rotates into ×
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: AppGradients.tint(context.colors.primary),
                          borderRadius: AppRadius.mdRadius,
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: context.colors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: expanded ? 0.5 : 0,
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: context.colors.textMuted,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(height: 1, color: context.colors.border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                        child: child,
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
