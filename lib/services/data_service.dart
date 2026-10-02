import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/models.dart';

/// Loads the bundled destinations dataset (merged Luzon/Visayas/Mindanao JSON).
class DataService {
  static final DataService _i = DataService._();
  factory DataService() => _i;
  DataService._();

  List<Destination> _destinations = [];
  List<Province> _provinces = [];
  bool get loaded => _destinations.isNotEmpty;
  List<Destination> get destinations => _destinations;
  List<Province> get provinces => _provinces;

  Province? provinceById(String id) {
    for (final p in _provinces) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Destination> destinationsByProvince(String provinceId) =>
      _destinations.where((d) => d.provinceId == provinceId).toList();

  /// Parses one JSON object, skipping it when it is not a map or the
  /// model parser rejects it. One bad entry must never sink a whole file.
  static T? _entry<T>(Object? e, T Function(Map<String, dynamic>) fromJson) {
    if (e is! Map<String, dynamic>) return null;
    try {
      return fromJson(e);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    if (loaded) return;
    const files = [
      'assets/data/destinations_luzon.json',
      'assets/data/destinations_visayas.json',
      'assets/data/destinations_mindanao.json',
      'assets/data/destinations_new_1.json',
      'assets/data/destinations_new_2.json',
    ];
    final all = <Destination>[];
    for (final f in files) {
      try {
        final raw = await rootBundle.loadString(f);
        final j = json.decode(raw) as Map<String, dynamic>;
        final list = (j['destinations'] as List?) ?? [];
        for (final e in list) {
          final d = _entry(e, Destination.fromJson);
          if (d != null) all.add(d);
        }
      } catch (_) {
        // A missing region file simply contributes nothing.
      }
    }
    _destinations = all;
    try {
      final raw = await rootBundle.loadString('assets/data/provinces.json');
      final j = json.decode(raw) as Map<String, dynamic>;
      final list = (j['provinces'] as List?) ?? [];
      final parsed = <Province>[];
      for (final e in list) {
        final p = _entry(e, Province.fromJson);
        if (p != null) parsed.add(p);
      }
      _provinces = parsed;
    } catch (_) {
      _provinces = [];
    }
  }

  /// Search destinations and places by name. Returns matches grouped for the UI.
  List<SearchHit> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final hits = <SearchHit>[];
    for (final d in _destinations) {
      if (d.name.toLowerCase().contains(q) ||
          d.province.toLowerCase().contains(q) ||
          d.tagline.toLowerCase().contains(q)) {
        hits.add(SearchHit.destination(d));
      }
      for (final p in d.places) {
        if (p.name.toLowerCase().contains(q) ||
            p.area.toLowerCase().contains(q) ||
            p.placeType.toLowerCase().contains(q)) {
          hits.add(SearchHit.place(d, p));
        }
      }
      if (hits.length > 25) break;
    }
    return hits;
  }

  Place? placeById(String id) {
    for (final d in _destinations) {
      for (final p in d.places) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  Destination? destinationOfPlace(String placeId) {
    for (final d in _destinations) {
      if (d.places.any((p) => p.id == placeId)) return d;
    }
    return null;
  }
}

class SearchHit {
  final Destination destination;
  final Place? place; // null => the hit is the destination itself
  SearchHit.destination(this.destination) : place = null;
  SearchHit.place(this.destination, Place p) : place = p;
  bool get isDestination => place == null;
  String get title => isDestination ? destination.name : place!.name;
  String get subtitle => isDestination
      ? '${destination.province} · ${destination.tagline}'
      : '${place!.placeType} · ${destination.name}';
  double get lat => isDestination ? destination.centerLat : place!.lat;
  double get lng => isDestination ? destination.centerLng : place!.lng;
}
