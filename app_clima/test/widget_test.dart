import 'package:app_clima/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('abre o prototipo do AppClima', (tester) async {
    await tester.pumpWidget(const AppClimaPrototype());

    expect(find.text('Clima agora'), findsOneWidget);
    expect(find.text('Sao Paulo, SP'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.route_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Rota com clima'), findsOneWidget);
    expect(find.text('Padaria Central - 5 km'), findsOneWidget);
  });
}
