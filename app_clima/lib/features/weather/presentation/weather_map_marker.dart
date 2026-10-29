import 'package:flutter/material.dart';

import '../domain/weather_data.dart';

/// A small geographic marker; the details expand outside the map on tap.
class WeatherMapMarker extends StatelessWidget {
  const WeatherMapMarker({
    required this.value,
    this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
    this.compact = false,
    super.key,
  });

  final String value;
  final String? title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    button: true,
    excludeSemantics: true,
    child: Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: const Color(0x3312343B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: compact
              ? Icon(icon, color: color, size: 22)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5A6B70),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF12343B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}

class WeatherPointDetails extends StatelessWidget {
  const WeatherPointDetails({required this.weather, this.cityName, super.key});
  final String? cityName;
  final WeatherData weather;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cityName ?? weather.locationName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Fechar detalhes do clima',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(weather.condition),
          const SizedBox(height: 16),
          const Text(
            'Condições atuais',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric(Icons.thermostat, '${weather.temperature.round()}°C'),
              _metric(
                Icons.device_thermostat,
                'Sensação ${weather.feelsLike.round()}°C',
              ),
              _metric(Icons.air, '${weather.windKph.round()} km/h'),
              _metric(
                Icons.wb_sunny_outlined,
                'UV ${weather.uv.toStringAsFixed(1)}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Chuva na próxima hora',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${weather.rainChance}% de chance · ${weather.forecastPrecipitationMm.toStringAsFixed(1)} mm previstos',
          ),
          if (weather.hours.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Próximas horas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            for (final hour in weather.hours)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      hour.time,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Icon(hour.icon, color: const Color(0xFF087F8C), size: 20),
                    Text(hour.temperature.replaceAll(' C', '°C')),
                    Text('${hour.rainChance} de chuva'),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
  );

  Widget _metric(IconData icon, String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F4F4),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF087F8C), size: 20),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
