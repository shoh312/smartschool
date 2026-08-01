import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.imageAsset,
    this.color,
  }) : assert(icon != null || imageAsset != null, 'Provide icon or imageAsset');

  final String label;
  final String value;
  final IconData? icon;

  /// Path to a custom PNG icon (e.g. 'assets/icons/absent.png'), shown
  /// instead of [icon] when set -- these come pre-colored, so unlike the
  /// Material icon path they're shown without a tinted background chip, and
  /// laid out beside the value/label instead of stacked above it so the
  /// bigger artwork doesn't force the card taller than its content.
  final String? imageAsset;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? context.colors.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      child: imageAsset != null
          ? Row(
              children: [
                Image.asset(imageAsset!, width: 48, height: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: AppGradients.tint(accent),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Icon(icon, color: accent, size: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 16,
                    height: 1.05,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1.05,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
    );
  }
}
