import 'package:app_clima/features/route/domain/route_climate_point.dart';
import 'package:app_clima/features/route/domain/route_result.dart';
import 'package:app_clima/features/route/presentation/route_forecast_views.dart';
import 'package:app_clima/features/weather/domain/weather_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const weather = WeatherData(
  locationName: 'Região de Jundiaí',
  temperature: 23,
  feelsLike: 25,
  condition: 'Chuva moderada',
  windKph: 18,
  windDirection: 'SE',
  gustKph: 25,
  uv: 3,
  humidity: 80,
  pressureMb: 1010,
  visibilityKm: 8,
  cloudCoverage: 50,
  precipitationMm: 0,
  forecastPrecipitationMm: 2.4,
  rainChance: 75,
  hours: [],
  days: [],
);
final departure = DateTime(2026, 10, 27, 23, 40);
final points = [
  RouteClimatePoint(routeIndex: 0, arrivalAt: departure, weather: weather),
  RouteClimatePoint(
    routeIndex: 1,
    arrivalAt: departure.add(const Duration(minutes: 20)),
    weather: weather,
  ),
  RouteClimatePoint(
    routeIndex: 2,
    arrivalAt: departure.add(const Duration(minutes: 40)),
    weather: weather,
  ),
];
const route = RouteResult(
  points: [LatLng(0, 0), LatLng(0, 1), LatLng(0, 2)],
  distanceMeters: 25000,
  durationSeconds: 2400,
);

Widget summary({List<RouteClimatePoint>? forecasts, bool loading = false}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: RouteTripSummary(
            route: route,
            departureAt: departure,
            points: forecasts ?? points,
            isLoading: loading,
            onForecast: () {},
            onStart: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('resumo mostra distância, duração e chegada no dia seguinte', (
    tester,
  ) async {
    await tester.pumpWidget(summary());
    expect(find.text('25.0 km'), findsOneWidget);
    expect(find.text('40 min'), findsOneWidget);
    expect(find.text('28/10 · 00:20'), findsOneWidget);
    expect(
      find.text('Chuva possível em 3 pontos consultados.'),
      findsOneWidget,
    );
    expect(find.text('Iniciar viagem'), findsOneWidget);
  });

  testWidgets('falta de previsão não aparece como ausência de chuva', (
    tester,
  ) async {
    await tester.pumpWidget(summary(forecasts: []));
    expect(find.text('Previsão do trajeto indisponível.'), findsOneWidget);
    expect(find.textContaining('Baixa chance'), findsNothing);
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
    await tester.pumpWidget(summary(forecasts: [], loading: true));
    expect(find.text('Consultando o clima do caminho…'), findsOneWidget);
  });

  testWidgets(
    'linha do tempo devolve o trecho escolhido para localizar no mapa',
    (tester) async {
      RouteClimatePoint? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await Navigator.of(context)
                      .push<RouteClimatePoint>(
                        MaterialPageRoute(
                          builder: (_) => RouteForecastTimelinePage(
                            points: points,
                            departureAt: departure,
                          ),
                        ),
                      );
                },
                child: const Text('Abrir previsão'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir previsão'));
      await tester.pumpAndSettle();
      expect(find.text('Saída · 27/10 · 23:40'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Chegada · 28/10 · 00:20'),
        250,
      );
      await tester.tap(find.text('Chegada · 28/10 · 00:20'));
      await tester.pumpAndSettle();
      expect(selected, same(points.last));
      expect(find.text('Abrir previsão'), findsOneWidget);
    },
  );

  testWidgets('ícone no mapa abre previsão do horário de passagem', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 46,
              height: 46,
              child: RouteWeatherMapIcon(point: points[1], color: Colors.blue),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(RouteWeatherMapIcon));
    await tester.pumpAndSettle();
    expect(find.text('Passagem estimada: 28/10 · 00:00'), findsOneWidget);
    expect(find.text('2.4 mm'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar previsão do trecho'));
    await tester.pumpAndSettle();
    expect(find.text('Passagem estimada: 28/10 · 00:00'), findsNothing);
  });

  testWidgets(
    'resumo e linha do tempo cabem em tela estreita com fonte ampliada',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(summary());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: RouteForecastTimelinePage(
            points: points,
            departureAt: departure,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Chegada · 28/10 · 00:20'),
        250,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
