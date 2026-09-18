import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'features/weather/data/weather_service.dart';
import 'features/weather/domain/weather_data.dart';
import 'core/widgets/app_widgets.dart';
import 'features/history/presentation/history_page.dart';
import 'features/history/domain/route_history_entry.dart';
import 'features/route/presentation/route_page.dart';
import 'features/route/domain/route_result.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  assert(() {
    debugPrint(
      "Configuracao de APIs: WeatherAPI=${dotenv.env['WEATHER_API_KEY']?.isNotEmpty == true}, "
      "OpenRouteService=${dotenv.env['ORS_API_KEY']?.isNotEmpty == true}",
    );
    return true;
  }());
  runApp(const AppClimaApp());
}

class AppClimaApp extends StatelessWidget {
  const AppClimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1565C0),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'AppClima',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF5F8FF),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: scheme.primaryContainer,
          backgroundColor: scheme.surface,
        ),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int currentIndex = 0;
  final _historyDestination = ValueNotifier<RouteDestination?>(null);

  @override
  void dispose() {
    _historyDestination.dispose();
    super.dispose();
  }

  void _useHistoryDestination(RouteHistoryEntry entry) {
    _historyDestination.value = RouteDestination(
      name: entry.destination,
      location: LatLng(entry.latitude, entry.longitude),
      isMapSelection: true,
    );
    setState(() => currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const WeatherPage(),
      RoutePage(destinationNotifier: _historyDestination),
      HistoryPage(onRouteSelected: _useHistoryDestination),
    ];
    return Scaffold(
      body: SafeArea(child: pages[currentIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() => currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Clima',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Rota',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historico',
          ),
        ],
      ),
    );
  }
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  static const fallbackLocation = LatLng(-23.5505, -46.6333);
  WeatherData? weather;
  LatLng? currentLocation;
  String? errorMessage;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeather());
  }

  Future<void> _loadWeather() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final position = await LocationService.currentPosition();
      final location = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        currentLocation = location;
      });
      final result = await WeatherService.fetchForecast(location);
      if (!mounted) return;
      setState(() => weather = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeader(
          title: 'Clima agora',
          subtitle: weather?.locationName ?? 'Sua localizacao',
        ),
        const SizedBox(height: 18),
        CurrentWeatherCard(weather: weather),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          WeatherErrorCard(message: errorMessage!),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: isLoading ? null : _openWeatherMap,
          icon: const Icon(Icons.radar),
          label: const Text('Ver radar do clima'),
        ),
        const SizedBox(height: 16),
        const SectionTitle('Previsao para hoje'),
        const SizedBox(height: 12),
        HourlyForecastList(weather: weather),
        const SizedBox(height: 20),
        const SectionTitle('Proximos dias'),
        const SizedBox(height: 12),
        DailyForecastList(weather: weather),
        const SizedBox(height: 20),
        const SectionTitle('Detalhes de hoje'),
        const SizedBox(height: 12),
        WeatherMetricGrid(weather: weather),
      ],
    );
  }

  void _openWeatherMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WeatherMapPage(
          userLocation: currentLocation ?? fallbackLocation,
          currentWeather: weather,
        ),
      ),
    );
  }
}

class WeatherMapCard extends StatelessWidget {
  const WeatherMapCard({
    required this.mapController,
    required this.location,
    required this.weather,
    required this.isLoading,
    required this.onLocate,
    required this.onOpenMap,
    super.key,
  });

  final MapController mapController;
  final LatLng location;
  final WeatherData? weather;
  final bool isLoading;
  final VoidCallback onLocate;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_outlined, color: Color(0xFF1B7F8C)),
              const SizedBox(width: 8),
              const Text(
                'Mapa do clima',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                onPressed: isLoading ? null : onLocate,
                icon: const Icon(Icons.my_location),
                tooltip: 'Mostrar minha localizacao',
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onOpenMap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 230,
                width: double.infinity,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: location,
                        initialZoom: 12.5,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.app_clima',
                        ),
                        const SimpleAttributionWidget(
                          source: Text('OpenStreetMap contributors'),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: location,
                              width: 44,
                              height: 44,
                              child: const Icon(
                                Icons.my_location,
                                color: Color(0xFF12343B),
                                size: 34,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (weather != null) ...[
                      MapWeatherBubble(
                        left: 12,
                        top: 14,
                        icon: Icons.water_drop,
                        label: 'Chuva ${weather!.rainChance}%',
                        color: const Color(0xFF2F80ED),
                      ),
                      MapWeatherBubble(
                        right: 12,
                        top: 72,
                        icon: Icons.air,
                        label: '${weather!.windKph.round()} km/h',
                        color: const Color(0xFF6C63FF),
                      ),
                      MapWeatherBubble(
                        left: 72,
                        bottom: 14,
                        icon: Icons.wb_sunny,
                        label: 'UV ${weather!.uv.toStringAsFixed(1)}',
                        color: const Color(0xFFE39D17),
                      ),
                    ],
                    if (isLoading)
                      const Center(child: CircularProgressIndicator()),
                    const Positioned(
                      right: 10,
                      bottom: 10,
                      child: Icon(Icons.open_in_full, color: Color(0xFF12343B)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Toque no mapa para ver os indicadores em tela cheia.',
            style: TextStyle(color: Color(0xFF5A6B70)),
          ),
        ],
      ),
    );
  }
}

class WeatherMapPage extends StatefulWidget {
  const WeatherMapPage({
    required this.userLocation,
    required this.currentWeather,
    super.key,
  });

  final LatLng userLocation;
  final WeatherData? currentWeather;

  @override
  State<WeatherMapPage> createState() => _WeatherMapPageState();
}

class _WeatherMapPageState extends State<WeatherMapPage> {
  final mapController = MapController();
  WeatherMapFilter selectedFilter = WeatherMapFilter.rain;
  MapBaseStyle selectedMapStyle = MapBaseStyle.light;
  List<WeatherPoint> points = [];
  String? errorMessage;
  bool isLoading = true;
  late LatLng mapCenter;
  Timer? updateTimer;
  bool mapReady = false;

  @override
  void initState() {
    super.initState();
    mapCenter = widget.userLocation;
  }

  Future<void> _loadNearbyWeather() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final bounds = mapReady
        ? mapController.camera.visibleBounds
        : LatLngBounds(
            LatLng(mapCenter.latitude - 0.05, mapCenter.longitude - 0.05),
            LatLng(mapCenter.latitude + 0.05, mapCenter.longitude + 0.05),
          );
    const divisions = 2;
    const edgeMargin = 0.25;
    final nearbyLocations = [
      for (var latitudeIndex = 0; latitudeIndex <= divisions; latitudeIndex++)
        for (
          var longitudeIndex = 0;
          longitudeIndex <= divisions;
          longitudeIndex++
        )
          LatLng(
            bounds.south +
                ((bounds.north - bounds.south) *
                    (edgeMargin +
                        ((1 - (2 * edgeMargin)) * latitudeIndex / divisions))),
            bounds.west +
                ((bounds.east - bounds.west) *
                    (edgeMargin +
                        ((1 - (2 * edgeMargin)) * longitudeIndex / divisions))),
          ),
    ];

    try {
      final nearbyData = await Future.wait(
        nearbyLocations.map(WeatherService.fetchForecast),
      );
      final loadedPoints = [
        for (var index = 0; index < nearbyData.length; index++)
          WeatherPoint(nearbyLocations[index], nearbyData[index]),
      ];

      if (!mounted) return;
      setState(() {
        points = loadedPoints;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => errorMessage = 'Nao foi possivel carregar os pontos do mapa.',
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    updateTimer?.cancel();
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visiblePoints = points.where((point) {
      return selectedFilter != WeatherMapFilter.rain ||
          point.weather.rainChance > 0;
    });
    final centralWeather = points.length >= 5
        ? points[4].weather
        : widget.currentWeather;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa do clima'),
        actions: [
          PopupMenuButton<MapBaseStyle>(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Mudar estilo do mapa',
            onSelected: (style) => setState(() => selectedMapStyle = style),
            itemBuilder: (context) => MapBaseStyle.values.map((style) {
              return PopupMenuItem(
                value: style,
                child: Row(
                  children: [
                    Icon(
                      style.icon,
                      color: style == selectedMapStyle
                          ? const Color(0xFF1B7F8C)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(style.label),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Stack(
        children: [
          ColorFiltered(
            colorFilter: selectedMapStyle.colorFilter,
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: widget.userLocation,
                initialZoom: 11.5,
                onMapReady: () {
                  setState(() => mapReady = true);
                  _loadNearbyWeather();
                },
                onPositionChanged: (camera, hasGesture) {
                  if (!hasGesture) return;
                  setState(() {
                    mapCenter = camera.center;
                  });
                  _scheduleAreaUpdate();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app_clima',
                ),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.userLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: Color(0xFF12343B),
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (mapReady)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ThermalMapPainter(
                    camera: mapController.camera,
                    filter: selectedFilter,
                    points: visiblePoints.toList(),
                  ),
                ),
              ),
            ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
          if (centralWeather != null)
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: WeatherMapSummary(weather: centralWeather),
            ),
          if (errorMessage != null)
            Positioned(
              top: centralWeather == null ? 18 : 98,
              left: 18,
              right: 18,
              child: WeatherErrorCard(message: errorMessage!),
            ),
          Positioned(
            top: centralWeather == null ? 18 : 98,
            left: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  '${selectedFilter.label}: cor mais forte = valor maior',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(blurRadius: 12, color: Color(0x33000000)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: WeatherMapFilter.values.map((filter) {
                      return ChoiceChip(
                        selected: selectedFilter == filter,
                        avatar: Icon(
                          filter.icon,
                          size: 18,
                          color: filter.color,
                        ),
                        label: Text(filter.label),
                        onSelected: (_) =>
                            setState(() => selectedFilter = filter),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleAreaUpdate() {
    updateTimer?.cancel();
    updateTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted && !isLoading) {
        _loadNearbyWeather();
      }
    });
  }
}

class WeatherRegionStyle {
  static double intensityFor(WeatherMapFilter filter, WeatherData weather) {
    return switch (filter) {
      WeatherMapFilter.rain => weather.rainChance / 100,
      WeatherMapFilter.wind =>
        (weather.windKph / 45).clamp(0.2, 1.0).toDouble(),
      WeatherMapFilter.temperature =>
        (weather.temperature / 40).clamp(0.2, 1.0).toDouble(),
      WeatherMapFilter.uv => (weather.uv / 11).clamp(0.2, 1.0).toDouble(),
    };
  }
}

class ThermalMapPainter extends CustomPainter {
  const ThermalMapPainter({
    required this.camera,
    required this.filter,
    required this.points,
  });

  final MapCamera camera;
  final WeatherMapFilter filter;
  final List<WeatherPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    for (final point in points) {
      final intensity = WeatherRegionStyle.intensityFor(filter, point.weather);
      final center = camera.latLngToScreenOffset(point.location);
      final radius = 135 + (135 * intensity);
      final centerOpacity = 0.10 + (0.26 * intensity);
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            filter.color.withValues(alpha: centerOpacity),
            filter.color.withValues(alpha: centerOpacity * 0.42),
            filter.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect);
      canvas.drawCircle(center, radius, paint);

      final label = switch (filter) {
        WeatherMapFilter.rain =>
          '${point.weather.rainChance}%\n${point.weather.forecastPrecipitationMm.toStringAsFixed(1)} mm',
        WeatherMapFilter.wind => '${point.weather.windKph.round()} km/h',
        WeatherMapFilter.temperature =>
          '${point.weather.temperature.round()} C\nS ${point.weather.feelsLike.round()} C',
        WeatherMapFilter.uv => 'UV ${point.weather.uv.toStringAsFixed(1)}',
      };
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Color(0xAA000000), blurRadius: 4)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ThermalMapPainter oldDelegate) {
    return oldDelegate.camera != camera ||
        oldDelegate.filter != filter ||
        oldDelegate.points != points;
  }
}

class WeatherMapSummary extends StatelessWidget {
  const WeatherMapSummary({required this.weather, super.key});

  final WeatherData weather;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Color(0x22000000))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 10,
          runSpacing: 6,
          children: [
            MapMetric(Icons.water_drop, '${weather.rainChance}% chuva'),
            MapMetric(Icons.air, '${weather.windKph.round()} km/h'),
            MapMetric(
              Icons.device_thermostat,
              '${weather.temperature.round()} C',
            ),
            MapMetric(Icons.wb_sunny, 'UV ${weather.uv.toStringAsFixed(1)}'),
          ],
        ),
      ),
    );
  }
}

class MapMetric extends StatelessWidget {
  const MapMetric(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF1B7F8C)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class WeatherPoint {
  const WeatherPoint(this.location, this.weather);

  final LatLng location;
  final WeatherData weather;
}

enum WeatherMapFilter {
  rain('Chuva', Icons.water_drop, Color(0xFF2F80ED)),
  wind('Vento', Icons.air, Color(0xFF6C63FF)),
  temperature('Temperatura', Icons.device_thermostat, Color(0xFFD85C3B)),
  uv('UV', Icons.wb_sunny, Color(0xFFE39D17));

  const WeatherMapFilter(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

enum MapBaseStyle {
  light(
    'Claro',
    Icons.light_mode_outlined,
    ColorFilter.matrix(<double>[
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
  ),
  dark(
    'Escuro',
    Icons.dark_mode_outlined,
    ColorFilter.matrix(<double>[
      -1,
      0,
      0,
      0,
      255,
      0,
      -1,
      0,
      0,
      255,
      0,
      0,
      -1,
      0,
      255,
      0,
      0,
      0,
      1,
      0,
    ]),
  );

  const MapBaseStyle(this.label, this.icon, this.colorFilter);

  final String label;
  final IconData icon;
  final ColorFilter colorFilter;
}

class CurrentWeatherCard extends StatelessWidget {
  const CurrentWeatherCard({required this.weather, super.key});

  final WeatherData? weather;

  @override
  Widget build(BuildContext context) {
    final style = _WeatherCardStyle.fromCondition(weather?.condition);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: style.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(weather?.condition ?? 'Carregando condicoes...', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(weather == null ? 'Atualizando sua previsao' : 'Sensacao de ${weather!.feelsLike.round()} C', style: const TextStyle(color: Color(0xFFE3F2FD))),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  style.icon,
                  key: ValueKey(weather?.condition),
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(weather == null ? '-- C' : '${weather!.temperature.round()} C', style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800, height: 1)),
          const SizedBox(height: 18),
          Row(
            children: [
              _WeatherHighlight(icon: Icons.water_drop_outlined, label: 'Chuva', value: weather == null ? '--' : '${weather!.rainChance}%'),
              const SizedBox(width: 18),
              _WeatherHighlight(icon: Icons.air, label: 'Vento', value: weather == null ? '--' : '${weather!.windKph.round()} km/h'),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherCardStyle {
  const _WeatherCardStyle(this.colors, this.icon);
  final List<Color> colors;
  final IconData icon;

  factory _WeatherCardStyle.fromCondition(String? condition) {
    final text = (condition ?? '').toLowerCase();
    if (text.contains('trovoada') || text.contains('tempestade')) {
      return const _WeatherCardStyle(
        [Color(0xFF1A237E), Color(0xFF4527A0), Color(0xFF5C6BC0)],
        Icons.thunderstorm,
      );
    }
    if (text.contains('chuva') || text.contains('garoa') || text.contains('chuvisco')) {
      return const _WeatherCardStyle(
        [Color(0xFF263238), Color(0xFF455A64), Color(0xFF607D8B)],
        Icons.water_drop,
      );
    }
    if (text.contains('nublado') || text.contains('encoberto')) {
      return const _WeatherCardStyle(
        [Color(0xFF37474F), Color(0xFF546E7A), Color(0xFF78909C)],
        Icons.cloud,
      );
    }
    if (text.contains('nevoeiro') || text.contains('neblina') || text.contains('névoa')) {
      return const _WeatherCardStyle(
        [Color(0xFF546E7A), Color(0xFF78909C), Color(0xFF90A4AE)],
        Icons.foggy,
      );
    }
    if (text.contains('sol') || text.contains('limpo') || text.contains('claro')) {
      return const _WeatherCardStyle(
        [Color(0xFFFF8F00), Color(0xFFFFB300), Color(0xFFFFCA28)],
        Icons.wb_sunny,
      );
    }
    return const _WeatherCardStyle(
      [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
      Icons.wb_cloudy_outlined,
    );
  }
}

class _WeatherHighlight extends StatelessWidget {
  const _WeatherHighlight({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: const Color(0xFFE3F2FD), size: 19),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFFE3F2FD), fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      );

}

class HourlyForecastList extends StatelessWidget {
  const HourlyForecastList({required this.weather, super.key});

  final WeatherData? weather;

  static const fallbackItems = [
    ForecastHour('Agora', Icons.cloud, '24 C', '18%'),
    ForecastHour('15:00', Icons.water_drop, '23 C', '42%'),
    ForecastHour('16:00', Icons.thunderstorm, '22 C', '68%'),
    ForecastHour('17:00', Icons.air, '21 C', '51%'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 144,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: weather?.hours.length ?? fallbackItems.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = weather?.hours[index] ?? fallbackItems[index];

          return InfoCard(
            width: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.time,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Icon(item.icon, color: const Color(0xFF1B7F8C)),
                const SizedBox(height: 10),
                Text(item.temperature),
                Text('${item.rainChance} chuva'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DailyForecastList extends StatelessWidget {
  const DailyForecastList({required this.weather, super.key});
  final WeatherData? weather;

  @override
  Widget build(BuildContext context) {
    final days = weather?.days ?? const <DailyForecast>[];
    if (days.isEmpty) {
      return const InfoCard(child: Text('Carregando previsao dos proximos dias...'));
    }
    return Column(
      children: [
        for (final day in days)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InfoCard(
              child: Row(
                children: [
                  SizedBox(width: 48, child: Text(day.day, style: const TextStyle(fontWeight: FontWeight.w800))),
                  Icon(day.icon, color: const Color(0xFF1565C0)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${day.rainChance} de chuva · ${day.precipitationMm}', style: const TextStyle(color: Color(0xFF5A6B70)))),
                  Text('${day.minTemperature}  ${day.maxTemperature}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class WeatherMetricGrid extends StatelessWidget {
  const WeatherMetricGrid({required this.weather, super.key});

  final WeatherData? weather;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 12) / 2;
          final data = weather;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              MetricTile(width: width, icon: Icons.water_drop, label: 'Chuva prevista', value: data == null ? '--' : '${data.rainChance}%\n${data.forecastPrecipitationMm.toStringAsFixed(1)} mm'),
              MetricTile(width: width, icon: Icons.air, label: 'Vento', value: data == null ? '--' : '${data.windKph.round()} km/h\n${data.windDirection}'),
              MetricTile(width: width, icon: Icons.speed, label: 'Rajadas', value: data == null ? '--' : '${data.gustKph.round()} km/h'),
              MetricTile(width: width, icon: Icons.wb_sunny, label: 'Radiacao UV', value: data == null ? '--' : '${data.uv.toStringAsFixed(1)} · ${_uvLabel(data.uv)}'),
              MetricTile(width: width, icon: Icons.water, label: 'Umidade', value: data == null ? '--' : '${data.humidity}%'),
              MetricTile(width: width, icon: Icons.visibility, label: 'Visibilidade', value: data == null ? '--' : '${data.visibilityKm.toStringAsFixed(1)} km'),
              MetricTile(width: width, icon: Icons.compress, label: 'Pressao', value: data == null ? '--' : '${data.pressureMb.round()} mb'),
              MetricTile(width: width, icon: Icons.cloud_outlined, label: 'Nuvens', value: data == null ? '--' : '${data.cloudCoverage}%'),
            ],
          );
        },
      );

  String _uvLabel(double value) {
    if (value < 3) return 'baixo';
    if (value < 6) return 'moderado';
    if (value < 8) return 'alto';
    if (value < 11) return 'muito alto';
    return 'extremo';
  }
}

class LegacyRoutePage extends StatefulWidget {
  const LegacyRoutePage({super.key});

  @override
  State<LegacyRoutePage> createState() => _LegacyRoutePageState();
}

class _LegacyRoutePageState extends State<LegacyRoutePage> {
  LegacyTransportType selectedTransport = LegacyTransportType.walking;
  final destinationController = TextEditingController(text: 'Padaria Central');

  @override
  void dispose() {
    destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeader(
          title: 'Rota com clima',
          subtitle: 'Veja as condicoes previstas pelo caminho',
        ),
        const SizedBox(height: 18),
        TextField(
          controller: destinationController,
          onSubmitted: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Para onde voce vai?',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.arrow_forward),
              tooltip: 'Ver previsao da rota',
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE1EAEC)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.my_location, size: 17, color: Color(0xFF1B7F8C)),
            SizedBox(width: 6),
            Text(
              'Saida: sua localizacao atual',
              style: TextStyle(color: Color(0xFF5A6B70)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LegacyTransportSelector(
          selected: selectedTransport,
          onSelected: (transport) {
            setState(() => selectedTransport = transport);
          },
        ),
        const SizedBox(height: 18),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(selectedTransport.icon, color: const Color(0xFF1B7F8C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      destinationController.text.isEmpty
                          ? 'Escolha um destino'
                          : destinationController.text,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    selectedTransport.duration,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 260,
                width: double.infinity,
                child: CustomPaint(
                  painter: RouteWeatherPainter(),
                  child: const Stack(
                    children: [
                      MapWeatherBubble(
                        left: 42,
                        top: 138,
                        icon: Icons.water_drop,
                        label: 'chuva',
                        color: Color(0xFF2F80ED),
                      ),
                      MapWeatherBubble(
                        left: 164,
                        top: 64,
                        icon: Icons.air,
                        label: 'vento',
                        color: Color(0xFF6C63FF),
                      ),
                      MapWeatherBubble(
                        right: 28,
                        top: 124,
                        icon: Icons.wb_sunny,
                        label: 'UV',
                        color: Color(0xFFE39D17),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'As bolhas marcam o que pode acontecer em cada ponto da rota.',
                style: TextStyle(color: Color(0xFF5A6B70)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Alertas do trajeto'),
        const SizedBox(height: 12),
        const AlertTile(
          icon: Icons.water_drop,
          title: 'Chuva em 5 minutos',
          description: 'O trecho da Avenida Brasil pode ter chuva moderada.',
        ),
        const AlertTile(
          icon: Icons.air,
          title: 'Vento lateral',
          description: 'A regiao da ponte tem rajadas de vento.',
        ),
        const AlertTile(
          icon: Icons.wb_sunny,
          title: 'Radiacao alta',
          description: 'Use protecao solar se estiver caminhando ou pedalando.',
        ),
      ],
    );
  }
}

class LegacyTransportSelector extends StatelessWidget {
  const LegacyTransportSelector({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final LegacyTransportType selected;
  final ValueChanged<LegacyTransportType> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: LegacyTransportType.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final transport = LegacyTransportType.values[index];
          final isSelected = selected == transport;

          return ChoiceChip(
            selected: isSelected,
            avatar: Icon(transport.icon, size: 18),
            label: Text(transport.label),
            onSelected: (_) => onSelected(transport),
          );
        },
      ),
    );
  }
}

class RouteWeatherPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mapPaint = Paint()
      ..color = const Color(0xFFE7EEEE)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final roadOne = Path()
      ..moveTo(0, 44)
      ..cubicTo(92, 70, 160, 16, size.width, 54);
    final roadTwo = Path()
      ..moveTo(16, size.height - 22)
      ..cubicTo(112, 172, 176, 234, size.width, 166);
    canvas.drawPath(roadOne, mapPaint);
    canvas.drawPath(roadTwo, mapPaint);
    canvas.drawLine(Offset(42, 0), Offset(62, size.height), mapPaint);
    canvas.drawLine(
      Offset(size.width - 74, 0),
      Offset(size.width - 96, size.height),
      mapPaint,
    );

    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(30, size.height - 44)
      ..cubicTo(78, 174, 96, 118, 142, 132)
      ..cubicTo(196, 150, 194, 52, 246, 54)
      ..cubicTo(298, 56, 306, 144, size.width - 34, 102);

    routePaint.color = const Color(0xFF1B7F8C);
    canvas.drawPath(path, routePaint);

    final markerPaint = Paint()..color = const Color(0xFF12343B);
    canvas.drawCircle(Offset(30, size.height - 44), 10, markerPaint);
    canvas.drawCircle(Offset(size.width - 34, 102), 10, markerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MapWeatherBubble extends StatelessWidget {
  const MapWeatherBubble({
    required this.icon,
    required this.label,
    required this.color,
    this.left,
    this.right,
    this.top,
    this.bottom,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: 86,
        height: 86,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.72),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.75),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum LegacyTransportType {
  walking('Caminhada', '10 min', Icons.directions_walk),
  bike('Bicicleta', '6 min', Icons.directions_bike),
  motorcycle('Moto', '4 min', Icons.two_wheeler),
  car('Carro', '5 min', Icons.directions_car);

  const LegacyTransportType(this.label, this.duration, this.icon);

  final String label;
  final String duration;
  final IconData icon;
}
