import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../models/monetization_models.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/data_service.dart';
import '../services/game_service.dart';
import '../services/permission_service.dart';
import '../services/quest_service.dart';
import '../services/weather_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/place_photo.dart';
import '../widgets/store_price_text.dart';
import 'marketplace_screen.dart';
import 'place_detail_sheet.dart';
import 'province_explore_screen.dart';

/// Filter metadata for the quest pins. One distinct marker style per
/// filter: coral pushpin, gold star, orchid rice-bowl.
class _FilterMeta {
  final String key;
  final String label;
  final String emoji;
  final Color color;
  const _FilterMeta(this.key, this.label, this.emoji, this.color);
}

const _filters = [
  _FilterMeta('where_to_go', 'Where to Go', '📌', BohoColors.pinWhereToGo),
  _FilterMeta('things_to_do', 'Things to Do', '⭐', BohoColors.pinThingsToDo),
  _FilterMeta('where_to_eat', 'Where to Eat', '🍚', BohoColors.pinWhereToEat),
];

_FilterMeta _filterMeta(String key) =>
    _filters.firstWhere((f) => f.key == key, orElse: () => _filters[0]);

/// Map tab: a real Philippines map (OpenStreetMap tiles, pinch-to-zoom)
/// that opens on the 83 province pins + 37 destination pins.
///
/// Tapping a province zooms to it and opens its Explore page; tapping a
/// destination zooms to it and reveals its filter buttons (Where to Go /
/// Things to Do / Where to Eat) scoped to that place — the filter quest
/// pins then appear on the zoomed map.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Destination> _destinations = [];
  List<Province> _provinces = [];
  List<QuestPlace> _quests = [];
  List<BusinessListing> _questStops = [];
  Map<String, bool> _unlocked = {};
  Set<String> _doneIds = {};

  // Marker layers (toggled by the 83 / 37 chips).
  bool _showProvinces = true;
  bool _showDestinations = true;

  // Selection: exactly one destination at a time; provinces push a page.
  Destination? _selDestination;
  String? _activeFilter;
  List<QuestPlace> _scopedQuests = [];
  WeatherNow? _selWeather;

  double? _userLat;
  double? _userLng;
  bool _loading = true;
  bool _locating = false;
  bool _labelsOn = false;

  // Search state.
  bool _searching = false;
  List<Province> _provHits = [];
  List<Destination> _destHits = [];
  List<QuestPlace> _questHits = [];

  static const _phCenter = LatLng(12.8797, 121.7740);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await DataService().load();
    await QuestService().load();
    _destinations = DataService().destinations;
    _provinces = DataService().provinces;
    _quests = QuestService().all;
    final user = context.read<AuthService>().user;
    if (user != null) _doneIds = Set.of(user.donePlaceIds);
    await _refreshUnlocks();
    await _loadQuestStops();
    if (mounted) setState(() => _loading = false);
    // Ask for location after the first frame so the rationale dialog has
    // a valid context; on fix we auto-unlock nearby quest stops.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fixLocation());
  }

  // ---------- unlock state ----------

  Future<bool> _checkUnlock(AppUser user, QuestPlace q) async {
    try {
      return await GameService().isPlaceUnlocked(
        user: user,
        placeId: q.id,
        userLat: _userLat,
        userLng: _userLng,
        allPlaces: _quests,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshUnlocks() async {
    final user = context.read<AuthService>().user;
    if (user == null || _quests.isEmpty) {
      _unlocked = {for (final q in _quests) q.id: false};
      return;
    }
    final entries = await Future.wait(
        _quests.map((q) async => MapEntry(q.id, await _checkUnlock(user, q))));
    _unlocked = Map.fromEntries(entries);
  }

  Future<void> _afterUnlockChange() async {
    await _refreshUnlocks();
    if (mounted) setState(() {});
  }

  Future<void> _loadQuestStops() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('businesses')
          .where('status', isEqualTo: 'approved')
          .where('isQuestStop', isEqualTo: true)
          .get();
      _questStops = snap.docs
          .map((d) => BusinessListing.fromMap(d.id, d.data()))
          .where((b) => b.lat != 0 && b.lng != 0)
          .toList();
    } catch (_) {
      _questStops = [];
    }
  }

  // ---------- location ----------

  static double _km(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return 2 * r * asin(sqrt(a));
  }

  Future<void> _fixLocation() async {
    if (_locating) return;
    _locating = true;
    try {
      final ok = await PermissionService().ensureLocation(
          context, 'to unlock nearby places and grant passport stamps');
      if (!ok) return;
      final pos = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.high))
          .timeout(const Duration(seconds: 12));
      final before =
          _unlocked.entries.where((e) => e.value).map((e) => e.key).toSet();
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      await _refreshUnlocks();
      final after =
          _unlocked.entries.where((e) => e.value).map((e) => e.key).toSet();
      final fresh = after.difference(before);

      // Grant a passport stamp for the nearest quest stop.
      QuestPlace? nearest;
      var best = double.infinity;
      for (final q in _quests) {
        final d = _km(_userLat!, _userLng!, q.lat, q.lng);
        if (d < best) {
          best = d;
          nearest = q;
        }
      }
      var stamped = false;
      final user = context.read<AuthService>().user;
      if (nearest != null && user != null) {
        stamped = await GameService().grantStampIfNearby(
          uid: user.uid,
          place: nearest,
          userLat: _userLat!,
          userLng: _userLng!,
        );
      }
      if (!mounted) return;
      setState(() {});
      if (fresh.isNotEmpty) {
        _snack(
            '📍 ${fresh.length} quest stop${fresh.length == 1 ? '' : 's'} unlocked near you!');
      }
      if (stamped && nearest != null) {
        _snack('🏅 Passport stamp earned: ${nearest.name}! +200 pts');
      }
    } catch (_) {
      // Location unavailable: the map stays fully usable without it.
    } finally {
      _locating = false;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: BohoFonts.body(14, color: Colors.white)),
      backgroundColor: BohoColors.forest,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }

  // ---------- selection ----------

  /// Tapping a destination pin or card: zoom the map to it and reveal its
  /// scoped filter buttons in the bottom sheet.
  void _selectDestination(Destination d) {
    _clearSearch();
    final scoped = _quests.where((q) => q.destination == d.name).toList();
    setState(() {
      _selDestination = d;
      _scopedQuests = scoped;
      _activeFilter = null;
      _selWeather = null;
    });
    _mapController.move(LatLng(d.centerLat, d.centerLng), 10.5);
    _sheetController.animateTo(0.62,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    _loadSelWeather(d.centerLat, d.centerLng);
  }

  /// Tapping a province pin or card: zoom the map to it, then open its
  /// Explore page (hero, overview, Explore grid, points, memories).
  void _selectProvince(Province p) {
    _clearSearch();
    _mapController.move(LatLng(p.lat, p.lng), 8.5);
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProvinceExploreScreen(province: p)));
  }

  void _clearSelection() {
    setState(() {
      _selDestination = null;
      _activeFilter = null;
      _scopedQuests = [];
      _selWeather = null;
    });
    _mapController.move(_phCenter, 5.8);
    _sheetController.animateTo(0.44,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _loadSelWeather(double lat, double lng) async {
    final w = await WeatherService().current(lat, lng);
    if (!mounted) return;
    setState(() => _selWeather = w);
  }

  void _onFilterTap(String key) {
    // Tapping the active filter again hides its pins.
    setState(() => _activeFilter = _activeFilter == key ? null : key);
  }

  // ---------- opening quest places ----------

  Future<void> _onQuestTap(QuestPlace q) async {
    if (!(_unlocked[q.id] ?? false)) {
      _showUnlockSheet(q);
      return;
    }
    _mapController.move(LatLng(q.lat, q.lng), 13);
    if (!mounted) return;
    await _openPlaceDetail(q);
  }

  Future<void> _openPlaceDetail(QuestPlace q) async {
    final user = context.read<AuthService>().user;
    if (user == null) {
      _snack('Sign in to open quest details. 🌴');
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlaceDetailSheet(place: q, user: user),
    );
    if (!mounted) return;
    // Points / memories may have changed inside the sheet.
    await context.read<AuthService>().refreshUser();
    final u2 = context.read<AuthService>().user;
    if (u2 != null) _doneIds = Set.of(u2.donePlaceIds);
    await _afterUnlockChange();
  }

  void _onBizTap(BusinessListing b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: BohoColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BohoDecor.dragHandle(),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: BohoColors.sun.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('⭐ QUEST STOP',
                      style: BohoFonts.body(11,
                          color: BohoColors.espresso, weight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(b.name, style: BohoFonts.heading(22)),
            if (b.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(b.description,
                  style: BohoFonts.body(14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
            if (b.price.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(b.price,
                  style: BohoFonts.body(15,
                      color: BohoColors.terracotta, weight: FontWeight.w800)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MarketplaceScreen()));
                },
                child: const Text('View in Marketplace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- unlock upsell ----------

  void _showUnlockSheet(QuestPlace q) {
    final uid = context.read<AuthService>().user?.uid;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: BohoColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BohoDecor.dragHandle(),
            const SizedBox(height: 12),
            Text('🔒 ${q.name}', style: BohoFonts.heading(20)),
            const SizedBox(height: 6),
            Text(
              'Unlock this quest stop to open its details, earn ${q.points} pts, and collect passport stamps.',
              style: BohoFonts.body(14,
                  color: BohoColors.espresso.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 14),
            _unlockOption(
              Icons.near_me_rounded,
              Text('Visit nearby to unlock',
                  style: BohoFonts.body(15, weight: FontWeight.w800)),
              'Get within 3 km and it unlocks automatically — free.',
              () => _unlockViaProximity(q),
            ),
            _unlockOption(
              Icons.task_alt_rounded,
              Text('Complete a task',
                  style: BohoFonts.body(15, weight: FontWeight.w800)),
              'Finish a quick travel task to unlock it now (+20 pts).',
              () => _unlockViaTask(uid, q),
            ),
            _unlockOption(
              Icons.lock_open_rounded,
              StorePriceText(
                productId: BillingService.kPlaceUnlock,
                label: 'Unlock now',
                style: BohoFonts.body(15, weight: FontWeight.w800),
              ),
              'One-time unlock, yours forever.',
              () => _unlockViaPurchase(uid, q),
            ),
            _unlockOption(
              Icons.star_rounded,
              StorePriceText(
                productId: BillingService.kPremiumTraveler,
                label: 'Go Premium',
                style: BohoFonts.body(15, weight: FontWeight.w800),
              ),
              'Unlock every quest stop plus premium traveler perks.',
              _goPremium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _unlockOption(
      IconData icon, Widget title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BohoDecor.card(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: BohoColors.forest.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: BohoColors.forest),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  Text(subtitle,
                      style: BohoFonts.body(12,
                          color: BohoColors.espresso.withValues(alpha: 0.65))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BohoColors.espresso),
          ],
        ),
      ),
    );
  }

  Future<void> _unlockViaProximity(QuestPlace q) async {
    Navigator.of(context).pop();
    final ok = await PermissionService().ensureLocation(
        context, 'to unlock nearby places and grant passport stamps');
    if (!ok || !mounted) return;
    _snack('Checking your location… 📍');
    await _fixLocation();
    if (!mounted) return;
    if (_unlocked[q.id] ?? false) {
      await _onQuestTap(q);
    } else {
      _snack(
          'Not close enough yet — get within 3 km of ${q.name} to unlock it. 📍');
    }
  }

  Future<void> _unlockViaTask(String? uid, QuestPlace q) async {
    if (uid == null) {
      _snack('Sign in first to unlock quest stops. 🌴');
      return;
    }
    Navigator.of(context).pop();
    await GameService().unlockViaTask(uid, q.id);
    await _afterUnlockChange();
    if (!mounted) return;
    _snack('Unlocked! +20 pts for completing the task. 🎉');
    await _onQuestTap(q);
  }

  Future<void> _unlockViaPurchase(String? uid, QuestPlace q) async {
    if (uid == null) {
      _snack('Sign in first to unlock quest stops. 🌴');
      return;
    }
    final ok = await BillingService().buyPlaceUnlock(q.id);
    if (!mounted) return;
    if (ok) {
      await GameService().unlockPlace(uid, q.id);
      Navigator.of(context).pop();
      await _afterUnlockChange();
      if (!mounted) return;
      _snack('Unlocked — enjoy ${q.name}! 🔓');
      await _onQuestTap(q);
    } else {
      _snack('Purchase did not complete. No charge was made.');
    }
  }

  Future<void> _goPremium() async {
    final ok = await BillingService().buyTravelerPremium();
    if (!mounted) return;
    Navigator.of(context).pop();
    if (ok) {
      await context.read<AuthService>().refreshUser();
      await _afterUnlockChange();
      if (!mounted) return;
      _snack('Welcome to Premium! Every quest stop is now unlocked. ⭐');
    } else {
      _snack('Premium purchase did not complete. No charge was made.');
    }
  }

  // ---------- search ----------

  void _onSearchChanged(String v) {
    final t = v.trim().toLowerCase();
    if (t.isEmpty) {
      setState(() {
        _searching = false;
        _provHits = [];
        _destHits = [];
        _questHits = [];
      });
      return;
    }
    setState(() {
      _searching = true;
      _provHits = _provinces
          .where((p) => p.name.toLowerCase().contains(t))
          .take(5)
          .toList();
      _destHits = _destinations
          .where((d) => d.name.toLowerCase().contains(t))
          .take(5)
          .toList();
      _questHits = QuestService().search(v).take(6).toList();
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    FocusScope.of(context).unfocus();
    if (_searching && mounted) {
      setState(() {
        _searching = false;
        _provHits = [];
        _destHits = [];
        _questHits = [];
      });
    }
  }

  // ---------- markers ----------

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_showProvinces) {
      for (final p in _provinces) {
        markers.add(Marker(
          point: LatLng(p.lat, p.lng),
          width: 110,
          height: 48,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _selectProvince(p),
            child: _provincePin(p),
          ),
        ));
      }
    }
    if (_showDestinations) {
      for (final d in _destinations) {
        final selected = _selDestination?.id == d.id;
        markers.add(Marker(
          point: LatLng(d.centerLat, d.centerLng),
          width: 130,
          height: 56,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _selectDestination(d),
            child: _destinationPin(d, selected),
          ),
        ));
      }
    }
    // Filter quest pins: only for the selected place + active filter.
    if (_selDestination != null && _activeFilter != null) {
      for (final q in _scopedQuests.where((q) => q.filter == _activeFilter)) {
        final done = _doneIds.contains(q.id);
        final locked = !(_unlocked[q.id] ?? false);
        markers.add(Marker(
          point: LatLng(q.lat, q.lng),
          width: 46,
          height: 46,
          child: GestureDetector(
            onTap: () => _onQuestTap(q),
            child: _questPin(q, done: done, locked: locked),
          ),
        ));
      }
      // Quest-stop businesses near the destination ride Things to Do pins.
      if (_activeFilter == 'things_to_do') {
        final c = _selDestination!;
        for (final b in _questStops.where((b) =>
            (b.lat - c.centerLat).abs() < 0.75 &&
            (b.lng - c.centerLng).abs() < 0.75)) {
          markers.add(Marker(
            point: LatLng(b.lat, b.lng),
            width: 46,
            height: 46,
            child: GestureDetector(
              onTap: () => _onBizTap(b),
              child: _bizPin(),
            ),
          ));
        }
      }
    }
    return markers;
  }

  Widget _provincePin(Province p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: BohoColors.terracotta,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
        ),
        if (_labelsOn)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BohoColors.tan.withValues(alpha: 0.6)),
            ),
            child: Text(p.name,
                style: BohoFonts.body(9, weight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }

  Widget _destinationPin(Destination d, bool selected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: selected ? 40 : 32,
          height: selected ? 40 : 32,
          decoration: BoxDecoration(
            color: selected ? BohoColors.coralDeep : BohoColors.sun,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: selected ? 3 : 2.5),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))
            ],
          ),
          child: Center(
              child: Text('⭐', style: TextStyle(fontSize: selected ? 20 : 16))),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: selected
                ? BohoColors.coralDeep
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: BohoColors.tan.withValues(alpha: 0.6)),
          ),
          child: Text(d.name,
              style: BohoFonts.body(10,
                  weight: FontWeight.w800,
                  color: selected ? Colors.white : BohoColors.espresso),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _questPin(QuestPlace q, {required bool done, required bool locked}) {
    final meta = _filterMeta(q.filter);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: meta.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))
            ],
          ),
          child: Center(
              child: Text(meta.emoji, style: const TextStyle(fontSize: 20))),
        ),
        if (locked)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: BohoColors.espresso,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child:
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 10),
            ),
          ),
        if (done)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: BohoColors.leaf,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 12),
            ),
          ),
      ],
    );
  }

  Widget _bizPin() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: BohoColors.ocean,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))
        ],
      ),
      child: const Center(child: Text('🏪', style: TextStyle(fontSize: 20))),
    );
  }

  void _onMapEvent(MapEvent evt) {
    final show = _mapController.camera.zoom >= 7.0;
    if (show != _labelsOn && mounted) setState(() => _labelsOn = show);
  }

  // ================= build =================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: BohoColors.cream,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: BohoColors.cream,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _phCenter,
              initialZoom: 5.8,
              minZoom: 4.0,
              maxZoom: 18.0,
              onMapEvent: _onMapEvent,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gotrvl.app',
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          _buildTopBar(),
          if (_searching) _buildSearchOverlay(),
          _buildAttribution(),
          _buildBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildAttribution() {
    return Positioned(
      right: 8,
      bottom: MediaQuery.of(context).size.height * 0.24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('© OpenStreetMap contributors',
            style: TextStyle(fontSize: 9, color: Colors.black54)),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 14,
      right: 14,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 3))
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search Philippines...',
                  hintStyle: BohoFonts.body(15,
                      color: BohoColors.espresso.withValues(alpha: 0.45)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: BohoColors.espresso),
                  suffixIcon: _searching
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: BohoColors.espresso),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MarketplaceScreen())),
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 3))
                ],
              ),
              child: const Icon(Icons.grid_view_rounded,
                  color: BohoColors.espresso, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay() {
    final total = _provHits.length + _destHits.length + _questHits.length;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 72,
      left: 14,
      right: 76,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x29000000), blurRadius: 12, offset: Offset(0, 4))
          ],
        ),
        child: total == 0
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: Text('No matches — try another search. 🌺',
                    style: BohoFonts.body(14)),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ..._provHits.map((p) => _searchRow(
                        '📍',
                        p.name,
                        'Province · ${p.region}',
                        () => _selectProvince(p),
                      )),
                  ..._destHits.map((d) => _searchRow(
                        '⭐',
                        d.name,
                        d.province,
                        () => _selectDestination(d),
                      )),
                  ..._questHits.map((q) => _searchRow(
                        _filterMeta(q.filter).emoji,
                        q.name,
                        q.province,
                        () {
                          _clearSearch();
                          _onQuestTap(q);
                        },
                      )),
                ],
              ),
      ),
    );
  }

  Widget _searchRow(
      String emoji, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: BohoFonts.body(15, weight: FontWeight.w800)),
                  Text(subtitle,
                      style: BohoFonts.body(12,
                          color: BohoColors.espresso.withValues(alpha: 0.6))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BohoColors.tan),
          ],
        ),
      ),
    );
  }

  // ---------- bottom sheet ----------

  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.44,
      minChildSize: 0.20,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: BohoColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
                color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))
          ],
        ),
        child: _selDestination == null
            ? _buildDiscover(scroll)
            : _buildDestinationDetail(scroll),
      ),
    );
  }

  // ----- Discover Philippines (overview mode) -----

  Widget _buildDiscover(ScrollController scroll) {
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        BohoDecor.dragHandle(),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discover Philippines',
                      style: BohoFonts.display(28, color: BohoColors.espresso)),
                  Text('Featured destinations for you',
                      style: BohoFonts.body(13,
                          color: BohoColors.espresso.withValues(alpha: 0.55))),
                ],
              ),
            ),
            _layerChip('🇵🇭', '83 places', _showProvinces,
                () => setState(() => _showProvinces = !_showProvinces)),
            const SizedBox(width: 8),
            _layerChip('🌐', '37 places', _showDestinations,
                () => setState(() => _showDestinations = !_showDestinations)),
          ],
        ),
        if (_showDestinations) ...[
          const SizedBox(height: 16),
          _rowHeader('⭐ Top destinations', null),
          const SizedBox(height: 10),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _destinations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _destinationCard(_destinations[i]),
            ),
          ),
        ],
        if (_showProvinces) ...[
          const SizedBox(height: 16),
          _rowHeader('📍 Provinces', null),
          const SizedBox(height: 10),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _provinces.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _provinceCard(_provinces[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _rowHeader(String title, VoidCallback? onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: BohoFonts.heading(18)),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }

  Widget _layerChip(
      String emoji, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              active ? BohoColors.coral.withValues(alpha: 0.22) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? BohoColors.terracotta : BohoColors.tan,
              width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(label,
                style: BohoFonts.body(12,
                    weight: FontWeight.w800,
                    color: active
                        ? BohoColors.terracotta
                        : BohoColors.espresso.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _destinationCard(Destination d) {
    return GestureDetector(
      onTap: () => _selectDestination(d),
      child: Container(
        width: 190,
        decoration: BohoDecor.card(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 118,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlacePhoto(
                      placeId: 'dest:${d.id}',
                      placeName: d.name,
                      fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BohoColors.dustyBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(d.region,
                          style: BohoFonts.body(11,
                              color: Colors.white, weight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      style: BohoFonts.heading(17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(d.province,
                      style: BohoFonts.body(12,
                          color: BohoColors.espresso.withValues(alpha: 0.55))),
                  const SizedBox(height: 4),
                  Text(d.tagline,
                      style: const TextStyle(
                          fontSize: 12, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: BohoColors.cream,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: BohoColors.tan),
                    ),
                    child: Text('Destination',
                        style: BohoFonts.body(11, weight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _provinceCard(Province p) {
    return GestureDetector(
      onTap: () => _selectProvince(p),
      child: Container(
        width: 190,
        decoration: BohoDecor.card(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 118,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlacePhoto(
                      placeId: 'prov:${p.id}',
                      placeName: p.name,
                      fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BohoColors.dustyBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(p.region,
                          style: BohoFonts.body(11,
                              color: Colors.white, weight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: BohoFonts.heading(17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('Capital: ${p.capital}',
                      style: BohoFonts.body(12,
                          color: BohoColors.espresso.withValues(alpha: 0.55)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(p.tagline,
                      style: const TextStyle(
                          fontSize: 12, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: BohoColors.cream,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: BohoColors.tan),
                    ),
                    child: Text('Province',
                        style: BohoFonts.body(11, weight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----- Destination detail (focused mode) -----

  Widget _buildDestinationDetail(ScrollController scroll) {
    final d = _selDestination!;
    final scopedFilters =
        _filters.where((f) => _scopedQuests.any((q) => q.filter == f.key));
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        BohoDecor.dragHandle(),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: BohoColors.sun.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('⭐ FEATURED PLACE',
                  style: BohoFonts.body(11,
                      color: BohoColors.espresso, weight: FontWeight.w800)),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Back to all Philippines',
              onPressed: _clearSelection,
            ),
          ],
        ),
        Text('Name of the place:',
            style: BohoFonts.body(13,
                color: BohoColors.espresso.withValues(alpha: 0.6))),
        Text(d.name, style: BohoFonts.display(30, color: BohoColors.espresso)),
        const SizedBox(height: 6),
        Text('Address: ${d.province}, Philippines',
            style: BohoFonts.body(14, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text('Overview',
            style: BohoFonts.heading(18, color: BohoColors.espresso)),
        const SizedBox(height: 4),
        Text(d.description.isNotEmpty ? d.description : d.tagline,
            style: BohoFonts.body(14,
                color: BohoColors.espresso.withValues(alpha: 0.8))),
        if (_selWeather != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('🌤️ ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  'Now ${_selWeather!.tempC.round()}°C, ${_selWeather!.condition} in ${d.name}',
                  style: BohoFonts.body(13,
                      color: BohoColors.espresso.withValues(alpha: 0.75),
                      weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
        if (d.bestTime.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Best time to visit',
              style: BohoFonts.heading(16, color: BohoColors.espresso)),
          const SizedBox(height: 2),
          Text(d.bestTime, style: BohoFonts.body(14)),
        ],
        if (d.howToGetThere.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('How to get there',
              style: BohoFonts.heading(16, color: BohoColors.espresso)),
          const SizedBox(height: 2),
          Text(d.howToGetThere,
              style: BohoFonts.body(14,
                  color: BohoColors.espresso.withValues(alpha: 0.8))),
        ],
        const SizedBox(height: 14),
        Text('Filter buttons:',
            style: BohoFonts.body(13,
                color: BohoColors.espresso.withValues(alpha: 0.6),
                weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: scopedFilters.map((f) {
            final active = _activeFilter == f.key;
            final count = _scopedQuests.where((q) => q.filter == f.key).length;
            return GestureDetector(
              onTap: () => _onFilterTap(f.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? f.color : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: active ? f.color : BohoColors.tan, width: 1.5),
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: f.color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(f.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(f.label,
                        style: BohoFonts.body(13,
                            weight: FontWeight.w800,
                            color:
                                active ? Colors.white : BohoColors.espresso)),
                    const SizedBox(width: 4),
                    Text('($count)',
                        style: BohoFonts.body(12,
                            color: active
                                ? Colors.white.withValues(alpha: 0.85)
                                : BohoColors.espresso.withValues(alpha: 0.55))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_activeFilter != null) ...[
          const SizedBox(height: 14),
          ..._scopedQuests
              .where((q) => q.filter == _activeFilter)
              .map((q) => _questRow(q)),
        ] else ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BohoColors.tan.withValues(alpha: 0.6)),
            ),
            child: Text(
              '👆 Pick a filter above to pin its quest stops on the map.',
              style: BohoFonts.body(14,
                  color: BohoColors.espresso.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _questRow(QuestPlace q) {
    final done = _doneIds.contains(q.id);
    final locked = !(_unlocked[q.id] ?? false);
    final meta = _filterMeta(q.filter);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _onQuestTap(q),
        child: Container(
          decoration: BohoDecor.card(),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PlacePhoto(
                        placeId: q.id, placeName: q.name, fit: BoxFit.cover),
                    if (locked)
                      Container(
                        color: Colors.black38,
                        child: const Icon(Icons.lock_rounded,
                            color: Colors.white, size: 26),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(q.name,
                                style:
                                    BohoFonts.body(15, weight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(meta.emoji,
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(q.blurb,
                          style: BohoFonts.body(12,
                              color:
                                  BohoColors.espresso.withValues(alpha: 0.65)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('${q.points} pts',
                              style: BohoFonts.body(13,
                                  color: BohoColors.terracotta,
                                  weight: FontWeight.w800)),
                          if (done) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle_rounded,
                                color: BohoColors.leaf, size: 16),
                          ],
                          const Spacer(),
                          Text(
                            locked ? 'Unlock →' : 'View Details →',
                            style: BohoFonts.body(12,
                                color: BohoColors.dustyBlue,
                                weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
