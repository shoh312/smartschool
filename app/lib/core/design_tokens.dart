import 'package:flutter/material.dart';

/// Shared design primitives for the premium SmartSchool visual language.
/// Screens and shared widgets should pull colors, gradients, radii and
/// shadows from here instead of hardcoding one-off values.
///
/// Colors are theme-aware: use `context.colors.xxx` (not a static constant)
/// so widgets automatically pick up the light/dark palette.
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderStrong,
  });

  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSunken;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderStrong;

  static const light = AppColorScheme(
    primary: Color(0xFF4F46E5), // Indigo 600
    primaryDark: Color(0xFF3730A3), // Indigo 800
    primaryLight: Color(0xFF818CF8), // Indigo 400
    accent: Color(0xFF06B6D4), // Cyan 500
    success: Color(0xFF10B981), // Emerald 500
    warning: Color(0xFFF59E0B), // Amber 500
    danger: Color(0xFFEF4444), // Red 500
    info: Color(0xFF3B82F6), // Blue 500
    background: Color(0xFFF6F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F2F8),
    surfaceSunken: Color(0xFFEEF0F8),
    textPrimary: Color(0xFF0F172A), // Slate 900
    textSecondary: Color(0xFF64748B), // Slate 500
    textMuted: Color(0xFF94A3B8), // Slate 400
    border: Color(0xFFE6E8F0),
    borderStrong: Color(0xFFD8DBE8),
  );

  static const dark = AppColorScheme(
    primary: Color(0xFF818CF8), // Indigo 400 (brighter for dark backgrounds)
    primaryDark: Color(0xFF4F46E5),
    primaryLight: Color(0xFFA5B4FC),
    accent: Color(0xFF22D3EE),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    info: Color(0xFF60A5FA),
    background: Color(0xFF0B0F19),
    surface: Color(0xFF161B2E),
    surfaceAlt: Color(0xFF1E2438),
    surfaceSunken: Color(0xFF1A1F33),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF6B7280),
    border: Color(0xFF2A3149),
    borderStrong: Color(0xFF3B4363),
  );

  @override
  AppColorScheme copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? accent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSunken,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? borderStrong,
  }) {
    return AppColorScheme(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
    );
  }

  @override
  AppColorScheme lerp(ThemeExtension<AppColorScheme>? other, double t) {
    if (other is! AppColorScheme) return this;
    return AppColorScheme(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
    );
  }
}

/// Convenience accessor: `context.colors.primary` instead of
/// `Theme.of(context).extension<AppColorScheme>()!.primary`.
extension AppColorsContext on BuildContext {
  AppColorScheme get colors =>
      Theme.of(this).extension<AppColorScheme>() ?? AppColorScheme.light;
}

class AppGradients {
  AppGradients._();

  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
  );

  static const primarySoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEEF0FF), Color(0xFFE4E7FE)],
  );

  static const accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
  );

  static const success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF059669)],
  );

  static const canvas = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8F9FD), Color(0xFFF1F2FA)],
  );

  static LinearGradient tint(Color color) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withOpacity(0.16), color.withOpacity(0.06)],
      );
}

class AppRadius {
  AppRadius._();

  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;

  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);
  static BorderRadius get xlRadius => BorderRadius.circular(xl);
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.04),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get raised => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.06),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> colored(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.28),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];
}
