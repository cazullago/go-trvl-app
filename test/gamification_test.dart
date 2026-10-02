import 'package:flutter_test/flutter_test.dart';
import 'package:go_trvl/models/models.dart';

void main() {
  group('categoryPoints', () {
    test('matches the specified point values', () {
      expect(categoryPoints['where_to_go'], 200);
      expect(categoryPoints['things_to_do'], 150);
      expect(categoryPoints['where_to_eat'], 100);
      expect(categoryPoints['where_to_stay'], 50);
      expect(categoryPoints['where_to_buy'], 50);
      expect(categoryPoints['how_to_get_around'], 20);
    });
  });

  group('TravelLevel', () {
    test('level boundaries match the spec', () {
      expect(TravelLevel.of(0).name, 'New Traveler');
      expect(TravelLevel.of(499).name, 'New Traveler');
      expect(TravelLevel.of(500).name, 'Explorer');
      expect(TravelLevel.of(1499).name, 'Explorer');
      expect(TravelLevel.of(1500).name, 'Adventurer');
      expect(TravelLevel.of(2999).name, 'Adventurer');
      expect(TravelLevel.of(3000).name, 'Wanderer');
      expect(TravelLevel.of(5499).name, 'Wanderer');
      expect(TravelLevel.of(5500).name, 'Voyager');
      expect(TravelLevel.of(8999).name, 'Voyager');
      expect(TravelLevel.of(9000).name, 'Island Hopper');
      expect(TravelLevel.of(13999).name, 'Island Hopper');
      expect(TravelLevel.of(14000).name, 'Trailblazer');
      expect(TravelLevel.of(20999).name, 'Trailblazer');
      expect(TravelLevel.of(21000).name, 'Expedition Leader');
      expect(TravelLevel.of(29999).name, 'Expedition Leader');
      expect(TravelLevel.of(30000).name, 'Philippine Legend');
      expect(TravelLevel.of(99999).name, 'Philippine Legend');
    });

    test('Alamat is granted only via hasAllStamps', () {
      expect(TravelLevel.of(99999).name, 'Philippine Legend');
      expect(TravelLevel.of(99999, hasAllStamps: true).name, 'Alamat');
      expect(TravelLevel.of(0, hasAllStamps: true).name, 'Alamat');
    });

    test('levelNumber runs 1..10 with Alamat as 10', () {
      expect(TravelLevel.of(0).levelNumber, 1);
      expect(TravelLevel.of(500).levelNumber, 2);
      expect(TravelLevel.of(30000).levelNumber, 9);
      expect(TravelLevel.of(0, hasAllStamps: true).levelNumber, 10);
    });

    test('nextThreshold returns the next level boundary', () {
      expect(TravelLevel.nextThreshold(0), 500);
      expect(TravelLevel.nextThreshold(499), 500);
      expect(TravelLevel.nextThreshold(500), 1500);
      expect(TravelLevel.nextThreshold(30000), isNull);
    });
  });

  group('Place', () {
    test('points resolve from category', () {
      final p = Place(
        id: 'x',
        name: 'Test',
        category: 'how_to_get_around',
        placeType: 'bus terminal',
        description: 'd',
        priceRange: '₱',
        area: 'a',
        bestTime: 'b',
        lat: 14.5,
        lng: 121.0,
      );
      expect(p.points, 20);
    });
  });
}
