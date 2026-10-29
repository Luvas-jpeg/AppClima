import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../domain/route_result.dart';

class RouteService {
  RouteService({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _configuredKey = apiKey;

  final http.Client _client;
  final String? _configuredKey;
  String get _apiKey =>
      _configuredKey ??
      (dotenv.isInitialized ? dotenv.env['GEOAPIFY_API_KEY'] ?? '' : '');

  void close() => _client.close();

  Future<List<RouteDestination>> searchDestinations(
    String text,
    LatLng? near, {
    bool autocomplete = true,
  }) async {
    final query = text.trim();
    if (query.length < 3) return const [];
    final cepInput = RegExp(
      r'^(?:CEP\s*:?\s*)?([0-9]{5})-?([0-9]{3})$',
      caseSensitive: false,
    ).firstMatch(query);
    final numericInput = RegExp(
      r'^(?:CEP\s*:?\s*)?[0-9-]+$',
      caseSensitive: false,
    ).hasMatch(query);
    if (numericInput && cepInput == null) return const [];
    if (cepInput != null) {
      return _searchPostcode('${cepInput.group(1)}${cepInput.group(2)}');
    }
    final data = await _get(
      '/v1/geocode/${autocomplete ? 'autocomplete' : 'search'}',
      {
        'text': query,
        'limit': '5',
        'lang': 'pt',
        if (near != null)
          'bias': 'proximity:${near.longitude},${near.latitude}',
      },
    );
    return _features(data).map(_destination).toList();
  }

  Future<List<RouteDestination>> _searchPostcode(String digits) async {
    final formatted = '${digits.substring(0, 5)}-${digits.substring(5)}';
    final direct = await _get('/v1/geocode/search', {
      'postcode': formatted,
      'type': 'postcode',
      'filter': 'countrycode:br',
      'lang': 'pt',
      'limit': '5',
    });
    final matches = _features(direct).where((feature) {
      final properties = feature['properties'] as Map<String, dynamic>;
      final postcode = properties['postcode']?.toString().replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      return postcode == digits && properties['country_code'] == 'br';
    }).toList();
    if (matches.isNotEmpty) {
      return matches.map((feature) {
        final destination = _destination(feature);
        return RouteDestination(
          name: destination.name,
          location: destination.location,
          requiresMapConfirmation: true,
        );
      }).toList();
    }

    // Postal coverage is incomplete in the geocoder. Resolve the address in a
    // Brazilian postal source, then geocode only matching streets/areas.
    final http.Response response;
    try {
      response = await _client
          .get(Uri.https('viacep.com.br', '/ws/$digits/json/'))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw Exception(
        'Não foi possível consultar esse CEP. Verifique a internet e tente novamente.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception('O serviço de CEP está indisponível. Tente novamente.');
    }
    final Map<String, dynamic> postal;
    try {
      postal = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('O serviço de CEP retornou uma resposta inválida.');
    }
    if (postal['erro'] == true || postal['erro'] == 'true') return const [];
    final city = postal['localidade']?.toString().trim() ?? '';
    final street = postal['logradouro']?.toString().trim() ?? '';
    final neighborhood = postal['bairro']?.toString().trim() ?? '';
    final state = postal['uf']?.toString().trim() ?? '';
    if (city.isEmpty || state.isEmpty) {
      throw Exception('Não foi possível identificar a cidade desse CEP.');
    }
    final label = [
      street,
      neighborhood,
      '$city - $state',
      'CEP $formatted',
    ].where((part) => part.isNotEmpty).join(', ');
    final searches = <({Map<String, String> query, String level})>[
      if (street.isNotEmpty)
        (
          query: {'street': street, 'city': city, 'state': state},
          level: 'street',
        ),
      if (neighborhood.isNotEmpty)
        (
          query: {
            'text': '$neighborhood, $city, $state, Brasil',
            'type': 'locality',
          },
          level: 'neighborhood',
        ),
      (query: {'city': city, 'state': state, 'type': 'city'}, level: 'city'),
    ];
    for (final search in searches) {
      final query = search.query;
      final data = await _get('/v1/geocode/search', {
        ...query,
        if (!query.containsKey('text')) 'country': 'Brasil',
        'filter': 'countrycode:br',
        'lang': 'pt',
        'limit': '5',
      });
      for (final feature in _features(data)) {
        final properties = feature['properties'] as Map<String, dynamic>;
        final resultCity =
            properties['city'] ??
            properties['town'] ??
            properties['municipality'] ??
            (properties['result_type'] == 'city' ? properties['name'] : null);
        if (_normalized(resultCity) != _normalized(city)) continue;
        final resultState = properties['state_code']?.toString();
        if (resultState != null && resultState.split('-').last != state) {
          continue;
        }
        final matches = switch (search.level) {
          'street' =>
            properties['result_type'] != 'city' &&
                _normalized(properties['street']) == _normalized(street),
          'neighborhood' =>
            _normalized(
                  properties['suburb'] ??
                      properties['district'] ??
                      properties['name'],
                ) ==
                _normalized(neighborhood),
          _ => properties['result_type'] == 'city',
        };
        if (!matches) continue;
        return [
          RouteDestination(
            name: label,
            location: _destination(feature).location,
            requiresMapConfirmation: true,
            requiresPreciseMapSelection: search.level != 'street',
          ),
        ];
      }
    }
    throw Exception(
      'CEP encontrado: $label. Não foi possível localizar a região no mapa. Busque pelo endereço ou marque o destino manualmente.',
    );
  }

  String _normalized(Object? value) {
    var text = value?.toString().toLowerCase() ?? '';
    const accented = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const plain = 'aaaaaeeeeiiiiooooouuuuc';
    for (var index = 0; index < accented.length; index++) {
      text = text.replaceAll(accented[index], plain[index]);
    }
    return text.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<RouteDestination> reverseGeocode(LatLng location) async {
    final data = await _get('/v1/geocode/reverse', {
      'lat': '${location.latitude}',
      'lon': '${location.longitude}',
      'limit': '1',
      'lang': 'pt',
    });
    final features = _features(data);
    if (features.isEmpty) {
      throw Exception('Nenhum endereço encontrado para este ponto.');
    }
    return RouteDestination(
      name: _destination(features.first).name,
      // Preserve the exact point tapped instead of snapping to a nearby address.
      location: location,
      isMapSelection: true,
    );
  }

  Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    required String profile,
  }) async {
    final data = await _get('/v1/routing', {
      'waypoints':
          '${origin.latitude},${origin.longitude}|'
          '${destination.latitude},${destination.longitude}',
      'mode': profile,
      'units': 'metric',
      'lang': 'pt',
    });
    final features = _features(data);
    if (features.isEmpty) {
      throw Exception('Nenhuma rota encontrada para esse transporte.');
    }
    try {
      final feature = features.first;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List;
      final Iterable<dynamic> pairs;
      if (geometry['type'] == 'MultiLineString') {
        pairs = coordinates.expand((line) => line as List);
      } else if (geometry['type'] == 'LineString') {
        pairs = coordinates;
      } else {
        throw const FormatException();
      }
      final points = pairs
          .map(
            (pair) => LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            ),
          )
          .toList();
      if (points.length < 2) throw const FormatException();
      final properties = feature['properties'] as Map<String, dynamic>;
      return RouteResult(
        points: points,
        distanceMeters: (properties['distance'] as num).toDouble(),
        durationSeconds: (properties['time'] as num).toDouble(),
      );
    } catch (_) {
      throw Exception('A Geoapify retornou uma rota em formato inválido.');
    }
  }

  RouteDestination _destination(Map<String, dynamic> feature) {
    try {
      final properties = feature['properties'] as Map<String, dynamic>;
      final coordinates = feature['geometry']['coordinates'] as List;
      return RouteDestination(
        name: properties['formatted'] as String,
        location: LatLng(
          (coordinates[1] as num).toDouble(),
          (coordinates[0] as num).toDouble(),
        ),
      );
    } catch (_) {
      throw Exception('A Geoapify retornou um endereço em formato inválido.');
    }
  }

  List<Map<String, dynamic>> _features(Map<String, dynamic> data) {
    final features = data['features'];
    if (features is! List) {
      throw Exception('Resposta inválida da Geoapify. Tente novamente.');
    }
    return features.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> parameters,
  ) async {
    if (_apiKey.trim().isEmpty) {
      throw Exception('Configure GEOAPIFY_API_KEY no arquivo .env do app.');
    }
    final uri = Uri.https('api.geoapify.com', path, {
      ...parameters,
      'apiKey': _apiKey,
    });
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('A Geoapify demorou para responder. Tente novamente.');
    } catch (_) {
      // HTTP exceptions may contain the URL and its API key.
      throw Exception(
        'Não foi possível conectar à Geoapify. Verifique a internet.',
      );
    }
    if (response.statusCode != 200) {
      final message = switch (response.statusCode) {
        401 || 403 => 'A Geoapify recusou a chave. Confira a chave e suas restrições no painel.',
        429 => 'Limite de consultas da Geoapify atingido. Aguarde e tente novamente.',
        400 => 'A Geoapify não conseguiu processar esse endereço ou trajeto.',
        _ =>
          'A Geoapify está indisponível (HTTP ${response.statusCode}). Tente novamente.',
      };
      throw Exception(message);
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Resposta inválida da Geoapify. Tente novamente.');
    }
  }
}
