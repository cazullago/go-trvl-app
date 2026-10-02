import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/boho_theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/affiliate_service.dart';
import '../services/database_service.dart';
import '../widgets/affiliate_buttons.dart';

/// Shared entry point for opening a pin's detail sheet: resolves the
/// signed-in user's done state and presents [PinDetailSheet].
Future<void> showPinDetailSheet(
  BuildContext context, {
  required Place place,
  required Destination destination,
  VoidCallback? onDoneMarked,
}) async {
  final uid = Provider.of<AuthService>(context, listen: false).user?.uid;
  Set<String> doneIds = const {};
  if (uid != null) {
    try {
      doneIds = await DatabaseService().donePlaceIds(uid);
    } catch (_) {}
  }
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PinDetailSheet(
      place: place,
      destination: destination,
      alreadyDone: doneIds.contains(place.id),
      onDoneMarked: onDoneMarked ?? () {},
    ),
  );
}

class _PinCatMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _PinCatMeta(this.label, this.icon, this.color);
}

_PinCatMeta _pinCatMeta(String key) =>
    const {
      'where_to_go': _PinCatMeta(
          'Where to go', Icons.place_rounded, BohoColors.terracotta),
      'things_to_do': _PinCatMeta(
          'Things to do', Icons.kayaking_rounded, BohoColors.dustyBlue),
      'where_to_eat': _PinCatMeta(
          'Where to eat', Icons.restaurant_rounded, BohoColors.forest),
      'where_to_stay': _PinCatMeta(
          'Where to stay', Icons.hotel_rounded, BohoColors.dustyBlue),
      'where_to_buy': _PinCatMeta(
          'Where to buy', Icons.shopping_bag_rounded, BohoColors.terracotta),
      'how_to_get_around': _PinCatMeta(
          'Get around', Icons.directions_bus_rounded, BohoColors.espresso),
    }[key] ??
    const _PinCatMeta('Place', Icons.place_rounded, BohoColors.forest);

/// Bottom sheet with full place details + "Mark as done" + directions.
class PinDetailSheet extends StatefulWidget {
  final Place place;
  final Destination destination;
  final bool alreadyDone;
  final VoidCallback onDoneMarked;

  const PinDetailSheet(
      {super.key,
      required this.place,
      required this.destination,
      required this.alreadyDone,
      required this.onDoneMarked});

  @override
  State<PinDetailSheet> createState() => _PinDetailSheetState();
}

class _PinDetailSheetState extends State<PinDetailSheet> {
  bool _busy = false;
  late bool _done;

  @override
  void initState() {
    super.initState();
    _done = widget.alreadyDone;
  }

  Future<void> _markDone() async {
    final uid = context.read<AuthService>().user?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final earned = await DatabaseService().markPlaceDone(uid, widget.place);
      await context.read<AuthService>().refreshUser();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
      widget.onDoneMarked();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(earned > 0
              ? '+$earned pts for ${widget.place.name}. Nice!'
              : 'Already counted. Nice memory lane!'),
          backgroundColor: BohoColors.forest,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (_) {
      // Never leave the button stuck in its loading state.
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save. Check your connection and try again.'),
        ),
      );
    }
  }

  Future<void> _directions() async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${widget.place.lat},${widget.place.lng}&travelmode=driving');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final meta = _pinCatMeta(p.category);
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: BohoColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.zero,
          children: [
            // Hero header
            Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [BohoColors.forest, BohoColors.espresso],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(meta.icon, size: 15, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(meta.label,
                                style: BohoFonts.body(12,
                                    color: Colors.white,
                                    weight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('+${p.points} pts',
                            style: BohoFonts.body(13,
                                color: BohoColors.forest,
                                weight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(p.name,
                      style: BohoFonts.heading(30, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('${p.placeType} · ${widget.destination.name}',
                      style: BohoFonts.body(14,
                          color: Colors.white, weight: FontWeight.w600)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.description,
                      style: BohoFonts.body(15, color: BohoColors.espresso)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _fact(Icons.payments_outlined, 'Price', p.priceRange),
                      _fact(Icons.place_outlined, 'Area', p.area),
                      if (p.bestTime.isNotEmpty)
                        _fact(Icons.wb_sunny_outlined, 'Best time', p.bestTime),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_done || _busy) ? null : _markDone,
                      icon: Icon(_done
                          ? Icons.check_circle_rounded
                          : Icons.flag_rounded),
                      label: Text(_done
                          ? 'Visited'
                          : _busy
                              ? 'Saving...'
                              : 'Mark as Done (+${p.points} pts)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BohoColors.forest,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            BohoColors.forest.withValues(alpha: 0.6),
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: BohoFonts.body(16, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _directions,
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('Get Directions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BohoColors.espresso,
                        side: const BorderSide(
                            color: BohoColors.espresso, width: 1.6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: BohoFonts.body(16, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                  _affiliateSection(p),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Affiliate partner buttons for this place. Hidden automatically
  /// when there are no links (affiliates disabled or unconfigured).
  Widget _affiliateSection(Place p) {
    final links = AffiliateService().linksForPlace(p);
    if (links.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        AffiliateButtons(links: links),
      ],
    );
  }

  Widget _fact(IconData icon, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BohoColors.tan.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: BohoColors.forest),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: BohoFonts.body(11,
                      color: BohoColors.espresso, weight: FontWeight.w700)),
              Text(value,
                  style: BohoFonts.body(14,
                      color: BohoColors.espresso, weight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}
