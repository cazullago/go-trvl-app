import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/boho_theme.dart';

/// Rounded level pill: level emoji + "Lv.N" (TravelLevel.of).
/// Tan background, espresso text — matches the boho mockup palette.
class LevelBadge extends StatelessWidget {
  final int points;
  final bool hasAllStamps;
  final double fontSize;

  const LevelBadge({
    super.key,
    required this.points,
    this.hasAllStamps = false,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final level = TravelLevel.of(points, hasAllStamps: hasAllStamps);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BohoColors.tan,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(level.emoji, style: TextStyle(fontSize: fontSize + 2)),
          const SizedBox(width: 4),
          Text(
            'Lv.${level.levelNumber}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: BohoColors.espresso,
            ),
          ),
        ],
      ),
    );
  }
}
