import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';

import '../domain/weather_data.dart';
import 'weather_forecast_client.dart';

class LocationService {
  static Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Ative a localizacao do aparelho para ver o clima.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('A permissao de localizacao foi negada.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permita a localizacao nas configuracoes do Android.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () =>
          throw Exception('O GPS demorou para responder. Tente novamente.'),
    );
  }
}

class WeatherService {
  static final _forecastClient = WeatherForecastClient(
    apiKey: () =>
        dotenv.isInitialized ? dotenv.env['WEATHER_API_KEY'] ?? '' : '',
  );

  static Future<WeatherData> fetchForecast(LatLng location) async {
    final data = await _forecastClient.fetch(location, days: 3);
    final weather = _weatherFromJson(data);
    unawaited(_saveForecast(location, data));
    return weather;
  }

  static Future<void> _saveForecast(
    LatLng location,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_weather_v1',
        jsonEncode({
          'latitude': location.latitude,
          'longitude': location.longitude,
          'savedAt': DateTime.now().toIso8601String(),
          'data': data,
        }),
      );
    } catch (_) {}
  }

  static Future<({WeatherData weather, LatLng location, DateTime savedAt})?>
  loadSavedForecast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('last_weather_v1');
      if (raw == null) return null;
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.parse(saved['savedAt'] as String);
      if (DateTime.now().difference(savedAt) > const Duration(hours: 24)) {
        return null;
      }
      return (
        weather: _weatherFromJson(saved['data'] as Map<String, dynamic>),
        location: LatLng(
          (saved['latitude'] as num).toDouble(),
          (saved['longitude'] as num).toDouble(),
        ),
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<WeatherData> fetchForecastAt(
    LatLng location,
    DateTime expectedTime,
  ) async {
    final data = await _forecastClient.fetch(
      location,
      days: 2,
      allowCached: true,
    );
    return _weatherFromJson(data, forecastAt: expectedTime);
  }

  static WeatherData _weatherFromJson(
    Map<String, dynamic> data, {
    DateTime? forecastAt,
  }) {
    final current = data['current'] as Map<String, dynamic>;
    final location = data['location'] as Map<String, dynamic>;
    final forecast = data['forecast'] as Map<String, dynamic>;
    final forecastDays = (forecast['forecastday'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final forecastDay = forecastDays.first;
    final hours = forecastDay['hour'] as List<dynamic>;
    final allHours = forecastDays
        .expand(
          (day) => (day['hour'] as List<dynamic>).cast<Map<String, dynamic>>(),
        )
        .toList();
    final now = DateTime.now();
    final nextHours = hours
        .cast<Map<String, dynamic>>()
        .where((hour) {
          final time = DateTime.tryParse(hour['time'] as String);
          return time == null || !time.isBefore(now);
        })
        .take(4)
        .map(ForecastHour.fromJson)
        .toList();
    final nextHour = hours.firstWhere(
      (hour) =>
          DateTime.tryParse((hour as Map<String, dynamic>)['time'] as String)
              ?.isAfter(now) ??
          false,
      orElse: () => hours.first,
    ) as Map<String, dynamic>;
    final selectedHour = forecastAt == null
        ? null
        : allHours.reduce((closest, candidate) {
            final closestTime = DateTime.parse(closest['time'] as String);
            final candidateTime = DateTime.parse(candidate['time'] as String);
            final closestDistance = closestTime.difference(forecastAt).abs();
            final candidateDistance = candidateTime
                .difference(forecastAt)
                .abs();
            return candidateDistance < closestDistance ? candidate : closest;
          });
    final weatherSource = selectedHour ?? current;
    final condition = weatherSource['condition'] as Map<String, dynamic>;

    final sourceEpoch = current['last_updated_epoch'] as num?;
    return WeatherData(
      sourceUpdatedAt: forecastAt == null && sourceEpoch != null
          ? DateTime.fromMillisecondsSinceEpoch(
              sourceEpoch.toInt() * 1000,
              isUtc: true,
            ).toLocal()
          : null,
      locationName: '${location['name']}, ${location['region']}',
      temperature: (weatherSource['temp_c'] as num).toDouble(),
      feelsLike: (weatherSource['feelslike_c'] as num).toDouble(),
      condition: condition['text'] as String,
      windKph: (weatherSource['wind_kph'] as num).toDouble(),
      windDirection: weatherSource['wind_dir']?.toString() ?? '--',
      gustKph: (weatherSource['gust_kph'] as num?)?.toDouble() ?? 0,
      uv: (weatherSource['uv'] as num).toDouble(),
      humidity: (weatherSource['humidity'] as num?)?.round() ?? 0,
      pressureMb: (weatherSource['pressure_mb'] as num?)?.toDouble() ?? 0,
      visibilityKm: (weatherSource['vis_km'] as num?)?.toDouble() ?? 0,
      cloudCoverage: (weatherSource['cloud'] as num?)?.round() ?? 0,
      precipitationMm: (weatherSource['precip_mm'] as num).toDouble(),
      forecastPrecipitationMm: ((selectedHour ?? nextHour)['precip_mm'] as num)
          .toDouble(),
      rainChance:
          int.tryParse(
            (selectedHour ?? nextHour)['chance_of_rain'].toString(),
          ) ??
          0,
      hours: nextHours.isEmpty
          ? hours.take(4).map((hour) => ForecastHour.fromJson(hour)).toList()
          : nextHours,
      days: [
        for (var index = 0; index < forecastDays.length; index++)
          DailyForecast.fromJson(forecastDays[index], index),
      ],
    );
  }
}
