import 'dart:convert';

import 'package:app_clima/features/weather/data/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'recupera previsão salva com localização e horário da consulta',
    () async {
      final now = DateTime.now();
      final hour = {
        'time': now.add(const Duration(hours: 1)).toIso8601String(),
        'condition': {'text': 'Sol'},
        'temp_c': 25,
        'feelslike_c': 26,
        'wind_kph': 10,
        'uv': 3,
        'precip_mm': 0,
        'chance_of_rain': 20,
      };
      SharedPreferences.setMockInitialValues({
        'last_weather_v1': jsonEncode({
          'latitude': -23.55,
          'longitude': -46.63,
          'savedAt': now.toIso8601String(),
          'data': {
            'current': hour,
            'location': {'name': 'São Paulo', 'region': 'SP'},
            'forecast': {
              'forecastday': [
                {
                  'date': now.toIso8601String(),
                  'hour': [hour],
                  'day': {
                    'condition': {'text': 'Sol'},
                    'mintemp_c': 20,
                    'maxtemp_c': 27,
                    'daily_chance_of_rain': 20,
                    'totalprecip_mm': 0,
                  },
                },
              ],
            },
          },
        }),
      });
      final saved = await WeatherService.loadSavedForecast();
      expect(saved?.weather.temperature, 25);
      expect(saved?.location.latitude, -23.55);
      expect(saved?.savedAt, now);
    },
  );

  test('ignora cache corrompido ou com mais de um dia', () async {
    SharedPreferences.setMockInitialValues({'last_weather_v1': 'invalid'});
    expect(await WeatherService.loadSavedForecast(), isNull);
    SharedPreferences.setMockInitialValues({
      'last_weather_v1': jsonEncode({
        'savedAt': DateTime.now()
            .subtract(const Duration(hours: 25))
            .toIso8601String(),
      }),
    });
    expect(await WeatherService.loadSavedForecast(), isNull);
  });
}
