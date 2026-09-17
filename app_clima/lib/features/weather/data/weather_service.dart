import 'dart:convert';

import 'package:geolocator/geolocator.dart';
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
    );
  }
}

class WeatherService {
  static const _apiKey = String.fromEnvironment('WEATHER_API_KEY');

  static Future<WeatherData> fetchForecast(LatLng location) async {
    if (_apiKey.isEmpty) {
      throw Exception('A chave do WeatherAPI ainda nao foi configurada.');
    }

    final uri = Uri.https('api.weatherapi.com', '/v1/forecast.json', {
      'key': _apiKey,
      'q': '${location.latitude},${location.longitude}',
      'days': '1',
      'aqi': 'no',
      'alerts': 'no',
      'lang': 'pt',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final apiError = data['error'] as Map<String, dynamic>?;
      throw Exception(apiError?['message'] ?? 'Nao foi possivel obter o clima.');
    }

    return _weatherFromJson(data);
  }

  static WeatherData _weatherFromJson(Map<String, dynamic> data) {
    final current = data['current'] as Map<String, dynamic>;
    final location = data['location'] as Map<String, dynamic>;
    final forecast = data['forecast'] as Map<String, dynamic>;
    final forecastDay = (forecast['forecastday'] as List<dynamic>).first
        as Map<String, dynamic>;
    final hours = forecastDay['hour'] as List<dynamic>;
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

    return WeatherData(
      locationName: '${location['name']}, ${location['region']}',
      temperature: (current['temp_c'] as num).toDouble(),
      feelsLike: (current['feelslike_c'] as num).toDouble(),
      condition: (current['condition'] as Map<String, dynamic>)['text'] as String,
      windKph: (current['wind_kph'] as num).toDouble(),
      uv: (current['uv'] as num).toDouble(),
      precipitationMm: (current['precip_mm'] as num).toDouble(),
      rainChance: int.tryParse(nextHour['chance_of_rain'].toString()) ?? 0,
      hours: nextHours.isEmpty
          ? hours.take(4).map((hour) => ForecastHour.fromJson(hour)).toList()
          : nextHours,
    );
  }
}
