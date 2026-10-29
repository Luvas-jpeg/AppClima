import 'package:app_clima/main.dart';
import 'package:app_clima/features/weather/domain/weather_data.dart';
import 'package:app_clima/features/weather/domain/weather_city.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:app_clima/features/weather/presentation/weather_map_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const weather = WeatherData(
  locationName: 'São Paulo',
  temperature: 23,
  feelsLike: 25,
  condition: 'Parcialmente nublado',
  windKph: 18,
  windDirection: 'SE',
  gustKph: 25,
  uv: 3,
  humidity: 80,
  pressureMb: 1010,
  visibilityKm: 8,
  cloudCoverage: 50,
  precipitationMm: 0,
  forecastPrecipitationMm: 0,
  rainChance: 0,
  hours: [ForecastHour('15:00', Icons.cloud, '24 C', '20%')],
  days: [],
);

Widget page() => MaterialApp(
  home: WeatherMapPage(
    userLocation: const LatLng(-23.55, -46.63),
    currentWeather: weather,
    forecastLoader: (_) async => weather,
    cityLoader: (_) async => const [
      WeatherCity(
        id: 'sp',
        name: 'São Paulo',
        location: LatLng(-23.57, -46.67),
      ),
    ],
  ),
);

void main() {
  testWidgets(
    'mapa geral exibe pontos mesmo sem chuva, troca filtros e abre detalhes',
    (tester) async {
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('Mapa do clima'), findsOneWidget);
      expect(find.byType(WeatherMapMarker), findsWidgets);
      expect(find.text('São Paulo'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Chuva'));
      await tester.pumpAndSettle();
      expect(find.text('0%'), findsWidgets);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Temperatura'));
      await tester.pumpAndSettle();
      expect(find.text('23°C'), findsWidgets);
      expect(find.text('Temperatura · agora'), findsOneWidget);
      await tester.tap(find.byType(WeatherMapMarker).first);
      await tester.pumpAndSettle();
      expect(find.text('São Paulo'), findsWidgets);
      expect(find.text('Condições atuais'), findsOneWidget);
      expect(find.text('Chuva na próxima hora'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('20% de chuva'), findsOneWidget);
      await tester.tap(find.byTooltip('Fechar detalhes do clima'));
      await tester.pumpAndSettle();
      expect(find.text('Condições atuais'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mapa e detalhes funcionam em tela estreita com texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(WeatherMapMarker).first);
    await tester.pumpAndSettle();
    expect(find.text('Condições atuais'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('consulta por cidade e reutiliza previsão ao mover o mapa', (
    tester,
  ) async {
    var calls = 0;
    var cityCalls = 0;
    const city = WeatherCity(
      id: 'sp',
      name: 'São Paulo',
      location: LatLng(-23.57, -46.67),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WeatherMapPage(
          userLocation: const LatLng(-23.55, -46.63),
          currentWeather: weather,
          cityLoader: (_) async {
            cityCalls++;
            return [city];
          },
          forecastLoader: (location) async {
            expect(location, city.location);
            calls++;
            return weather;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(WeatherMapMarker), findsOneWidget);
    await tester.drag(find.byType(FlutterMap), const Offset(25, 0));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(cityCalls, greaterThan(1));
    expect(calls, 1);
  });

  testWidgets('área sem cidades mostra orientação em vez de inventar pontos', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WeatherMapPage(
          userLocation: const LatLng(-23.55, -46.63),
          currentWeather: weather,
          cityLoader: (_) async => [],
          forecastLoader: (_) async =>
              throw StateError('Não deve consultar sem cidades'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WeatherMapMarker), findsNothing);
    expect(find.textContaining('Nenhuma cidade encontrada'), findsOneWidget);
  });
}
