import '../../weather/domain/weather_data.dart';

class RouteClimatePoint {
  const RouteClimatePoint({
    required this.routeIndex,
    required this.arrivalAt,
    required this.weather,
  });
  final int routeIndex;
  final DateTime arrivalAt;
  final WeatherData weather;
}
