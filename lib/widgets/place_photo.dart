import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/boho_theme.dart';

/// Curated real photo URLs keyed by place id.
///
/// EMPTY ON PURPOSE (2026-09-30): every Wikimedia Commons candidate was
/// left unverified — the Commons API refused access (HTTP 403) from this
/// environment, and per the "if unsure, omit it" rule no guessed
/// upload.wikimedia.org URL was included. Everything currently falls back
/// to a seeded picsum image below.
///
/// To add real photos later: verify the filename exists on Commons
/// (https://commons.wikimedia.org/wiki/Special:FilePath/<name> resolves
/// to the real upload.wikimedia.org file), then add
///   '<placeId>': 'https://upload.wikimedia.org/wikipedia/commons/thumb/…'
/// entries here.
const Map<String, String> _curatedPhotos = <String, String>{};

/// Photo URL for a place card / detail header.
///
/// Returns the curated real photo when one exists for [placeId];
/// otherwise a stable seeded placeholder:
/// `https://picsum.photos/seed/<placeId>/600/400`.
String placePhotoUrl(String placeId, String placeName) {
  final curated = _curatedPhotos[placeId];
  if (curated != null && curated.isNotEmpty) return curated;
  return 'https://picsum.photos/seed/${Uri.encodeComponent(placeId)}/600/400';
}

/// Extra gallery photos for a place detail page. The first entry matches
/// [placePhotoUrl]; the rest are stable seeded variants so the gallery
/// always has 6 images even without curated photos.
List<String> placeGalleryUrls(String placeId, String placeName) {
  return List<String>.generate(
    6,
    (i) => i == 0
        ? placePhotoUrl(placeId, placeName)
        : 'https://picsum.photos/seed/${Uri.encodeComponent('${placeId}_$i')}/600/400',
  );
}

/// Network photo with a shimmer placeholder and a boho gradient fallback.
class PlacePhoto extends StatelessWidget {
  final String placeId;
  final String placeName;

  /// Direct override URL (e.g. a gallery variant). Defaults to
  /// [placePhotoUrl].
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const PlacePhoto({
    super.key,
    required this.placeId,
    required this.placeName,
    this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl ?? placePhotoUrl(placeId, placeName);
    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => ShimmerBox(width: width, height: height),
        errorWidget: (_, __, ___) => Container(
          width: width,
          height: height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [BohoColors.ocean, BohoColors.forest],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Text('🏝️', style: TextStyle(fontSize: 40)),
          ),
        ),
      ),
    );
  }
}

/// Lightweight shimmer placeholder used while photos (and weather) load.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => ClipRRect(
        borderRadius: widget.borderRadius,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                BohoColors.sandDark.withValues(alpha: 0.35 + 0.25 * _ctrl.value),
                BohoColors.cream,
                BohoColors.sandDark.withValues(alpha: 0.35 + 0.25 * _ctrl.value),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    );
  }
}
