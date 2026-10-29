import 'dart:async';

import 'package:app_clima/features/route/domain/route_climate_point.dart';
import 'package:app_clima/features/route/domain/route_forecast_plan.dart';
import 'package:app_clima/features/route/domain/route_result.dart';
import 'package:app_clima/features/route/presentation/route_page.dart';
import 'package:app_clima/features/route/presentation/route_forecast_views.dart';
import 'package:app_clima/features/weather/domain/weather_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

const weather = WeatherData(
  locationName: 'São Paulo',
  temperature: 23,
  feelsLike: 24,
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
);
Position position(double lat, double lon, {int seconds = 0}) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime(2026).add(Duration(seconds: seconds)),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);
final plan = RouteForecastPlan.create(
  const RouteResult(
    points: [LatLng(-23.55, -46.63), LatLng(-23.56, -46.64)],
    distanceMeters: 1500,
    durationSeconds: 600,
  ),
  DateTime(2026, 10, 28, 14),
);
final forecasts = plan.samples
    .map(
      (sample) => RouteClimatePoint(
        routeIndex: sample.routeIndex,
        arrivalAt: sample.arrivalAt,
        weather: weather,
      ),
    )
    .toList();
Widget page(Stream<Position> stream) => MaterialApp(
  home: RouteNavigationPage(
    route: plan.route,
    destination: RouteDestination(
      name: 'Destino de teste',
      location: plan.route.points.last,
    ),
    climatePoints: forecasts,
    filter: RouteWeatherFilter.rain,
    initialPosition: position(-23.55, -46.63),
    positionStream: stream,
    forecastLoader: (_, _) async => weather,
    clock: () => DateTime(2026, 10, 28, 14),
  ),
);

void main() {
  testWidgets('GPS ajusta distância, chegada e horários sem novas consultas', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 29, 14);
    final stream = StreamController<Position>();
    addTearDown(stream.close);
    var calls = 0;
    const route = RouteResult(
      points: [LatLng(0, 0), LatLng(0, .001), LatLng(0, .01)],
      distanceMeters: 1112,
      durationSeconds: 600,
    );
    Position fix(double longitude) => Position(
      latitude: 0,
      longitude: longitude,
      timestamp: now,
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RouteNavigationPage(
          route: route,
          destination: null,
          climatePoints: [
            for (var i = 0; i < 3; i++)
              RouteClimatePoint(
                routeIndex: i,
                arrivalAt: now,
                weather: weather,
              ),
          ],
          filter: RouteWeatherFilter.rain,
          initialPosition: fix(0),
          positionStream: stream.stream,
          clock: () => now,
          forecastLoader: (_, _) async {
            calls++;
            return weather;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chegada em cerca de 10 min'), findsOneWidget);
    expect(calls, 3);
    now = now.add(const Duration(minutes: 2));
    stream.add(fix(.001));
    await tester.pumpAndSettle();
    expect(find.text('10% do trajeto percorrido'), findsOneWidget);
    expect(find.text('Chegada em cerca de 18 min'), findsOneWidget);
    expect(find.textContaining('ritmo do GPS'), findsOneWidget);
    final markers = tester.widgetList<RouteWeatherMapIcon>(
      find.byType(RouteWeatherMapIcon),
    );
    expect(
      markers.last.point.arrivalAt.difference(now).inSeconds,
      closeTo(1080, 1),
    );
    expect(calls, 3);
    await tester.tap(find.byTooltip('Ocultar detalhes'));
    await tester.pumpAndSettle();
    now = now.add(const Duration(minutes: 1));
    stream.add(fix(.002));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mostrar detalhes'));
    await tester.pumpAndSettle();
    expect(find.text('20% do trajeto percorrido'), findsOneWidget);
    expect(find.text('Chegada em cerca de 12 min'), findsOneWidget);
    expect(calls, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'atualiza pelo relógio só na rota ativa e preserva clima em falhas',
    (tester) async {
      var now = DateTime(2026, 10, 28, 14, 14);
      final requests = <({LatLng location, DateTime arrival})>[];
      var fail = false;
      final stream = StreamController<Position>();
      addTearDown(stream.close);
      await tester.pumpWidget(
        MaterialApp(
          home: RouteNavigationPage(
            route: plan.route,
            destination: null,
            climatePoints: forecasts,
            filter: RouteWeatherFilter.rain,
            initialPosition: position(-23.55, -46.63),
            positionStream: stream.stream,
            clock: () => now,
            forecastLoader: (location, arrival) async {
              requests.add((location: location, arrival: arrival));
              if (fail) throw Exception('Sem internet');
              return weather;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, hasLength(4));
      expect(requests.first.arrival, now);
      expect(requests.last.arrival, now.add(const Duration(minutes: 10)));
      now = DateTime(2026, 10, 28, 14, 14, 59);
      await tester.pump(const Duration(seconds: 59));
      expect(requests, hasLength(4));
      stream.add(position(-23.56, -46.64, seconds: 60));
      await tester.pumpAndSettle();
      expect(requests, hasLength(4));
      now = DateTime(2026, 10, 28, 14, 15);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(requests, hasLength(5)); // Only the destination remains.
      expect(requests.last.arrival, now);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 10, 28, 14, 30);
      await tester.pump(const Duration(minutes: 15));
      expect(requests, hasLength(5));
      fail = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(requests, hasLength(6));
      expect(
        find.textContaining('Os últimos dados foram mantidos'),
        findsOneWidget,
      );
      expect(find.byType(RouteWeatherMapIcon), findsNWidgets(4));
      fail = false;
      now = DateTime(2026, 10, 28, 14, 45);
      await tester.pump(const Duration(minutes: 15));
      await tester.pumpAndSettle();
      expect(requests, hasLength(7));
      expect(
        find.textContaining('Os últimos dados foram mantidos'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      now = DateTime(2026, 10, 28, 15);
      await tester.pump(const Duration(minutes: 15));
      expect(requests, hasLength(7));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('oculta detalhes e amplia o mapa sem interromper a navegação', (
    tester,
  ) async {
    final stream = StreamController<Position>();
    addTearDown(stream.close);
    await tester.pumpWidget(page(stream.stream));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Vento'));
    await tester.pumpAndSettle();
    final map = find.byType(FlutterMap);
    final heightWithDetails = tester.getSize(map).height;
    await tester.tap(find.byTooltip('Ocultar detalhes'));
    await tester.pumpAndSettle();
    expect(tester.getSize(map).height, greaterThan(heightWithDetails));
    expect(find.textContaining('do trajeto percorrido'), findsNothing);
    expect(find.textContaining('Chegada em cerca de'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byTooltip('Encerrar rota'), findsOneWidget);
    await tester.tap(find.byTooltip('Acompanhar minha localização'));
    await tester.pumpAndSettle();
    final camera = tester.widget<FlutterMap>(map).mapController!;
    final previousCenter = camera.camera.center;
    stream.add(position(-23.56, -46.64, seconds: 60));
    await tester.pumpAndSettle();
    expect(camera.camera.center, isNot(previousCenter));
    await tester.tap(find.byTooltip('Mostrar detalhes'));
    await tester.pumpAndSettle();
    expect(tester.getSize(map).height, heightWithDetails);
    expect(find.text('100% do trajeto percorrido'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Vento'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('inicia mostrando a rota toda e todos os pontos de previsão', (
    tester,
  ) async {
    await tester.pumpWidget(page(const Stream.empty()));
    await tester.pumpAndSettle();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(
      map.mapController!.camera.visibleBounds.contains(plan.route.points.first),
      isTrue,
    );
    expect(
      map.mapController!.camera.visibleBounds.contains(plan.route.points.last),
      isTrue,
    );
    expect(find.byType(RouteWeatherMapIcon), findsNWidgets(4));
    expect(
      find.byKey(const ValueKey('route-forecast-anchor-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('route-forecast-anchor-2')),
      findsOneWidget,
    );
    expect(find.text('4 previsões no trajeto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite acompanhar o usuário e retornar à visão geral', (
    tester,
  ) async {
    final stream = StreamController<Position>();
    addTearDown(stream.close);
    await tester.pumpWidget(page(stream.stream));
    await tester.pumpAndSettle();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final center = map.mapController!.camera.center;
    stream.add(position(-23.552, -46.632, seconds: 60));
    await tester.pumpAndSettle();
    expect(map.mapController!.camera.center, center);
    await tester.tap(find.byTooltip('Acompanhar minha localização'));
    await tester.pumpAndSettle();
    expect(map.mapController!.camera.zoom, 15);
    await tester.tap(find.byTooltip('Ver trajeto completo'));
    await tester.pumpAndSettle();
    expect(
      map.mapController!.camera.visibleBounds.contains(plan.route.points.last),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('controles não cobrem o mapa em celular com fonte ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(page(const Stream.empty()));
    await tester.pumpAndSettle();
    expect(find.byType(RouteWeatherMapIcon), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'painel fica acima da navegação do Android mesmo com padding temporariamente zerado',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.only(bottom: 48),
          ),
          child: page(const Stream.empty()),
        ),
      );
      await tester.pumpAndSettle();
      final panelText = find.textContaining('Próximo trecho ·');
      // On small viewports the details scroll without covering the map.
      await tester.ensureVisible(panelText);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(panelText).dy, lessThanOrEqualTo(800 - 48));
      final wind = find.widgetWithText(ChoiceChip, 'Vento');
      await tester.ensureVisible(wind);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(wind).dy, lessThanOrEqualTo(800 - 48));
      await tester.tap(wind);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(wind).selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cada filtro muda valores, unidade, ícone, legenda e painel do próximo trecho',
    (tester) async {
      await tester.pumpWidget(page(const Stream.empty()));
      await tester.pumpAndSettle();
      for (final entry in [
        (filter: RouteWeatherFilter.wind, value: '15 km/h'),
        (filter: RouteWeatherFilter.temperature, value: '23°C'),
        (filter: RouteWeatherFilter.uv, value: 'UV 3.0'),
        (filter: RouteWeatherFilter.rain, value: '20%'),
      ]) {
        final chip = find.widgetWithText(ChoiceChip, entry.filter.label);
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(RouteWeatherMapIcon),
            matching: find.text(entry.value),
          ),
          findsNWidgets(4),
        );
        expect(
          find.descendant(
            of: find.byType(RouteWeatherMapIcon),
            matching: find.byIcon(entry.filter.icon),
          ),
          findsNWidgets(4),
        );
        expect(
          find.textContaining('${entry.filter.title}: ${entry.value}'),
          findsOneWidget,
        );
        expect(
          find.text('${entry.filter.title} no horário de passagem'),
          findsOneWidget,
        );
        final line = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
        expect(line.polylines[1].color, entry.filter.colorFor(weather));
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('arrastar o mapa não leva trajetória e previsões para o rodapé', (
    tester,
  ) async {
    await tester.pumpWidget(page(const Stream.empty()));
    await tester.pumpAndSettle();
    final map = find.byType(FlutterMap);
    final footer = find.byKey(const ValueKey('route-map-footer'));
    final viewport = find.byKey(const ValueKey('route-map-viewport'));
    final footerBefore = tester.getRect(footer);
    expect(tester.getRect(map).bottom, lessThanOrEqualTo(footerBefore.top));
    expect(
      tester.getRect(viewport).bottom,
      lessThanOrEqualTo(footerBefore.top),
    );
    await tester.drag(map, const Offset(0, 180));
    await tester.pumpAndSettle();
    expect(tester.getRect(footer), footerBefore);
    expect(find.ancestor(of: footer, matching: map), findsNothing);
    expect(
      tester.getRect(map).bottom,
      lessThanOrEqualTo(tester.getRect(footer).top),
    );
    expect(
      find
          .descendant(of: footer, matching: find.byType(TextButton))
          .hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
