import 'package:flutter/material.dart';

class WeatherData {
  const WeatherData({
    required this.locationName,
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    required this.windKph,
    required this.uv,
    required this.precipitationMm,
    required this.rainChance,
    required this.hours,
  });

  final String locationName;
  final double temperature;
  final double feelsLike;
  final String condition;
  final double windKph;
  final double uv;
  final double precipitationMm;
  final int rainChance;
  final List<ForecastHour> hours;
}

class ForecastHour {
  const ForecastHour(this.time, this.icon, this.temperature, this.rainChance);

  final String time;
  final IconData icon;
  final String temperature;
  final String rainChance;

  factory ForecastHour.fromJson(Map<String, dynamic> data) {
    final parsedTime = DateTime.tryParse(data['time'] as String);
    final condition = data['condition'] as Map<String, dynamic>;
    final chance = data['chance_of_rain'].toString();
    return ForecastHour(
      parsedTime == null
          ? '--:--'
          : '${parsedTime.hour.toString().padLeft(2, '0')}:00',
      _iconForCondition(condition['text'] as String),
      '${(data['temp_c'] as num).round()} C',
      '$chance%',
    );
  }

  static IconData _iconForCondition(String condition) {
    final text = condition.toLowerCase();
    if (text.contains('chuva') || text.contains('garoa')) {
      return Icons.water_drop;
    }
    if (text.contains('trovoada')) return Icons.thunderstorm;
    if (text.contains('sol') || text.contains('limpo')) return Icons.wb_sunny;
    return Icons.cloud;
  }
}
