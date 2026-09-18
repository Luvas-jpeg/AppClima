import 'package:app_clima/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exibe as abas principais do AppClima', (tester) async {
    await tester.pumpWidget(const AppClimaApp());

    expect(find.text('Clima agora'), findsOneWidget);
    expect(find.text('Clima'), findsOneWidget);
    expect(find.text('Rota'), findsOneWidget);
    expect(find.text('Historico'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.route_outlined));
    await tester.pump();

    expect(find.text('Rota com clima'), findsOneWidget);
  });
}
