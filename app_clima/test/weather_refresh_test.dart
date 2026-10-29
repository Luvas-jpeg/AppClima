import 'dart:async';

import 'package:app_clima/main.dart';
import 'package:app_clima/features/weather/domain/weather_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

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
WeatherData sample(double temperature, int minute) => WeatherData(
  locationName: 'São Paulo',
  temperature: temperature,
  feelsLike: 30,
  condition: 'Parcialmente nublado',
  windKph: 15,
  windDirection: 'SE',
  gustKph: 20,
  uv: 3,
  humidity: 60,
  pressureMb: 1010,
  visibilityKm: 10,
  cloudCoverage: 50,
  precipitationMm: 0,
  forecastPrecipitationMm: 0,
  rainChance: 20,
  hours: [],
  days: [],
  sourceUpdatedAt: DateTime(2026, 10, 28, 14, minute),
);

void main() {
  testWidgets(
    'puxar para baixo consulta localização e clima novamente, atualizando dados e horário',
    (tester) async {
      var calls = 0;
      var locationCalls = 0;
      final refreshed = Completer<WeatherData>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherPage(
              locationProvider: () async {
                locationCalls++;
                return position();
              },
              forecastLoader: (_) async {
                calls++;
                return calls == 1 ? sample(29, 0) : refreshed.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('29°'), findsOneWidget);
      expect(find.text('Dados da WeatherAPI: 28/10 às 14:00'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('weather-home-list')),
        const Offset(0, 400),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 250));
      expect(calls, 2);
      expect(locationCalls, 2);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Atualizar clima',
              ),
            )
            .onPressed,
        isNull,
      );
      refreshed.complete(sample(26, 15));
      await tester.pumpAndSettle();
      expect(find.text('26°'), findsOneWidget);
      expect(find.text('29°'), findsNothing);
      expect(find.text('Dados da WeatherAPI: 28/10 às 14:15'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'falha na atualização mantém os dados anteriores e permite tentar novamente',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherPage(
              locationProvider: () async => position(),
              forecastLoader: (_) async {
                calls++;
                if (calls == 2) throw Exception('Sem conexão');
                return sample(29, 0);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Atualizar clima',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('29°'), findsOneWidget);
      expect(
        find.textContaining('Os últimos dados foram mantidos'),
        findsOneWidget,
      );
      expect(find.text('Dados da WeatherAPI: 28/10 às 14:00'), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Atualizar clima',
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(
        find.textContaining('Os últimos dados foram mantidos'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('toques repetidos compartilham a consulta em andamento', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<WeatherData>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeatherPage(
            locationProvider: () async => position(),
            forecastLoader: (_) async {
              calls++;
              return calls == 1 ? sample(29, 0) : pending.future;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final callback = tester
        .widget<IconButton>(
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton && widget.tooltip == 'Atualizar clima',
          ),
        )
        .onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(calls, 2);
    pending.complete(sample(26, 15));
    await tester.pumpAndSettle();
    expect(find.text('26°'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
