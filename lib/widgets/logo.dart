import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/boho_theme.dart';

/// GoTRVL PH wordmark: a palm tree + sun mark beside Pacifico "Go" and
/// Poppins 800 "TRVL PH", with the tagline underneath.
///
/// [size] is the height of the mark; the wordmark scales with it.
/// [light] renders everything in white/cream for dark or sunset
/// backgrounds.
class GoTrvlLogo extends StatelessWidget {
  final double size;
  final bool light;

  const GoTrvlLogo({super.key, this.size = 48, this.light = false});

  @override
  Widget build(BuildContext context) {
    final markColor = light ? Colors.white : BohoColors.forest;
    final sunColor = light ? Colors.white : BohoColors.terracotta;
    final goColor = light ? Colors.white : BohoColors.forest;
    final trvlColor = light ? BohoColors.cream : BohoColors.espresso;
    final tagColor = light
        ? Colors.white.withValues(alpha: 0.88)
        : BohoColors.espresso.withValues(alpha: 0.66);

    final List<Shadow>? shadows = light
        ? const [
            Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2)),
          ]
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _LogoMarkPainter(palm: markColor, sun: sunColor),
        ),
        SizedBox(width: size * 0.22),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Go ',
                    style: BohoFonts.script(size * 0.74, color: goColor)
                        .copyWith(shadows: shadows),
                  ),
                  TextSpan(
                    text: 'TRVL PH',
                    style: GoogleFonts.poppins(
                      fontSize: size * 0.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: trvlColor,
                      shadows: shadows,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Discover the Philippines, one trip at a time.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: tagColor,
                shadows: shadows,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Palm silhouette with a sun, drawn in a square box.
class _LogoMarkPainter extends CustomPainter {
  final Color palm;
  final Color sun;

  const _LogoMarkPainter({required this.palm, required this.sun});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = palm
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Sun, upper right of the palm.
    canvas.drawCircle(
        Offset(s * 0.68, s * 0.26), s * 0.15, Paint()..color = sun);

    // Trunk: gentle curve leaning right.
    stroke.strokeWidth = s * 0.07;
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.40, s * 0.98)
        ..cubicTo(s * 0.40, s * 0.78, s * 0.50, s * 0.70, s * 0.52, s * 0.48),
      stroke,
    );

    final crown = Offset(s * 0.52, s * 0.48);

    // Coconuts tucked under the crown.
    final nut = Paint()..color = palm;
    canvas.drawCircle(crown + Offset(-s * 0.055, s * 0.03), s * 0.045, nut);
    canvas.drawCircle(crown + Offset(s * 0.055, s * 0.035), s * 0.038, nut);

    // Five fronds fanning from the crown.
    stroke.strokeWidth = s * 0.055;
    final tips = <Offset>[
      Offset(s * 0.06, s * 0.44),
      Offset(s * 0.18, s * 0.24),
      Offset(s * 0.44, s * 0.12),
      Offset(s * 0.72, s * 0.16),
      Offset(s * 0.90, s * 0.34),
    ];
    for (final tip in tips) {
      final ctrl = Offset(
        crown.dx + (tip.dx - crown.dx) * 0.4,
        crown.dy + (tip.dy - crown.dy) * 0.15 - s * 0.06,
      );
      canvas.drawPath(
        Path()
          ..moveTo(crown.dx, crown.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogoMarkPainter old) =>
      old.palm != palm || old.sun != sun;
}
