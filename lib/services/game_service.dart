import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

/// Gamification write layer for GoTRVL PH: points, stamps, quest-place
/// unlocks. Every method swallows errors and never throws, so a failing
/// backend call can never crash a screen.
///
/// Money policy: points and stamps are cosmetic game counters only. This
/// service never moves money, never touches wallets or balances, and never
/// holds funds (see MONETIZATION_POLICY.md).
class GameService {
  static final GameService _i = GameService._();
  factory GameService() => _i;
  GameService._();

  // Lazily resolved so constructing this class never crashes when Firebase
  // has not been configured yet (methods only run while signed in).
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ---- Tuning constants ----
  static const int ptsMemory = 50;
  static const int ptsPost = 20;
  static const int ptsStory = 10;
  static const int ptsLike = 2;
  static const int ptsStamp = 200;

  /// Total stamps needed for the special Alamat level (level 10).
  static const int totalStamps = 120;

  /// How close (km) a user must be to a quest place to earn its stamp or
  /// to see it unlocked without paying.
  static const double stampRadiusKm = 3.0;

  // ---- Points ----

  /// Adds [pts] points to the user's running total. Never throws.
  Future<void> addPoints(String uid, int pts) async {
    if (pts == 0) return;
    try {
      await _db.collection('users').doc(uid).update({
        'points': FieldValue.increment(pts),
      });
    } catch (_) {}
  }

  /// Marks a quest visit done: awards the place's points and records the
  /// place id in `donePlaceIds`. Never throws.
  Future<void> awardVisit(String uid, QuestPlace p) async {
    try {
      await addPoints(uid, p.points);
      await _db.collection('users').doc(uid).update({
        'donePlaceIds': FieldValue.arrayUnion([p.id]),
      });
    } catch (_) {}
  }

  /// Points for posting a quest memory. Never throws.
  Future<void> awardMemory(String uid) async => addPoints(uid, ptsMemory);

  /// Points for creating a post. Never throws.
  Future<void> awardPost(String uid) async => addPoints(uid, ptsPost);

  /// Points for posting a story. Never throws.
  Future<void> awardStory(String uid) async => addPoints(uid, ptsStory);

  /// Points awarded when the user's post receives a like. Never throws.
  Future<void> awardLikeReceived(String uid) async => addPoints(uid, ptsLike);

  // ---- Stamps ----

  static double _km(
      double lat1, double lng1, double lat2, double lng2) {
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

  /// Grants the stamp for [place] when the user is within [radiusKm] of it
  /// and does not already own it. Adds 'stamp:<place.id>' to the user's
  /// `stamps` array and awards [ptsStamp] points.
  ///
  /// Returns true only when the stamp was newly granted. Never throws.
  Future<bool> grantStampIfNearby({
    required String uid,
    required QuestPlace place,
    required double userLat,
    required double userLng,
    double radiusKm = stampRadiusKm,
  }) async {
    try {
      final stampId = 'stamp:${place.id}';
      final dist = _km(userLat, userLng, place.lat, place.lng);
      if (dist > radiusKm) return false;
      final doc = await _db.collection('users').doc(uid).get();
      final stamps = stringList(doc.data()?['stamps']);
      if (stamps.contains(stampId)) return false;
      await _db.collection('users').doc(uid).update({
        'stamps': FieldValue.arrayUnion([stampId]),
        'points': FieldValue.increment(ptsStamp),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// True when the user has collected every stamp ([totalStamps]).
  /// Never throws.
  Future<bool> hasAllStamps(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return stringList(doc.data()?['stamps']).length >= totalStamps;
    } catch (_) {
      return false;
    }
  }

  /// Resolves the display level, honoring the Alamat override.
  TravelLevel levelFor(int points, bool allStamps) =>
      TravelLevel.of(points, hasAllStamps: allStamps);

  // ---- Place unlocks ----

  /// Quest place ids the user has unlocked (paid, task, or granted).
  /// Never throws; returns an empty set on any error.
  Future<Set<String>> unlockedPlaceIds(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return stringList(doc.data()?['unlockedPlaceIds']).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Records [placeId] as unlocked for the user. Never throws.
  Future<void> unlockPlace(String uid, String placeId) async {
    try {
      await _db.collection('users').doc(uid).update({
        'unlockedPlaceIds': FieldValue.arrayUnion([placeId]),
      });
    } catch (_) {}
  }

  /// True when the place is accessible to [user]:
  /// - the user is a premium traveler, OR
  /// - the place is in their `unlockedPlaceIds` or `donePlaceIds`, OR
  /// - the user is within [stampRadiusKm] of the place (needs
  ///   [userLat]/[userLng] and a matching entry in [allPlaces]).
  Future<bool> isPlaceUnlocked({
    required AppUser user,
    required String placeId,
    double? userLat,
    double? userLng,
    required List<QuestPlace> allPlaces,
  }) async {
    if (user.premiumTraveler) return true;
    if (user.unlockedPlaceIds.contains(placeId)) return true;
    if (user.donePlaceIds.contains(placeId)) return true;
    if (userLat != null && userLng != null) {
      for (final p in allPlaces) {
        if (p.id == placeId &&
            _km(userLat, userLng, p.lat, p.lng) <= stampRadiusKm) {
          return true;
        }
      }
    }
    return false;
  }

  /// Unlocks [placeId] as a reward for completing an unlock task, with a
  /// small points bonus. Never throws.
  Future<void> unlockViaTask(String uid, String placeId) async {
    try {
      await unlockPlace(uid, placeId);
      await addPoints(uid, 20);
    } catch (_) {}
  }
}
