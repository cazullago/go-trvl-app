import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/boho_theme.dart';

/// Faint palm-leaf and hibiscus flourishes tucked into the screen corners,
/// for cream backgrounds. Deliberately cheap: a handful of static paths,
/// no animation, never repaints.
class TropicalCorners extends StatelessWidget {
  /// Paint opacity for the flourishes (mockup uses a faint wash).
  final double opacity;

  const TropicalCorners({super.key, this.opacity = 0.12});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TropicalCornersPainter(opacity));
  }
}

class _TropicalCornersPainter extends CustomPainter {
  final double opacity;

  const _TropicalCornersPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final leaf = Paint()
      ..color = BohoColors.forest.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    final bloom = Paint()
      ..color = BohoColors.terracotta.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // Four corners: anchor just outside the corner, leaves fan inward.
    _corner(canvas, const Offset(-10, -10), [25, 45, 65], leaf);
    _corner(canvas, Offset(w + 10, -10), [115, 135, 155], leaf);
    _corner(canvas, Offset(-10, h + 10), [295, 315, 335], leaf);
    _corner(canvas, Offset(w + 10, h + 10), [205, 225, 245], leaf);

    // Two small hibiscus blooms on the diagonal.
    _hibiscus(canvas, Offset(w - 40, 46), 17, bloom);
    _hibiscus(canvas, Offset(40, h - 46), 17, bloom);
  }

  void _corner(
      Canvas canvas, Offset anchor, List<double> degrees, Paint paint) {
    const lengths = [64.0, 86.0, 62.0];
    for (int i = 0; i < degrees.length; i++) {
      final rad = degrees[i] * pi / 180;
      final len = lengths[i % lengths.length];
      final wid = len * 0.30;
      canvas.save();
      canvas.translate(anchor.dx, anchor.dy);
      canvas.rotate(rad);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(len * 0.55, -wid, len, 0)
          ..quadraticBezierTo(len * 0.55, wid, 0, 0)
          ..close(),
        paint,
      );
      canvas.restore();
    }
  }

  void _hibiscus(Canvas canvas, Offset c, double r, Paint paint) {
    for (int i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * 2 * pi / 5);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, -r * 0.58), width: r * 0.72, height: r),
        paint,
      );
      canvas.restore();
    }
    canvas.drawCircle(c, r * 0.26, paint);
  }

  @override
  bool shouldRepaint(covariant _TropicalCornersPainter old) =>
      old.opacity != opacity;
}
