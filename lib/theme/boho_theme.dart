import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GoTRVL PH palette: the approved mockup tokens (tan, cream, forest,
/// espresso, dusty blue, terracotta) sit alongside the legacy boho tokens
/// so existing screens keep compiling.
class BohoColors {
  /// Warm paper cream: the mockup scaffold background.
  static const cream = Color(0xFFF5EFE6);

  /// Mockup palette.
  static const tan = Color(0xFFBFA181);
  static const forest = Color(0xFF4F6F52);
  static const espresso = Color(0xFF2E2A26);
  static const dustyBlue = Color(0xFF7897A4);
  static const terracotta = Color(0xFFD98C78);
  static const sand = Color(0xFFF5E6C4);
  static const sandDark = Color(0xFFE8D3A1);
  static const sandDeep = Color(0xFFD9B978);
  static const ocean = Color(0xFF2AA5B8);
  static const oceanDeep = Color(0xFF166E7C);
  static const oceanMist = Color(0xFFD9F0EC);
  static const coral = Color(0xFFFF7E5F);
  static const coralDeep = Color(0xFFE85D3D);
  static const coralMist = Color(0xFFFFE3D6);
  static const cocoa = Color(0xFF6B4A2F);
  static const cocoaSoft = Color(0xFF8A5A33);
  static const leaf = Color(0xFF4C9A5B);
  static const leafDeep = Color(0xFF2F6B3C);
  static const leafMist = Color(0xFFDFF0DA);
  static const sun = Color(0xFFFFC53D);

  /// Refined auth-surface tokens (inspired by the Go TRVL PH prototype):
  /// deep ocean teal hero, warm cream sheet, espresso text, muted sand text.
  static const tealHeroTop = Color(0xFF1A5D6B);
  static const tealHeroMid = Color(0xFF144B56);
  static const tealHeroDeep = Color(0xFF0F3942);
  static const creamSheet = Color(0xFFFAF7F2);
  static const coconut = Color(0xFF3E2A1E);
  static const sandMuted = Color(0xFF9C8E7E);

  /// Lush tropical tokens: jungle greens and hibiscus pinks.
  static const jungle = Color(0xFF1E5C44);
  static const jungleDeep = Color(0xFF123B2C);
  static const hibiscus = Color(0xFFE85D8A);
  static const hibiscusDeep = Color(0xFFB93A6B);

  /// Pin colors per map category.
  static const pinWhereToGo = Color(0xFFE85D3D); // coral landmark
  static const pinThingsToDo = Color(0xFFFFC53D); // sun adventure
  static const pinWhereToEat = Color(0xFF8A4FFF); // tropical orchid
  static const pinWhereToStay = Color(0xFF2AA5B8); // ocean hotel
  static const pinWhereToBuy = Color(0xFF4C9A5B); // leaf store
  static const pinHowToGetAround = Color(0xFF6B7280); // jeepney asphalt
}

class BohoFonts {
  /// Legacy handwritten display (Caveat): kept compiling for existing
  /// callers; new work should use [script] / [heading].
  static TextStyle display(double size, {Color color = BohoColors.cocoa}) =>
      GoogleFonts.caveat(
          fontSize: size, fontWeight: FontWeight.w700, color: color);

  /// Handwritten script for the wordmark (Pacifico).
  static TextStyle script(double size, {Color color = BohoColors.forest}) =>
      GoogleFonts.pacifico(fontSize: size, color: color);

  /// Poppins headings for the redesign.
  static TextStyle heading(double size,
          {Color color = BohoColors.espresso,
          FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

  /// Poppins body text (redesign default). The signature is unchanged from
  /// the legacy Quicksand body so every existing caller keeps compiling.
  static TextStyle body(double size,
          {Color color = BohoColors.espresso,
          FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

  /// Serif headings (Playfair Display) for the refined auth surfaces.
  static TextStyle headline(double size,
          {Color color = BohoColors.coconut,
          FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.playfairDisplay(
          fontSize: size, fontWeight: weight, color: color);

  /// Letterspaced caps labels for form fields.
  static TextStyle capsLabel(double size, {Color color = BohoColors.coconut}) =>
      GoogleFonts.quicksand(
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: color);
}

/// App theme for the GoTRVL PH redesign: cream scaffold, espresso text,
/// forest primary actions. Same signature as before.
ThemeData bohoTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BohoColors.forest,
    primary: BohoColors.forest,
    secondary: BohoColors.dustyBlue,
    tertiary: BohoColors.terracotta,
    surface: BohoColors.cream,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: BohoColors.cream,
    textTheme: GoogleFonts.poppinsTextTheme().apply(
      bodyColor: BohoColors.espresso,
      displayColor: BohoColors.espresso,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: BohoColors.cream,
      foregroundColor: BohoColors.espresso,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: BohoColors.espresso),
      titleTextStyle: BohoFonts.heading(22, color: BohoColors.espresso),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: BohoColors.cream,
      selectedItemColor: BohoColors.forest,
      unselectedItemColor: BohoColors.espresso.withValues(alpha: 0.55),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BohoColors.tan,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: GoogleFonts.poppins(
        color: BohoColors.espresso.withValues(alpha: 0.4),
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: BohoColors.tan),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: BohoColors.tan),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: BohoColors.forest, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BohoColors.forest,
        foregroundColor: Colors.white,
        textStyle:
            GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
        elevation: 2,
      ),
    ),
  );
}

/// Shared boho decorations.
class BohoDecor {
  static BoxDecoration card({Color color = Colors.white}) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BohoColors.sandDark, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: BohoColors.cocoa.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      );

  static BoxDecoration gradientHeader = BoxDecoration(
    gradient: const LinearGradient(
      colors: [BohoColors.ocean, BohoColors.leaf],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(22),
  );

  static BoxDecoration sunsetHeader = BoxDecoration(
    gradient: const LinearGradient(
      colors: [BohoColors.coral, BohoColors.sun],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(22),
  );

  /// Sunset sky gradient (coral to hibiscus to gold).
  static BoxDecoration sunsetSky = const BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Color(0xFFFF8A5F),
        BohoColors.hibiscus,
        BohoColors.sun,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  /// Cream journal card with a soft arch top, for auth sheets.
  static BoxDecoration tropicalCard = BoxDecoration(
    color: BohoColors.creamSheet,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(38),
      topRight: Radius.circular(38),
    ),
    boxShadow: [
      BoxShadow(
        color: BohoColors.jungleDeep.withValues(alpha: 0.35),
        blurRadius: 30,
        offset: const Offset(0, -10),
      ),
    ],
  );

  /// Small centered drag-handle bar for bottom sheets.
  static Widget dragHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: BohoColors.sandMuted.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  /// Ghost/outline button style for secondary auth actions.
  static ButtonStyle ghostButtonStyle = OutlinedButton.styleFrom(
    backgroundColor: BohoColors.creamSheet,
    foregroundColor: BohoColors.jungleDeep,
    side: const BorderSide(color: BohoColors.jungleDeep, width: 1.4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    textStyle: GoogleFonts.quicksand(fontWeight: FontWeight.w700, fontSize: 16),
  );
}

/// Category metadata shared by map, filters and gamification.
class MapCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const MapCategory(this.key, this.label, this.icon, this.color);

  static const list = [
    MapCategory('where_to_go', 'Where to Go', Icons.landscape_rounded,
        BohoColors.pinWhereToGo),
    MapCategory('things_to_do', 'Things to Do', Icons.kayaking_rounded,
        BohoColors.pinThingsToDo),
    MapCategory('where_to_eat', 'Where to Eat', Icons.restaurant_rounded,
        BohoColors.pinWhereToEat),
    MapCategory('where_to_stay', 'Where to Stay', Icons.hotel_rounded,
        BohoColors.pinWhereToStay),
    MapCategory('where_to_buy', 'Where to Buy', Icons.shopping_bag_rounded,
        BohoColors.pinWhereToBuy),
    MapCategory('how_to_get_around', 'How to Get Around',
        Icons.directions_bus_rounded, BohoColors.pinHowToGetAround),
  ];

  static MapCategory of(String key) =>
      list.firstWhere((c) => c.key == key, orElse: () => list[0]);
}

/// Public dot-pattern overlay for hero surfaces.
class DotPatternOverlay extends StatelessWidget {
  const DotPatternOverlay({super.key});
  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _DotPatternPainter());
}

/// Subtle woven dot texture.
class _DotPatternPainter extends CustomPainter {
  const _DotPatternPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    const gap = 26.0;
    for (double y = gap / 2; y < size.height; y += gap) {
      for (double x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full-bleed hand-painted tropical sunset: gradient sky, glowing sun,
/// palm silhouettes, monstera leaves, hibiscus blooms, petals and birds.
class TropicalScene extends StatelessWidget {
  const TropicalScene({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TropicalScenePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _TropicalScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sky: sunset melting into the sea.
    final sky = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFF8A5F),
          Color(0xFFE85D8A),
          Color(0xFFFFC53D),
          Color(0xFF2A7E8C),
          Color(0xFF0F3942),
        ],
        stops: [0.0, 0.32, 0.55, 0.78, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    // Sun with a warm glow.
    final sunC = Offset(w * 0.70, h * 0.32);
    final sunR = w * 0.15;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF6DC).withValues(alpha: 0.95),
          const Color(0xFFFFE9A8).withValues(alpha: 0.45),
          const Color(0xFFFFE9A8).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: sunC, radius: sunR * 2.6));
    canvas.drawCircle(sunC, sunR * 2.6, glow);
    canvas.drawCircle(sunC, sunR, Paint()..color = const Color(0xFFFFF3D0));

    // Sea shimmer.
    final rnd = Random(11);
    final shimmer = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 9; i++) {
      final y = h * (0.72 + rnd.nextDouble() * 0.24);
      final cx = w * rnd.nextDouble();
      final len = w * (0.03 + rnd.nextDouble() * 0.05);
      canvas.drawLine(Offset(cx - len, y), Offset(cx + len, y), shimmer);
    }

    // Distant birds.
    final birdPaint = Paint()
      ..color = BohoColors.jungleDeep.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    void bird(double x, double y, double s) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 12 * s, y)
          ..quadraticBezierTo(x - 6 * s, y - 8 * s, x, y)
          ..quadraticBezierTo(x + 6 * s, y - 8 * s, x + 12 * s, y),
        birdPaint,
      );
    }

    bird(w * 0.24, h * 0.20, 1.0);
    bird(w * 0.36, h * 0.15, 0.7);
    bird(w * 0.82, h * 0.16, 0.85);

    // Big soft leaves for depth.
    _bigLeaf(canvas, Offset(w * 0.10, h * 0.30), w * 0.16, -0.5,
        Colors.white.withValues(alpha: 0.08));
    _bigLeaf(canvas, Offset(w * 0.92, h * 0.44), w * 0.20, 0.6,
        Colors.white.withValues(alpha: 0.07));
    _bigLeaf(canvas, Offset(w * 0.55, h * 0.10), w * 0.13, 0.3,
        BohoColors.jungleDeep.withValues(alpha: 0.10));

    // Floating petals.
    final petalPaint = Paint()
      ..color = const Color(0xFFFFD9E6).withValues(alpha: 0.5);
    const petals = [
      (0.18, 0.42, 0.5),
      (0.30, 0.55, -0.4),
      (0.66, 0.52, 0.9),
      (0.78, 0.60, -0.7),
      (0.45, 0.38, 0.2),
      (0.88, 0.30, 1.1),
    ];
    for (final petal in petals) {
      canvas.save();
      canvas.translate(w * petal.$1, h * petal.$2);
      canvas.rotate(petal.$3);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 14, height: 9),
          petalPaint);
      canvas.restore();
    }

    // Hibiscus blooms tucked near the palms.
    _hibiscus(canvas, Offset(w * 0.16, h * 0.62), w * 0.045);
    _hibiscus(canvas, Offset(w * 0.86, h * 0.58), w * 0.038);

    // Palm silhouettes: one faint for depth, two bold in front.
    _palm(canvas, Offset(w * 0.38, h * 1.02), h * 0.52, 26,
        BohoColors.jungleDeep.withValues(alpha: 0.35), false);
    _palm(canvas, Offset(w * 0.02, h * 1.04), h * 0.66, 40,
        BohoColors.jungleDeep.withValues(alpha: 0.92), false);
    _palm(canvas, Offset(w * 0.99, h * 1.04), h * 0.60, -36,
        BohoColors.jungleDeep.withValues(alpha: 0.92), true);
  }

  void _palm(Canvas canvas, Offset base, double h, double lean, Color color,
      bool flip) {
    final dir = flip ? -1.0 : 1.0;
    final crown = Offset(base.dx + lean * dir, base.dy - h);
    final trunkW = h * 0.045;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final trunk = Path()
      ..moveTo(base.dx - trunkW, base.dy)
      ..quadraticBezierTo(base.dx - trunkW * 0.5 + lean * dir * 0.4,
          base.dy - h * 0.6, crown.dx - trunkW * 0.45, crown.dy)
      ..lineTo(crown.dx + trunkW * 0.45, crown.dy)
      ..quadraticBezierTo(base.dx + trunkW * 0.5 + lean * dir * 0.4,
          base.dy - h * 0.6, base.dx + trunkW, base.dy)
      ..close();
    canvas.drawPath(trunk, fill);
    // Coconuts.
    canvas.drawCircle(
        crown + Offset(-trunkW * 0.9, trunkW * 1.4), trunkW * 0.75, fill);
    canvas.drawCircle(
        crown + Offset(trunkW * 0.9, trunkW * 1.7), trunkW * 0.62, fill);
    // Fronds: thick drooping strokes fanning from the crown.
    final frond = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = h * 0.038;
    for (int i = 0; i < 7; i++) {
      final dx = -1.0 + i * (2.0 / 6);
      final len = h * 0.30 * (1 - 0.12 * dx.abs());
      final end = crown + Offset(dx * len, -len * 0.42 + dx.abs() * len * 0.38);
      final ctrl = crown + Offset(dx * len * 0.45, -len * 0.42);
      canvas.drawPath(
        Path()
          ..moveTo(crown.dx, crown.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy),
        frond,
      );
    }
  }

  void _bigLeaf(Canvas canvas, Offset c, double s, double rot, Color color) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    canvas.drawPath(
      Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s * 0.75, -s * 0.3, 0, s)
        ..quadraticBezierTo(-s * 0.75, -s * 0.3, 0, -s)
        ..close(),
      Paint()..color = color,
    );
    canvas.drawLine(
        Offset(0, -s * 0.85),
        Offset(0, s * 0.85),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.restore();
  }

  void _hibiscus(Canvas canvas, Offset c, double r) {
    final petal = Paint()..color = BohoColors.hibiscus;
    for (int i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * 2 * pi / 5);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(0, -r * 0.62), width: r * 0.78, height: r * 1.05),
          petal);
      canvas.restore();
    }
    canvas.drawCircle(c, r * 0.28, Paint()..color = BohoColors.hibiscusDeep);
    canvas.drawLine(
        c + Offset(0, -r * 0.2),
        c + Offset(r * 0.5, -r * 0.9),
        Paint()
          ..color = const Color(0xFFFFE9A8)
          ..strokeWidth = r * 0.14
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small hibiscus bloom stamp, for decorating cards and titles.
class HibiscusStamp extends StatelessWidget {
  final double size;
  final double opacity;
  const HibiscusStamp({super.key, this.size = 44, this.opacity = 0.9});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _HibiscusPainter(opacity)),
    );
  }
}

class _HibiscusPainter extends CustomPainter {
  final double opacity;
  const _HibiscusPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 * 0.9;
    final petal = Paint()
      ..color = BohoColors.hibiscus.withValues(alpha: opacity);
    for (int i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * 2 * pi / 5);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(0, -r * 0.62), width: r * 0.78, height: r * 1.05),
          petal);
      canvas.restore();
    }
    canvas.drawCircle(c, r * 0.28,
        Paint()..color = BohoColors.hibiscusDeep.withValues(alpha: opacity));
  }

  @override
  bool shouldRepaint(covariant _HibiscusPainter old) => old.opacity != opacity;
}

/// "OR" divider row for the auth sheets.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: BohoColors.sandDark)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR',
              style: BohoFonts.capsLabel(12, color: BohoColors.sandMuted)),
        ),
        const Expanded(child: Divider(color: BohoColors.sandDark)),
      ],
    );
  }
}
