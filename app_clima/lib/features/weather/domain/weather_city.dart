import 'package:latlong2/latlong.dart';

class WeatherCity {
  const WeatherCity({
    required this.id,
    required this.name,
    required this.location,
  });
  final String id;
  final String name;
  final LatLng location;
}
