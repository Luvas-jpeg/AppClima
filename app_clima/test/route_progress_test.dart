import 'package:app_clima/features/route/domain/route_progress.dart';
import 'package:app_clima/features/route/domain/route_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final start = DateTime(2026, 10, 29, 14);
  RouteProgress tracker() => RouteProgress(
    const RouteResult(
      points: [LatLng(0, 0), LatLng(0, .001), LatLng(0, .01)],
      distanceMeters: 1112,
      durationSeconds: 600,
    ),
  );
  void fix(
    RouteProgress tracker,
    double longitude,
    int seconds, {
    double accuracy = 5,
    double latitude = 0,
  }) {
    tracker.update(
      LatLng(latitude, longitude),
      start.add(Duration(seconds: seconds)),
      accuracy: accuracy,
    );
  }

  test('progresso usa distância e interpola entre coordenadas desiguais', () {
    final progress = tracker();
    fix(progress, .001, 0);
    expect(progress.fraction, closeTo(.1, .001));
    fix(progress, .005, 60);
    expect(progress.fraction, closeTo(.5, .001));
    expect(progress.traveledMeters, closeTo(progress.totalMeters / 2, 1));
  });

  test('usa duração da API antes de observar movimento suficiente', () {
    final progress = tracker();
    fix(progress, 0, 0);
    expect(progress.usesObservedPace, isFalse);
    expect(
      progress.arrivalAt(2, start),
      start.add(const Duration(minutes: 10)),
    );
    fix(progress, .0001, 10);
    expect(progress.usesObservedPace, isFalse);
  });

  test('recorta o traçado entre vértices e preserva os trechos futuros', () {
    final progress = tracker();
    fix(progress, .0005, 0);
    final remaining = progress.remainingPoints();
    expect(remaining.first.longitude, closeTo(.0005, 1e-9));
    expect(remaining.skip(1), progress.route.points.skip(1));
    expect(
      progress.remainingPoints(startIndex: 1),
      progress.route.points.sublist(1),
    );
    fix(progress, .005, 60);
    expect(progress.remainingPoints(endIndex: 1), isEmpty);
    expect(progress.remainingPoints().first.longitude, closeTo(.005, 1e-9));
    fix(progress, .01, 120);
    expect(progress.remainingPoints(), isEmpty);
  });

  test('ritmo mais lento amplia o tempo e os horários dos pontos', () {
    final progress = tracker();
    fix(progress, 0, 0);
    fix(progress, .0005, 60);
    fix(progress, .001, 120);
    expect(progress.usesObservedPace, isTrue);
    expect(progress.timeTo(progress.totalMeters).inSeconds, closeTo(1080, 2));
    expect(
      progress.arrivalAt(2, start.add(const Duration(minutes: 2))),
      start.add(const Duration(minutes: 20)),
    );
  });

  test('ritmo recente acompanha aceleração e inclui paradas', () {
    final progress = tracker();
    fix(progress, 0, 0);
    fix(progress, .001, 60);
    final movingSpeed = progress.metersPerSecond;
    fix(progress, .001, 120);
    expect(progress.metersPerSecond, lessThan(movingSpeed));
    expect(progress.fraction, closeTo(.1, .001));
    expect(progress.isPaused(start.add(const Duration(seconds: 120))), isTrue);
    fix(progress, .003, 180);
    fix(progress, .005, 240);
    fix(progress, .007, 300);
    expect(progress.metersPerSecond, greaterThan(movingSpeed));
    expect(progress.isPaused(start.add(const Duration(seconds: 300))), isFalse);
  });

  test('ignora GPS impreciso, antigo, fora da rota e saltos impossíveis', () {
    final progress = tracker();
    fix(progress, .001, 60);
    fix(progress, .005, 120, accuracy: 100);
    fix(progress, .005, 30);
    fix(progress, .005, 120, latitude: .01);
    expect(progress.offRoute, isTrue);
    expect(progress.fraction, closeTo(.1, .001));
    fix(progress, .009, 61);
    expect(progress.fraction, closeTo(.1, .001));
    fix(progress, .002, 120);
    expect(progress.offRoute, isFalse);
    expect(progress.fraction, closeTo(.2, .001));
  });

  test('ruído parado não acumula distância nem aprende velocidade falsa', () {
    final progress = tracker();
    fix(progress, 0, 0);
    for (var i = 1; i <= 60; i++) {
      fix(progress, i.isEven ? .00001 : 0, i);
    }
    expect(progress.fraction, 0);
    expect(progress.usesObservedPace, isFalse);
    expect(progress.isPaused(start.add(const Duration(seconds: 60))), isTrue);
  });

  test('fim da rota zera o tempo e voltar no trajeto reduz progresso', () {
    final progress = tracker();
    fix(progress, .01, 0);
    expect(progress.fraction, 1);
    expect(progress.timeTo(progress.totalMeters), Duration.zero);
    fix(progress, .009, 60);
    expect(progress.fraction, closeTo(.9, .001));
    expect(progress.timeTo(progress.totalMeters), greaterThan(Duration.zero));
  });

  test('geometria sem distância mantém uma estimativa finita', () {
    final progress = RouteProgress(
      const RouteResult(
        points: [LatLng(0, 0), LatLng(0, 0)],
        distanceMeters: 0,
        durationSeconds: 0,
      ),
    );
    fix(progress, 0, 0);
    expect(progress.fraction, 0);
    expect(progress.timeTo(0), Duration.zero);
  });

  test('reutiliza geometria parada e invalida após avançar ou voltar', () {
    final progress = tracker();
    fix(progress, .0005, 0);
    final original = progress.remainingPoints();
    expect(identical(progress.remainingPoints(), original), isTrue);
    fix(progress, .0005, 10);
    expect(identical(progress.remainingPoints(), original), isTrue);
    fix(progress, .005, 60);
    final advanced = progress.remainingPoints();
    expect(identical(advanced, original), isFalse);
    expect(advanced.first.longitude, closeTo(.005, 1e-9));
    fix(progress, .0005, 120);
    expect(progress.remainingPoints().first.longitude, closeTo(.0005, 1e-9));
  });

  test('recorta corretamente uma rota longa com vértices duplicados', () {
    final points = <LatLng>[
      for (var i = 0; i <= 10000; i++)
        for (var duplicate = 0; duplicate < 2; duplicate++)
          LatLng(0, i / 10000),
    ];
    final progress = RouteProgress(
      RouteResult(points: points, distanceMeters: 11120, durationSeconds: 600),
    );
    fix(progress, .90005, 0);
    final remaining = progress.remainingPoints();
    expect(remaining.first.longitude, closeTo(.90005, 1e-9));
    expect(remaining.last, points.last);
    expect(remaining.length, lessThan(2100));
    expect(progress.remainingPoints(endIndex: 100), isEmpty);
  });
}
