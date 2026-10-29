import 'dart:async';
import 'dart:convert';

import 'package:app_clima/features/route/data/route_service.dart';
import 'package:app_clima/features/route/domain/route_result.dart';
import 'package:app_clima/features/route/presentation/route_search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

http.Response response(String name) => http.Response(
  jsonEncode({
    'features': [
      {
        'properties': {'formatted': name},
        'geometry': {
          'coordinates': [-46.65, -23.56],
        },
      },
    ],
  }),
  200,
);

void main() {
  testWidgets(
    'CEP localizado mostra marcador e permite confirmar sem redigitar endereço',
    (tester) async {
      final service = RouteService(
        apiKey: 'test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'formatted': 'CEP 01310-100, São Paulo',
                    'postcode': '01310-100',
                    'country_code': 'br',
                  },
                  'geometry': {
                    'coordinates': [-46.65, -23.56],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      addTearDown(service.close);
      RouteDestination? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await Navigator.of(context).push<RouteDestination>(
                    MaterialPageRoute(
                      builder: (_) => RouteSearchPage(service: service),
                    ),
                  );
                },
                child: const Text('Buscar CEP'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buscar CEP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '01310100');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CEP 01310-100, São Paulo'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.location_pin), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar destino'));
      await tester.pumpAndSettle();
      expect(selected?.location, const LatLng(-23.56, -46.65));
      expect(selected?.requiresMapConfirmation, isFalse);
      expect(find.text('Buscar CEP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('busca endereço sem esperar a localização do GPS', (
    tester,
  ) async {
    final requests = <Uri>[];
    final service = RouteService(
      apiKey: 'test',
      client: MockClient((request) async {
        requests.add(request.url);
        return response('Paulista, São Paulo');
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(home: RouteSearchPage(service: service)),
    );
    await tester.enterText(find.byType(TextField), 'Paulista');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(requests.single.queryParameters.containsKey('bias'), isFalse);
    expect(find.text('Paulista, São Paulo'), findsOneWidget);
  });

  testWidgets('busca aguarda digitação e descarta respostas antigas', (
    tester,
  ) async {
    final pending = <Completer<http.Response>>[];
    final service = RouteService(
      apiKey: 'test',
      client: MockClient((_) {
        final completer = Completer<http.Response>();
        pending.add(completer);
        return completer.future;
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: RouteSearchPage(origin: const LatLng(0, 0), service: service),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Paulista');
    await tester.pump(const Duration(milliseconds: 449));
    expect(pending, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(pending, hasLength(1));
    await tester.enterText(find.byType(TextField), 'Consolação');
    await tester.pump(const Duration(milliseconds: 450));
    pending[1].complete(response('Consolação, São Paulo'));
    await tester.pumpAndSettle();
    pending[0].complete(response('Paulista, São Paulo'));
    await tester.pumpAndSettle();
    expect(find.text('Consolação, São Paulo'), findsOneWidget);
    expect(find.text('Paulista, São Paulo'), findsNothing);
  });

  testWidgets('selecionar endereço retorna à página anterior com coordenadas', (
    tester,
  ) async {
    final service = RouteService(
      apiKey: 'test',
      client: MockClient((_) async => response('Paulista, São Paulo')),
    );
    addTearDown(service.close);
    RouteDestination? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await Navigator.of(context).push<RouteDestination>(
                  MaterialPageRoute(
                    builder: (_) => RouteSearchPage(
                      origin: const LatLng(0, 0),
                      service: service,
                    ),
                  ),
                );
              },
              child: const Text('Abrir busca'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir busca'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Paulista');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paulista, São Paulo'));
    await tester.pumpAndSettle();
    expect(selected?.name, 'Paulista, São Paulo');
    expect(selected?.location, const LatLng(-23.56, -46.65));
    expect(find.text('Abrir busca'), findsOneWidget);
  });
  testWidgets(
    'CEP sem coordenada exata pede confirmação no mapa antes de retornar destino',
    (tester) async {
      final service = RouteService(
        apiKey: 'test',
        client: MockClient((request) async {
          if (request.url.host == 'viacep.com.br') {
            return http.Response(
              jsonEncode({
                'logradouro': 'Rua de Teste',
                'bairro': '',
                'localidade': 'São José do Rio Preto',
                'uf': 'SP',
              }),
              200,
            );
          }
          final query = request.url.queryParameters;
          if (query['type'] != 'city') {
            return http.Response('{"features":[]}', 200);
          }
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'formatted': 'São José do Rio Preto',
                    'city': 'São José do Rio Preto',
                    'state_code': 'SP',
                    'result_type': 'city',
                  },
                  'geometry': {
                    'coordinates': [-49.38, -20.81],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      RouteDestination? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await Navigator.of(context).push<RouteDestination>(
                    MaterialPageRoute(
                      builder: (_) => RouteSearchPage(
                        origin: const LatLng(-23.55, -46.63),
                        service: service,
                      ),
                    ),
                  );
                },
                child: const Text('Abrir busca CEP'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir busca CEP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '15054700');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.textContaining('CEP 15054-700'), findsOneWidget);
      await tester.tap(find.textContaining('CEP 15054-700'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar destino'), findsNWidgets(2));
      expect(selected, isNull);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.initialCenter, const LatLng(-20.81, -49.38));
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar destino'));
      await tester.pumpAndSettle();
      expect(selected?.name, contains('CEP 15054-700'));
      expect(selected?.isMapSelection, isTrue);
      expect(selected?.requiresMapConfirmation, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
