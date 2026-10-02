import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/monetization_models.dart';
import '../theme/boho_theme.dart';
import '../screens/business_hub_screen.dart';

/// Ad unit that is visually DISTINCT from editorial content: dashed
/// terracotta border, an "Ad"/"Sponsored" tag, and a cream background.
/// Ads are never mistakable for editorial recommendations.
///
/// Tap behavior: an explicit [onTap] wins; otherwise a house ad pushes
/// [BusinessHubScreen], and a third-party ad opens its [AdPlacement]
/// target URL in the external browser.
class AdCard extends StatelessWidget {
  final AdPlacement placement;
  final VoidCallback? onTap;

  const AdCard({super.key, required this.placement, this.onTap});

  Future<void> _defaultTap(BuildContext context) async {
    if (onTap != null) {
      onTap!();
      return;
    }
    if (placement.isHouseAd) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BusinessHubScreen()),
      );
      return;
    }
    final target = placement.targetUrl;
    if (target.isNotEmpty) {
      final uri = Uri.tryParse(target);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DashedBorder(
      color: BohoColors.terracotta,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _defaultTap(context),
        child: Container(
          decoration: BoxDecoration(
            color: BohoColors.cream,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  if (placement.imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: placement.imageUrl,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 120,
                          color: BohoColors.tan.withValues(alpha: 0.4),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 120,
                          color: BohoColors.tan.withValues(alpha: 0.4),
                          child: const Icon(Icons.image_not_supported_rounded,
                              color: BohoColors.espresso),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [BohoColors.terracotta, BohoColors.tan],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.campaign_rounded,
                            color: Colors.white, size: 36),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BohoColors.espresso,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        placement.isHouseAd ? 'Ad' : 'Sponsored',
                        style: BohoFonts.body(11,
                            color: Colors.white, weight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(placement.title,
                        style:
                            BohoFonts.heading(16, color: BohoColors.espresso),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          placement.ctaLabel,
                          style: BohoFonts.body(14,
                              color: BohoColors.forest,
                              weight: FontWeight.w800),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 18, color: BohoColors.forest),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded-rectangle dashed border, drawn with a custom painter since
/// Border.all cannot dash.
class _DashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;

  const _DashedBorder({required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color: color, radius: 18),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    const dashLen = 7.0;
    const gapLen = 5.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
