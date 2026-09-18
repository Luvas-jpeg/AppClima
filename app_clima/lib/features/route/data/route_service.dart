import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../domain/route_result.dart';

class RouteService {
  static String get _apiKey => dotenv.env['ORS_API_KEY'] ?? '';
  static const _host = 'api.openrouteservice.org';

  static Future<RouteDestination> findDestination(String text, LatLng near) async {
    _checkKey();
    final uri = Uri.https(_host, '/geocode/search', {
      'text': text,
      'size': '1',
      'focus.point.lon': near.longitude.toString(),
      'focus.point.lat': near.latitude.toString(),
    });
    final response = await http
        .get(uri, headers: {'Authorization': _apiKey})
        .timeout(const Duration(seconds: 15));
    final data = _decodeResponse(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, data));
    }
    if ((data['features'] as List).isEmpty) {
      throw Exception('Destino nao encontrado.');
    }
    final feature = (data['features'] as List).first as Map<String, dynamic>;
    final coordinates = feature['geometry']['coordinates'] as List;
    final properties = feature['properties'] as Map<String, dynamic>;
    return RouteDestination(
      name: properties['label']?.toString() ?? text,
      location: LatLng((coordinates[1] as num).toDouble(), (coordinates[0] as num).toDouble()),
    );
  }

  static Future<RouteDestination> reverseGeocode(LatLng location) async {
    _checkKey();
    final uri = Uri.https(_host, '/geocode/reverse', {
      'point.lon': location.longitude.toString(),
      'point.lat': location.latitude.toString(),
      'size': '1',
    });
    final response = await http
        .get(uri, headers: {'Authorization': _apiKey})
        .timeout(const Duration(seconds: 15));
    final data = _decodeResponse(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, data));
    }
    final features = data['features'] as List? ?? const [];
    if (features.isEmpty) {
      throw Exception('Nao foi encontrado endereco para este ponto.');
    }
    final properties = (features.first as Map<String, dynamic>)['properties'] as Map<String, dynamic>;
    final label = properties['label']?.toString();
    final name = properties['name']?.toString();
    return RouteDestination(
      name: label?.isNotEmpty == true ? label! : (name?.isNotEmpty == true ? name! : 'Ponto selecionado no mapa'),
      location: location,
      isMapSelection: true,
    );
  }

  static Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    required String profile,
  }) async {
    _checkKey();
    final uri = Uri.https(_host, '/v2/directions/$profile/geojson');
    final response = await http
        .post(
          uri,
          headers: {'Authorization': _apiKey, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'coordinates': [
              [origin.longitude, origin.latitude],
              [destination.longitude, destination.latitude],
            ],
          }),
        )
        .timeout(const Duration(seconds: 15));
    final data = _decodeResponse(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, data));
    }
    final feature = (data['features'] as List).first as Map<String, dynamic>;
    final coordinates = feature['geometry']['coordinates'] as List;
    final summary = feature['properties']['summary'] as Map<String, dynamic>;
    return RouteResult(
      points: coordinates.map((point) {
        final pair = point as List;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList(),
      distanceMeters: (summary['distance'] as num).toDouble(),
      durationSeconds: (summary['duration'] as num).toDouble(),
    );
  }

  static void _checkKey() {
    if (_apiKey.isEmpty) throw Exception('A chave do OpenRouteService nao foi configurada.');
  }

  static Map<String, dynamic> _decodeResponse(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  static String _errorMessage(http.Response response, Map<String, dynamic> data) {
    if (response.statusCode == 403) {
      if (response.headers['x-ratelimit-remaining'] == '0') {
        return 'O limite diario do OpenRouteService foi atingido. Aguarde a renovacao da cota ou use outra chave.';
      }
      return 'O OpenRouteService recusou a chave (403). Confira se a chave esta ativa e se foi copiada inteira.';
    }
    final error = data['error'];
    final message = error is Map<String, dynamic>
        ? error['message']
        : error is String
        ? error
        : data['message'];
    if (message?.toString().toLowerCase().contains('maximum distance') == true) {
      return 'O destino esta longe demais para uma unica rota nesta API. Escolha um ponto mais proximo.';
    }
    return 'OpenRouteService respondeu ${response.statusCode}: ${message ?? 'nao foi possivel calcular a rota.'}';
  }
}
