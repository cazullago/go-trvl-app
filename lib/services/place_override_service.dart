// Admin place overrides: fix pins and place info without shipping a build.
//
// SECURITY MODEL: admin role is a Firebase Auth custom claim only,
// enforced server-side by Firestore security rules. This service assumes
// the signed-in user already carries the admin claim; the rules reject
// any write from a non-admin client.
//
// Storage: `place_overrides/{placeId}` documents holding only the fields
// the admin changed. QuestService merges them over the bundled
// quest_places.json at load, so overrides apply instantly on next app
// start with no new APK.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';

/// Rough Philippines bounding box. Overrides outside it are rejected:
/// a typo'd coordinate must never fling a pin into the ocean.
const double phMinLat = 4.5;
const double phMaxLat = 18.6;
const double phMinLng = 116.5;
const double phMaxLng = 126.6;

/// Editable fields on a quest place.
const List<String> kPlaceFilterBuckets = [
  'where_to_go',
  'things_to_do',
  'where_to_eat',
];

class PlaceOverrideService {
  static final PlaceOverrideService _i = PlaceOverrideService._();
  factory PlaceOverrideService() => _i;
  PlaceOverrideService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// All overrides keyed by place id. Never throws: on any failure the
  /// app simply runs on bundled data.
  Future<Map<String, Map<String, dynamic>>> fetchOverrides() async {
    try {
      final snap = await _db.collection('place_overrides').get();
      return {
        for (final d in snap.docs) d.id: Map<String, dynamic>.from(d.data()),
      };
    } catch (_) {
      return {};
    }
  }

  /// Validates and saves an override. Only the keys present in [fields]
  /// are stored; missing keys keep the bundled value at merge time.
  Future<void> saveOverride(String placeId, Map<String, dynamic> fields) async {
    final error = validateFields(fields);
    if (error != null) throw Exception(error);
    final clean = Map<String, dynamic>.from(fields)
      ..removeWhere((k, _) => !_editableKeys.contains(k));
    await _db.collection('place_overrides').doc(placeId).set({
      ...clean,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
    }, SetOptions(merge: true));
  }

  /// Removes the override; the place falls back to the bundled data.
  Future<void> deleteOverride(String placeId) async {
    await _db.collection('place_overrides').doc(placeId).delete();
  }

  static const Set<String> _editableKeys = {
    'name',
    'lat',
    'lng',
    'address',
    'blurb',
    'filter',
    'points',
  };

  /// Returns an error message when [fields] are invalid, else null.
  /// Pure and unit-testable.
  static String? validateFields(Map<String, dynamic> fields) {
    final lat = _asDouble(fields['lat']);
    final lng = _asDouble(fields['lng']);
    if (fields.containsKey('lat') || fields.containsKey('lng')) {
      if (lat == null || lng == null) {
        return 'Latitude and longitude must be numbers.';
      }
      if (lat < phMinLat ||
          lat > phMaxLat ||
          lng < phMinLng ||
          lng > phMaxLng) {
        return 'Coordinates must be inside the Philippines '
            '(${phMinLat.toStringAsFixed(1)}–${phMaxLat.toStringAsFixed(1)}°N, '
            '${phMinLng.toStringAsFixed(1)}–${phMaxLng.toStringAsFixed(1)}°E).';
      }
    }
    if (fields.containsKey('filter') &&
        !kPlaceFilterBuckets.contains(fields['filter'])) {
      return 'Unknown category. Pick one of the three.';
    }
    final points = fields['points'];
    if (points != null) {
      final p = points is num ? points.toInt() : int.tryParse('$points');
      if (p == null || p < 100 || p > 1000) {
        return 'Points must be between 100 and 1000.';
      }
    }
    final name = fields['name'];
    if (name != null && '$name'.trim().isEmpty) {
      return 'Name cannot be empty.';
    }
    return null;
  }

  static double? _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  /// Merges one override document over a bundled place. Only keys the
  /// admin actually set are applied; everything else keeps the bundled
  /// value. Pure and unit-testable.
  static QuestPlace applyOverride(
      QuestPlace base, Map<String, dynamic> override) {
    final filter = override['filter']?.toString() ?? base.filter;
    final rawPoints = override['points'];
    final points = rawPoints is num
        ? rawPoints.toInt().clamp(100, 1000)
        : rawPoints != null
            ? int.tryParse('$rawPoints')?.clamp(100, 1000) ?? base.points
            : base.points;
    return QuestPlace(
      id: base.id,
      name: (override['name']?.toString() ?? '').trim().isEmpty
          ? base.name
          : override['name'].toString().trim(),
      province: base.province,
      destination: base.destination,
      filter: kPlaceFilterBuckets.contains(filter) ? filter : base.filter,
      lat: _asDouble(override['lat']) ?? base.lat,
      lng: _asDouble(override['lng']) ?? base.lng,
      address: override['address']?.toString() ?? base.address,
      blurb: override['blurb']?.toString() ?? base.blurb,
      points: points,
    );
  }
}
