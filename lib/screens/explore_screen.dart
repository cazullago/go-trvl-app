import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/tropical_corners.dart';
import 'destination_detail_screen.dart';
import 'province_detail_screen.dart';

/// Discover Philippines: two browse layers (provinces + destinations)
/// under a single serif header, with a search field, layer toggle chips
/// and horizontal scrolling cards.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

enum _Layer { provinces, destinations }

const _regions = ['All', 'Luzon', 'Visayas', 'Mindanao'];

class _ExploreScreenState extends State<ExploreScreen> {
  _Layer _layer = _Layer.provinces;
  String _query = '';
  String _region = 'All';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    DataService().load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  List<Province> get _filteredProvinces {
    final q = _query.trim().toLowerCase();
    return DataService().provinces.where((p) {
      if (_region != 'All' && p.region != _region) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.capital.toLowerCase().contains(q) ||
          p.tagline.toLowerCase().contains(q);
    }).toList();
  }

  List<Destination> get _filteredDestinations {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return DataService().destinations;
    return DataService().destinations.where((d) {
      return d.name.toLowerCase().contains(q) ||
          d.province.toLowerCase().contains(q) ||
          d.tagline.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provinceCount = DataService().provinces.length;
    final destinationCount = DataService().destinations.length;

    return Scaffold(
      backgroundColor: BohoColors.cream,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: TropicalCorners()),
            if (!_ready)
              const Center(
                  child: CircularProgressIndicator(color: BohoColors.forest))
            else
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Discover Philippines', style: BohoFonts.headline(30)),
                    const SizedBox(height: 4),
                    Text('Featured destinations for you',
                        style: BohoFonts.body(14,
                            color: BohoColors.espresso.withValues(alpha: 0.6))),
                    const SizedBox(height: 16),
                    _buildLayerChips(provinceCount, destinationCount),
                    const SizedBox(height: 14),
                    SearchBarField(
                      hint: _layer == _Layer.provinces
                          ? 'Search provinces'
                          : 'Search destinations',
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 14),
                    if (_layer == _Layer.provinces) _buildRegionFilter(),
                    if (_layer == _Layer.provinces) const SizedBox(height: 12),
                    SizedBox(
                      height: 250,
                      child: _layer == _Layer.provinces
                          ? _buildProvinceCards()
                          : _buildDestinationCards(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerChips(int provinceCount, int destinationCount) {
    return Row(
      children: [
        _layerChip(
          active: _layer == _Layer.provinces,
          label: '🇵🇭 $provinceCount places',
          onTap: () => setState(() => _layer = _Layer.provinces),
        ),
        const SizedBox(width: 10),
        _layerChip(
          active: _layer == _Layer.destinations,
          label: '🌐 $destinationCount places',
          onTap: () => setState(() => _layer = _Layer.destinations),
        ),
      ],
    );
  }

  Widget _layerChip(
      {required bool active,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? BohoColors.terracotta : BohoColors.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? BohoColors.terracotta : BohoColors.tan,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: BohoFonts.body(13,
              color: active ? Colors.white : BohoColors.espresso,
              weight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildRegionFilter() {
    return Wrap(
      spacing: 8,
      children: _regions.map((r) {
        final active = _region == r;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _region = r),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active ? BohoColors.espresso : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BohoColors.tan, width: 1),
            ),
            child: Text(
              r,
              style: BohoFonts.body(12,
                  color: active
                      ? BohoColors.cream
                      : BohoColors.espresso.withValues(alpha: 0.7),
                  weight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProvinceCards() {
    final items = _filteredProvinces;
    if (items.isEmpty) {
      return const EmptyState(text: 'No provinces match your search.');
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, i) {
        final p = items[i];
        return _ExploreCard(
          badge: p.region,
          initial: p.name,
          name: p.name,
          tagline: p.tagline,
          tags: p.tags,
          photoGradient: const LinearGradient(
            colors: [BohoColors.forest, BohoColors.dustyBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProvinceDetailScreen(province: p),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDestinationCards() {
    final items = _filteredDestinations;
    if (items.isEmpty) {
      return const EmptyState(text: 'No destinations match your search.');
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, i) {
        final d = items[i];
        return _ExploreCard(
          badge: d.region.isNotEmpty ? d.region : d.province,
          initial: d.name,
          name: d.name,
          tagline: d.tagline,
          tags: const [],
          photoGradient: const LinearGradient(
            colors: [BohoColors.terracotta, BohoColors.tan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DestinationDetailScreen(destination: d),
            ),
          ),
        );
      },
    );
  }
}

/// Horizontal browse card: gradient photo area with a big serif initial,
/// region badge, serif name, italic tagline and tag chips.
class _ExploreCard extends StatelessWidget {
  final String badge;
  final String initial;
  final String name;
  final String tagline;
  final List<String> tags;
  final Gradient photoGradient;
  final VoidCallback onTap;

  const _ExploreCard({
    required this.badge,
    required this.initial,
    required this.name,
    required this.tagline,
    required this.tags,
    required this.photoGradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BohoDecor.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo area.
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: photoGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          initial.isNotEmpty ? initial[0] : '?',
                          style: BohoFonts.headline(72,
                              color: Colors.white.withValues(alpha: 0.55)),
                        ),
                      ),
                    ),
                    if (badge.isNotEmpty)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: BohoColors.dustyBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badge,
                            style: BohoFonts.body(11,
                                color: Colors.white, weight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Text area.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: BohoFonts.headline(18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    tagline,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: BohoColors.espresso.withValues(alpha: 0.65),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags
                          .take(3)
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: BohoColors.cream,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: BohoColors.tan, width: 1),
                              ),
                              child: Text(
                                t,
                                style:
                                    BohoFonts.body(10, weight: FontWeight.w600),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
