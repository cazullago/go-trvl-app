import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/affiliate_service.dart';
import '../services/database_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/affiliate_buttons.dart';
import 'pin_detail_sheet.dart';

/// Full destination detail: overview, places, food, stay and travel tips.
class DestinationDetailScreen extends StatefulWidget {
  final Destination destination;
  const DestinationDetailScreen({super.key, required this.destination});

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _CatMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _CatMeta(this.label, this.icon, this.color);
}

_CatMeta _catMeta(String key) =>
    const {
      'where_to_go':
          _CatMeta('Where to go', Icons.place_rounded, BohoColors.terracotta),
      'things_to_do': _CatMeta(
          'Things to do', Icons.kayaking_rounded, BohoColors.dustyBlue),
      'where_to_eat':
          _CatMeta('Where to eat', Icons.restaurant_rounded, BohoColors.forest),
      'where_to_stay':
          _CatMeta('Where to stay', Icons.hotel_rounded, BohoColors.dustyBlue),
      'where_to_buy': _CatMeta(
          'Where to buy', Icons.shopping_bag_rounded, BohoColors.terracotta),
      'how_to_get_around': _CatMeta(
          'Get around', Icons.directions_bus_rounded, BohoColors.espresso),
    }[key] ??
    const _CatMeta('Place', Icons.place_rounded, BohoColors.forest);

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  Set<String> _doneIds = {};

  @override
  void initState() {
    super.initState();
    _loadDone();
  }

  Future<void> _loadDone() async {
    final uid = context.read<AuthService>().user?.uid;
    if (uid == null) return;
    try {
      final ids = await DatabaseService().donePlaceIds(uid);
      if (mounted) setState(() => _doneIds = ids);
    } catch (_) {}
  }

  Future<void> _markDone(Place p) async {
    final uid = context.read<AuthService>().user?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sign in to earn points for visited places.')));
      return;
    }
    if (_doneIds.contains(p.id)) return;
    try {
      final earned = await DatabaseService().markPlaceDone(uid, p);
      await context.read<AuthService>().refreshUser();
      if (!mounted) return;
      setState(() => _doneIds = {..._doneIds, p.id});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(earned > 0
            ? '+$earned pts for ${p.name}. Nice!'
            : '${p.name} was already counted.'),
        backgroundColor: BohoColors.forest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not save. Check your connection and try again.'),
      ));
    }
  }

  void _openPin(Place p) {
    showPinDetailSheet(
      context,
      place: p,
      destination: widget.destination,
      onDoneMarked: _loadDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.destination;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: BohoColors.cream,
        body: SafeArea(
          child: Column(
            children: [
              _hero(d),
              _affiliateRow(d),
              _tabBar(),
              Expanded(
                child: TabBarView(
                  children: [
                    _overviewTab(d),
                    _placesTab([
                      ...d.placesIn('where_to_go'),
                      ...d.placesIn('things_to_do'),
                    ], 'Places to visit and things to do'),
                    _placesTab(d.placesIn('where_to_eat'), 'Where to eat'),
                    _placesTab(d.placesIn('where_to_stay'), 'Where to stay'),
                    _tipsTab(d),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(Destination d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [BohoColors.forest, BohoColors.espresso],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: BohoFonts.heading(30, color: Colors.white)),
                const SizedBox(height: 4),
                Text(d.tagline,
                    style: BohoFonts.body(15,
                        color: Colors.white, weight: FontWeight.w600)),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${d.region} · ${d.province} · ${d.places.length} places',
                    style: BohoFonts.body(12,
                        color: Colors.white, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Affiliate partner buttons under the header. Hidden automatically
  /// when there are no links (affiliates disabled or unconfigured).
  Widget _affiliateRow(Destination d) {
    final links = AffiliateService().linksForDestination(d);
    if (links.isEmpty) return const SizedBox.shrink();
    return Container(
      color: BohoColors.cream,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: AffiliateButtons(links: links),
    );
  }

  Widget _tabBar() {
    return Container(
      color: BohoColors.cream,
      child: TabBar(
        isScrollable: true,
        labelColor: BohoColors.forest,
        unselectedLabelColor: BohoColors.espresso,
        indicatorColor: BohoColors.forest,
        indicatorWeight: 3,
        labelStyle: BohoFonts.body(14,
            color: BohoColors.forest, weight: FontWeight.w800),
        unselectedLabelStyle: BohoFonts.body(14,
            color: BohoColors.espresso, weight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Places'),
          Tab(text: 'Food'),
          Tab(text: 'Stay'),
          Tab(text: 'Tips'),
        ],
      ),
    );
  }

  Widget _overviewTab(Destination d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        _overviewSection('About', d.description),
        _overviewSection('Why travelers love it', d.whyPopular),
        _infoRow(Icons.wb_sunny_rounded, 'Best time to go', d.bestTime,
            BohoColors.terracotta),
        _infoRow(Icons.flight_takeoff_rounded, 'How to get there',
            d.howToGetThere, BohoColors.dustyBlue),
      ],
    );
  }

  Widget _overviewSection(String title, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: BohoFonts.heading(18, color: BohoColors.espresso)),
          const SizedBox(height: 6),
          Text(body, style: BohoFonts.body(15, color: BohoColors.espresso)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String body, Color accent) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BohoColors.tan.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: BohoFonts.body(14,
                        color: BohoColors.espresso, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(body,
                    style: BohoFonts.body(14, color: BohoColors.espresso)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placesTab(List<Place> places, String emptyMsg) {
    if (places.isEmpty) {
      return Center(
        child: Text(emptyMsg,
            style: BohoFonts.body(15, color: BohoColors.espresso)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      itemCount: places.length,
      itemBuilder: (_, i) => _placeRow(places[i]),
    );
  }

  Widget _placeRow(Place p) {
    final done = _doneIds.contains(p.id);
    final meta = _catMeta(p.category);
    final sub = [p.area, p.priceRange].where((s) => s.isNotEmpty).join(' · ');
    return InkWell(
      onTap: () => _openPin(p),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BohoColors.tan.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(meta.icon, color: meta.color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: BohoFonts.body(15,
                          color: BohoColors.espresso, weight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (sub.isNotEmpty)
                    Text(sub,
                        style: BohoFonts.body(12,
                            color: BohoColors.espresso,
                            weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: BohoColors.forest.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('+${p.points}',
                  style: BohoFonts.body(12,
                      color: BohoColors.forest, weight: FontWeight.w800)),
            ),
            const SizedBox(width: 4),
            if (done)
              const Icon(Icons.check_circle_rounded, color: BohoColors.forest)
            else
              TextButton(
                onPressed: () => _markDone(p),
                style: TextButton.styleFrom(
                  foregroundColor: BohoColors.forest,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Mark done',
                    style: BohoFonts.body(12,
                        color: BohoColors.forest, weight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tipsTab(Destination d) {
    final buy = d.placesIn('where_to_buy');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        if (buy.isNotEmpty) ...[
          Text('Where to buy',
              style: BohoFonts.heading(18, color: BohoColors.espresso)),
          const SizedBox(height: 10),
          for (final p in buy) _placeRow(p),
          const SizedBox(height: 10),
        ],
        Text('How to get around',
            style: BohoFonts.heading(18, color: BohoColors.espresso)),
        const SizedBox(height: 10),
        for (final t in d.transport) _transportRow(t),
        if (d.transport.isEmpty)
          Text('No transport notes for this destination yet.',
              style: BohoFonts.body(14, color: BohoColors.espresso)),
      ],
    );
  }

  Widget _transportRow(TransportOption t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BohoColors.tan.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.type,
                    style: BohoFonts.body(15,
                        color: BohoColors.espresso, weight: FontWeight.w800)),
              ),
              Text(t.priceRange,
                  style: BohoFonts.body(13,
                      color: BohoColors.forest, weight: FontWeight.w800)),
            ],
          ),
          if (t.useCase.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(t.useCase,
                style: BohoFonts.body(13,
                    color: BohoColors.espresso, weight: FontWeight.w600)),
          ],
          if (t.notes.isNotEmpty)
            Text(t.notes,
                style: BohoFonts.body(13, color: BohoColors.espresso)),
        ],
      ),
    );
  }
}
