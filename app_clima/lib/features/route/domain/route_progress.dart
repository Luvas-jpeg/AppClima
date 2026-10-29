import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'route_result.dart';

/// Projects GPS fixes onto the route and estimates pace from recent progress.
class RouteProgress {
  RouteProgress(this.route) {
    const distance = Distance(roundResult: false);
    for (var i = 1; i < route.points.length; i++) {
      distances.add(
        distances.last + distance(route.points[i - 1], route.points[i]),
      );
    }
  }

  final RouteResult route;
  final List<double> distances = [0];
  final List<({DateTime time, double meters})> _samples = [];
  double traveledMeters = 0;
  double? _observedSpeed;
  DateTime? _lastFixAt;
  DateTime? _lastMovementAt;
  double _movementAnchor = 0;
  bool offRoute = false;

  double get totalMeters => distances.last;
  double get fraction =>
      totalMeters == 0 ? 0 : (traveledMeters / totalMeters).clamp(0, 1);
  bool get usesObservedPace => _observedSpeed != null;
  double get metersPerSecond =>
      _observedSpeed ??
      (route.durationSeconds > 0 ? totalMeters / route.durationSeconds : 1.4);

  Duration timeTo(double meters) => Duration(
    milliseconds:
        (math.max(0, meters - traveledMeters) /
                math.max(0.3, metersPerSecond) *
                1000)
            .round(),
  );

  DateTime arrivalAt(int routeIndex, DateTime now) =>
      now.add(timeTo(distances[routeIndex]));

  bool isPaused(DateTime now) =>
      _lastMovementAt != null &&
      now.difference(_lastMovementAt!).inSeconds >= 45 &&
      _lastFixAt != null &&
      now.difference(_lastFixAt!).inSeconds <= 30 &&
      fraction < 0.999;

  bool update(
    LatLng location,
    DateTime measuredAt, {
    required double accuracy,
  }) {
    if (!accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > 50 ||
        (_lastFixAt != null && !measuredAt.isAfter(_lastFixAt!))) {
      return false;
    }
    if (route.points.length < 2 || totalMeters == 0) return false;

    // Use a local plane for the segment projection; lengths follow the route
    // geometry rather than the number or spacing of its coordinates.
    const radius = 6371000.0;
    final scale = math.cos(location.latitude * math.pi / 180);
    double longitudeDelta(double longitude) =>
        ((longitude - location.longitude + 540) % 360 - 180) * math.pi / 180;
    var bestOffset = double.infinity;
    var along = traveledMeters;
    for (var i = 1; i < route.points.length; i++) {
      final a = route.points[i - 1];
      final b = route.points[i];
      final ax = longitudeDelta(a.longitude) * radius * scale;
      final ay = (a.latitude - location.latitude) * math.pi / 180 * radius;
      final bx = longitudeDelta(b.longitude) * radius * scale;
      final by = (b.latitude - location.latitude) * math.pi / 180 * radius;
      final dx = bx - ax;
      final dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0);
      final offset = math.sqrt(
        math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2),
      );
      final candidate =
          distances[i - 1] + t * (distances[i] - distances[i - 1]);
      if (offset < bestOffset - 1 ||
          ((offset - bestOffset).abs() <= 1 &&
              (candidate - traveledMeters).abs() <
                  (along - traveledMeters).abs())) {
        bestOffset = offset;
        along = candidate;
      }
    }
    offRoute = bestOffset > math.max(30, accuracy * 2);
    if (offRoute) return false;
    final previousTime = _lastFixAt;
    if (previousTime != null) {
      final seconds = measuredAt.difference(previousTime).inMilliseconds / 1000;
      if ((along - traveledMeters).abs() > 80 * seconds + 50) return false;
      if (seconds > 120) {
        _samples.clear();
        _lastMovementAt = measuredAt;
        _movementAnchor = along;
      }
    }
    final noise = math.max(5.0, accuracy);
    if (previousTime == null || (along - _movementAnchor).abs() >= noise) {
      _lastMovementAt = measuredAt;
      _movementAnchor = along;
    }
    if (previousTime == null ||
        (along - traveledMeters).abs() >= noise ||
        totalMeters - along < 1) {
      traveledMeters = along;
    }
    _lastFixAt = measuredAt;
    _samples.add((time: measuredAt, meters: traveledMeters));
    final cutoff = measuredAt.subtract(const Duration(minutes: 3));
    while (_samples.length > 2 && _samples[1].time.isBefore(cutoff)) {
      _samples.removeAt(0);
    }
    final seconds =
        measuredAt.difference(_samples.first.time).inMilliseconds / 1000;
    final advance = traveledMeters - _samples.first.meters;
    if (seconds >= 30 && advance >= math.max(20, accuracy * 2)) {
      _observedSpeed = (advance / seconds).clamp(0.3, 80.0);
    }
    return true;
  }
}
