import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/moderation_service.dart';
import '../theme/boho_theme.dart';
import '../widgets/level_badge.dart';
import '../widgets/premium_upsell_card.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Travel Buddy matching: a swipe deck of fellow travelers, NOT dating.
/// Right = like, left = pass. Mutual likes create a buddy conversation and
/// a match entry for both travelers.
///
/// Safety: the tab is 18+ only. Users under 18 (or with no age set) see a
/// blocked state instead of the deck, and candidates under 18 are never
/// shown. Report / block entry points sit on every card (Apple guideline 1.2).
class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

enum _GenderFilter { all, women, men }

class _MatchingScreenState extends State<MatchingScreen> {
  final DatabaseService _db = DatabaseService();

  final List<BuddyCard> _deck = [];
  bool _loading = true;
  String? _error;
  bool _acting = false;

  // Guards overlapping reloads (e.g. filter change while a load is in
  // flight): a stale response must not overwrite a newer deck.
  int _reloadGen = 0;

  // Filters.
  bool _showFilters = false;
  bool _gridView = false;
  _GenderFilter _gender = _GenderFilter.all;
  double _minAge = 18;
  double _maxAge = 50;
  double _maxDistance = 1000;

  /// Recipient premium flags, so teaser notifications are written
  /// correctly (non-premium travelers get the blurred teaser version).
  final Map<String, bool> _premiumByUid = {};

  /// Recipient notification prefs (settings → "Likes and profile views").
  /// Absent entries default to true (notifications on).
  final Map<String, bool> _notifyLikesByUid = {};

  bool _hidePremiumCard = false;

  /// Uid the deck was last loaded for. When the auth state changes (e.g.
  /// the user signs in from the sign-in prompt), the deck reloads instead
  /// of sitting on a stale empty state.
  String? _loadedForUid;

  @override
  void initState() {
    super.initState();
    _loadedForUid = context.read<AuthService>().user?.uid ?? '';
    _load();
  }

  // ---------- Candidate loading ----------

  static const _women = {'woman', 'women', 'female', 'f'};
  static const _men = {'man', 'men', 'male', 'm'};

  bool _genderOk(String gender) {
    switch (_gender) {
      case _GenderFilter.all:
        return true;
      case _GenderFilter.women:
        return _women.contains(gender);
      case _GenderFilter.men:
        return _men.contains(gender);
    }
  }

  /// True when the raw user doc carries an active premium membership
  /// (flag set and not expired).
  bool _docIsPremiumActive(Map<String, dynamic> m) {
    if (m['premiumTraveler'] != true) return false;
    final exp = dateTimeOfOrNull(m['premiumExpiry']);
    if (exp == null) return true;
    return DateTime.now().isBefore(exp);
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
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

  Future<void> _load() async {
    final me = context.read<AuthService>().user;
    if (me == null || me.uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final gen = ++_reloadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final seen = await _db.seenBuddyIds(me.uid);
      final blocked = await _db.blockedUids(me.uid);
      final blockedMe = await _db.blockedByMe(me.uid);
      final snap =
          await FirebaseFirestore.instance.collection('users').limit(80).get();

      double? myLat;
      double? myLng;
      final cards = <BuddyCard>[];
      _premiumByUid.clear();
      _notifyLikesByUid.clear();
      for (final d in snap.docs) {
        final m = d.data();
        if (d.id == me.uid) {
          myLat = (m['lat'] as num?)?.toDouble();
          myLng = (m['lng'] as num?)?.toDouble();
          continue;
        }
        if (seen.contains(d.id)) continue;
        if (blocked.contains(d.id) || blockedMe.contains(d.id)) continue;
        final age = (m['age'] as num?)?.toInt() ?? 0;
        // 18+ floor is baked into the filter range: minors never appear.
        if (age < _minAge.round() || age > _maxAge.round()) continue;
        final gender = ((m['gender'] as String?) ?? '').toLowerCase().trim();
        if (!_genderOk(gender)) continue;
        final lat = (m['lat'] as num?)?.toDouble();
        final lng = (m['lng'] as num?)?.toDouble();
        double distanceKm = -1; // -1 = unknown
        if (myLat != null && myLng != null && lat != null && lng != null) {
          distanceKm = _haversineKm(myLat, myLng, lat, lng);
        }
        if (distanceKm >= 0 && distanceKm > _maxDistance) continue;
        _premiumByUid[d.id] = _docIsPremiumActive(m);
        _notifyLikesByUid[d.id] = m['notifyLikes'] != false;
        cards.add(BuddyCard(
          uid: d.id,
          name: (m['name'] as String?) ?? 'Traveler',
          age: age,
          location: (m['location'] as String?) ?? '',
          photoUrl: (m['photoUrl'] as String?) ?? '',
          bio: (m['bio'] as String?) ?? '',
          interests: stringList(m['interests']),
          points: (m['points'] as num?)?.toInt() ?? 0,
          distanceKm: distanceKm,
        ));
      }
      // Known distances first, nearest first; unknown distances last.
      cards.sort((a, b) {
        if (a.distanceKm < 0 && b.distanceKm < 0) return 0;
        if (a.distanceKm < 0) return 1;
        if (b.distanceKm < 0) return -1;
        return a.distanceKm.compareTo(b.distanceKm);
      });
      if (gen != _reloadGen || !mounted) return;
      setState(() {
        _deck
          ..clear()
          ..addAll(cards);
        _loading = false;
      });
      if (_deck.isNotEmpty) _noteView(_deck.last);
    } catch (_) {
      if (gen != _reloadGen || !mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load travel buddies.';
      });
    }
  }

  // ---------- Swipe actions ----------

  Future<void> _onSwipe(BuddyCard buddy, bool liked) async {
    if (_acting) return;
    final auth = context.read<AuthService>();
    final me = auth.user;
    if (me == null || me.uid.isEmpty) return;
    setState(() => _acting = true);
    try {
      if (liked) {
        final matched = await _db.swipeRight(me.uid, buddy.uid);
        // Let them know someone liked them. Non-premium travelers get the
        // teaser version; premium travelers get the full notification.
        // (NotificationsScreen renders the teaser rule.)
        await _writeNotification(
          recipientUid: buddy.uid,
          type: 'like',
          actorUid: me.uid,
          actorName: me.name,
          actorPhoto: me.photoUrl,
        );
        if (!mounted) return;
        setState(() => _deck.removeWhere((b) => b.uid == buddy.uid));
        if (matched) {
          await _recordMatch(me, buddy);
          if (!mounted) return;
          _showMatchDialog(buddy);
        }
      } else {
        await _db.swipeLeft(me.uid, buddy.uid);
        if (!mounted) return;
        setState(() => _deck.removeWhere((b) => b.uid == buddy.uid));
      }
      if (mounted && _deck.isNotEmpty) _noteView(_deck.last);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  /// Records a mutual match: a `matches` entry under both users (the heart
  /// badge counts this subcollection) and flags the conversation as a
  /// buddy chat.
  Future<void> _recordMatch(AppUser me, BuddyCard buddy) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(
        db.collection('users').doc(me.uid).collection('matches').doc(buddy.uid),
        {
          'uid': buddy.uid,
          'name': buddy.name,
          'photoUrl': buddy.photoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      batch.set(
        db.collection('users').doc(buddy.uid).collection('matches').doc(me.uid),
        {
          'uid': me.uid,
          'name': me.name,
          'photoUrl': me.photoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      await batch.commit();
      final convId = await _db.conversationWith(me.uid, buddy.uid);
      await db.collection('conversations').doc(convId).set(
        {'kind': 'buddy'},
        SetOptions(merge: true),
      );
      // Tell the FIRST liker (they are not looking at the deck right now).
      // Honors their "New matches" preference inside notifyMatch.
      await NotificationService().notifyMatch(
        toUid: buddy.uid,
        fromUid: me.uid,
        fromName: me.name,
        fromPhoto: me.photoUrl,
      );
    } catch (_) {
      // The match itself was already recorded by swipeRight; a failed
      // counter write must not break the match dialog.
    }
  }

  /// Writes a like/view notification to the recipient's `notifications`
  /// subcollection. Best-effort: never blocks the swipe flow.
  Future<void> _writeNotification({
    required String recipientUid,
    required String type, // 'like' | 'view'
    required String actorUid,
    required String actorName,
    required String actorPhoto,
  }) async {
    try {
      // Honor the recipient's "Likes and profile views" preference.
      if (_notifyLikesByUid[recipientUid] == false) return;
      final isPremium = _premiumByUid[recipientUid] ?? false;
      // Title/body stay teaser-safe (no actor name): the notifications
      // screen hides the name for non-premium viewers on 'like'/'view'.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientUid)
          .collection('notifications')
          .add({
        'type': type,
        'actorUid': actorUid,
        'actorName': actorName,
        'actorPhoto': actorPhoto,
        'title': type == 'like' ? 'New like' : 'Profile view',
        'body': type == 'like'
            ? 'Someone liked your travel profile'
            : 'Someone viewed your travel profile',
        'teaser': !isPremium,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Notes a profile view, throttled to one notification per viewer/viewed
  /// pair per 24h so scrolling the deck does not spam anyone.
  Future<void> _noteView(BuddyCard buddy) async {
    final me = context.read<AuthService>().user;
    if (me == null || me.uid.isEmpty || me.uid == buddy.uid) return;
    try {
      final db = FirebaseFirestore.instance;
      final ref = db
          .collection('users')
          .doc(me.uid)
          .collection('viewsGiven')
          .doc(buddy.uid);
      final snap = await ref.get();
      final last = snap.data()?['at'];
      if (last is Timestamp &&
          DateTime.now().difference(last.toDate()) <
              const Duration(hours: 24)) {
        return;
      }
      await _writeNotification(
        recipientUid: buddy.uid,
        type: 'view',
        actorUid: me.uid,
        actorName: me.name,
        actorPhoto: me.photoUrl,
      );
      await ref.set({'at': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  void _showMatchDialog(BuddyCard buddy) {
    final me = context.read<AuthService>().user;
    if (me == null) return;
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("It's a match! \u{1F389}",
                style: BohoFonts.display(32, color: BohoColors.coralDeep),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
                'You and ${buddy.name} both want to travel together. Say hi and plan something!',
                style: BohoFonts.body(15),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text('Keep exploring',
                style: BohoFonts.body(15, color: BohoColors.cocoaSoft)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BohoColors.forest),
            onPressed: () async {
              Navigator.of(dctx).pop();
              final convId = await _db.conversationWith(me.uid, buddy.uid);
              if (!mounted) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(
                  conversationId: convId,
                  otherUid: buddy.uid,
                  otherName: buddy.name,
                  otherPhoto: buddy.photoUrl,
                ),
              ));
            },
            child:
                Text('Say Hi', style: BohoFonts.body(16, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMatchesSheet() {
    final me = context.read<AuthService>().user;
    if (me == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: BohoColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BohoDecor.dragHandle(),
              const SizedBox(height: 12),
              Text('Your travel buddies',
                  style: BohoFonts.heading(22, color: BohoColors.espresso)),
              const SizedBox(height: 12),
              Flexible(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(me.uid)
                      .collection('matches')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                            'No matches yet. Keep swiping, your next travel buddy is out there.',
                            style:
                                BohoFonts.body(15, color: BohoColors.cocoaSoft),
                            textAlign: TextAlign.center),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final m = docs[i].data() as Map<String, dynamic>;
                        final uid = (m['uid'] as String?) ?? docs[i].id;
                        final name = (m['name'] as String?) ?? 'Traveler';
                        final photo = (m['photoUrl'] as String?) ?? '';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: BohoColors.tan,
                            backgroundImage: photo.isNotEmpty
                                ? CachedNetworkImageProvider(photo)
                                : null,
                            child: photo.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: BohoFonts.heading(18,
                                        color: BohoColors.espresso))
                                : null,
                          ),
                          title: Text(name,
                              style: BohoFonts.body(16,
                                  color: BohoColors.espresso,
                                  weight: FontWeight.w700)),
                          trailing: TextButton(
                            onPressed: () async {
                              Navigator.of(sctx).pop();
                              final convId =
                                  await _db.conversationWith(me.uid, uid);
                              if (!mounted) return;
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  conversationId: convId,
                                  otherUid: uid,
                                  otherName: name,
                                  otherPhoto: photo,
                                ),
                              ));
                            },
                            child: Text('Message',
                                style: BohoFonts.body(14,
                                    color: BohoColors.forest,
                                    weight: FontWeight.w800)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final me = auth.user;
        final uid = me?.uid ?? '';
        // Auth state changed since the deck was loaded (sign in / sign out
        // / account switch): reload the deck for the current user.
        if (uid != _loadedForUid) {
          _loadedForUid = uid;
          WidgetsBinding.instance.addPostFrameCallback((_) => _load());
        }
        if (me != null && me.age < 18) return _ageBlocked(me);
        return Scaffold(
          backgroundColor: BohoColors.cream,
          appBar: AppBar(
            backgroundColor: BohoColors.cream,
            title: Text('Travel Buddy',
                style: BohoFonts.script(28, color: BohoColors.espresso)),
            actions: [
              IconButton(
                icon: Icon(_gridView
                    ? Icons.view_agenda_rounded
                    : Icons.grid_view_rounded),
                tooltip: _gridView ? 'Card view' : 'Grid view',
                onPressed: () => setState(() => _gridView = !_gridView),
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Filters',
                color: _showFilters ? BohoColors.forest : null,
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
              _matchesButton(),
            ],
          ),
          body: Column(
            children: [
              if (_showFilters) _filterPanel(),
              if (me != null && !me.isPremiumActive && !_hidePremiumCard)
                PremiumUpsellCard(
                  dense: true,
                  onClose: () => setState(() => _hidePremiumCard = true),
                ),
              Expanded(child: _body()),
            ],
          ),
        );
      },
    );
  }

  /// 18+ gate: no access to Travel Buddy for minors (or unset ages).
  /// Fail closed, with a path to fix an unset age.
  Widget _ageBlocked(AppUser me) {
    return Scaffold(
      backgroundColor: BohoColors.cream,
      appBar: AppBar(
        backgroundColor: BohoColors.cream,
        title: Text('Travel Buddy',
            style: BohoFonts.script(28, color: BohoColors.espresso)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔞', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text('Travel Buddy is 18+',
                  style: BohoFonts.heading(26, color: BohoColors.espresso),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                  me.age == 0
                      ? 'Please set your age in Settings so we can confirm you are old enough to meet fellow travelers.'
                      : 'Meeting fellow travelers is only available to travelers aged 18 and above. Come back and explore the map with us in the meantime!',
                  style: BohoFonts.body(15, color: BohoColors.cocoaSoft),
                  textAlign: TextAlign.center),
              if (me.age == 0) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: BohoColors.forest),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: const Text('Open Settings'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _matchesButton() {
    final uid = context.read<AuthService>().user?.uid ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('matches')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.favorite_rounded,
                  color: BohoColors.coralDeep),
              tooltip: 'Matches',
              onPressed: _showMatchesSheet,
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: BohoColors.forest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count',
                      style: BohoFonts.body(10,
                          color: Colors.white, weight: FontWeight.w800)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _filterPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BohoColors.tan, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Show me',
              style: BohoFonts.body(13,
                  color: BohoColors.cocoaSoft, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              _genderPill(_GenderFilter.all, 'All'),
              const SizedBox(width: 8),
              _genderPill(_GenderFilter.women, 'Women'),
              const SizedBox(width: 8),
              _genderPill(_GenderFilter.men, 'Men'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Age range',
                  style: BohoFonts.body(13,
                      color: BohoColors.cocoaSoft, weight: FontWeight.w800)),
              Text('${_minAge.round()} - ${_maxAge.round()}',
                  style: BohoFonts.body(13,
                      color: BohoColors.espresso, weight: FontWeight.w700)),
            ],
          ),
          RangeSlider(
            values: RangeValues(_minAge, _maxAge),
            min: 18,
            max: 50,
            divisions: 32,
            activeColor: BohoColors.forest,
            labels: RangeLabels('${_minAge.round()}', '${_maxAge.round()}'),
            onChanged: (v) => setState(() {
              _minAge = v.start;
              _maxAge = v.end;
            }),
            onChangeEnd: (_) => _load(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Max distance',
                  style: BohoFonts.body(13,
                      color: BohoColors.cocoaSoft, weight: FontWeight.w800)),
              Text(
                  _maxDistance >= 1000
                      ? 'Anywhere'
                      : '${_maxDistance.round()} km',
                  style: BohoFonts.body(13,
                      color: BohoColors.espresso, weight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: _maxDistance,
            min: 10,
            max: 1000,
            divisions: 99,
            activeColor: BohoColors.forest,
            onChanged: (v) => setState(() => _maxDistance = v),
            onChangeEnd: (_) => _load(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _gender = _GenderFilter.all;
                  _minAge = 18;
                  _maxAge = 50;
                  _maxDistance = 1000;
                });
                _load();
              },
              child: Text('Reset filters',
                  style: BohoFonts.body(13,
                      color: BohoColors.forest, weight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderPill(_GenderFilter value, String label) {
    final selected = _gender == value;
    return InkWell(
      onTap: () {
        setState(() => _gender = value);
        _load();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? BohoColors.forest : BohoColors.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? BohoColors.forest : BohoColors.tan, width: 1.2),
        ),
        child: Text(label,
            style: BohoFonts.body(13,
                color: selected ? Colors.white : BohoColors.espresso,
                weight: FontWeight.w700)),
      ),
    );
  }

  Widget _body() {
    if (_loading && _deck.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: BohoColors.forest));
    }
    if (_error != null && _deck.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: BohoFonts.body(15)),
            const SizedBox(height: 12),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: BohoColors.forest),
                onPressed: _load,
                child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_deck.isEmpty) {
      final me = context.read<AuthService>().user;
      if (me == null || me.uid.isEmpty) return _signInPrompt();
      return _emptyDeck();
    }
    if (_gridView) return _grid();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text('\u{2190} swipe to decide \u{2192}',
              style: BohoFonts.body(13, color: BohoColors.cocoaSoft)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _deckStack(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: _actionRow(_deck.last),
        ),
      ],
    );
  }

  Widget _grid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _deck.length,
      itemBuilder: (context, i) {
        final buddy = _deck[i];
        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfileScreen(uid: buddy.uid)),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BohoDecor.card(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _photo(buddy)),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('${buddy.name}, ${buddy.age}',
                                  style: BohoFonts.body(14,
                                      color: Colors.white,
                                      weight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            _miniButton(
                              icon: Icons.close_rounded,
                              onTap: () => _onSwipe(buddy, false),
                            ),
                            const SizedBox(width: 6),
                            _miniButton(
                              icon: Icons.favorite_rounded,
                              onTap: () => _onSwipe(buddy, true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: LevelBadge(points: buddy.points, fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Widget _deckStack() {
    final count = _deck.length >= 3 ? 3 : _deck.length;
    final visible = _deck.sublist(_deck.length - count);
    return Stack(
      children: [
        for (var i = 0; i < visible.length; i++)
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                (visible.length - 1 - i) * 10.0,
                (visible.length - 1 - i) * 12.0,
                (visible.length - 1 - i) * 10.0,
                0,
              ),
              child: i == visible.length - 1
                  ? _swipeableCard(visible[i])
                  : _buddyCard(visible[i]),
            ),
          ),
      ],
    );
  }

  Widget _swipeableCard(BuddyCard buddy) {
    return Dismissible(
      key: ValueKey(buddy.uid),
      direction: DismissDirection.horizontal,
      background: _swipeBackdrop(right: true),
      secondaryBackground: _swipeBackdrop(right: false),
      onDismissed: (dir) => _onSwipe(buddy, dir == DismissDirection.startToEnd),
      child: Stack(
        children: [
          _buddyCard(buddy),
          // Report / block entry points on the traveler's profile
          // (Apple guideline 1.2).
          Positioned(
            top: 10,
            right: 10,
            child: _buddyMenu(buddy),
          ),
        ],
      ),
    );
  }

  /// More-options menu on a buddy profile: report the profile or block
  /// the traveler. Blocking also removes them from the deck.
  Widget _buddyMenu(BuddyCard buddy) {
    final meUid = context.read<AuthService>().user?.uid ?? '';
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: PopupMenuButton<String>(
        icon:
            const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
        tooltip: 'More options',
        padding: EdgeInsets.zero,
        onSelected: (v) async {
          if (meUid.isEmpty) return;
          if (v == 'report') {
            await ModerationService.fileReport(
              context,
              targetType: 'user',
              targetId: buddy.uid,
              authorUid: buddy.uid,
              reporterUid: meUid,
              details: 'Profile of ${buddy.name}',
            );
          } else if (v == 'block') {
            final blocked = await ModerationService.confirmAndBlock(
              context,
              meUid: meUid,
              otherUid: buddy.uid,
              otherName: buddy.name,
            );
            if (blocked && mounted) {
              setState(() => _deck.removeWhere((b) => b.uid == buddy.uid));
            }
          } else if (v == 'profile') {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(uid: buddy.uid)),
            );
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    color: BohoColors.forest, size: 20),
                const SizedBox(width: 10),
                Text('View profile',
                    style: BohoFonts.body(15, color: BohoColors.espresso)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                const Icon(Icons.flag_outlined,
                    color: BohoColors.terracotta, size: 20),
                const SizedBox(width: 10),
                Text('Report profile',
                    style: BohoFonts.body(15, color: BohoColors.espresso)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'block',
            child: Row(
              children: [
                const Icon(Icons.block_rounded,
                    color: BohoColors.terracotta, size: 20),
                const SizedBox(width: 10),
                Text('Block traveler',
                    style: BohoFonts.body(15, color: BohoColors.espresso)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _swipeBackdrop({required bool right}) {
    return Container(
      alignment: right ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        color: right ? BohoColors.forest : BohoColors.cocoaSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(right ? Icons.favorite_rounded : Icons.close_rounded,
              color: Colors.white, size: 40),
          const SizedBox(width: 8),
          Text(right ? 'LIKE' : 'PASS',
              style: BohoFonts.body(18,
                  color: Colors.white, weight: FontWeight.w800)),
        ],
      ),
    );
  }

  String _distanceLine(BuddyCard buddy) {
    if (buddy.location.isEmpty && buddy.distanceKm < 0) return '';
    final dist = buddy.distanceKm >= 0
        ? ' \u00B7 ${buddy.distanceKm < 10 ? buddy.distanceKm.toStringAsFixed(1) : buddy.distanceKm.round()} km away'
        : '';
    return '${buddy.location}$dist'.trim();
  }

  Widget _buddyCard(BuddyCard buddy) {
    final locLine = _distanceLine(buddy);
    return Container(
      decoration: BohoDecor.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _photo(buddy)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${buddy.name}, ${buddy.age}',
                          style:
                              BohoFonts.heading(24, color: BohoColors.espresso),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    LevelBadge(points: buddy.points),
                  ],
                ),
                if (locLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('\u{1F4CD}', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(locLine,
                            style:
                                BohoFonts.body(13, color: BohoColors.cocoaSoft),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
                if (buddy.bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(buddy.bio,
                      style: BohoFonts.body(14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (buddy.interests.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final interest in buddy.interests.take(6))
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: BohoColors.oceanMist,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(interest,
                              style: BohoFonts.body(12,
                                  color: BohoColors.oceanDeep,
                                  weight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photo(BuddyCard buddy) {
    if (buddy.photoUrl.isEmpty) return _photoPlaceholder(buddy);
    return CachedNetworkImage(
      imageUrl: buddy.photoUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => _photoPlaceholder(buddy),
      errorWidget: (_, __, ___) => _photoPlaceholder(buddy),
    );
  }

  Widget _photoPlaceholder(BuddyCard buddy) {
    final initial = buddy.name.isNotEmpty ? buddy.name[0].toUpperCase() : '?';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [BohoColors.ocean, BohoColors.leaf],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
          child:
              Text(initial, style: BohoFonts.display(72, color: Colors.white))),
    );
  }

  Widget _actionRow(BuddyCard top) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionButton(
          icon: Icons.close_rounded,
          iconColor: BohoColors.cocoaSoft,
          bg: Colors.white,
          size: 62,
          onTap: () => _onSwipe(top, false),
        ),
        const SizedBox(width: 36),
        _actionButton(
          icon: Icons.favorite_rounded,
          iconColor: Colors.white,
          bg: BohoColors.forest,
          size: 76,
          onTap: () => _onSwipe(top, true),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color iconColor,
    required Color bg,
    required VoidCallback onTap,
    required double size,
  }) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: BohoColors.cocoa.withValues(alpha: 0.25),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: iconColor, size: size * 0.44),
        ),
      ),
    );
  }

  /// Shown when signed out: Travel Buddy needs an account.
  Widget _signInPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💘', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text('Find your travel buddy',
                style: BohoFonts.display(26), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Sign in to meet fellow travelers heading your way.',
                style: BohoFonts.body(14,
                    color: BohoColors.espresso.withValues(alpha: 0.65)),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: BohoColors.forest,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999))),
              onPressed: () => Navigator.of(context).pushNamed('/login'),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyDeck() {
    final me = context.read<AuthService>().user;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\u{1F9ED}', style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text("That's everyone for now. Check back soon!",
                style: BohoFonts.display(26), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('New travelers join GoTRVL every day.',
                style: BohoFonts.body(14, color: BohoColors.cocoaSoft),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style:
                  ElevatedButton.styleFrom(backgroundColor: BohoColors.forest),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
            if (me != null && !me.isPremiumActive) ...[
              const SizedBox(height: 16),
              const PremiumUpsellCard(),
            ],
          ],
        ),
      ),
    );
  }
}
