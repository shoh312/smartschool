import 'package:flutter/material.dart';

/// Shared breakpoint policy -- every screen picking column counts or
/// swapping nav styles should read from here instead of inventing its own
/// width thresholds, so "is this wide enough for N columns" stays
/// consistent app-wide instead of drifting screen to screen.
class Responsive {
  Responsive._();

  static const double tablet = 600;
  static const double desktop = 1024;
  static const double maxContentWidth = 1200;
}

extension ResponsiveContext on BuildContext {
  double get _width => MediaQuery.sizeOf(this).width;
  bool get isTablet => _width >= Responsive.tablet;
  bool get isDesktop => _width >= Responsive.desktop;
}

/// How many tiles of roughly [tileWidth] fit across [width], clamped to
/// [min]/[max] -- the shared policy behind every LayoutBuilder+GridView tile
/// grid in the app (metric cards, quick actions, class cards) instead of
/// each screen hardcoding its own "> 600 ? 4 : 2" breakpoint.
int responsiveColumns(
  double width, {
  int min = 2,
  int max = 4,
  double tileWidth = 240,
}) {
  final columns = (width / tileWidth).floor();
  return columns.clamp(min, max);
}
