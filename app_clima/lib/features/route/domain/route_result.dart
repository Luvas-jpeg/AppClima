import 'package:latlong2/latlong.dart';

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

class RouteDestination {
  const RouteDestination({
    required this.name,
    required this.location,
    this.isMapSelection = false,
  });

  final String name;
  final LatLng location;
  final bool isMapSelection;
}
