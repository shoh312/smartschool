import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

/// Flat rectangular flag swatch, hand-drawn with CustomPainter.
///
/// Flag emoji (regional-indicator codepoint pairs) don't render as flags in
/// Flutter's Windows/Linux desktop text layout -- Skia's font fallback there
/// doesn't reliably pick a color-emoji glyph for them, so they show as boxes
/// or bare letters even though the same emoji renders fine on Android/iOS/
/// Web. Drawing the flags ourselves sidesteps that platform gap entirely.
class FlagBadge extends StatelessWidget {
  const FlagBadge({
    super.key,
    required this.countryCode,
    this.width = 32,
    this.height = 22,
  });

  /// 'tj' (Tajikistan), 'ru' (Russia), or 'gb' (United Kingdom).
  final String countryCode;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: context.colors.border),
      ),
      child: CustomPaint(
        size: Size(width, height),
        painter: _painterFor(countryCode),
      ),
    );
  }

  CustomPainter _painterFor(String code) {
    switch (code) {
      case 'ru':
        return const _StripesFlagPainter(
          colors: [Colors.white, Color(0xFF0039A6), Color(0xFFD52B1E)],
        );
      case 'gb':
        return const _UnionJackPainter();
      case 'tj':
      default:
        return const _TajikistanFlagPainter();
    }
  }
}

class _StripesFlagPainter extends CustomPainter {
  const _StripesFlagPainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final stripeHeight = size.height / colors.length;
    for (var i = 0; i < colors.length; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, stripeHeight * i, size.width, stripeHeight),
        Paint()..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TajikistanFlagPainter extends CustomPainter {
  const _TajikistanFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final redHeight = size.height * 0.3;
    final whiteHeight = size.height * 0.4;
    final greenHeight = size.height * 0.3;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, redHeight),
      Paint()..color = const Color(0xFFCC0000),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, redHeight, size.width, whiteHeight),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, redHeight + whiteHeight, size.width, greenHeight),
      Paint()..color = const Color(0xFF006600),
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.height * 0.09,
      Paint()..color = const Color(0xFFF8C300),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UnionJackPainter extends CustomPainter {
  const _UnionJackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);

    canvas.drawRect(rect, Paint()..color = const Color(0xFF00247D));

    void diagonalCross(Color color, double strokeWidth) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), paint);
      canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
    }

    diagonalCross(Colors.white, size.height * 0.35);
    diagonalCross(const Color(0xFFCF142B), size.height * 0.16);

    final white = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.36, size.width, size.height * 0.28),
      white,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.40, 0, size.width * 0.2, size.height),
      white,
    );

    final red = Paint()..color = const Color(0xFFCF142B);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.42, size.width, size.height * 0.16),
      red,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.44, 0, size.width * 0.12, size.height),
      red,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
