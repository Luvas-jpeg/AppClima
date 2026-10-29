import 'package:app_clima/features/route/domain/route_forecast_plan.dart';
import 'package:app_clima/features/route/domain/route_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

final departure = DateTime(2026, 10, 28, 14);
RouteResult route(
  double duration, {
  double distance = 1000,
  List<LatLng>? points,
}) => RouteResult(
  points: points ?? const [LatLng(0, 0), LatLng(0, 1)],
  distanceMeters: distance,
  durationSeconds: duration,
);

void main() {
  test(
    'rota curta possui quatro previsões distintas incluindo saída e chegada',
    () {
      final plan = RouteForecastPlan.create(route(600), departure);
      expect(plan.samples, hasLength(4));
      expect(
        plan.samples.map((sample) => sample.routeIndex).toSet(),
        hasLength(4),
      );
      expect(plan.samples.first.location, const LatLng(0, 0));
      expect(plan.samples.last.location, const LatLng(0, 1));
      expect(
        plan.samples.last.arrivalAt,
        departure.add(const Duration(minutes: 10)),
      );
      for (final sample in plan.samples) {
        expect(plan.route.points[sample.routeIndex], sample.location);
      }
    },
  );

  test('mais tempo de viagem produz mais pontos, aproximadamente a cada vinte minutos', () {
    final plan = RouteForecastPlan.create(
      route(7200, distance: 90000),
      departure,
    );
    expect(plan.samples, hasLength(7));
    for (var index = 0; index < plan.samples.length; index++) {
      expect(
        plan.samples[index].arrivalAt,
        departure.add(Duration(minutes: index * 20)),
      );
    }
  });

  test(
    'distribui pela distância mesmo quando os vértices se concentram no começo',
    () {
      final plan = RouteForecastPlan.create(
        route(
          600,
          points: const [
            LatLng(0, 0),
            LatLng(0, 0.01),
            LatLng(0, 0.02),
            LatLng(0, 0.03),
            LatLng(0, 1),
          ],
        ),
        departure,
      );
      expect(plan.samples[1].location.longitude, closeTo(1 / 3, 0.001));
      expect(plan.samples[2].location.longitude, closeTo(2 / 3, 0.001));
      expect(plan.route.points, contains(const LatLng(0, 0.01)));
      expect(plan.route.points, contains(const LatLng(0, 0.03)));
    },
  );

  test('limita consultas em rotas longas sem perder o destino e a chegada', () {
    final plan = RouteForecastPlan.create(
      route(86400, distance: 1000000),
      departure,
    );
    expect(plan.samples, hasLength(16));
    expect(plan.samples.last.arrivalAt, departure.add(const Duration(days: 1)));
    expect(plan.route.points.last, plan.samples.last.location);
  });

  test('tolera vértices duplicados e rejeita rota sem deslocamento', () {
    final plan = RouteForecastPlan.create(
      route(600, points: const [LatLng(0, 0), LatLng(0, 0), LatLng(0, 1)]),
      departure,
    );
    expect(plan.samples, hasLength(4));
    expect(
      () => RouteForecastPlan.create(
        route(600, points: const [LatLng(0, 0), LatLng(0, 0)]),
        departure,
      ),
      throwsArgumentError,
    );
  });
}
