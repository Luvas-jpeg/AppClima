import 'package:flutter/material.dart';

import '../../weather/domain/weather_data.dart';

enum RouteWeatherFilter {
  rain('Chuva', Icons.water_drop, Color(0xFF2F80ED)),
  wind('Vento', Icons.air, Color(0xFF6C63FF)),
  temperature('Temp.', Icons.device_thermostat, Color(0xFFE05A47)),
  uv('UV', Icons.wb_sunny, Color(0xFFE39D17));

  const RouteWeatherFilter(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  String get title => this == temperature ? 'Temperatura' : label;

  double value(WeatherData weather) => switch (this) {
    rain => weather.rainChance.toDouble(),
    wind => weather.windKph,
    temperature => weather.temperature,
    uv => weather.uv,
  };

  String valueLabel(WeatherData weather) => switch (this) {
    rain => '${weather.rainChance}%',
    wind => '${weather.windKph.round()} km/h',
    temperature => '${weather.temperature.round()}°C',
    uv => 'UV ${weather.uv.toStringAsFixed(1)}',
  };

  String detailLabel(WeatherData weather) => switch (this) {
    rain =>
      '${weather.forecastPrecipitationMm.toStringAsFixed(1)} mm previstos',
    wind => 'Rajadas de ${weather.gustKph.round()} km/h',
    temperature => 'Sensação de ${weather.feelsLike.round()}°C',
    uv => 'Índice ultravioleta previsto',
  };

  List<String> get ticks => switch (this) {
    rain => ['0%', '50%', '100%'],
    wind => ['0 km/h', '30 km/h', '≥60 km/h'],
    temperature => ['≤10°C', '25°C', '≥40°C'],
    uv => ['0', '5.5', '≥11'],
  };

  List<Color> get colors => switch (this) {
    rain => [
      const Color(0xFFB6C7D5),
      const Color(0xFF2F80ED),
      const Color(0xFF123F88),
    ],
    wind => [
      const Color(0xFF55A7A1),
      const Color(0xFF8871CB),
      const Color(0xFF4B237C),
    ],
    temperature => [
      const Color(0xFF3D86CF),
      const Color(0xFFE2A237),
      const Color(0xFFCD4338),
    ],
    uv => [
      const Color(0xFF429C8C),
      const Color(0xFFD9A02D),
      const Color(0xFF853D9C),
    ],
  };

  /// Visual scale for comparing values; not a classification of travel safety.
  Color colorFor(WeatherData weather) {
    final raw = value(weather);
    final fraction = switch (this) {
      rain => raw / 100,
      wind => raw / 60,
      temperature => (raw - 10) / 30,
      uv => raw / 11,
    }.clamp(0.0, 1.0);
    return fraction <= 0.5
        ? Color.lerp(colors[0], colors[1], fraction * 2)!
        : Color.lerp(colors[1], colors[2], (fraction - 0.5) * 2)!;
  }
}

class RouteWeatherLegend extends StatelessWidget {
  const RouteWeatherLegend({required this.filter, super.key});
  final RouteWeatherFilter filter;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${filter.title} no horário de passagem',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5A6B70),
        ),
      ),
      const SizedBox(height: 6),
      Container(
        height: 6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(colors: filter.colors),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          for (var index = 0; index < filter.ticks.length; index++)
            Expanded(
              child: Text(
                filter.ticks[index],
                textAlign: index == 0
                    ? TextAlign.left
                    : index == 1
                    ? TextAlign.center
                    : TextAlign.right,
                style: const TextStyle(fontSize: 11, color: Color(0xFF5A6B70)),
              ),
            ),
        ],
      ),
    ],
  );
}
