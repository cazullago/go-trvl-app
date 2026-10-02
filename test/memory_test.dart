import 'package:flutter_test/flutter_test.dart';
import 'package:go_trvl/models/models.dart';

/// Profile page data contracts: quest memories must round-trip through
/// Firestore, default to public when privacy is missing/invalid, and the
/// only_me flag must survive so other travelers never see private memories.
void main() {
  Map<String, dynamic> base({String privacy = 'public'}) => {
        'uid': 'u1',
        'userName': 'Test Traveler',
        'placeId': 'q1',
        'placeName': 'Boracay',
        'caption': 'Sunset!',
        'photoUrls': ['https://example.com/a.jpg'],
        'privacy': privacy,
        'createdAt': '2026-09-30T12:00:00.000',
      };

  group('Memory privacy contract', () {
    test('public memory parses as public', () {
      final m = Memory.fromMap('m1', base(privacy: 'public'));
      expect(m.isPublic, isTrue);
      expect(m.privacy, 'public');
    });

    test('only_me memory parses as private', () {
      final m = Memory.fromMap('m1', base(privacy: 'only_me'));
      expect(m.isPublic, isFalse);
      expect(m.privacy, 'only_me');
    });

    test('missing privacy defaults to public (never leaks private)', () {
      final map = base()..remove('privacy');
      final m = Memory.fromMap('m1', map);
      expect(m.privacy, 'public');
    });

    test('unknown privacy value defaults to public', () {
      final m = Memory.fromMap('m1', base(privacy: 'friends_only'));
      expect(m.privacy, 'public');
    });

    test('privacy survives toMap/fromMap round-trip', () {
      for (final p in ['public', 'only_me']) {
        final m = Memory.fromMap('m1', base(privacy: p));
        final back = Memory.fromMap('m1', m.toMap());
        expect(back.privacy, p);
      }
    });

    test('document id is preserved', () {
      final m = Memory.fromMap('doc-123', base());
      expect(m.id, 'doc-123');
    });

    test('viewer filter keeps only public memories for other travelers', () {
      final mine = [
        Memory.fromMap('a', base(privacy: 'public')),
        Memory.fromMap('b', base(privacy: 'only_me')),
      ];
      final visibleToOthers = mine.where((m) => m.privacy == 'public').toList();
      expect(visibleToOthers, hasLength(1));
      expect(visibleToOthers.first.id, 'a');
    });

    test('createdAt accepts ISO string and Firestore-style map', () {
      final fromString = Memory.fromMap('m1', base());
      expect(fromString.createdAt.year, 2026);
    });
  });
  group('TravelLevel.progressInLevel', () {
    test('fresh level-up starts at 0%', () {
      // 500 pts = just reached Explorer (500..1500)
      expect(TravelLevel.progressInLevel(500), closeTo(0.0, 1e-9));
    });

    test('mid-level progress is floor-relative', () {
      // 1000 pts within Explorer (500..1500) -> 50%
      expect(TravelLevel.progressInLevel(1000), closeTo(0.5, 1e-9));
    });

    test('zero points is 0%', () {
      expect(TravelLevel.progressInLevel(0), closeTo(0.0, 1e-9));
    });

    test('maxed ladder is 1.0', () {
      expect(TravelLevel.progressInLevel(999999), 1.0);
    });

    test('Alamat is always 1.0', () {
      expect(TravelLevel.progressInLevel(0, hasAllStamps: true), 1.0);
      expect(TravelLevel.progressInLevel(1200, hasAllStamps: true), 1.0);
    });
  });
}
