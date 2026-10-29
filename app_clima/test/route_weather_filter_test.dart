import 'package:app_clima/features/route/presentation/route_weather_filter.dart';
import 'package:app_clima/features/weather/domain/weather_data.dart';
import 'package:flutter_test/flutter_test.dart';

WeatherData data({
  double temperature = 25,
  double wind = 30,
  double uv = 5.5,
  int rain = 50,
}) => WeatherData(
  locationName: 'Teste',
  temperature: temperature,
  feelsLike: 28,
  condition: 'Nublado',
  windKph: wind,
  windDirection: 'N',
  gustKph: 45,
  uv: uv,
  humidity: 60,
  pressureMb: 1010,
  visibilityKm: 10,
  cloudCoverage: 50,
  precipitationMm: 0,
  forecastPrecipitationMm: 2.4,
  rainChance: rain,
  hours: [],
  days: [],
);

void main() {
  test('unidades e detalhes correspondem à métrica selecionada', () {
    expect(RouteWeatherFilter.rain.valueLabel(data()), '50%');
    expect(RouteWeatherFilter.rain.detailLabel(data()), '2.4 mm previstos');
    expect(RouteWeatherFilter.wind.valueLabel(data()), '30 km/h');
    expect(RouteWeatherFilter.wind.detailLabel(data()), 'Rajadas de 45 km/h');
    expect(RouteWeatherFilter.temperature.valueLabel(data()), '25°C');
    expect(
      RouteWeatherFilter.temperature.detailLabel(data()),
      'Sensação de 28°C',
    );
    expect(RouteWeatherFilter.uv.valueLabel(data()), 'UV 5.5');
  });
  test(
    'escala diferencia os valores e limita extremos às cores da legenda',
    () {
      for (final filter in RouteWeatherFilter.values) {
        expect(
          filter.colorFor(data(temperature: -10, wind: 0, uv: 0, rain: 0)),
          filter.colors.first,
        );
        expect(filter.colorFor(data()), filter.colors[1]);
        expect(
          filter.colorFor(data(temperature: 50, wind: 100, uv: 15, rain: 100)),
          filter.colors.last,
        );
      }
    },
  );
}
