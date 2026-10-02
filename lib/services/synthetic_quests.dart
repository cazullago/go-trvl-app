import '../models/models.dart';

/// Builds [QuestPlace] views over data that is not in quest_places.json.
///
/// Cities/municipalities and provinces are not authored quest entries, but
/// the YouWare structure treats them as completable stops (500 pts per
/// city/town, 1000 pts per province, each with memories). Because
/// [GameService], [MemoryService] and the unlock flow all key purely on
/// place-id strings, these synthetic places participate in points,
/// Mark-as-done, unlocks and memories exactly like authored quests.
/// They are deliberately NOT passport stamps (the Alamat stamp ladder
/// stays scoped to the authored quest set).
class SyntheticQuests {
  /// Stable id for a city/municipality stop.
  static String cityId(Province p, ProvinceCity c) =>
      'city:${p.id}:${_slug(c.name)}';

  /// Stable id for a province stop.
  static String provinceId(Province p) => 'province:${p.id}';

  static String _slug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// A city/municipality as a completable quest stop (500 pts).
  static QuestPlace city(Province p, ProvinceCity c) {
    final isCapital =
        c.name.trim().toLowerCase() == p.capital.trim().toLowerCase();
    final kind = c.isCity ? 'City' : 'Municipality';
    return QuestPlace(
      id: cityId(p, c),
      name: c.name,
      province: p.name,
      destination: '',
      filter: 'where_to_go',
      lat: c.lat,
      lng: c.lng,
      address: '$kind · ${p.name}',
      blurb: isCapital
          ? 'The capital of ${p.name}.'
          : '$kind in the province of ${p.name}.',
      points: 500,
    );
  }

  /// All city/municipality stops for a province.
  static List<QuestPlace> citiesOf(Province p) =>
      p.cities.map((c) => city(p, c)).toList();

  /// A province as a completable stop (1000 pts).
  static QuestPlace province(Province p) => QuestPlace(
        id: provinceId(p),
        name: p.name,
        province: p.name,
        destination: '',
        filter: 'where_to_go',
        lat: p.lat,
        lng: p.lng,
        address: 'Province · ${p.region}',
        blurb: p.tagline.isNotEmpty ? p.tagline : p.description,
        points: 1000,
      );
}
