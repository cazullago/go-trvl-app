import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/models.dart';
import 'place_override_service.dart';

/// Gamified quest pins for the map: real PH places with filter buckets
/// ('where_to_go' | 'things_to_do' | 'where_to_eat').
///
/// Loads 'assets/data/quest_places.json'; on ANY failure (missing file,
/// malformed JSON, no Flutter binding yet) it falls back to a built-in
/// 14-entry sample so the map never ships empty.
class QuestService {
  static final QuestService _i = QuestService._();
  factory QuestService() => _i;
  QuestService._();

  List<QuestPlace> _places = [];
  bool get loaded => _places.isNotEmpty;

  /// All quest places (asset file, or the built-in fallback).
  List<QuestPlace> get all => List.unmodifiable(_places);

  /// Places in one filter bucket ('where_to_go' | 'things_to_do' |
  /// 'where_to_eat').
  List<QuestPlace> byFilter(String f) =>
      _places.where((p) => p.filter == f).toList();

  /// A single place by id, or null when unknown.
  QuestPlace? byId(String id) {
    for (final p in _places) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Case-insensitive name/province/destination search.
  List<QuestPlace> search(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return [];
    return _places
        .where((p) =>
            p.name.toLowerCase().contains(query) ||
            p.province.toLowerCase().contains(query) ||
            p.destination.toLowerCase().contains(query))
        .toList();
  }

  Future<void> load() async {
    if (loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/quest_places.json');
      final list = json.decode(raw) as List;
      final parsed = <QuestPlace>[];
      for (final e in list) {
        if (e is! Map<String, dynamic>) continue;
        try {
          parsed.add(QuestPlace.fromJson(e));
        } catch (_) {
          // One bad entry never sinks the file.
        }
      }
      if (parsed.isNotEmpty) {
        _places = await _withOverrides(parsed);
        return;
      }
    } catch (_) {
      // Fall through to the built-in fallback.
    }
    _places = _fallback;
  }

  /// Merges admin place overrides (Firestore `place_overrides`) over the
  /// bundled pins so a coordinate/name fix applies on next app start with
  /// no new build. Best effort: any failure leaves the bundled pins
  /// untouched so the map never breaks because of the admin backend.
  Future<List<QuestPlace>> _withOverrides(List<QuestPlace> bundled) async {
    try {
      final overrides = await PlaceOverrideService().fetchOverrides();
      if (overrides.isEmpty) return bundled;
      return [
        for (final p in bundled)
          overrides.containsKey(p.id)
              ? PlaceOverrideService.applyOverride(p, overrides[p.id]!)
              : p,
      ];
    } catch (_) {
      return bundled;
    }
  }

  /// Built-in 14-entry fallback: real PH coordinates matching the bundled
  /// JSON schema. Points follow the filter defaults
  /// (where_to_go 300 / things_to_do 200 / where_to_eat 150).
  static final List<QuestPlace> _fallback = [
    const QuestPlace(
        id: 'boracay_white_beach',
        name: 'Boracay White Beach',
        province: 'Aklan',
        destination: 'Boracay',
        filter: 'where_to_go',
        lat: 11.9674,
        lng: 121.9248,
        address: 'White Beach, Malay, Aklan',
        blurb:
            "Powder-white sand and legendary sunsets on the Philippines' most famous beach.",
        points: 300),
    const QuestPlace(
        id: 'elnido_nacpan',
        name: 'Nacpan Beach',
        province: 'Palawan',
        destination: 'El Nido',
        filter: 'where_to_go',
        lat: 11.1945,
        lng: 119.2924,
        address: 'Nacpan Beach, El Nido, Palawan',
        blurb: 'A 4-kilometer golden-sand stretch north of El Nido town.',
        points: 300),
    const QuestPlace(
        id: 'bohol_chocolate_hills',
        name: 'Chocolate Hills',
        province: 'Bohol',
        destination: 'Bohol',
        filter: 'where_to_go',
        lat: 9.8312,
        lng: 124.1427,
        address: 'Carmen, Bohol',
        blurb:
            'More than a thousand cone-shaped hills that turn chocolate-brown in summer.',
        points: 300),
    const QuestPlace(
        id: 'albay_mayon',
        name: 'Mayon Volcano',
        province: 'Albay',
        destination: 'Legazpi',
        filter: 'where_to_go',
        lat: 13.2546,
        lng: 123.6850,
        address: 'Legazpi City, Albay',
        blurb:
            "The world's most perfect volcanic cone, rising over Albay Gulf.",
        points: 300),
    const QuestPlace(
        id: 'siargao_cloud9',
        name: 'Cloud 9',
        province: 'Surigao del Norte',
        destination: 'Siargao',
        filter: 'things_to_do',
        lat: 9.8106,
        lng: 126.1648,
        address: 'General Luna, Siargao Island',
        blurb:
            'The iconic boardwalk and barreling wave that put Philippine surfing on the map.',
        points: 200),
    const QuestPlace(
        id: 'banaue_rice_terraces',
        name: 'Banaue Rice Terraces',
        province: 'Ifugao',
        destination: 'Banaue',
        filter: 'where_to_go',
        lat: 16.9239,
        lng: 121.0563,
        address: 'Banaue, Ifugao',
        blurb:
            'Two-thousand-year-old hand-carved amphitheaters often called the Eighth Wonder.',
        points: 300),
    const QuestPlace(
        id: 'coron_kayangan',
        name: 'Kayangan Lake',
        province: 'Palawan',
        destination: 'Coron',
        filter: 'things_to_do',
        lat: 11.9979,
        lng: 120.2045,
        address: 'Coron Island, Palawan',
        blurb: 'Swim the crystal lagoon once called the cleanest lake in Asia.',
        points: 200),
    const QuestPlace(
        id: 'panglao_alona',
        name: 'Alona Beach',
        province: 'Bohol',
        destination: 'Panglao',
        filter: 'where_to_go',
        lat: 9.5741,
        lng: 123.7737,
        address: 'Panglao, Bohol',
        blurb:
            "White-sand beach and dive-shops hub on Panglao Island's southwest tip.",
        points: 300),
    const QuestPlace(
        id: 'vigan_calle',
        name: 'Calle Crisologo',
        province: 'Ilocos Sur',
        destination: 'Vigan',
        filter: 'where_to_go',
        lat: 17.5747,
        lng: 120.3869,
        address: 'Calle Crisologo, Vigan City, Ilocos Sur',
        blurb:
            'A UNESCO cobblestone street lined with preserved Spanish-era houses.',
        points: 300),
    const QuestPlace(
        id: 'manila_intramuros',
        name: 'Intramuros',
        province: 'Metro Manila',
        destination: 'Manila',
        filter: 'things_to_do',
        lat: 14.5896,
        lng: 120.9753,
        address: 'Intramuros, Manila',
        blurb:
            'Walk the walls of the Walled City, the oldest district of Manila.',
        points: 200),
    const QuestPlace(
        id: 'cebu_magellan',
        name: "Magellan's Cross",
        province: 'Cebu',
        destination: 'Cebu City',
        filter: 'where_to_go',
        lat: 10.2931,
        lng: 123.9019,
        address: 'Plaza Sugbo, Cebu City',
        blurb:
            'The 1521 cross marking the arrival of Christianity in the Philippines.',
        points: 300),
    const QuestPlace(
        id: 'davao_eden',
        name: 'Eden Nature Park',
        province: 'Davao del Sur',
        destination: 'Davao',
        filter: 'things_to_do',
        lat: 7.0995,
        lng: 125.3555,
        address: 'Toril, Davao City',
        blurb:
            'Mountain resort with ziplines, skycycling and pine forests in Davao.',
        points: 200),
    const QuestPlace(
        id: 'bacolod_manokan',
        name: 'Manokan Country',
        province: 'Negros Occidental',
        destination: 'Bacolod',
        filter: 'where_to_eat',
        lat: 10.6765,
        lng: 122.9500,
        address: 'Fr. Ferrero St., Bacolod City',
        blurb:
            'Home of the original chicken inasal — smoky, garlicky, unforgettable.',
        points: 150),
    const QuestPlace(
        id: 'pampanga_aling_lucing',
        name: "Aling Lucing's Sisig",
        province: 'Pampanga',
        destination: 'Angeles City',
        filter: 'where_to_eat',
        lat: 15.1450,
        lng: 120.5900,
        address: 'Glaciano Valdez St., Angeles City, Pampanga',
        blurb:
            "The sizzling birthplace of sisig, the Sisig Queen's legendary stall.",
        points: 150),
  ];
}
