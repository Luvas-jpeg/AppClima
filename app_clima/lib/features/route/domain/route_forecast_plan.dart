import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'route_result.dart';

class RouteForecastSample {
  const RouteForecastSample({
    required this.routeIndex,
    required this.location,
    required this.arrivalAt,
  });
  final int routeIndex;
  final LatLng location;
  final DateTime arrivalAt;
}

class RouteForecastPlan {
  const RouteForecastPlan({required this.route, required this.samples});
  final RouteResult route;
  final List<RouteForecastSample> samples;

  /// Spread points by geometry distance, estimating time with average speed.
  /// Insert sample coordinates into the line so map markers and colors agree.
  factory RouteForecastPlan.create(RouteResult route, DateTime departureAt) {
    if (route.points.length < 2) {
      throw ArgumentError('A rota precisa de pelo menos dois pontos.');
    }
    const distance = Distance();
    final cumulative = <double>[0];
    for (var index = 1; index < route.points.length; index++) {
      cumulative.add(
        cumulative.last +
            distance.as(
              LengthUnit.Meter,
              route.points[index - 1],
              route.points[index],
            ),
      );
    }
    if (cumulative.last <= 0) {
      throw ArgumentError('A rota não possui distância percorrível.');
    }
    final count = math
        .max(
          4,
          math.max(
            (route.durationSeconds / 1200).ceil() + 1,
            (route.distanceMeters / 25000).ceil() + 1,
          ),
        )
        .clamp(4, 16);
    final enriched = <LatLng>[route.points.first];
    final samples = <RouteForecastSample>[
      RouteForecastSample(
        routeIndex: 0,
        location: route.points.first,
        arrivalAt: departureAt,
      ),
    ];
    var edge = 1;
    for (var sample = 1; sample < count - 1; sample++) {
      final progress = sample / (count - 1);
      final target = cumulative.last * progress;
      while (edge < route.points.length - 1 && cumulative[edge] < target) {
        if (enriched.last != route.points[edge]) {
          enriched.add(route.points[edge]);
        }
        edge++;
      }
      final from = route.points[edge - 1];
      final to = route.points[edge];
      final segmentLength = cumulative[edge] - cumulative[edge - 1];
      final fraction = segmentLength == 0
          ? 0.0
          : (target - cumulative[edge - 1]) / segmentLength;
      final location = LatLng(
        from.latitude + (to.latitude - from.latitude) * fraction,
        from.longitude + (to.longitude - from.longitude) * fraction,
      );
      if (enriched.last != location) enriched.add(location);
      samples.add(
        RouteForecastSample(
          routeIndex: enriched.length - 1,
          location: location,
          arrivalAt: departureAt.add(
            Duration(
              milliseconds: (route.durationSeconds * progress * 1000).round(),
            ),
          ),
        ),
      );
    }
    for (; edge < route.points.length; edge++) {
      if (enriched.last != route.points[edge]) enriched.add(route.points[edge]);
    }
    samples.add(
      RouteForecastSample(
        routeIndex: enriched.length - 1,
        location: enriched.last,
        arrivalAt: departureAt.add(
          Duration(milliseconds: (route.durationSeconds * 1000).round()),
        ),
      ),
    );
    return RouteForecastPlan(
      route: RouteResult(
        points: enriched,
        distanceMeters: route.distanceMeters,
        durationSeconds: route.durationSeconds,
      ),
      samples: samples,
    );
  }
}
