import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_trvl/models/models.dart';
import 'package:go_trvl/services/synthetic_quests.dart';

/// Day-1 Map page data contract tests.
///
/// The map overview renders exactly two pin layers (83 provinces + 37
/// tourist destinations) and no quest pins. Tapping a destination zooms to
/// it and shows ONLY that destination's quest pins, matched by destination
/// NAME (quest_places.json stores names, not ids). Tapping a province opens
/// its Explore page whose Where-to-Go list is the province's real
/// cities/municipalities.
Map<String, dynamic> _readJson(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<Province> _loadProvinces() {
  final j = _readJson('assets/data/provinces.json');
  return [
    for (final e in (j['provinces'] as List))
      if (e is Map<String, dynamic>) Province.fromJson(e)
  ];
}

List<Destination> _loadDestinations() {
  const files = [
    'assets/data/destinations_luzon.json',
    'assets/data/destinations_visayas.json',
    'assets/data/destinations_mindanao.json',
    'assets/data/destinations_new_1.json',
    'assets/data/destinations_new_2.json',
  ];
  return [
    for (final f in files)
      if (File(f).existsSync())
        for (final e in (_readJson(f)['destinations'] as List))
          if (e is Map<String, dynamic>) Destination.fromJson(e)
  ];
}

List<QuestPlace> _loadQuests() {
  final j = json.decode(File('assets/data/quest_places.json').readAsStringSync());
  final list = j is List ? j : (j as Map<String, dynamic>)['quest_places'] as List;
  return [
    for (final e in list)
      if (e is Map<String, dynamic>) QuestPlace.fromJson(e)
  ];
}

void main() {
  group('Map overview pin layers', () {
    test('exactly 83 provinces and 37 destinations', () {
      expect(_loadProvinces().length, 83);
      expect(_loadDestinations().length, 37);
    });

    test('every province and destination has valid coordinates', () {
      for (final p in _loadProvinces()) {
        expect(p.lat, inInclusiveRange(-90.0, 90.0), reason: p.name);
        expect(p.lng, inInclusiveRange(-180.0, 180.0), reason: p.name);
      }
      for (final d in _loadDestinations()) {
        expect(d.centerLat, inInclusiveRange(-90.0, 90.0), reason: d.name);
        expect(d.centerLng, inInclusiveRange(-180.0, 180.0), reason: d.name);
      }
    });
  });

  group('Destination-scoped quest pins', () {
    test('every quest destination name matches a real destination', () {
      final names = _loadDestinations().map((d) => d.name).toSet();
      for (final q in _loadQuests()) {
        expect(names.contains(q.destination), isTrue,
            reason: 'quest ${q.id} -> ${q.destination}');
      }
    });

    test('Boracay scoped pins are all on Boracay island', () {
      final scoped =
          _loadQuests().where((q) => q.destination == 'Boracay').toList();
      expect(scoped, isNotEmpty);
      for (final q in scoped) {
        // Boracay island bounding box.
        expect(q.lat, inInclusiveRange(11.90, 12.00), reason: q.name);
        expect(q.lng, inInclusiveRange(121.90, 122.00), reason: q.name);
      }
    });

    test('quest filters stay in the three known buckets', () {
      const buckets = {'where_to_go', 'things_to_do', 'where_to_eat'};
      for (final q in _loadQuests()) {
        expect(buckets.contains(q.filter), isTrue, reason: q.id);
      }
    });

    test('371 quest places loaded', () {
      expect(_loadQuests().length, 371);
    });
  });

  group('Province Where-to-Go = real cities/municipalities', () {
    test('every province has at least one city/municipality', () {
      for (final p in _loadProvinces()) {
        expect(p.cities, isNotEmpty, reason: p.name);
      }
    });

    test('Aklan lists Kalibo among its cities', () {
      final aklan = _loadProvinces().firstWhere((p) => p.id == 'aklan');
      expect(aklan.cities.any((c) => c.name == 'Kalibo'), isTrue);
    });

    test('synthetic city ids are stable and unique per province', () {
      final provs = _loadProvinces();
      final ids = <String>{};
      for (final p in provs) {
        for (final c in p.cities) {
          final id = SyntheticQuests.cityId(p, c);
          expect(ids.add(id), isTrue, reason: 'duplicate $id');
          // Stability: same inputs -> same id.
          expect(SyntheticQuests.cityId(p, c), id);
        }
      }
      expect(ids.length, 408);
    });

    test('synthetic city/province quests carry 500/1000 points', () {
      final p = _loadProvinces().first;
      final city = SyntheticQuests.city(p, p.cities.first);
      expect(city.points, 500);
      expect(city.province, p.name);
      final prov = SyntheticQuests.province(p);
      expect(prov.points, 1000);
      expect(SyntheticQuests.provinceId(p), 'province:${p.id}');
    });
  });
}
