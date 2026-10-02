import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Current weather snapshot for a place detail header.
class WeatherNow {
  final double tempC;
  final String condition;
  final String emoji;
  final bool isRaining;

  const WeatherNow({
    required this.tempC,
    required this.condition,
    required this.emoji,
    required this.isRaining,
  });
}

/// Keyless weather via Open-Meteo (no account, no API key).
///
/// WMO weather codes are mapped to a (condition, emoji, isRaining) tuple.
/// Returns null on any error (no network, bad payload, timeout).
class WeatherService {
  static const Duration _timeout = Duration(seconds: 8);

  /// Maps a WMO weather code to (condition, emoji, isRaining).
  static WeatherNow mapCode(int code, double tempC) {
    if (code == 0) {
      return WeatherNow(
          tempC: tempC, condition: 'Clear', emoji: '☀️', isRaining: false);
    }
    if (code >= 1 && code <= 3) {
      return WeatherNow(
          tempC: tempC, condition: 'Cloudy', emoji: '⛅', isRaining: false);
    }
    if (code == 45 || code == 48) {
      return WeatherNow(
          tempC: tempC, condition: 'Foggy', emoji: '🌫️', isRaining: false);
    }
    if (code >= 51 && code <= 57) {
      return WeatherNow(
          tempC: tempC, condition: 'Drizzle', emoji: '🌦️', isRaining: true);
    }
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      return WeatherNow(
          tempC: tempC, condition: 'Rain', emoji: '🌧️', isRaining: true);
    }
    if (code >= 71 && code <= 77) {
      return WeatherNow(
          tempC: tempC, condition: 'Snow', emoji: '❄️', isRaining: false);
    }
    if (code >= 95 && code <= 99) {
      return WeatherNow(
          tempC: tempC,
          condition: 'Thunderstorm',
          emoji: '⛈️',
          isRaining: true);
    }
    return WeatherNow(
        tempC: tempC, condition: 'Cloudy', emoji: '⛅', isRaining: false);
  }

  /// Fetches current weather for [lat]/[lng]. Never throws: returns null
  /// on any failure.
  Future<WeatherNow?> current(double lat, double lng) async {
    try {
      final uri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code');
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final j = json.decode(res.body);
      if (j is! Map<String, dynamic>) return null;
      final cur = j['current'];
      if (cur is! Map<String, dynamic>) return null;
      final temp = (cur['temperature_2m'] as num?)?.toDouble();
      final code = (cur['weather_code'] as num?)?.toInt();
      if (temp == null || code == null) return null;
      return mapCode(code, temp);
    } catch (_) {
      return null;
    }
  }
}
