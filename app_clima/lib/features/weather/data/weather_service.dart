import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../domain/weather_data.dart';

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
  static String get _apiKey => dotenv.env['WEATHER_API_KEY'] ?? '';

  static Future<WeatherData> fetchForecast(LatLng location) async {
    final data = await _fetchForecastJson(location, days: 3);
    return _weatherFromJson(data);
  }

  static Future<WeatherData> fetchForecastAt(
    LatLng location,
    DateTime expectedTime,
  ) async {
    final data = await _fetchForecastJson(location, days: 2);
    return _weatherFromJson(data, forecastAt: expectedTime);
  }

  static Future<Map<String, dynamic>> _fetchForecastJson(
    LatLng location, {
    int days = 1,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('A chave do WeatherAPI ainda nao foi configurada.');
    }

    final uri = Uri.https('api.weatherapi.com', '/v1/forecast.json', {
      'key': _apiKey,
      'q': '${location.latitude},${location.longitude}',
      'days': '$days',
      'aqi': 'no',
      'alerts': 'no',
      'lang': 'pt',
    });
    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('A WeatherAPI demorou para responder. Tente novamente.');
    } catch (_) {
      throw Exception(
        'Não foi possível conectar à WeatherAPI. Verifique a internet.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final apiError = data['error'] as Map<String, dynamic>?;
      throw Exception(
        'WeatherAPI respondeu ${response.statusCode}: '
        '${apiError?['message'] ?? 'Nao foi possivel obter o clima.'}',
      );
    }

    return data;
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
