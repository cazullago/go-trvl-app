import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_trvl/admin/triple_tap_detector.dart';
import 'package:go_trvl/models/models.dart';
import 'package:go_trvl/models/monetization_models.dart';
import 'package:go_trvl/services/ad_service.dart';
import 'package:go_trvl/services/auth_service.dart';
import 'package:go_trvl/services/content_filter.dart';
import 'package:go_trvl/services/moderation_service.dart';
import 'package:go_trvl/widgets/affiliate_buttons.dart';

/// Reads a bundled JSON asset straight from the repo. `flutter test` runs
/// with the package root as the working directory, so relative asset paths
/// resolve without involving Flutter's asset bundle.
Map<String, dynamic> _readJson(String assetPath) {
  final file = File(assetPath);
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<Province> _loadProvinces() {
  final j = _readJson('assets/data/provinces.json');
  final out = <Province>[];
  for (final e in (j['provinces'] as List)) {
    if (e is Map<String, dynamic>) out.add(Province.fromJson(e));
  }
  return out;
}

List<Destination> _loadDestinations() {
  const files = [
    'assets/data/destinations_luzon.json',
    'assets/data/destinations_visayas.json',
    'assets/data/destinations_mindanao.json',
    'assets/data/destinations_new_1.json',
    'assets/data/destinations_new_2.json',
  ];
  final out = <Destination>[];
  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) continue;
    final j = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final e in (j['destinations'] as List)) {
      if (e is Map<String, dynamic>) out.add(Destination.fromJson(e));
    }
  }
  return out;
}

void main() {
  group('Bundled dataset integrity', () {
    test('provinces file parses to 83 provinces', () {
      expect(_loadProvinces().length, 83);
    });

    test('every province has parsed cities, 408 in total', () {
      var total = 0;
      for (final p in _loadProvinces()) {
        expect(p.cities, isNotEmpty, reason: '${p.name} has no cities');
        total += p.cities.length;
      }
      expect(total, 408);
    });

    test('destinations file parses to 37 destinations', () {
      expect(_loadDestinations().length, 37);
    });

    test('every destination provinceId resolves to a province', () {
      final ids = _loadProvinces().map((p) => p.id).toSet();
      for (final d in _loadDestinations()) {
        expect(ids.contains(d.provinceId), isTrue,
            reason: '${d.name} has unknown provinceId "${d.provinceId}"');
      }
    });
  });

  group('Malformed bundled entries are skipped, not fatal', () {
    test('destination keeps valid places and drops junk entries', () {
      final d = Destination.fromJson({
        'id': 'x',
        'name': 'X',
        'provinceId': 'abra',
        'places': [
          {'id': 'ok', 'name': 'OK Spot', 'lat': 1.0, 'lng': 2.0},
          'not a map',
          42,
          null,
        ],
      });
      expect(d.places.map((p) => p.id), ['ok']);
    });

    test('province keeps valid cities and drops junk entries', () {
      final p = Province.fromJson({
        'id': 'x',
        'name': 'X',
        'cities': [
          {'name': 'OK City', 'type': 'city', 'lat': 1.0, 'lng': 2.0},
          ['a list, not a map'],
          7,
        ],
      });
      expect(p.cities.map((c) => c.name), ['OK City']);
    });

    test('modelList skips entries whose parser throws', () {
      final out = modelList<String>([
        {'a': 1},
        {'b': 2},
      ], (_) => throw StateError('boom'));
      expect(out, isEmpty);
    });
  });

  group('Safe parsing helpers', () {
    test('stringList drops junk values without throwing', () {
      expect(
        stringList([
          'a',
          42,
          null,
          'b',
          {'k': 'v'},
          true
        ]),
        ['a', 'b'],
      );
      expect(stringList('not a list'), isEmpty);
      expect(stringList(null), isEmpty);
    });

    test('dateTimeOf never throws on wrong types or junk', () {
      for (final junk in [
        42,
        true,
        ['x'],
        {'d': 1},
        'not-a-date'
      ]) {
        expect(() => dateTimeOf(junk), returnsNormally);
        expect(dateTimeOf(junk), isA<DateTime>());
      }
      expect(
        dateTimeOf('2026-01-02T03:04:05Z'),
        DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
    });

    test('dateTimeOf honors Firestore Timestamps', () {
      final ts = Timestamp.fromDate(DateTime.utc(2020, 5, 6, 7, 8, 9));
      // Timestamp.toDate() returns local time; compare instants, not zones.
      expect(dateTimeOf(ts).millisecondsSinceEpoch,
          DateTime.utc(2020, 5, 6, 7, 8, 9).millisecondsSinceEpoch);
    });

    test('dateTimeOfOrNull returns null for junk, date for Timestamp', () {
      expect(dateTimeOfOrNull('junk'), isNull);
      expect(dateTimeOfOrNull(42), isNull);
      expect(dateTimeOfOrNull(null), isNull);
      final ts = Timestamp.fromDate(DateTime.utc(2021, 2, 3));
      expect(dateTimeOfOrNull(ts)!.millisecondsSinceEpoch,
          DateTime.utc(2021, 2, 3).millisecondsSinceEpoch);
    });
  });

  group('BusinessListing hardened parsing', () {
    test('malformed map degrades safely without throwing', () {
      final l = BusinessListing.fromMap('x', {
        'ownerUid': 'u',
        'name': 'N',
        'photoUrls': ['ok.jpg', 42, null],
        'socials': {'fb': 'https://fb.example', 'junk': 7},
        'tier': 'hacker',
        'isFeatured': 'true',
        'createdAt': 'not-a-date',
      });
      expect(l.photoUrls, ['ok.jpg']);
      expect(l.socials, {'fb': 'https://fb.example'});
      expect(l.tier, BusinessTier.free);
      expect(l.isFeatured, isFalse);
      expect(l.createdAt, isA<DateTime>());
    });

    test('isFeatured only accepts an actual boolean true', () {
      for (final junk in [1, 'true', 'yes', null]) {
        final l = BusinessListing.fromMap('x', {
          'ownerUid': 'u',
          'name': 'N',
          'isFeatured': junk,
        });
        expect(l.isFeatured, isFalse, reason: 'junk: $junk');
      }
      final real = BusinessListing.fromMap('x', {
        'ownerUid': 'u',
        'name': 'N',
        'isFeatured': true,
      });
      expect(real.isFeatured, isTrue);
    });

    test('junk createdAt Timestamp cast does not throw', () {
      expect(
        () => BusinessListing.fromMap('x', {
          'ownerUid': 'u',
          'name': 'N',
          'createdAt': 12345,
        }),
        returnsNormally,
      );
    });
  });

  group('UserReport validation', () {
    UserReport report({
      String reason = 'spam',
      String targetType = 'post',
      String targetId = 'p1',
      String reporterUid = 'u1',
    }) =>
        UserReport(
          reason: reason,
          targetType: targetType,
          targetId: targetId,
          authorUid: 'u2',
          reporterUid: reporterUid,
        );

    test('a complete report with a known target type is valid', () {
      expect(report().isValid, isTrue);
    });

    test('blank reason fails validation', () {
      expect(report(reason: '   ').isValid, isFalse);
    });

    test('unknown target type fails validation', () {
      expect(report(targetType: 'carrier-pigeon').isValid, isFalse);
    });

    test('blank target id or reporter id fails validation', () {
      expect(report(targetId: '').isValid, isFalse);
      expect(report(reporterUid: '').isValid, isFalse);
    });
  });

  group('ContentFilter boundary matching', () {
    test('catches banned words with trailing punctuation', () {
      expect(ContentFilter.isAllowed('This is shit!'), isFalse);
      expect(ContentFilter.isAllowed('(gago) ka'), isFalse);
    });

    test('catches mixed-case banned words with punctuation', () {
      expect(ContentFilter.isAllowed('You are a ShIt? Wow'), isFalse);
    });

    test('catches multi-word phrases with punctuation', () {
      expect(ContentFilter.isAllowed('Putang ina! Grabe.'), isFalse);
    });

    test('still allows innocent substrings', () {
      expect(
        ContentFilter.isAllowed('This classic Scunthorpe thread rocks'),
        isTrue,
      );
    });
  });

  group('Auth error mapping', () {
    test('credential errors map to the sign-in message', () {
      for (final code in [
        'user-not-found',
        'wrong-password',
        'invalid-credential',
      ]) {
        expect(AuthService.friendlyAuthError(code),
            'Incorrect email or password.');
      }
    });

    test('requires-recent-login asks to sign in again', () {
      expect(AuthService.friendlyAuthError('requires-recent-login'),
          contains('sign'));
    });

    test('unknown codes fall back to the generic message', () {
      expect(AuthService.friendlyAuthError('some-future-code'),
          'Something went wrong. Please try again.');
    });
  });

  group('Triple-tap detector edges', () {
    test('taps exactly on the window boundary still count', () {
      final d = TripleTapDetector(windowMs: 1500);
      expect(d.registerTap(0), isFalse);
      expect(d.registerTap(1500), isFalse);
      expect(d.registerTap(1500), isTrue);
    });

    test('a tap just outside the window drops the oldest tap', () {
      final d = TripleTapDetector(windowMs: 1500);
      d.registerTap(0);
      d.registerTap(100);
      expect(d.registerTap(1601), isFalse);
    });

    test('out-of-order timestamps do not throw', () {
      final d = TripleTapDetector(windowMs: 1500);
      d.registerTap(1000);
      d.registerTap(500);
      expect(() => d.registerTap(0), returnsNormally);
    });
  });

  group('Monetization defaults', () {
    test('an ad slot serves exactly one house ad by default', () {
      final placements = AdService().placementsForSlot(AdPlacement.slotFeed);
      expect(placements, hasLength(1));
      expect(placements.first.isHouseAd, isTrue);
      expect(placements.first.slot, AdPlacement.slotFeed);
    });

    testWidgets('empty affiliate links render no buttons or disclosure',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AffiliateButtons(links: [])),
        ),
      );
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.textContaining('commission'), findsNothing);
    });
  });
}
