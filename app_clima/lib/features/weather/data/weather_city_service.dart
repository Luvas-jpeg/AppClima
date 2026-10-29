import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../domain/weather_city.dart';

class WeatherCityService {
  WeatherCityService({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _key = apiKey;

  final http.Client _client;
  final String? _key;
  void close() => _client.close();

  Future<List<WeatherCity>> findCities(LatLngBounds bounds) async {
    final key =
        _key ??
        (dotenv.isInitialized ? dotenv.env['GEOAPIFY_API_KEY'] ?? '' : '');
    if (key.isEmpty) {
      throw Exception('Configure GEOAPIFY_API_KEY para buscar as cidades.');
    }
    final uri = Uri.https('api.geoapify.com', '/v2/places', {
      'categories': 'populated_place.city,populated_place.town,populated_place.municipality',
      'filter':
          'rect:${bounds.west},${bounds.south},${bounds.east},${bounds.north}',
      'bias': 'proximity:${bounds.center.longitude},${bounds.center.latitude}',
      'limit': '16',
      'lang': 'pt',
      'apiKey': key,
    });
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception(
        'A busca de cidades demorou para responder. Tente novamente.',
      );
    } catch (_) {
      throw Exception(
        'Não foi possível buscar as cidades. Verifique a internet.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception(switch (response.statusCode) {
        401 || 403 => 'A Geoapify recusou a busca de cidades. Confira a chave e suas restrições.',
        429 =>
          'Limite de consultas de cidades atingido. Aguarde e tente novamente.',
        _ =>
          'Não foi possível buscar as cidades (HTTP ${response.statusCode}).',
      });
    }
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final cities = <WeatherCity>[];
      final seen = <String>{};
      for (final feature in data['features'] as List) {
        final properties = feature['properties'] as Map<String, dynamic>;
        final geometry = feature['geometry'] as Map<String, dynamic>;
        if (geometry['type'] != 'Point') continue;
        final name =
            (properties['name'] ?? properties['city'] ?? properties['town'])
                ?.toString()
                .trim();
        if (name == null || name.isEmpty) continue;
        final coordinates = geometry['coordinates'] as List;
        final location = LatLng(
          (coordinates[1] as num).toDouble(),
          (coordinates[0] as num).toDouble(),
        );
        // A municipality and its urban center can describe the same city.
        final identity =
            '${name.toLowerCase()}|${properties['state_code'] ?? properties['state']}|${properties['country_code']}';
        if (!bounds.contains(location) || !seen.add(identity)) continue;
        cities.add(WeatherCity(id: identity, name: name, location: location));
        if (cities.length == 8) break;
      }
      return cities;
    } catch (_) {
      throw Exception('A Geoapify retornou cidades em formato inválido.');
    }
  }
}
