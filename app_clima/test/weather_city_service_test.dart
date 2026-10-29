import 'dart:convert';

import 'package:app_clima/features/weather/data/weather_city_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

final bounds = LatLngBounds(const LatLng(-24, -47), const LatLng(-23, -46));
Map<String, dynamic> feature(String name, double lon, double lat) => {
  'properties': {'name': name, 'state_code': 'SP', 'country_code': 'br'},
  'geometry': {
    'type': 'Point',
    'coordinates': [lon, lat],
  },
};

void main() {
  test(
    'busca cidades na área visível, elimina duplicatas e preserva coordenadas',
    () async {
      final service = WeatherCityService(
        apiKey: 'test',
        client: MockClient((request) async {
          expect(request.url.path, '/v2/places');
          expect(
            request.url.queryParameters['filter'],
            'rect:-47.0,-24.0,-46.0,-23.0',
          );
          expect(
            request.url.queryParameters['categories'],
            contains('populated_place.city'),
          );
          return http.Response(
            jsonEncode({
              'features': [
                feature('São Paulo', -46.63, -23.55),
                feature('São Paulo', -46.63, -23.55),
                feature('Osasco', -46.79, -23.53),
                feature('Fora da área', -44, -22),
              ],
            }),
            200,
          );
        }),
      );
      final cities = await service.findCities(bounds);
      expect(cities.map((city) => city.name), ['São Paulo', 'Osasco']);
      expect(cities.first.location, const LatLng(-23.55, -46.63));
      service.close();
    },
  );

  test('limita a oito cidades antes de consultar o clima', () async {
    final service = WeatherCityService(
      apiKey: 'test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'features': [
              for (var i = 0; i < 16; i++) feature('Cidade $i', -46.5, -23.5),
            ],
          }),
          200,
        ),
      ),
    );
    expect(await service.findCities(bounds), hasLength(8));
    service.close();
  });

  test(
    'erro de cota não expõe chave e ausência de cidades é lista vazia',
    () async {
      final service = WeatherCityService(
        apiKey: 'segredo',
        client: MockClient((_) async => http.Response('segredo', 429)),
      );
      await expectLater(
        service.findCities(bounds),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('Limite') &&
                !e.toString().contains('segredo'),
          ),
        ),
      );
      service.close();
      final empty = WeatherCityService(
        apiKey: 'test',
        client: MockClient((_) async => http.Response('{"features":[]}', 200)),
      );
      expect(await empty.findCities(bounds), isEmpty);
      empty.close();
    },
  );
}
