import 'package:flutter/material.dart';
import '../theme/boho_theme.dart';
import '../models/models.dart';

/// Destination overview: description, best time, how to get there,
/// categorized place lists and transport options.
class DestinationSheet extends StatelessWidget {
  final Destination destination;
  final Set<String> doneIds;
  final void Function(Place place) onPlaceTap;

  const DestinationSheet(
      {super.key,
      required this.destination,
      required this.doneIds,
      required this.onPlaceTap});

  @override
  Widget build(BuildContext context) {
    final d = destination;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: BohoColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          children: [
            Center(
              child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                      color: BohoColors.sandDark,
                      borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 14),
            Text(d.name, style: BohoFonts.display(38)),
            Text(d.tagline,
                style: BohoFonts.body(15,
                    color: BohoColors.coralDeep, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(d.description,
                style: BohoFonts.body(15, weight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('Why travelers love it: ${d.whyPopular}',
                style: BohoFonts.body(14,
                    color: BohoColors.cocoaSoft, weight: FontWeight.w600)),
            const SizedBox(height: 16),
            _infoCard(Icons.wb_sunny_rounded, 'Best time to go', d.bestTime,
                BohoColors.sun),
            const SizedBox(height: 10),
            _infoCard(Icons.flight_takeoff_rounded, 'How to get there',
                d.howToGetThere, BohoColors.ocean),
            const SizedBox(height: 20),
            for (final cat in MapCategory.list) ...[
              _sectionTitle('${_emoji(cat.key)} ${cat.label}'),
              const SizedBox(height: 8),
              ...d.placesIn(cat.key).map((p) => _placeRow(context, p)),
              const SizedBox(height: 14),
            ],
            _sectionTitle('🛺 How to Get Around'),
            const SizedBox(height: 8),
            ...d.transport.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BohoDecor.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(t.type,
                                  style: BohoFonts.body(15,
                                      weight: FontWeight.w800))),
                          Text(t.priceRange,
                              style: BohoFonts.body(13,
                                  color: BohoColors.leafDeep,
                                  weight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(t.useCase,
                          style: BohoFonts.body(13, weight: FontWeight.w600)),
                      Text(t.notes,
                          style:
                              BohoFonts.body(13, color: BohoColors.cocoaSoft)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _emoji(String key) =>
      {
        'where_to_go': '🏝️',
        'things_to_do': '🤿',
        'where_to_eat': '🍜',
        'where_to_stay': '🏨',
        'where_to_buy': '🛍️',
      }[key] ??
      '📍';

  Widget _sectionTitle(String text) =>
      Text(text, style: BohoFonts.display(26, color: BohoColors.oceanDeep));

  Widget _infoCard(IconData icon, String title, String body, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BohoDecor.card(color: accent.withValues(alpha: 0.10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: BohoFonts.body(14, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(body, style: BohoFonts.body(14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeRow(BuildContext context, Place p) {
    final done = doneIds.contains(p.id);
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onPlaceTap(p);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BohoDecor.card(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (done ? BohoColors.leaf : BohoColors.coral)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                  child: Text(done ? '✓' : _emoji(p.category),
                      style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: BohoFonts.body(15, weight: FontWeight.w800)),
                  Text('${p.placeType} · ${p.priceRange}',
                      style: BohoFonts.body(12,
                          color: BohoColors.cocoaSoft,
                          weight: FontWeight.w600)),
                ],
              ),
            ),
            Text('+${p.points}',
                style: BohoFonts.body(13,
                    color: BohoColors.coralDeep, weight: FontWeight.w800)),
            const Icon(Icons.chevron_right_rounded,
                color: BohoColors.cocoaSoft),
          ],
        ),
      ),
    );
  }
}
