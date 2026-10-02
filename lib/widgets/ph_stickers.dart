import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/boho_theme.dart';

/// Tasteful Filipino decorative stickers, drawn with CustomPaint in two or
/// three palette colors. Kept deliberately simple and elegant — these sit on
/// cards and headers, not over content.
///
/// Each static method returns a fixed-size widget; [stickerRow] lays a few
/// out in a row for banners and empty states.
class PhStickers {
  const PhStickers._();

  /// Coconut palm: curved trunk, three fronds, two coconuts.
  static Widget coconutTree({double size = 48}) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _CoconutTreePainter()),
      );

  /// Simple radiant sun (also the palette's `BohoColors.sun`).
  static Widget sun({double size = 48}) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _SunPainter()),
      );

  /// Layered ocean wave, two blues.
  static Widget wave({double size = 48}) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _WavePainter()),
      );

  /// Scallop shell in soft terracotta.
  static Widget shell({double size = 48}) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _ShellPainter()),
      );

  /// Parol: the Christmas-lantern star, warm yellow with a terracotta ring.
  static Widget parol({double size = 48}) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _ParolPainter()),
      );

  /// A small decorative row: sun, coconut tree, wave. Useful above empty
  /// states and section headers.
  static Widget stickerRow({double size = 40, double spacing = 12}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          sun(size: size),
          SizedBox(width: spacing),
          coconutTree(size: size * 1.15),
          SizedBox(width: spacing),
          wave(size: size),
        ],
      );
}

// ---------------------------------------------------------------------------
// Painters (all work in a unit box, scaled by the SizedBox above)
// ---------------------------------------------------------------------------

class _CoconutTreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final trunk = Paint()
      ..color = BohoColors.cocoa
      ..strokeWidth = size.width * 0.07
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Curved trunk.
    final trunkPath = Path()
      ..moveTo(size.width * 0.5, size.height * 0.98)
      ..quadraticBezierTo(size.width * 0.42, size.height * 0.65,
          size.width * 0.5, size.height * 0.4);
    canvas.drawPath(trunkPath, trunk);

    final frond = Paint()
      ..color = BohoColors.forest
      ..strokeWidth = size.width * 0.06
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final cx = size.width * 0.5;
    final cy = size.height * 0.38;
    for (var i = -1; i <= 1; i++) {
      // Drooping fronds left and right.
      final dir = i == 0 ? 0.0 : (i < 0 ? -1.0 : 1.0);
      final path = Path()
        ..moveTo(cx, cy)
        ..quadraticBezierTo(cx + dir * size.width * 0.32, cy - size.height * 0.06,
            cx + dir * size.width * 0.4, cy + size.height * 0.12);
      canvas.drawPath(path, frond);
    }
    // Two coconuts.
    final nut = Paint()..color = BohoColors.cocoaSoft;
    canvas.drawCircle(Offset(cx - size.width * 0.08, cy + size.height * 0.05),
        size.width * 0.06, nut);
    canvas.drawCircle(Offset(cx + size.width * 0.08, cy + size.height * 0.06),
        size.width * 0.06, nut);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.22;
    final ray = Paint()
      ..color = BohoColors.terracotta
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      final p1 = Offset(c.dx + cos(a) * (r + size.width * 0.06),
          c.dy + sin(a) * (r + size.width * 0.06));
      final p2 = Offset(c.dx + cos(a) * (r + size.width * 0.16),
          c.dy + sin(a) * (r + size.width * 0.16));
      canvas.drawLine(p1, p2, ray);
    }
    canvas.drawCircle(c, r, Paint()..color = BohoColors.sun);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final back = Paint()..color = BohoColors.ocean;
    final front = Paint()..color = BohoColors.oceanDeep;
    final w = size.width;
    final h = size.height;
    final backPath = Path()
      ..moveTo(0, h * 0.55)
      ..cubicTo(w * 0.25, h * 0.35, w * 0.4, h * 0.7, w * 0.65, h * 0.5)
      ..cubicTo(w * 0.8, h * 0.38, w * 0.92, h * 0.52, w, h * 0.45)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(backPath, back);
    final frontPath = Path()
      ..moveTo(0, h * 0.72)
      ..cubicTo(w * 0.3, h * 0.55, w * 0.5, h * 0.85, w * 0.75, h * 0.68)
      ..cubicTo(w * 0.87, h * 0.6, w * 0.95, h * 0.68, w, h * 0.64)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(frontPath, front);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShellPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.62);
    final r = size.width * 0.34;
    final fill = Paint()..color = BohoColors.terracotta;
    final line = Paint()
      ..color = BohoColors.cocoa
      ..strokeWidth = size.width * 0.035
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Fan of 5 arcs.
    for (var i = 0; i < 5; i++) {
      final a = pi + (i / 4) * pi; // pi..2pi
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          a - 0.28,
          0.56,
          false,
          i == 4 ? line : fill);
    }
    // Hinge dot.
    canvas.drawCircle(
        Offset(c.dx, c.dy + r * 0.55), size.width * 0.06, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParolPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final outer = size.width * 0.36;
    final inner = size.width * 0.16;
    // Five-pointed star.
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final r = i.isEven ? outer : inner;
      final p = Offset(c.dx + cos(a) * r, c.dy + sin(a) * r);
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = BohoColors.sun);
    canvas.drawPath(
        star,
        Paint()
          ..color = BohoColors.terracotta
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.03);
    // Tails.
    final tail = Paint()
      ..color = BohoColors.terracotta
      ..strokeWidth = size.width * 0.03
      ..strokeCap = StrokeCap.round;
    for (var i = -1; i <= 1; i += 2) {
      canvas.drawLine(
          Offset(c.dx + i * size.width * 0.08, c.dy + outer * 0.82),
          Offset(c.dx + i * size.width * 0.13, size.height * 0.98),
          tail);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
