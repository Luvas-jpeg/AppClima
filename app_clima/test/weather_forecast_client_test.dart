import 'dart:async';

import 'package:app_clima/features/weather/data/weather_forecast_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const location = LatLng(-23.55, -46.63);

  test(
    'limita consultas simultâneas e compartilha uma consulta na fila',
    () async {
      final responses = List.generate(8, (_) => Completer<http.Response>());
      var calls = 0;
      var active = 0;
      var maximumActive = 0;
      final httpClient = MockClient((_) async {
        final index = calls++;
        active++;
        if (active > maximumActive) maximumActive = active;
        try {
          return await responses[index].future;
        } finally {
          active--;
        }
      });
      addTearDown(httpClient.close);
      final client = WeatherForecastClient(
        apiKey: () => 'test',
        client: httpClient,
      );
      final requests = [
        for (var i = 0; i < 8; i++)
          client.fetch(LatLng(0, i.toDouble()), days: 2),
      ];
      final shared = client.fetch(const LatLng(0, 7), days: 2);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 4);
      for (var i = 0; i < 4; i++) {
        responses[i].complete(http.Response('{}', 200));
      }
      await Future<void>.delayed(Duration.zero);
      expect(calls, 8);
      for (var i = 4; i < 8; i++) {
        responses[i].complete(http.Response('{}', 200));
      }
      await Future.wait([...requests, shared]);
      expect(maximumActive, 4);
      expect(calls, 8);
    },
  );

  test('mantém no máximo dezesseis respostas no cache', () async {
    var calls = 0;
    final httpClient = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    addTearDown(httpClient.close);
    final client = WeatherForecastClient(
      apiKey: () => 'test',
      client: httpClient,
    );
    for (var i = 0; i < 17; i++) {
      await client.fetch(LatLng(0, i.toDouble()), days: 2, allowCached: true);
    }
    await client.fetch(const LatLng(0, 16), days: 2, allowCached: true);
    expect(calls, 17);
    await client.fetch(const LatLng(0, 0), days: 2, allowCached: true);
    expect(calls, 18);
  });

  test(
    'compartilha consultas em andamento e reutiliza previsões recentes',
    () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final httpClient = MockClient((_) {
        calls++;
        return response.future;
      });
      addTearDown(httpClient.close);
      final client = WeatherForecastClient(
        apiKey: () => 'test',
        client: httpClient,
      );
      final first = client.fetch(location, days: 2, allowCached: true);
      final second = client.fetch(location, days: 2, allowCached: true);
      response.complete(http.Response('{"value":1}', 200));
      expect(await first, {'value': 1});
      expect(await second, {'value': 1});
      expect(await client.fetch(location, days: 2, allowCached: true), {
        'value': 1,
      });
      expect(calls, 1);
      await client.fetch(location, days: 2);
      expect(calls, 2); // Explicit refresh bypasses cached data.
    },
  );

  test(
    'renova após cinco minutos e na próxima atualização de quinze minutos',
    () async {
      var now = DateTime(2026, 10, 30, 14, 9);
      var calls = 0;
      final httpClient = MockClient(
        (_) async => http.Response('{"value":${++calls}}', 200),
      );
      addTearDown(httpClient.close);
      final client = WeatherForecastClient(
        apiKey: () => 'test',
        client: httpClient,
        clock: () => now,
      );
      await client.fetch(location, days: 2, allowCached: true);
      now = now.add(const Duration(minutes: 5));
      expect(await client.fetch(location, days: 2, allowCached: true), {
        'value': 2,
      });
      now = now.add(const Duration(minutes: 1));
      expect(await client.fetch(location, days: 2, allowCached: true), {
        'value': 3,
      });
      await client.fetch(location, days: 3, allowCached: true);
      await client.fetch(
        const LatLng(-23.56, -46.64),
        days: 2,
        allowCached: true,
      );
      expect(calls, 5);
    },
  );

  test('falha não fica no cache e permite tentar novamente', () async {
    var calls = 0;
    final httpClient = MockClient(
      (_) async => ++calls == 1
          ? http.Response('{"error":{"message":"Indisponível"}}', 503)
          : http.Response('{"value":2}', 200),
    );
    addTearDown(httpClient.close);
    final client = WeatherForecastClient(
      apiKey: () => 'test',
      client: httpClient,
    );
    await expectLater(
      client.fetch(location, days: 2, allowCached: true),
      throwsException,
    );
    expect(await client.fetch(location, days: 2, allowCached: true), {
      'value': 2,
    });
    expect(calls, 2);
  });
}
