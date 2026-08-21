import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

/// A single quick-action tile on a dashboard's "Quick Actions"/actions grid
/// -- shared by the director, teacher, and parent dashboards so a new
/// destination (e.g. Ruznoma/Kalendar/E'lonlar) looks identical everywhere
/// instead of each dashboard re-implementing its own tile style.
class DashboardActionTile extends StatelessWidget {
  const DashboardActionTile({
    super.key,
    this.icon,
    this.imageAsset,
    required this.label,
    this.route,
    this.color,
    this.onTap,
  }) : assert(icon != null || imageAsset != null, 'Provide icon or imageAsset'),
       assert(route != null || onTap != null, 'Provide route or onTap');

  final IconData? icon;
  final String? imageAsset;
  final String label;
  final String? route;

  /// Defaults to the brand colour. A grid where every tile picked its own
  /// hue read as a random colour swatch rather than a set of equal
  /// destinations, so leave this unset unless one tile genuinely needs to
  /// stand apart from the rest.
  final Color? color;

  /// Overrides the default `Navigator.pushNamed(context, route)` tap
  /// behavior for destinations that need constructor arguments rather than
  /// a plain named route.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.primary;
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: onTap ?? () => Navigator.pushNamed(context, route!),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: context.colors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              if (imageAsset != null)
                Image.asset(imageAsset!, width: 40, height: 40)
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppGradients.tint(tint),
                    borderRadius: AppRadius.mdRadius,
                  ),
                  child: Icon(icon, color: tint, size: 22),
                ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A width-aware `Wrap` of [DashboardActionTile]s, matching the tile-sizing
/// pattern already proven on the director dashboard -- 2 columns on phones,
/// 4 on wide windows.
class DashboardActionGrid extends StatelessWidget {
  const DashboardActionGrid({super.key, required this.actions});

  final List<DashboardActionTile> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth > 700 ? 4 : 2;
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions) SizedBox(width: tileWidth, child: action),
          ],
        );
      },
    );
  }
}
