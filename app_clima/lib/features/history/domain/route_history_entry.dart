class RouteHistoryEntry {
  const RouteHistoryEntry({
    required this.destination,
    required this.transport,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    this.rainChance,
  });

  final String destination;
  final String transport;
  final double distanceMeters;
  final double durationSeconds;
  final DateTime createdAt;
  final double latitude;
  final double longitude;
  final int? rainChance;

  Map<String, dynamic> toJson() => {
        'destination': destination,
        'transport': transport,
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
        'createdAt': createdAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'rainChance': rainChance,
      };

  factory RouteHistoryEntry.fromJson(Map<String, dynamic> json) => RouteHistoryEntry(
        destination: json['destination'] as String? ?? 'Destino',
        transport: json['transport'] as String? ?? 'Rota',
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        rainChance: (json['rainChance'] as num?)?.round(),
      );
}
