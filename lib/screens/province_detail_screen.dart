import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/tropical_corners.dart';
import 'destination_detail_screen.dart';

/// Province detail: gradient header, about, tags and the destination
/// guides linked to this province.
class ProvinceDetailScreen extends StatelessWidget {
  final Province province;

  const ProvinceDetailScreen({super.key, required this.province});

  @override
  Widget build(BuildContext context) {
    final guides = DataService().destinationsByProvince(province.id);

    return Scaffold(
      backgroundColor: BohoColors.cream,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: TropicalCorners()),
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: CircleAvatar(
                      backgroundColor: BohoColors.cream.withValues(alpha: 0.9),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: BohoColors.espresso),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  expandedHeight: 220,
                  pinned: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [BohoColors.forest, BohoColors.dustyBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(province.name,
                                style: BohoFonts.headline(32,
                                    color: Colors.white)),
                            const SizedBox(height: 6),
                            Text('Capital: ${province.capital}',
                                style: BohoFonts.body(14,
                                    color: Colors.white,
                                    weight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(
                              province.tagline,
                              style: const TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'About'),
                        const SizedBox(height: 8),
                        Text(province.description,
                            style: BohoFonts.body(14,
                                color: BohoColors.espresso
                                    .withValues(alpha: 0.8))),
                        if (province.tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: province.tags
                                .map(
                                  (t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: BohoColors.cream,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: BohoColors.tan, width: 1),
                                    ),
                                    child: Text(
                                      t,
                                      style: BohoFonts.body(12,
                                          weight: FontWeight.w600),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SectionHeader(
                            title: 'Where to Go (${province.cities.length})'),
                        const SizedBox(height: 4),
                        Text(
                          'Cities and towns of ${province.name}',
                          style: BohoFonts.body(12,
                              color:
                                  BohoColors.espresso.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 12),
                        if (province.cities.isEmpty)
                          Container(
                            width: double.infinity,
                            decoration: BohoDecor.card(),
                            padding: const EdgeInsets.all(20),
                            child: const Text(
                              'City list coming soon.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...province.cities.map((c) => _CityRow(city: c)),
                        const SizedBox(height: 24),
                        SectionHeader(
                            title: 'Tourist destinations (${guides.length})'),
                        const SizedBox(height: 12),
                        if (guides.isEmpty)
                          Container(
                            width: double.infinity,
                            decoration: BohoDecor.card(),
                            padding: const EdgeInsets.all(20),
                            child: const Text(
                              'No detailed guides yet for this province. Check back soon.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...guides.map((d) => _GuideRow(destination: d)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  final ProvinceCity city;

  const _CityRow({required this.city});

  @override
  Widget build(BuildContext context) {
    final isCity = city.isCity;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BohoDecor.card(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCity
                    ? BohoColors.forest.withValues(alpha: 0.12)
                    : BohoColors.tan.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                isCity
                    ? Icons.location_city_rounded
                    : Icons.location_on_outlined,
                color: isCity ? BohoColors.forest : BohoColors.espresso,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(city.name,
                  style: BohoFonts.body(14, weight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCity
                    ? BohoColors.forest.withValues(alpha: 0.12)
                    : BohoColors.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isCity
                        ? BohoColors.forest.withValues(alpha: 0.4)
                        : BohoColors.tan,
                    width: 1),
              ),
              child: Text(
                isCity ? 'City' : 'Town',
                style: BohoFonts.body(11,
                    weight: FontWeight.w700,
                    color: isCity
                        ? BohoColors.forest
                        : BohoColors.espresso.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  final Destination destination;

  const _GuideRow({required this.destination});

  @override
  Widget build(BuildContext context) {
    final placeCount = destination.places.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DestinationDetailScreen(destination: destination),
          ),
        ),
        child: Container(
          decoration: BohoDecor.card(),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [BohoColors.terracotta, BohoColors.tan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  destination.name.isNotEmpty ? destination.name[0] : '?',
                  style: BohoFonts.headline(24, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(destination.name,
                        style: BohoFonts.headline(16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(destination.tagline,
                        style: BohoFonts.body(12,
                            color: BohoColors.espresso.withValues(alpha: 0.65)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '$placeCount place${placeCount == 1 ? '' : 's'}',
                      style: BohoFonts.body(11,
                          color: BohoColors.dustyBlue, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: BohoColors.tan),
            ],
          ),
        ),
      ),
    );
  }
}
