import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';
import '../domain/route_climate_point.dart';
import '../domain/route_result.dart';
import 'route_weather_filter.dart';

String routeClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
String routeDateTime(DateTime time) =>
    '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} · ${routeClock(time)}';

IconData routeWeatherIcon(RouteClimatePoint point) {
  final condition = point.weather.condition.toLowerCase();
  if (condition.contains('trovoada') || condition.contains('tempestade')) {
    return Icons.thunderstorm_rounded;
  }
  if (point.weather.rainChance >= 40) return Icons.umbrella_rounded;
  if (point.weather.windKph >= 40) return Icons.air_rounded;
  if (condition.contains('sol') || condition.contains('limpo')) {
    return Icons.wb_sunny_rounded;
  }
  return Icons.cloud_rounded;
}

class RouteTripSummary extends StatelessWidget {
  const RouteTripSummary({
    required this.route,
    required this.departureAt,
    required this.points,
    required this.isLoading,
    required this.onForecast,
    required this.onStart,
    super.key,
  });
  final RouteResult route;
  final DateTime departureAt;
  final List<RouteClimatePoint> points;
  final bool isLoading;
  final VoidCallback onForecast;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final minutes = (route.durationSeconds / 60).ceil();
    final duration = minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} h ${minutes % 60} min';
    final distance = route.distanceMeters >= 1000
        ? '${(route.distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${route.distanceMeters.round()} m';
    final arrival = departureAt.add(
      Duration(milliseconds: (route.durationSeconds * 1000).round()),
    );
    final rainPoints = points
        .where((point) => point.weather.rainChance >= 40)
        .length;
    final climate = points.isEmpty
        ? isLoading
              ? 'Consultando o clima do caminho…'
              : 'Previsão do trajeto indisponível.'
        : rainPoints == 0
        ? 'Baixa chance de chuva nos pontos consultados.'
        : 'Chuva possível em $rainPoints ${rainPoints == 1 ? 'ponto consultado' : 'pontos consultados'}.';
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sua viagem',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _stat(Icons.route, 'Distância', distance),
              _stat(Icons.schedule, 'Duração', duration),
              _stat(
                Icons.flag_outlined,
                'Chegada estimada',
                routeDateTime(arrival),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4F4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  points.isEmpty
                      ? Icons.info_outline
                      : rainPoints > 0
                      ? Icons.umbrella_outlined
                      : Icons.cloud_outlined,
                  color: const Color(0xFF087F8C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    climate,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (points.isNotEmpty)
            Text(
              '${points.length} previsões distribuídas pelo caminho',
              style: const TextStyle(color: Color(0xFF5A6B70)),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: points.isEmpty ? null : onForecast,
              icon: const Icon(Icons.timeline_rounded),
              label: const Text('Ver previsão do trajeto'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.navigation_rounded),
              label: const Text('Iniciar viagem'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF087F8C)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B70)),
          ),
        ],
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
    ],
  );
}

class RouteForecastTimelinePage extends StatelessWidget {
  const RouteForecastTimelinePage({
    required this.points,
    required this.departureAt,
    super.key,
  });
  final List<RouteClimatePoint> points;
  final DateTime departureAt;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Previsão do trajeto')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PageHeader(
            title: 'O tempo no caminho',
            subtitle: 'Previsão para o horário estimado de passagem. Toque em um trecho para localizá-lo no mapa.',
          ),
          const SizedBox(height: 16),
          if (points.isEmpty)
            const InfoCard(
              child: Text('A previsão do trajeto ainda não está disponível.'),
            ),
          for (var index = 0; index < points.length; index++)
            _tile(context, points[index], index),
          const SizedBox(height: 12),
          const Text(
            'Horários aproximados, considerando saída no momento do cálculo da rota. A previsão pode mudar.',
            style: TextStyle(color: Color(0xFF5A6B70)),
          ),
        ],
      ),
    ),
  );

  Widget _tile(BuildContext context, RouteClimatePoint point, int index) {
    final elapsed = point.arrivalAt
        .difference(departureAt)
        .inMinutes
        .clamp(0, 999999);
    final stage = index == 0
        ? 'Saída'
        : index == points.length - 1
        ? 'Chegada'
        : 'Trecho $index';
    final timing = elapsed == 0 ? 'Na saída' : 'Em cerca de $elapsed min';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F4F4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    index == 0
                        ? Icons.trip_origin
                        : index == points.length - 1
                        ? Icons.flag_outlined
                        : routeWeatherIcon(point),
                    size: 18,
                    color: const Color(0xFF087F8C),
                  ),
                ),
                if (index != points.length - 1)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFCEE4E5)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(point),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$stage · ${routeDateTime(point.arrivalAt)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$timing · ${point.weather.locationName}',
                          style: const TextStyle(color: Color(0xFF5A6B70)),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Text(
                              '${point.weather.temperature.round()}°C',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Chuva ${point.weather.rainChance}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text('Vento ${point.weather.windKph.round()} km/h'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(point.weather.condition),
                        const SizedBox(height: 8),
                        const Text(
                          'Ver no mapa →',
                          style: TextStyle(
                            color: Color(0xFF087F8C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RouteForecastPointDetails extends StatelessWidget {
  const RouteForecastPointDetails({
    required this.point,
    this.focusFilter,
    super.key,
  });
  final RouteClimatePoint point;
  final RouteWeatherFilter? focusFilter;

  static void show(
    BuildContext context,
    RouteClimatePoint point, {
    RouteWeatherFilter? filter,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) =>
        RouteForecastPointDetails(point: point, focusFilter: filter),
  );

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
                  point.weather.locationName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Fechar previsão do trecho',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Passagem estimada: ${routeDateTime(point.arrivalAt)}',
            style: const TextStyle(
              color: Color(0xFF087F8C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(point.weather.condition),
          if (focusFilter != null) ...[
            const SizedBox(height: 14),
            Text(
              '${focusFilter!.title}: ${focusFilter!.valueLabel(point.weather)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: focusFilter!.colorFor(point.weather),
              ),
            ),
            const SizedBox(height: 5),
            Text(focusFilter!.detailLabel(point.weather)),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Chip(
                avatar: const Icon(Icons.thermostat, size: 18),
                label: Text('${point.weather.temperature.round()}°C'),
              ),
              Chip(
                avatar: const Icon(Icons.umbrella_outlined, size: 18),
                label: Text('Chuva ${point.weather.rainChance}%'),
              ),
              Chip(
                avatar: const Icon(Icons.water_drop_outlined, size: 18),
                label: Text(
                  '${point.weather.forecastPrecipitationMm.toStringAsFixed(1)} mm',
                ),
              ),
              Chip(
                avatar: const Icon(Icons.air, size: 18),
                label: Text('${point.weather.windKph.round()} km/h'),
              ),
              Chip(
                avatar: const Icon(Icons.wb_sunny_outlined, size: 18),
                label: Text('UV ${point.weather.uv.toStringAsFixed(1)}'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class RouteWeatherMapIcon extends StatelessWidget {
  const RouteWeatherMapIcon({
    required this.point,
    this.filter = RouteWeatherFilter.rain,
    this.color,
    super.key,
  });
  final RouteClimatePoint point;
  final RouteWeatherFilter filter;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? filter.colorFor(point.weather);
    return Semantics(
      button: true,
      label:
          '${point.weather.locationName}, passagem ${routeDateTime(point.arrivalAt)}, ${filter.title}: ${filter.valueLabel(point.weather)}. Ver previsão do trecho.',
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: tint, width: 2),
        ),
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              RouteForecastPointDetails.show(context, point, filter: filter),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(filter.icon, color: tint, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      filter.valueLabel(point.weather),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF12343B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
