import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'features/weather/data/weather_service.dart';
import 'features/weather/data/weather_city_service.dart';
import 'features/weather/domain/weather_city.dart';
import 'features/route/presentation/geoapify_attribution.dart';
import 'features/weather/domain/weather_data.dart';
import 'features/weather/presentation/weather_map_marker.dart';
import 'core/widgets/app_widgets.dart';
import 'features/history/presentation/history_page.dart';
import 'features/history/domain/route_history_entry.dart';
import 'features/route/presentation/route_page.dart';
import 'features/route/domain/route_result.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  assert(() {
    debugPrint(
      "Configuracao de APIs: WeatherAPI=${dotenv.env['WEATHER_API_KEY']?.isNotEmpty == true}"
      "Geoapify=${dotenv.env['GEOAPIFY_API_KEY']?.isNotEmpty == true}",
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
      seedColor: const Color(0xFF087F8C),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'AppClima',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF5F8FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F8FF),
          foregroundColor: Color(0xFF12343B),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF12343B),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE1EAEC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE1EAEC)),
          ),
        ),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  void _openRoute(BuildContext context, {RouteHistoryEntry? entry}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Planejar viagem')),
          body: SafeArea(
            child: RoutePage(
              initialDestination: entry == null
                  ? null
                  : RouteDestination(
                      name: entry.destination,
                      location: LatLng(entry.latitude, entry.longitude),
                      isMapSelection: true,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openHistory(BuildContext context) async {
    final entry = await Navigator.of(context).push<RouteHistoryEntry>(
      MaterialPageRoute(
        builder: (pageContext) => Scaffold(
          appBar: AppBar(title: const Text('Suas viagens')),
          body: SafeArea(
            child: HistoryPage(
              onRouteSelected: (entry) => Navigator.of(pageContext).pop(entry),
            ),
          ),
        ),
      ),
    );
    if (entry != null && context.mounted) _openRoute(context, entry: entry);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          Icon(Icons.explore, color: Color(0xFF087F8C)),
          SizedBox(width: 10),
          Text('AppClima'),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Histórico de viagens',
          onPressed: () => _openHistory(context),
          icon: const Icon(Icons.history_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(
      child: WeatherPage(
        onPlanRoute: () => _openRoute(context),
        onHistory: () => _openHistory(context),
      ),
    ),
  );
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({
    this.onPlanRoute,
    this.onHistory,
    this.locationProvider,
    this.forecastLoader,
    super.key,
  });
  final VoidCallback? onPlanRoute;
  final VoidCallback? onHistory;
  final Future<Position> Function()? locationProvider;
  final Future<WeatherData> Function(LatLng)? forecastLoader;

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  static const fallbackLocation = LatLng(-23.5505, -46.6333);
  WeatherData? weather;
  LatLng? currentLocation;
  String? errorMessage;
  bool isLoading = false;
  DateTime? lastRefreshAt;
  Future<void>? _weatherRequest;
  bool _showingSavedWeather = false;

  @override
  void initState() {
    super.initState();
    if (widget.forecastLoader == null) _restoreWeather();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeather());
  }

  Future<void> _restoreWeather() async {
    final saved = await WeatherService.loadSavedForecast();
    if (!mounted || saved == null || weather != null) return;
    setState(() {
      weather = saved.weather;
      currentLocation = saved.location;
      lastRefreshAt = saved.savedAt;
      _showingSavedWeather = true;
    });
  }

  Future<void> _loadWeather() async {
    final pending = _weatherRequest;
    if (pending != null) return pending;
    final request = _fetchWeather();
    _weatherRequest = request;
    try {
      await request;
    } finally {
      if (identical(_weatherRequest, request)) _weatherRequest = null;
    }
  }

  Future<void> _fetchWeather() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final position =
          await (widget.locationProvider ?? LocationService.currentPosition)();
      final location = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      final result =
          await (widget.forecastLoader ?? WeatherService.fetchForecast)(
            location,
          );
      if (!mounted) return;
      setState(() {
        weather = result;
        _showingSavedWeather = false;
        currentLocation = location;
        lastRefreshAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => errorMessage = weather == null
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Não foi possível atualizar. Os últimos dados foram mantidos.\n${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadWeather,
      child: ListView(
        key: const ValueKey('weather-home-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          PageHeader(
            title: 'Clima agora',
            subtitle: weather?.locationName ?? 'O tempo no seu próximo caminho',
          ),
          const SizedBox(height: 14),
          CurrentWeatherCard(weather: weather),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Puxe para baixo para atualizar',
                      style: TextStyle(fontSize: 12, color: Color(0xFF5A6B70)),
                    ),
                    if (lastRefreshAt != null)
                      Text(
                        _showingSavedWeather
                            ? 'Previsão salva em ${_sourceTime(lastRefreshAt!)}${isLoading ? ' · atualizando…' : ''}'
                            : 'Consulta atualizada às ${_clock(lastRefreshAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5A6B70),
                        ),
                      ),
                    if (weather?.sourceUpdatedAt != null)
                      Text(
                        'Dados da WeatherAPI: ${_sourceTime(weather!.sourceUpdatedAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5A6B70),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Atualizar clima',
                onPressed: isLoading ? null : _loadWeather,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            WeatherErrorCard(message: errorMessage!),
          ],
          const SizedBox(height: 24),
          if (widget.onPlanRoute != null) ...[
            JourneyActionCard(
              title: 'Planejar rota',
              description: 'Descubra como estará o tempo no caminho.',
              icon: Icons.route_rounded,
              onTap: widget.onPlanRoute!,
              primary: true,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.onHistory != null) ...[
            JourneyActionCard(
              title: 'Histórico',
              description: 'Retome um destino das suas últimas viagens.',
              icon: Icons.history_rounded,
              onTap: widget.onHistory!,
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: isLoading ? null : _openWeatherMap,
            icon: const Icon(Icons.radar),
            label: const Text('Explorar mapa do clima'),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Nas próximas horas'),
          const SizedBox(height: 12),
          HourlyForecastList(weather: weather),
          const SizedBox(height: 20),
          const SectionTitle('Próximos dias'),
          const SizedBox(height: 12),
          DailyForecastList(weather: weather),
          const SizedBox(height: 20),
          ExpansionTile(
            title: const Text('Detalhes de hoje'),
            subtitle: const Text('Vento, umidade, UV e outros indicadores'),
            children: [WeatherMetricGrid(weather: weather)],
          ),
        ],
      ),
    );
  }

  String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  String _sourceTime(DateTime time) =>
      '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} às ${_clock(time)}';

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
    this.forecastLoader,
    this.cityLoader,
    super.key,
  });

  final LatLng userLocation;
  final WeatherData? currentWeather;
  final Future<WeatherData> Function(LatLng)? forecastLoader;
  final Future<List<WeatherCity>> Function(LatLngBounds)? cityLoader;

  @override
  State<WeatherMapPage> createState() => _WeatherMapPageState();
}

class _WeatherMapPageState extends State<WeatherMapPage> {
  final mapController = MapController();
  WeatherMapFilter selectedFilter = WeatherMapFilter.temperature;
  MapBaseStyle selectedMapStyle = MapBaseStyle.light;
  List<WeatherPoint> points = [];
  String? errorMessage;
  bool isLoading = true;
  late LatLng mapCenter;
  Timer? updateTimer;
  bool mapReady = false;
  int _weatherRequest = 0;
  bool _loadingArea = false;
  bool _areaUpdatePending = false;
  final _cities = WeatherCityService();
  final _forecastCache =
      <String, ({DateTime createdAt, Future<WeatherData> forecast})>{};

  Future<WeatherData> _cityForecast(WeatherCity city) {
    final cached = _forecastCache[city.id];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) <
            const Duration(minutes: 15)) {
      return cached.forecast;
    }
    if (_forecastCache.length >= 16) {
      _forecastCache.remove(_forecastCache.keys.first);
    }
    final forecast = (widget.forecastLoader ?? WeatherService.fetchForecast)(
      city.location,
    );
    _forecastCache[city.id] = (createdAt: DateTime.now(), forecast: forecast);
    return forecast;
  }

  @override
  void initState() {
    super.initState();
    mapCenter = widget.userLocation;
  }

  Future<void> _loadNearbyWeather() async {
    if (!mounted) return;
    if (_loadingArea) {
      _areaUpdatePending = true;
      return;
    }
    _loadingArea = true;
    final request = ++_weatherRequest;
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
    try {
      final cities = await (widget.cityLoader ?? _cities.findCities)(bounds);
      if (!mounted || request != _weatherRequest) return;
      var failures = 0;
      final loaded = List<WeatherPoint?>.filled(cities.length, null);
      var nextCity = 0;
      // Obsolete map areas stop launching requests as soon as active work ends.
      await Future.wait(
        List.generate(cities.length.clamp(0, 4), (_) async {
          while (mounted &&
              request == _weatherRequest &&
              nextCity < cities.length) {
            final index = nextCity++;
            final city = cities[index];
            try {
              final weather = await _cityForecast(city);
              loaded[index] = WeatherPoint(
                city.location,
                weather,
                cityName: city.name,
              );
              if (mounted && request == _weatherRequest) {
                setState(
                  () => points = loaded.whereType<WeatherPoint>().toList(),
                );
              }
            } catch (_) {
              _forecastCache.remove(city.id);
              failures++;
            }
          }
        }),
      );
      final loadedPoints = loaded.whereType<WeatherPoint>().toList();
      if (!mounted || request != _weatherRequest) return;
      setState(() {
        points = loadedPoints;
        errorMessage = failures > 0
            ? 'Não foi possível carregar o clima de ${failures == 1 ? 'uma cidade' : 'algumas cidades'}. Tente novamente.'
            : cities.isEmpty
            ? 'Nenhuma cidade encontrada nesta área. Afaste o zoom ou mova o mapa.'
            : null;
      });
    } catch (error) {
      if (!mounted || request != _weatherRequest) return;
      setState(
        () => errorMessage = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      _loadingArea = false;
      if (mounted && request == _weatherRequest) {
        setState(() => isLoading = false);
      }
      if (mounted && _areaUpdatePending) {
        _areaUpdatePending = false;
        unawaited(_loadNearbyWeather());
      }
    }
  }

  @override
  void dispose() {
    updateTimer?.cancel();
    _weatherRequest++;
    _forecastCache.clear();
    mapController.dispose();
    _cities.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(selectedFilter.icon, color: selectedFilter.color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedFilter == WeatherMapFilter.rain
                                ? 'Chuva · próxima hora'
                                : '${selectedFilter.label} · agora',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (isLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Toque em uma cidade ou grupo para ver a previsão.',
                      style: TextStyle(color: Color(0xFF5A6B70), fontSize: 12),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      TextButton(
                        onPressed: isLoading ? null : _loadNearbyWeather,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: widget.userLocation,
                initialZoom: 10,
                onMapReady: () {
                  setState(() => mapReady = true);
                  _loadNearbyWeather();
                },
                onPositionChanged: (camera, hasGesture) {
                  if (!hasGesture) return;
                  mapCenter = camera.center;
                  _scheduleAreaUpdate();
                },
              ),
              children: [
                ColorFiltered(
                  colorFilter: selectedMapStyle.colorFilter,
                  child: TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app_clima',
                  ),
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
                        size: 30,
                      ),
                    ),
                  ],
                ),
                WeatherPointMarkerLayer(points: points, filter: selectedFilter),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.zero,
            child: SafeArea(
              top: false,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
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
                      const SizedBox(height: 6),
                      const GeoapifyAttribution(),
                    ],
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
    _weatherRequest++;
    updateTimer?.cancel();
    updateTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        _loadNearbyWeather();
      }
    });
  }
}

class WeatherPointMarkerLayer extends StatelessWidget {
  const WeatherPointMarkerLayer({
    required this.points,
    required this.filter,
    super.key,
  });
  final List<WeatherPoint> points;
  final WeatherMapFilter filter;

  String _value(WeatherData weather) => switch (filter) {
    WeatherMapFilter.rain => '${weather.rainChance}%',
    WeatherMapFilter.temperature => '${weather.temperature.round()}°C',
    WeatherMapFilter.wind => '${weather.windKph.round()} km/h',
    WeatherMapFilter.uv => 'UV ${weather.uv.toStringAsFixed(1)}',
  };

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      double.infinity,
    );
    final width = 154 * scale;
    final height = 76 * scale;
    final groups =
        <({WeatherPoint anchor, Rect bounds, List<WeatherPoint> points})>[];
    for (final point in points) {
      final offset = camera.latLngToScreenOffset(point.location);
      final bounds = Rect.fromCenter(
        center: offset,
        width: width + 12,
        height: height + 12,
      );
      final match = groups.indexWhere((group) => group.bounds.overlaps(bounds));
      if (match < 0) {
        groups.add((anchor: point, bounds: bounds, points: [point]));
      } else {
        groups[match].points.add(point);
      }
    }
    final markers = <Marker>[];
    for (final group in groups) {
      final point = group.anchor;
      if (group.points.length > 1) {
        markers.add(
          Marker(
            point: point.location,
            width: 64,
            height: 64,
            child: Semantics(
              label: '${group.points.length} cidades próximas. Ver previsões.',
              button: true,
              child: Material(
                color: filter.color,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    useSafeArea: true,
                    builder: (sheetContext) => ListView(
                      shrinkWrap: true,
                      children: [
                        for (final city in group.points)
                          ListTile(
                            leading: Icon(filter.icon, color: filter.color),
                            title: Text(
                              city.cityName ?? city.weather.locationName,
                            ),
                            subtitle: Text(_value(city.weather)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                useSafeArea: true,
                                builder: (_) => WeatherPointDetails(
                                  weather: city.weather,
                                  cityName: city.cityName,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${group.points.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        continue;
      }
      markers.add(
        Marker(
          point: point.location,
          width: width,
          height: height,
          rotate: true,
          child: WeatherMapMarker(
            title: point.cityName ?? point.weather.locationName,
            value: _value(point.weather),
            icon: filter.icon,
            color: filter.color,
            compact: false,
            semanticLabel:
                '${point.cityName ?? point.weather.locationName}, ${filter.label}: ${_value(point.weather)}. Toque para detalhes.',
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              useSafeArea: true,
              builder: (_) => WeatherPointDetails(
                weather: point.weather,
                cityName: point.cityName,
              ),
            ),
          ),
        ),
      );
    }
    return MarkerLayer(markers: markers);
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
  const WeatherPoint(this.location, this.weather, {this.cityName});

  final String? cityName;

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
                    Text(
                      weather?.condition ?? 'Carregando condicoes...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      weather == null
                          ? 'Atualizando sua previsao'
                          : 'Sensação de ${weather!.feelsLike.round()}°C',
                      style: const TextStyle(color: Color(0xFFE3F2FD)),
                    ),
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
          Text(
            weather == null ? '--°' : '${weather!.temperature.round()}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _WeatherHighlight(
                icon: Icons.water_drop_outlined,
                label: 'Chuva',
                value: weather == null ? '--' : '${weather!.rainChance}%',
              ),
              const SizedBox(width: 18),
              _WeatherHighlight(
                icon: Icons.air,
                label: 'Vento',
                value: weather == null
                    ? '--'
                    : '${weather!.windKph.round()} km/h',
              ),
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
      return const _WeatherCardStyle([
        Color(0xFF1A237E),
        Color(0xFF4527A0),
        Color(0xFF5C6BC0),
      ], Icons.thunderstorm);
    }
    if (text.contains('chuva') ||
        text.contains('garoa') ||
        text.contains('chuvisco')) {
      return const _WeatherCardStyle([
        Color(0xFF263238),
        Color(0xFF455A64),
        Color(0xFF607D8B),
      ], Icons.water_drop);
    }
    if (text.contains('nublado') || text.contains('encoberto')) {
      return const _WeatherCardStyle([
        Color(0xFF37474F),
        Color(0xFF546E7A),
        Color(0xFF78909C),
      ], Icons.cloud);
    }
    if (text.contains('nevoeiro') ||
        text.contains('neblina') ||
        text.contains('névoa')) {
      return const _WeatherCardStyle([
        Color(0xFF546E7A),
        Color(0xFF78909C),
        Color(0xFF90A4AE),
      ], Icons.foggy);
    }
    if (text.contains('sol') ||
        text.contains('limpo') ||
        text.contains('claro')) {
      return const _WeatherCardStyle([
        Color(0xFFFF8F00),
        Color(0xFFFFB300),
        Color(0xFFFFCA28),
      ], Icons.wb_sunny);
    }
    return const _WeatherCardStyle([
      Color(0xFF0D47A1),
      Color(0xFF1976D2),
      Color(0xFF42A5F5),
    ], Icons.wb_cloudy_outlined);
  }
}

class _WeatherHighlight extends StatelessWidget {
  const _WeatherHighlight({
    required this.icon,
    required this.label,
    required this.value,
  });
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
          Text(
            label,
            style: const TextStyle(color: Color(0xFFE3F2FD), fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
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
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      double.infinity,
    );
    return SizedBox(
      height: 170 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: weather?.hours.length ?? fallbackItems.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = weather?.hours[index] ?? fallbackItems[index];

          return InfoCard(
            width: 112 * scale,
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
      return const InfoCard(
        child: Text('Carregando previsao dos proximos dias...'),
      );
    }
    return Column(
      children: [
        for (final day in days)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InfoCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      day.day,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(day.icon, color: const Color(0xFF1565C0)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${day.rainChance} de chuva · ${day.precipitationMm}',
                      style: const TextStyle(color: Color(0xFF5A6B70)),
                    ),
                  ),
                  Text(
                    '${day.minTemperature}  ${day.maxTemperature}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
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
          MetricTile(
            width: width,
            icon: Icons.water_drop,
            label: 'Chuva prevista',
            value: data == null
                ? '--'
                : '${data.rainChance}%\n${data.forecastPrecipitationMm.toStringAsFixed(1)} mm',
          ),
          MetricTile(
            width: width,
            icon: Icons.air,
            label: 'Vento',
            value: data == null
                ? '--'
                : '${data.windKph.round()} km/h\n${data.windDirection}',
          ),
          MetricTile(
            width: width,
            icon: Icons.speed,
            label: 'Rajadas',
            value: data == null ? '--' : '${data.gustKph.round()} km/h',
          ),
          MetricTile(
            width: width,
            icon: Icons.wb_sunny,
            label: 'Radiacao UV',
            value: data == null
                ? '--'
                : '${data.uv.toStringAsFixed(1)} · ${_uvLabel(data.uv)}',
          ),
          MetricTile(
            width: width,
            icon: Icons.water,
            label: 'Umidade',
            value: data == null ? '--' : '${data.humidity}%',
          ),
          MetricTile(
            width: width,
            icon: Icons.visibility,
            label: 'Visibilidade',
            value: data == null
                ? '--'
                : '${data.visibilityKm.toStringAsFixed(1)} km',
          ),
          MetricTile(
            width: width,
            icon: Icons.compress,
            label: 'Pressao',
            value: data == null ? '--' : '${data.pressureMb.round()} mb',
          ),
          MetricTile(
            width: width,
            icon: Icons.cloud_outlined,
            label: 'Nuvens',
            value: data == null ? '--' : '${data.cloudCoverage}%',
          ),
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
