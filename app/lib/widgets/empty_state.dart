import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon,
    this.imageAsset,
    required this.title,
    required this.message,
    this.onAction,
    this.actionLabel,
  }) : assert(icon != null || imageAsset != null, 'Provide icon or imageAsset');

  final IconData? icon;

  /// Path to a custom PNG illustration (e.g. 'assets/icons/not_notifications.png'),
  /// shown instead of [icon] when set.
  final String? imageAsset;
  final String title;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (imageAsset != null)
            Image.asset(imageAsset!, width: 96, height: 96)
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppGradients.tint(context.colors.primary),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: context.colors.primary,
              ),
            ),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdRadius,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );

    // A LayoutBuilder + scroll view so this never overflows when a caller
    // gives it a tight fixed height (e.g. SizedBox(height: 200)) -- it
    // centers normally when there's room, and scrolls instead of
    // overflowing when there isn't.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
