import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/network/request_pool.dart';

/// Reuses connections and shares recent route forecasts and pending requests.
class WeatherForecastClient {
  WeatherForecastClient({
    required this.apiKey,
    http.Client? client,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final String Function() apiKey;
  final http.Client _client;
  final DateTime Function() _clock;
  final _requests = RequestPool(4);
  final _cache = <Uri, ({DateTime fetchedAt, Map<String, dynamic> data})>{};
  final _pending = <Uri, Future<Map<String, dynamic>>>{};

  Future<Map<String, dynamic>> fetch(
    LatLng location, {
    required int days,
    bool allowCached = false,
  }) async {
    final key = apiKey();
    if (key.isEmpty) {
      throw Exception('A chave do WeatherAPI ainda nao foi configurada.');
    }
    final uri = Uri.https('api.weatherapi.com', '/v1/forecast.json', {
      'key': key,
      'q': '${location.latitude},${location.longitude}',
      'days': '$days',
      'aqi': 'no',
      'alerts': 'no',
      'lang': 'pt',
    });
    final now = _clock();
    _cache.removeWhere(
      (_, entry) =>
          now.difference(entry.fetchedAt) >= const Duration(minutes: 5) ||
          now.millisecondsSinceEpoch ~/ 900000 !=
              entry.fetchedAt.millisecondsSinceEpoch ~/ 900000,
    );
    final cached = _cache[uri];
    if (allowCached && cached != null) return cached.data;
    final pending = _pending[uri];
    if (pending != null) return pending;
    final request = _requests.run(() => _request(uri));
    _pending[uri] = request;
    try {
      final data = await request;
      if (_cache.length >= 16) _cache.remove(_cache.keys.first);
      _cache[uri] = (fetchedAt: _clock(), data: data);
      return data;
    } finally {
      _pending.remove(uri);
    }
  }

  Future<Map<String, dynamic>> _request(Uri uri) async {
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
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
}
