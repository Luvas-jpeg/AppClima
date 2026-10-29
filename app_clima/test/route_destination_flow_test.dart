import 'dart:async';
import 'dart:convert';

import 'package:app_clima/features/route/data/route_service.dart';
import 'package:app_clima/features/route/presentation/route_page.dart';
import 'package:app_clima/features/route/presentation/route_search_page.dart';
import 'package:app_clima/features/route/presentation/route_destination_picker_page.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

class _NavigationLog extends NavigatorObserver {
  var pushes = 0;
  var pops = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
  }
}

Position position() => Position(
  latitude: -23.55,
  longitude: -46.63,
  timestamp: DateTime(2026),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);

void main() {
  testWidgets('mapa pode ser aberto e marcado enquanto GPS carrega', (
    tester,
  ) async {
    final gps = Completer<Position>();
    final requestedDestinations = <String>[];
    final service = RouteService(
      apiKey: 'test',
      client: MockClient((request) async {
        if (request.url.path == '/v1/geocode/reverse') {
          return http.Response('{"features":[]}', 200);
        }
        requestedDestinations.add(request.url.queryParameters['waypoints']!);
        return http.Response('falha', 503);
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoutePage(locationProvider: () => gps.future, service: service),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Mapa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RouteDestinationPickerPage), findsOneWidget);
    expect(gps.isCompleted, isFalse);
    final mapFinder = find.descendant(
      of: find.byType(RouteDestinationPickerPage),
      matching: find.byType(FlutterMap),
    );
    final map = tester.widget<FlutterMap>(mapFinder);
    final selected = map.options.initialCenter;
    await tester.tapAt(tester.getCenter(mapFinder));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar destino'));
    expect(gps.isCompleted, isFalse);
    gps.complete(position());
    await tester.pumpAndSettle();
    expect(find.byType(RouteDestinationPickerPage), findsNothing);
    expect(find.text('Ponto selecionado no mapa'), findsOneWidget);
    final coordinates = requestedDestinations.single
        .split('|')
        .last
        .split(',')
        .map(double.parse)
        .toList();
    expect(coordinates[0], closeTo(selected.latitude, .000001));
    expect(coordinates[1], closeTo(selected.longitude, .000001));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'toque no mapa do planejamento abre confirmação do ponto marcado',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutePage(locationProvider: () async => position()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = find.byType(FlutterMap);
      await tester.ensureVisible(map);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(map));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byType(RouteDestinationPickerPage), findsOneWidget);
      final picker = tester.widget<RouteDestinationPickerPage>(
        find.byType(RouteDestinationPickerPage),
      );
      expect(picker.initialDestination, isNotNull);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RoutePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GPS lento não impede abrir uma só busca e começar a digitar', (
    tester,
  ) async {
    final gps = Completer<Position>();
    var locationCalls = 0;
    final log = _NavigationLog();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [log],
        home: Scaffold(
          body: RoutePage(
            locationProvider: () {
              locationCalls++;
              return gps.future;
            },
          ),
        ),
      ),
    );
    final field = find.byType(TextField);
    final openSearch = tester.widget<TextField>(field).onTap!;
    await tester.tap(field);
    openSearch();
    openSearch();
    expect(locationCalls, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RouteSearchPage), findsOneWidget);
    expect(log.pushes, 2);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(find.byType(TextField).hitTestable(), 'Av');
    expect(find.text('Av'), findsOneWidget);
    expect(gps.isCompleted, isFalse);
    gps.complete(position());
    await tester.pumpAndSettle();
    expect(find.byType(RouteSearchPage), findsOneWidget);
    expect(log.pushes, 2); // Initial page plus one search page.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(RouteSearchPage), findsNothing);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(log.pushes, 3); // Canceling must release the navigation guard.
    expect(locationCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resultado lento e seleção duplicada não fecham a página anterior',
    (tester) async {
      final response = Completer<http.Response>();
      var calls = 0;
      final service = RouteService(
        apiKey: 'test',
        client: MockClient((_) {
          calls++;
          return response.future;
        }),
      );
      addTearDown(service.close);
      final log = _NavigationLog();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [log],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RouteSearchPage(
                      origin: const LatLng(-23.55, -46.63),
                      service: service,
                    ),
                  ),
                ),
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
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(calls, 1);
      response.complete(
        http.Response(
          jsonEncode({
            'features': [
              {
                'properties': {'formatted': 'Avenida Paulista, São Paulo'},
                'geometry': {
                  'coordinates': [-46.65, -23.56],
                },
              },
            ],
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(log.pushes, 2);
      final select = tester.widget<ListTile>(find.byType(ListTile)).onTap!;
      select();
      select(); // Same callback before the previous screen has been disposed.
      await tester.pumpAndSettle();
      expect(log.pops, 1);
      expect(find.text('Abrir busca'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
