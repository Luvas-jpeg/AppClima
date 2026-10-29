import 'package:flutter/material.dart';

class WeatherData {
  const WeatherData({
    required this.locationName,
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    required this.windKph,
    required this.windDirection,
    required this.gustKph,
    required this.uv,
    required this.humidity,
    required this.pressureMb,
    required this.visibilityKm,
    required this.cloudCoverage,
    required this.precipitationMm,
    required this.forecastPrecipitationMm,
    required this.rainChance,
    required this.hours,
    required this.days,
    this.sourceUpdatedAt,
  });

  final DateTime? sourceUpdatedAt;
  final String locationName;
  final double temperature;
  final double feelsLike;
  final String condition;
  final double windKph;
  final String windDirection;
  final double gustKph;
  final double uv;
  final int humidity;
  final double pressureMb;
  final double visibilityKm;
  final int cloudCoverage;
  final double precipitationMm;
  final double forecastPrecipitationMm;
  final int rainChance;
  final List<ForecastHour> hours;
  final List<DailyForecast> days;
}

class DailyForecast {
  const DailyForecast({
    required this.day,
    required this.icon,
    required this.minTemperature,
    required this.maxTemperature,
    required this.rainChance,
    required this.precipitationMm,
  });

  final String day;
  final IconData icon;
  final String minTemperature;
  final String maxTemperature;
  final String rainChance;
  final String precipitationMm;

  factory DailyForecast.fromJson(Map<String, dynamic> data, int index) {
    final day = data['day'] as Map<String, dynamic>;
    final date = DateTime.tryParse(data['date'] as String? ?? '');
    final label = index == 0
        ? 'Hoje'
        : date == null
        ? 'Proximo dia'
        : const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'][date.weekday -
              1];
    final condition = day['condition'] as Map<String, dynamic>;
    return DailyForecast(
      day: label,
      icon: ForecastHour._iconForCondition(condition['text'] as String),
      minTemperature: '${(day['mintemp_c'] as num).round()} C',
      maxTemperature: '${(day['maxtemp_c'] as num).round()} C',
      rainChance: '${day['daily_chance_of_rain']}%',
      precipitationMm:
          '${(day['totalprecip_mm'] as num).toStringAsFixed(1)} mm',
    );
  }
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
