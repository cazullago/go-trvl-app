import 'package:flutter_test/flutter_test.dart';
import 'package:go_trvl/models/models.dart';
import 'package:go_trvl/services/place_override_service.dart';

const _base = QuestPlace(
  id: 'boracay-white-beach',
  name: 'White Beach',
  province: 'Aklan',
  destination: 'Boracay',
  filter: 'where_to_go',
  lat: 11.9674,
  lng: 121.9248,
  address: 'Boracay Island',
  blurb: 'Famous beach.',
  points: 300,
);

void main() {
  group('PlaceOverrideService.validateFields', () {
    test('accepts a valid full override', () {
      expect(
          PlaceOverrideService.validateFields({
            'name': 'White Beach',
            'lat': 11.9674,
            'lng': 121.9248,
            'filter': 'where_to_go',
            'points': 300,
          }),
          isNull);
    });

    test('accepts string coordinates', () {
      expect(
          PlaceOverrideService.validateFields(
              {'lat': '11.9674', 'lng': '121.9248'}),
          isNull);
    });

    test('rejects coordinates outside the Philippines', () {
      expect(
          PlaceOverrideService.validateFields(
              {'lat': 48.8566, 'lng': 2.3522}),
          isNotNull);
    });

    test('rejects a lone latitude without longitude', () {
      expect(PlaceOverrideService.validateFields({'lat': 11.9674}),
          isNotNull);
    });

    test('rejects non-numeric coordinates', () {
      expect(
          PlaceOverrideService.validateFields(
              {'lat': 'abc', 'lng': '121.9'}),
          isNotNull);
    });

    test('rejects unknown filter bucket', () {
      expect(
          PlaceOverrideService.validateFields({'filter': 'mystery'}),
          isNotNull);
    });

    test('rejects out-of-range points', () {
      expect(PlaceOverrideService.validateFields({'points': 50}),
          isNotNull);
      expect(PlaceOverrideService.validateFields({'points': 5000}),
          isNotNull);
    });

    test('rejects empty name', () {
      expect(
          PlaceOverrideService.validateFields({'name': '   '}),
          isNotNull);
    });

    test('empty field set is valid (no-op override)', () {
      expect(PlaceOverrideService.validateFields({}), isNull);
    });
  });

  group('PlaceOverrideService.applyOverride', () {
    test('override wins for the fields it sets', () {
      final merged = PlaceOverrideService.applyOverride(
          _base, {'lat': 11.9700, 'lng': 121.9300});
      expect(merged.lat, 11.9700);
      expect(merged.lng, 121.9300);
      expect(merged.name, _base.name);
      expect(merged.id, _base.id);
      expect(merged.province, _base.province);
      expect(merged.destination, _base.destination);
    });

    test('renames and re-categorizes a place', () {
      final merged = PlaceOverrideService.applyOverride(_base, {
        'name': 'White Beach Station 2',
        'filter': 'things_to_do',
      });
      expect(merged.name, 'White Beach Station 2');
      expect(merged.filter, 'things_to_do');
    });

    test('empty override keeps bundled values', () {
      final merged = PlaceOverrideService.applyOverride(_base, {});
      expect(merged.name, _base.name);
      expect(merged.lat, _base.lat);
      expect(merged.points, _base.points);
    });

    test('invalid filter in override keeps bundled filter', () {
      final merged = PlaceOverrideService.applyOverride(
          _base, {'filter': 'mystery'});
      expect(merged.filter, _base.filter);
    });

    test('points are clamped to 100..1000', () {
      final merged = PlaceOverrideService.applyOverride(
          _base, {'points': 9999});
      expect(merged.points, 1000);
    });
  });
}
