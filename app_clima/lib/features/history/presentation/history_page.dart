import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';
import '../data/route_history_repository.dart';
import '../domain/route_history_entry.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({this.onRouteSelected, super.key});
  final ValueChanged<RouteHistoryEntry>? onRouteSelected;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<RouteHistoryEntry>> _entries = RouteHistoryRepository.load();

  void _reload() => setState(() => _entries = RouteHistoryRepository.load());

  Future<void> _clear() async {
    await RouteHistoryRepository.clear();
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<RouteHistoryEntry>>(
    future: _entries,
    builder: (context, snapshot) {
      final entries = snapshot.data ?? const <RouteHistoryEntry>[];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: PageHeader(
                  title: 'Historico',
                  subtitle: 'Rotas salvas neste aparelho',
                ),
              ),
              if (entries.isNotEmpty)
                IconButton(
                  tooltip: 'Limpar historico',
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (entries.isEmpty)
            const InfoCard(
              child: Column(
                children: [
                  Icon(Icons.history, size: 44, color: Color(0xFF5A6B70)),
                  SizedBox(height: 12),
                  Text(
                    'Nenhuma rota salva ainda.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Calcule uma rota para ela aparecer aqui.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF5A6B70)),
                  ),
                ],
              ),
            )
          else
            for (final entry in entries)
              HistoryTile(
                place: entry.destination,
                detail: _details(context, entry),
                icon: _iconFor(entry.transport),
                onTap: entry.latitude == 0 && entry.longitude == 0
                    ? null
                    : () => widget.onRouteSelected?.call(entry),
              ),
        ],
      );
    },
  );

  String _details(BuildContext context, RouteHistoryEntry entry) {
    final distance = entry.distanceMeters >= 1000
        ? '${(entry.distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${entry.distanceMeters.round()} m';
    final date = MaterialLocalizations.of(context)
        .formatShortDate(entry.createdAt);
    final rain = entry.rainChance == null
        ? ''
        : ' - chuva ${entry.rainChance}%';
    return '${entry.transport} - $distance - ${(entry.durationSeconds / 60).round()} min$rain\n$date';
  }

  IconData _iconFor(String transport) => switch (transport) {
    'Caminhada' => Icons.directions_walk,
    'Bicicleta' => Icons.directions_bike,
    'Moto' => Icons.two_wheeler,
    _ => Icons.directions_car,
  };
}
