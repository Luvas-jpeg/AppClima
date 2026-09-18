import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/route_history_entry.dart';

class RouteHistoryRepository {
  static const _key = 'route_history_v1';
  static const _maxEntries = 30;

  static Future<List<RouteHistoryEntry>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final rawEntries = preferences.getStringList(_key) ?? const [];
    final entries = <RouteHistoryEntry>[];
    for (final raw in rawEntries) {
      try {
        entries.add(RouteHistoryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Ignora apenas um registro corrompido, sem perder o restante do histórico.
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final uniqueEntries = <RouteHistoryEntry>[];
    for (final entry in entries) {
      if (!uniqueEntries.any((saved) => _sameDestination(saved, entry))) {
        uniqueEntries.add(entry);
      }
    }
    return uniqueEntries;
  }

  static Future<void> save(RouteHistoryEntry entry) async {
    final entries = await load();
    if (entries.any((saved) => _sameDestination(saved, entry))) return;
    entries.insert(0, entry);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      entries.take(_maxEntries).map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static bool _sameDestination(RouteHistoryEntry first, RouteHistoryEntry second) {
    final bothHaveCoordinates =
        first.latitude != 0 && first.longitude != 0 && second.latitude != 0 && second.longitude != 0;
    if (bothHaveCoordinates) {
      const tolerance = 0.0002;
      return (first.latitude - second.latitude).abs() < tolerance &&
          (first.longitude - second.longitude).abs() < tolerance;
    }
    return first.destination.trim().toLowerCase() == second.destination.trim().toLowerCase();
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
