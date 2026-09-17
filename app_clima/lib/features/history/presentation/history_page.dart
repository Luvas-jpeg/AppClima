import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          PageHeader(title: 'Historico', subtitle: 'Pesquisas salvas neste aparelho'),
          SizedBox(height: 18),
          SearchFieldMock(),
          SizedBox(height: 18),
          HistoryTile(place: 'Padaria Central', detail: 'Caminhada - 10 min - risco de chuva', icon: Icons.bakery_dining),
          HistoryTile(place: 'Faculdade', detail: 'Carro - 22 min - vento moderado', icon: Icons.school),
          HistoryTile(place: 'Parque Municipal', detail: 'Bicicleta - 18 min - UV alto', icon: Icons.park),
        ],
      );
}
