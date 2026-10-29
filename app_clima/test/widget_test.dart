import 'package:app_clima/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('abre planejamento em outra página e volta ao clima', (
    tester,
  ) async {
    await tester.pumpWidget(const AppClimaApp());
    expect(find.text('AppClima'), findsOneWidget);
    expect(find.text('Clima agora'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.ensureVisible(find.text('Planejar rota'));
    await tester.tap(find.text('Planejar rota'));
    await tester.pumpAndSettle();
    expect(find.text('Planejar viagem'), findsOneWidget);
    expect(find.text('Rota com clima'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('AppClima'), findsOneWidget);
    expect(find.text('Planejar rota'), findsOneWidget);
    expect(find.text('Planejar viagem'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('abre histórico pelo atalho e volta à tela inicial', (
    tester,
  ) async {
    await tester.pumpWidget(const AppClimaApp());
    await tester.tap(find.byTooltip('Histórico de viagens'));
    await tester.pumpAndSettle();
    expect(find.text('Suas viagens'), findsOneWidget);
    expect(find.text('Nenhuma rota salva ainda.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('AppClima'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('telas cabem em celular estreito e com texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const AppClimaApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Planejar rota'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Planejar rota'));
    await tester.pumpAndSettle();
    expect(find.text('Rota com clima'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
