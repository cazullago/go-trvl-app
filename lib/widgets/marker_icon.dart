import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/boho_theme.dart';

const Map<String, String> categoryEmoji = {
  'where_to_go': '🏝️',
  'things_to_do': '🤿',
  'where_to_eat': '🍜',
  'where_to_stay': '🏨',
  'where_to_buy': '🛍️',
};

final Map<String, BitmapDescriptor> _cache = {};

/// Draws a playful boho map pin: colored teardrop with an emoji center.
/// Done places get a leaf-green pin with a check mark.
Future<BitmapDescriptor> bohoPin(String category, {bool done = false}) async {
  final key = '$category-$done';
  if (_cache.containsKey(key)) return _cache[key]!;
  final color = done ? BohoColors.leaf : MapCategory.of(category).color;
  const size = 150.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final cx = size / 2;

  // soft shadow
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, size - 14), width: 76, height: 18),
    Paint()..color = Colors.black.withValues(alpha: 0.18),
  );

  // pin body: circle + pointer
  final pinPaint = Paint()..color = color;
  canvas.drawCircle(Offset(cx, 62), 54, pinPaint);
  final pointer = Path()
    ..moveTo(cx - 35, 96)
    ..lineTo(cx + 35, 96)
    ..lineTo(cx, size - 10)
    ..close();
  canvas.drawPath(pointer, pinPaint);

  // white inner badge
  canvas.drawCircle(Offset(cx, 62), 40, Paint()..color = Colors.white);

  // emoji / check
  final glyph = done ? '✓' : (categoryEmoji[category] ?? '📍');
  final tp = TextPainter(
    text: TextSpan(
      text: glyph,
      style: TextStyle(
        fontSize: done ? 46 : 44,
        fontWeight: FontWeight.w900,
        color: done ? BohoColors.leafDeep : BohoColors.cocoa,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  tp.paint(canvas, Offset(cx - tp.width / 2, 62 - tp.height / 2));

  final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final descriptor = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  _cache[key] = descriptor;
  return descriptor;
}

void _drawGlyph(
    Canvas canvas, String glyph, Offset center, double fontSize, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: glyph,
      style: TextStyle(
          fontSize: fontSize, fontWeight: FontWeight.w900, color: color),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
}

Path _starPath(Offset c, double outer, double inner, int points) {
  final path = Path();
  for (int i = 0; i < points * 2; i++) {
    final r = i.isEven ? outer : inner;
    final a = -pi / 2 + i * pi / points;
    final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

/// Quest pin with a DISTINCT shape per filter, so the map reads at a
/// glance even without the legend:
/// - where_to_go: coral pushpin teardrop with 🏝️
/// - where_to_eat: rice-bowl marker — white circle, gold ring, 🍚
/// - things_to_do: sun/gold five-point star
///
/// [done] swaps in a leaf-green ✓ badge; [locked] dims the icon and adds
/// a lock medallion. Quest-stop businesses reuse the things_to_do star.
Future<BitmapDescriptor> questPin(String filter,
    {bool done = false, bool locked = false}) async {
  final key = 'quest-$filter-$done-$locked';
  final hit = _cache[key];
  if (hit != null) return hit;

  const size = 150.0;
  const cx = size / 2;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // soft shadow
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(cx, 128), width: 84, height: 18),
    Paint()..color = Colors.black.withValues(alpha: 0.18),
  );

  switch (filter) {
    case 'where_to_eat':
      // Rice-bowl marker: white circle, gold ring, 🍚 center.
      canvas.drawCircle(
          const Offset(cx, 70), 56, Paint()..color = Colors.white);
      canvas.drawCircle(
        const Offset(cx, 70),
        56,
        Paint()
          ..color = BohoColors.sun
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7,
      );
      _drawGlyph(canvas, '🍚', const Offset(cx, 72), 52, BohoColors.cocoa);
    case 'things_to_do':
      // Sun/gold star.
      final star = _starPath(const Offset(cx, 70), 60, 26, 5);
      canvas.drawPath(star, Paint()..color = BohoColors.sun);
      canvas.drawPath(
        star,
        Paint()
          ..color = BohoColors.cocoa
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round,
      );
    case 'where_to_go':
    default:
      // Coral pushpin teardrop.
      final pinPaint = Paint()..color = BohoColors.pinWhereToGo;
      canvas.drawCircle(const Offset(cx, 62), 54, pinPaint);
      final pointer = Path()
        ..moveTo(cx - 35, 96)
        ..lineTo(cx + 35, 96)
        ..lineTo(cx, size - 10)
        ..close();
      canvas.drawPath(pointer, pinPaint);
      canvas.drawCircle(const Offset(cx, 62), 40, Paint()..color = Colors.white);
      _drawGlyph(canvas, '🏝️', const Offset(cx, 62), 42, BohoColors.cocoa);
  }

  if (done) {
    canvas.drawCircle(
        const Offset(112, 112), 26, Paint()..color = BohoColors.leaf);
    canvas.drawCircle(
      const Offset(112, 112),
      26,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    _drawGlyph(canvas, '✓', const Offset(112, 112), 28, Colors.white);
  }

  if (locked) {
    // Dim the icon (overlay limited to the icon area so the transparent
    // corners stay transparent) and stamp a lock medallion on it.
    canvas.drawCircle(const Offset(cx, 68), 64,
        Paint()..color = Colors.white.withValues(alpha: 0.55));
    canvas.drawCircle(
        const Offset(112, 112), 26, Paint()..color = BohoColors.espresso);
    _drawGlyph(canvas, '🔒', const Offset(112, 112), 24, Colors.white);
  }

  final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final descriptor = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  _cache[key] = descriptor;
  return descriptor;
}
