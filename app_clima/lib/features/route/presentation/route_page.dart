import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../history/data/route_history_repository.dart';
import '../../history/domain/route_history_entry.dart';
import '../../weather/data/weather_service.dart';
import '../../weather/domain/weather_data.dart';
import '../data/route_service.dart';
import '../domain/route_result.dart';
import '../domain/route_progress.dart';
import '../domain/route_climate_point.dart';
import '../domain/route_forecast_plan.dart';
import 'route_forecast_views.dart';
import 'geoapify_attribution.dart';
import 'route_destination_picker_page.dart';
import 'route_search_page.dart';
import 'route_weather_filter.dart';

export 'route_weather_filter.dart' show RouteWeatherFilter;

class RoutePage extends StatefulWidget {
  const RoutePage({
    this.destinationNotifier,
    this.initialDestination,
    this.locationProvider,
    this.service,
    super.key,
  });
  final RouteDestination? initialDestination;
  final Future<Position> Function()? locationProvider;
  final RouteService? service;
  final ValueNotifier<RouteDestination?>? destinationNotifier;

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  final _destinationController = TextEditingController();
  late final _routeService = widget.service ?? RouteService();
  final _mapController = MapController();
  TransportType _selectedTransport = TransportType.walking;
  RouteWeatherFilter _selectedFilter = RouteWeatherFilter.rain;
  LatLng? _origin;
  RouteDestination? _destination;
  RouteResult? _route;
  DateTime? _departureAt;
  final _mapKey = GlobalKey();
  final _pageScroll = ScrollController();
  List<RouteClimatePoint> _climatePoints = const [];
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _liveLocation;
  int _currentRouteIndex = 0;
  bool _isNavigating = false;
  bool _isLoading = false;
  bool _isLocating = true;
  bool _isChoosingDestination = false;
  bool _isStartingNavigation = false;
  Future<void>? _locationRequest;
  bool get _destinationBusy =>
      _isLoading || _isChoosingDestination || _isStartingNavigation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _destination = widget.initialDestination;
    _destinationController.text = _destination?.name ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentLocation());
    widget.destinationNotifier?.addListener(_applyHistoryDestination);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _applyHistoryDestination(),
    );
  }

  @override
  void dispose() {
    widget.destinationNotifier?.removeListener(_applyHistoryDestination);
    _positionSubscription?.cancel();
    _destinationController.dispose();
    _pageScroll.dispose();
    if (widget.service == null) _routeService.close();
    super.dispose();
  }

  void _applyHistoryDestination() {
    final destination = widget.destinationNotifier?.value;
    if (destination == null || !mounted) return;
    setState(() {
      _destination = destination;
      _destinationController.text = destination.name;
      _route = null;
      _climatePoints = const [];
      _errorMessage = null;
    });
    widget.destinationNotifier!.value = null;
    _mapController.move(destination.location, 14);
  }

  Future<void> _loadCurrentLocation() async {
    final pending = _locationRequest;
    if (pending != null) return pending;
    final request = _fetchCurrentLocation();
    _locationRequest = request;
    try {
      await request;
    } finally {
      if (identical(_locationRequest, request)) _locationRequest = null;
    }
  }

  Future<void> _fetchCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLocating = true);
    try {
      final position =
          await (widget.locationProvider ?? LocationService.currentPosition)();
      final origin = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _origin = origin);
      _mapController.move(origin, 14);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<LatLng?> _ensureOrigin() async {
    if (_origin != null) return _origin;
    await _loadCurrentLocation();
    return _origin;
  }

  Future<void> _pickDestinationOnMap({LatLng? initialDestination}) async {
    if (_destinationBusy) return;
    setState(() => _isChoosingDestination = true);
    try {
      final selected = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(
          builder: (_) => RouteDestinationPickerPage(
            userLocation: _origin,
            initialDestination: initialDestination ?? _destination?.location,
          ),
        ),
      );
      if (selected == null || !mounted) return;

      setState(() {
        _destination = RouteDestination(
          name: 'Buscando endereco...',
          location: selected,
          isMapSelection: true,
        );
        _destinationController.text = 'Buscando endereco...';
        _route = null;
        _climatePoints = const [];
        _errorMessage = null;
      });
      _mapController.move(selected, 14);
      try {
        final destination = await _routeService.reverseGeocode(selected);
        if (!mounted) return;
        setState(() {
          _destination = destination;
          _destinationController.text = destination.name;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _destination = RouteDestination(
            name: 'Ponto selecionado no mapa',
            location: selected,
            isMapSelection: true,
          );
          _destinationController.text =
              '${selected.latitude.toStringAsFixed(5)}, ${selected.longitude.toStringAsFixed(5)}';
        });
      }
      if (mounted) await _buildRoute();
    } finally {
      if (mounted) setState(() => _isChoosingDestination = false);
    }
  }

  Future<void> _searchDestination() async {
    if (_destinationBusy) return;
    setState(() => _isChoosingDestination = true);
    try {
      final destination = await Navigator.of(context).push<RouteDestination>(
        MaterialPageRoute(
          builder: (_) =>
              RouteSearchPage(origin: _origin, service: _routeService),
        ),
      );
      if (destination == null || !mounted) return;
      setState(() {
        _destination = destination;
        _destinationController.text = destination.name;
        _route = null;
        _climatePoints = const [];
        _errorMessage = null;
      });
      await _buildRoute();
    } finally {
      if (mounted) setState(() => _isChoosingDestination = false);
    }
  }

  Future<void> _buildRoute() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final origin = await _ensureOrigin();
      if (origin == null) {
        throw Exception('Nao foi possivel obter sua localizacao atual.');
      }
      final destinationText = _destinationController.text.trim();
      if (destinationText.isEmpty && _destination == null) {
        throw Exception('Digite um destino ou marque um ponto no mapa.');
      }
      final destination = _destination;
      if (destination == null) {
        throw Exception('Selecione um endereço na busca ou no mapa.');
      }
      final calculatedRoute = await _routeService.calculateRoute(
        origin: origin,
        destination: destination.location,
        profile: _selectedTransport.routingMode,
      );
      final departureAt = DateTime.now();
      final plan = RouteForecastPlan.create(calculatedRoute, departureAt);
      final route = plan.route;
      if (!mounted) return;
      setState(() {
        _destination = destination;
        _route = route;
        _departureAt = departureAt;
        _climatePoints = const [];
        _isNavigating = false;
        _currentRouteIndex = 0;
      });
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitRoute(route);
      });
      // Salva primeiro: a previsao do clima e complementar e nao pode impedir
      // que a rota apareca no historico.
      await _saveRouteHistory(route, destination);

      try {
        final climatePoints = await _loadRouteClimate(plan)
            .timeout(const Duration(seconds: 20));
        if (mounted) setState(() => _climatePoints = climatePoints);
      } catch (_) {
        if (mounted) {
          setState(() {
            _errorMessage = 'A rota foi encontrada, mas nao foi possivel consultar o clima do trajeto.';
          });
        }
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeTransport(TransportType transport) async {
    if (_selectedTransport == transport || _destinationBusy) return;
    setState(() => _selectedTransport = transport);
    if (_destination != null || _destinationController.text.trim().isNotEmpty) {
      await _buildRoute();
    }
  }

  Future<void> _saveRouteHistory(
    RouteResult route,
    RouteDestination destination,
  ) async {
    try {
      final climate = _climatePoints.isEmpty
          ? null
          : _climatePoints[_climatePoints.length > 1 ? 1 : 0];
      await RouteHistoryRepository.save(
        RouteHistoryEntry(
          destination: destination.name,
          transport: _selectedTransport.label,
          distanceMeters: route.distanceMeters,
          durationSeconds: route.durationSeconds,
          createdAt: DateTime.now(),
          latitude: destination.location.latitude,
          longitude: destination.location.longitude,
          rainChance: climate?.weather.rainChance,
        ),
      );
    } catch (_) {
      // Uma falha no cache local nao impede a rota de funcionar.
    }
  }

  void _fitRoute(RouteResult route) {
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: route.points,
        padding: const EdgeInsets.all(64),
        maxZoom: 15,
      ),
    );
  }

  Future<List<RouteClimatePoint>> _loadRouteClimate(
    RouteForecastPlan plan,
  ) async {
    final samples = plan.samples;
    final weather = await Future.wait(
      samples.map(
        (sample) =>
            WeatherService.fetchForecastAt(sample.location, sample.arrivalAt),
      ),
    );
    return [
      for (var index = 0; index < samples.length; index++)
        RouteClimatePoint(
          routeIndex: samples[index].routeIndex,
          arrivalAt: samples[index].arrivalAt,
          weather: weather[index],
        ),
    ];
  }

  String _messageFor(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('TimeoutException')) {
      return 'O servico demorou para responder. Verifique sua internet e tente novamente.';
    }
    return message.isEmpty
        ? 'Nao foi possivel montar a rota. Verifique a internet, o GPS e as chaves das APIs.'
        : message;
  }

  Future<void> _toggleNavigation() async {
    final route = _route;
    if (route == null || _isStartingNavigation) return;
    FocusScope.of(context).unfocus();
    setState(() => _isStartingNavigation = true);
    try {
      final position =
          await (widget.locationProvider ?? LocationService.currentPosition)();
      if (!mounted) return;
      setState(() => _isNavigating = true);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RouteNavigationPage(
            route: route,
            destination: _destination,
            climatePoints: _climatePoints,
            filter: _selectedFilter,
            initialPosition: position,
          ),
        ),
      );
      if (mounted) setState(() => _isNavigating = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isNavigating = false;
          _errorMessage = _messageFor(error);
        });
      }
    } finally {
      if (mounted) setState(() => _isStartingNavigation = false);
    }
  }

  RouteClimatePoint? get _nextClimatePoint {
    for (final point in _climatePoints) {
      if (point.routeIndex >= _currentRouteIndex) return point;
    }
    return _climatePoints.isEmpty ? null : _climatePoints.last;
  }

  void _openFullMap() {
    if (_route == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RouteFullMapPage(
          origin: _origin,
          destination: _destination,
          route: _route!,
          climatePoints: _climatePoints,
          initialFilter: _selectedFilter,
        ),
      ),
    );
  }

  Future<void> _openForecastTimeline() async {
    final point = await Navigator.of(context).push<RouteClimatePoint>(
      MaterialPageRoute(
        builder: (_) => RouteForecastTimelinePage(
          points: _climatePoints,
          departureAt: _departureAt!,
        ),
      ),
    );
    if (point == null || !mounted || _route == null) return;
    if (_mapKey.currentContext == null && _pageScroll.hasClients) {
      await _pageScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    if (!mounted) return;
    final mapContext = _mapKey.currentContext;
    if (mapContext != null && mapContext.mounted) {
      await Scrollable.ensureVisible(
        mapContext,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }
    if (mounted) _mapController.move(_route!.points[point.routeIndex], 14);
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    return ListView(
      controller: _pageScroll,
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeader(
          title: 'Rota com clima',
          subtitle: 'Seu destino, com o clima de cada trecho',
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _destinationController,
          textInputAction: TextInputAction.search,
          readOnly: true,
          onTap: _destinationBusy ? null : _searchDestination,
          decoration: InputDecoration(
            hintText: 'Para onde voce vai?',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: _destinationBusy
                  ? null
                  : (_destination == null ? _searchDestination : _buildRoute),
              icon: _isChoosingDestination
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              tooltip: _isChoosingDestination
                  ? 'Aguarde a busca do destino'
                  : 'Definir rota',
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFE1EAEC)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.my_location, size: 17, color: Color(0xFF1B7F8C)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _isLocating
                    ? 'Buscando sua localizacao...'
                    : 'Saida: sua localizacao atual',
                style: const TextStyle(color: Color(0xFF5A6B70)),
              ),
            ),
            TextButton.icon(
              onPressed: _destinationBusy ? null : _pickDestinationOnMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Mapa'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TransportSelector(
          selected: _selectedTransport,
          onSelected: (transport) => _changeTransport(transport),
        ),
        const SizedBox(height: 12),
        if (route != null) ...[
          _RouteFilterSelector(
            selected: _selectedFilter,
            onSelected: (filter) => setState(() => _selectedFilter = filter),
          ),
          const SizedBox(height: 10),
          RouteWeatherLegend(filter: _selectedFilter),
        ],
        const SizedBox(height: 18),
        if (_errorMessage != null) ...[
          WeatherErrorCard(message: _errorMessage!),
          const SizedBox(height: 18),
        ],
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_selectedTransport.icon, color: const Color(0xFF1B7F8C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _destination?.name ??
                          'Vamos escolher seu próximo destino?',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                key: _mapKey,
                height: 300,
                child: _RouteMap(
                  mapController: _mapController,
                  origin: _origin,
                  destination: _destination,
                  route: route,
                  climatePoints: _climatePoints,
                  filter: _selectedFilter,
                  liveLocation: _liveLocation,
                  onDestinationTap: _destinationBusy
                      ? null
                      : (point) =>
                            _pickDestinationOnMap(initialDestination: point),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                route == null
                    ? 'Busque um endereço ou toque no mapa para marcar o destino.'
                    : '${_selectedFilter.title}: compare os valores nos pontos e as cores da legenda. Toque em um ponto para abrir os detalhes.',
                style: const TextStyle(color: Color(0xFF5A6B70)),
              ),
              if (route != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openFullMap,
                    icon: const Icon(Icons.open_in_full),
                    label: const Text('Abrir mapa'),
                  ),
                ),
            ],
          ),
        ),
        if (route != null && _departureAt != null) ...[
          const SizedBox(height: 16),
          RouteTripSummary(
            route: route,
            departureAt: _departureAt!,
            points: _climatePoints,
            isLoading: _isLoading,
            onForecast: _openForecastTimeline,
            onStart: _destinationBusy ? null : _toggleNavigation,
          ),
        ],
        if (_isNavigating) ...[
          const SizedBox(height: 16),
          _NavigationStatusCard(
            route: route!,
            currentRouteIndex: _currentRouteIndex,
            nextClimatePoint: _nextClimatePoint,
          ),
        ],
        if (_isLoading) ...[
          const SizedBox(height: 18),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.mapController,
    required this.origin,
    required this.destination,
    required this.route,
    required this.climatePoints,
    required this.filter,
    required this.liveLocation,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.onUserGesture,
    this.onDestinationTap,
  });
  final MapController mapController;
  final LatLng? origin;
  final RouteDestination? destination;
  final RouteResult? route;
  final List<RouteClimatePoint> climatePoints;
  final RouteWeatherFilter filter;
  final LatLng? liveLocation;
  final BorderRadius borderRadius;
  final VoidCallback? onUserGesture;
  final ValueChanged<LatLng>? onDestinationTap;

  @override
  Widget build(BuildContext context) {
    final points = route?.points ?? const <LatLng>[];
    final center = origin ?? const LatLng(-23.5505, -46.6333);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRect(
              key: const ValueKey('route-map-viewport'),
              clipBehavior: Clip.hardEdge,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13,
                  onTap: onDestinationTap == null
                      ? null
                      : (_, point) => onDestinationTap!(point),
                  onLongPress: onDestinationTap == null
                      ? null
                      : (_, point) => onDestinationTap!(point),
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture) onUserGesture?.call();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app_clima',
                  ),
                  if (points.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          color: Colors.white,
                          strokeWidth: 11,
                        ),
                        ..._routePolylines(points, climatePoints, filter),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (origin != null)
                        Marker(
                          point: origin!,
                          width: 42,
                          height: 42,
                          child: const Icon(
                            Icons.my_location,
                            color: Color(0xFF12343B),
                            size: 30,
                          ),
                        ),
                      if (destination != null)
                        Marker(
                          point: destination!.location,
                          width: 46,
                          height: 46,
                          child: const Icon(
                            Icons.location_pin,
                            color: Color(0xFFE05A47),
                            size: 42,
                          ),
                        ),
                      for (var index = 0; index < climatePoints.length; index++)
                        Marker(
                          point: points[climatePoints[index].routeIndex],
                          width: 14,
                          height: 14,
                          child: DecoratedBox(
                            key: ValueKey('route-forecast-anchor-$index'),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filter.colorFor(
                                climatePoints[index].weather,
                              ),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x55000000),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      for (var index = 0; index < climatePoints.length; index++)
                        Marker(
                          point: points[climatePoints[index].routeIndex],
                          width:
                              112 *
                              (MediaQuery.textScalerOf(context).scale(14) / 14)
                                  .clamp(1.0, double.infinity),
                          height: 54,
                          alignment: index.isEven
                              ? Alignment.topCenter
                              : Alignment.bottomCenter,
                          rotate: true,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: index.isEven ? 8 : 0,
                              top: index.isOdd ? 8 : 0,
                            ),
                            child: RouteWeatherMapIcon(
                              point: climatePoints[index],
                              filter: filter,
                            ),
                          ),
                        ),
                      if (liveLocation != null)
                        Marker(
                          point: liveLocation!,
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.navigation,
                            color: Color(0xFF1B7F8C),
                            size: 36,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Material(
            key: ValueKey('route-map-footer'),
            color: Colors.white,
            child: GeoapifyAttribution(compact: true),
          ),
        ],
      ),
    );
  }

  List<Polyline> _routePolylines(
    List<LatLng> points,
    List<RouteClimatePoint> climatePoints,
    RouteWeatherFilter filter,
  ) {
    if (climatePoints.length < 2) {
      return [
        Polyline(
          points: points,
          color: const Color(0xFF1B7F8C),
          strokeWidth: 6,
        ),
      ];
    }
    return [
      for (var index = 0; index < climatePoints.length - 1; index++)
        Polyline(
          points: points.sublist(
            climatePoints[index].routeIndex,
            climatePoints[index + 1].routeIndex + 1,
          ),
          color: _colorFor(climatePoints[index + 1].weather, filter),
          strokeWidth: 7,
        ),
    ];
  }

  Color _colorFor(WeatherData weather, RouteWeatherFilter filter) {
    return filter.colorFor(weather);
  }
}

class _NavigationStatusCard extends StatelessWidget {
  const _NavigationStatusCard({
    required this.route,
    required this.currentRouteIndex,
    required this.nextClimatePoint,
  });
  final RouteResult route;
  final int currentRouteIndex;
  final RouteClimatePoint? nextClimatePoint;

  @override
  Widget build(BuildContext context) {
    final progress = route.points.length <= 1
        ? 0.0
        : currentRouteIndex / (route.points.length - 1);
    final climate = nextClimatePoint;
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.navigation, color: Color(0xFF1B7F8C)),
              SizedBox(width: 8),
              Text(
                'Rota em andamento',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
          const SizedBox(height: 10),
          Text('${(progress * 100).round()}% do trajeto percorrido'),
          if (climate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Proximo trecho: ${climate.weather.rainChance}% de chuva, '
              '${climate.weather.precipitationMm.toStringAsFixed(1)} mm e '
              'sensacao de ${climate.weather.feelsLike.round()} C.',
              style: const TextStyle(color: Color(0xFF5A6B70)),
            ),
          ],
        ],
      ),
    );
  }
}

class RouteNavigationPage extends StatefulWidget {
  const RouteNavigationPage({
    required this.route,
    required this.destination,
    required this.climatePoints,
    required this.filter,
    required this.initialPosition,
    this.positionStream,
    this.forecastLoader,
    this.clock = DateTime.now,
    super.key,
  });
  final RouteResult route;
  final RouteDestination? destination;
  final List<RouteClimatePoint> climatePoints;
  final RouteWeatherFilter filter;
  final Position initialPosition;
  final Stream<Position>? positionStream;
  final Future<WeatherData> Function(LatLng, DateTime)? forecastLoader;
  final DateTime Function() clock;

  @override
  State<RouteNavigationPage> createState() => _RouteNavigationPageState();
}

class _RouteNavigationPageState extends State<RouteNavigationPage>
    with WidgetsBindingObserver {
  final _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  late RouteWeatherFilter _filter = widget.filter;
  late Position _position = widget.initialPosition;
  late final _progress = RouteProgress(widget.route);
  Timer? _clockTimer;
  var _isFollowingUser = false;
  var _detailsVisible = true;
  late List<RouteClimatePoint> _climatePoints = widget.climatePoints;
  Timer? _weatherTimer;
  DateTime? _lastWeatherAttempt;
  DateTime? _weatherUpdatedAt;
  bool _refreshingWeather = false;
  bool _weatherActive = true;
  String? _weatherError;
  String? _trackingError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progress.update(
      LatLng(_position.latitude, _position.longitude),
      _position.timestamp,
      accuracy: _position.accuracy,
    );
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _weatherActive) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshWeather();
      _showRouteOverview();
      _positionSubscription =
          (widget.positionStream ??
                  Geolocator.getPositionStream(
                    locationSettings: const LocationSettings(
                      accuracy: LocationAccuracy.high,
                    ),
                  ))
              .listen(
                _followPosition,
                onError: (Object error) {
                  if (mounted) {
                    setState(
                      () => _trackingError = 'Não foi possível atualizar o GPS. Confira a permissão de localização.',
                    );
                  }
                },
              );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _weatherTimer?.cancel();
    _clockTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  int _weatherSlot(DateTime time) => time.millisecondsSinceEpoch ~/ 900000;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _weatherActive = state == AppLifecycleState.resumed;
    _weatherTimer?.cancel();
    if (!_weatherActive) return;
    final previous = _lastWeatherAttempt;
    if (previous == null ||
        _weatherSlot(previous) != _weatherSlot(widget.clock())) {
      _refreshWeather();
    } else {
      _scheduleWeatherRefresh();
    }
  }

  void _scheduleWeatherRefresh() {
    _weatherTimer?.cancel();
    if (!mounted || !_weatherActive) return;
    final now = widget.clock();
    final next = DateTime.fromMillisecondsSinceEpoch(
      (_weatherSlot(now) + 1) * 900000,
    );
    _weatherTimer = Timer(next.difference(now), _refreshWeather);
  }

  Future<void> _refreshWeather() async {
    if (!mounted || !_weatherActive || _refreshingWeather) return;
    _refreshingWeather = true;
    final now = widget.clock();
    _lastWeatherAttempt = now;
    final points = widget.route.points;
    final indices = _climatePoints.isEmpty
        ? {for (var i = 0; i < 4; i++) ((points.length - 1) * i / 3).round()}
        : _climatePoints.map((point) => point.routeIndex).toSet();
    try {
      final refreshed = await Future.wait([
        for (final index in indices)
          if (_progress.distances[index] >= _progress.traveledMeters)
            () async {
              final arrival = _progress.arrivalAt(index, now);
              final weather =
                  await (widget.forecastLoader ??
                      WeatherService.fetchForecastAt)(points[index], arrival);
              return RouteClimatePoint(
                routeIndex: index,
                arrivalAt: arrival,
                weather: weather,
              );
            }(),
      ]);
      if (!mounted) return;
      setState(() {
        _climatePoints = [
          ..._climatePoints.where(
            (old) =>
                !refreshed.any((point) => point.routeIndex == old.routeIndex),
          ),
          ...refreshed,
        ]..sort((a, b) => a.routeIndex.compareTo(b.routeIndex));
        _weatherUpdatedAt = now;
        _weatherError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _weatherError = 'Não foi possível atualizar o clima. Os últimos dados foram mantidos.',
        );
      }
    } finally {
      _refreshingWeather = false;
      _scheduleWeatherRefresh();
    }
  }

  void _followPosition(Position position) {
    if (!mounted) return;
    final location = LatLng(position.latitude, position.longitude);
    setState(() {
      _position = position;
      _trackingError = null;
      _progress.update(
        location,
        position.timestamp,
        accuracy: position.accuracy,
      );
    });
    final heading = position.heading.isFinite && position.heading >= 0
        ? -position.heading
        : 0.0;
    // Deixa a posicao abaixo do centro para priorizar a via a frente,
    // como em aplicativos de navegacao.
    if (_isFollowingUser) _centerOnUser(location, heading, false);
  }

  void _centerOnUser([
    LatLng? location,
    double? heading,
    bool enableFollowing = true,
  ]) {
    if (enableFollowing && mounted) setState(() => _isFollowingUser = true);
    final userLocation =
        location ?? LatLng(_position.latitude, _position.longitude);
    final userHeading =
        heading ??
        (_position.heading.isFinite && _position.heading >= 0
            ? -_position.heading
            : 0.0);
    _mapController.rotate(userHeading);
    _mapController.move(userLocation, 15, offset: const Offset(0, 60));
  }

  void _showRouteOverview() {
    if (!mounted) return;
    setState(() => _isFollowingUser = false);
    _mapController.rotate(0);
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: widget.route.points,
        padding: const EdgeInsets.fromLTRB(60, 70, 60, 60),
        maxZoom: 15,
      ),
    );
  }

  List<RouteClimatePoint> get _estimatedClimatePoints {
    final now = widget.clock();
    return [
      for (final point in _climatePoints)
        RouteClimatePoint(
          routeIndex: point.routeIndex,
          arrivalAt:
              _progress.distances[point.routeIndex] >= _progress.traveledMeters
              ? _progress.arrivalAt(point.routeIndex, now)
              : point.arrivalAt,
          weather: point.weather,
        ),
    ];
  }

  RouteClimatePoint? get _nextClimatePoint {
    for (final climatePoint in _estimatedClimatePoints) {
      if (_progress.distances[climatePoint.routeIndex] >=
          _progress.traveledMeters) {
        return climatePoint;
      }
    }
    return _climatePoints.isEmpty ? null : _climatePoints.last;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress.fraction;
    final nextClimate = _nextClimatePoint;
    final remainingMinutes =
        (_progress.timeTo(_progress.totalMeters).inMilliseconds / 60000).ceil();
    final destinationName = widget.destination?.name ?? 'Destino';
    return Scaffold(
      bottomNavigationBar: _detailsVisible
          ? Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                top: false,
                maintainBottomViewPadding: true,
                minimum: const EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: _navigationBottomPanel(progress, nextClimate),
                  ),
                ),
              ),
            )
          : null,
      body: SafeArea(
        bottom: !_detailsVisible,
        child: Column(
          children: [
            if (_detailsVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: _navigationHeader(destinationName, remainingMinutes),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _RouteMap(
                      mapController: _mapController,
                      origin: widget.route.points.first,
                      destination: widget.destination,
                      route: widget.route,
                      climatePoints: _estimatedClimatePoints,
                      filter: _filter,
                      liveLocation: LatLng(
                        _position.latitude,
                        _position.longitude,
                      ),
                      borderRadius: BorderRadius.zero,
                      onUserGesture: () {
                        if (mounted) setState(() => _isFollowingUser = false);
                      },
                    ),
                  ),
                  if (_detailsVisible)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            '${_climatePoints.length} previsões no trajeto',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'toggle_navigation_details',
                      tooltip: _detailsVisible
                          ? 'Ocultar detalhes'
                          : 'Mostrar detalhes',
                      backgroundColor: Colors.white,
                      onPressed: () =>
                          setState(() => _detailsVisible = !_detailsVisible),
                      child: Icon(
                        _detailsVisible
                            ? Icons.fullscreen
                            : Icons.fullscreen_exit,
                      ),
                    ),
                  ),
                  if (!_detailsVisible)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'close_navigation',
                        tooltip: 'Encerrar rota',
                        backgroundColor: Colors.white,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.close),
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 66,
                    child: FloatingActionButton.small(
                      heroTag: 'overview_navigation',
                      tooltip: 'Ver trajeto completo',
                      backgroundColor: Colors.white,
                      onPressed: _showRouteOverview,
                      child: const Icon(Icons.zoom_out_map),
                    ),
                  ),
                  Positioned(right: 12, bottom: 12, child: _recenterButton()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigationHeader(String destinationName, int remainingMinutes) =>
      Material(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.navigation, color: Color(0xFF1B7F8C)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destinationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _progress.offRoute
                          ? 'Fora do trajeto · estimativa mantida'
                          : _progress.isPaused(widget.clock())
                          ? 'Parado · chegada ajustada ao retomar'
                          : 'Chegada em cerca de $remainingMinutes min',
                      style: const TextStyle(color: Color(0xFF5A6B70)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Encerrar rota',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      );

  Widget _recenterButton() => FloatingActionButton.small(
    heroTag: 'recenter_navigation',
    tooltip: 'Acompanhar minha localização',
    backgroundColor: _isFollowingUser ? const Color(0xFFD8EFEF) : Colors.white,
    foregroundColor: const Color(0xFF1B7F8C),
    onPressed: _centerOnUser,
    child: const Icon(Icons.my_location),
  );

  Widget _navigationBottomPanel(
    double progress,
    RouteClimatePoint? nextClimate,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Material(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _RouteFilterSelector(
            selected: _filter,
            onSelected: (filter) => setState(() => _filter = filter),
          ),
        ),
      ),
      const SizedBox(height: 10),
      RouteWeatherLegend(filter: _filter),
      const SizedBox(height: 10),
      InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${(progress * 100).round()}% do trajeto percorrido',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${(_progress.fraction * widget.route.distanceMeters / 1000).toStringAsFixed(1)} de ${(widget.route.distanceMeters / 1000).toStringAsFixed(1)} km · ${_progress.usesObservedPace ? 'ritmo do GPS' : 'estimativa inicial da rota'}',
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            if (_weatherUpdatedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Clima consultado às ${routeClock(_weatherUpdatedAt!)} · atualização a cada 15 min',
              ),
            ],
            if (_weatherError != null) ...[
              const SizedBox(height: 8),
              Text(_weatherError!),
            ],
            if (_trackingError != null) ...[
              const SizedBox(height: 8),
              Text(
                _trackingError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (nextClimate != null) ...[
              const SizedBox(height: 10),
              Text(
                'Próximo trecho · ${routeClock(nextClimate.arrivalAt)}\n${nextClimate.weather.locationName}\n${_filter.title}: ${_filter.valueLabel(nextClimate.weather)}\n${_filter.detailLabel(nextClimate.weather)}',
                style: const TextStyle(color: Color(0xFF5A6B70)),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _RouteFilterSelector extends StatelessWidget {
  const _RouteFilterSelector({
    required this.selected,
    required this.onSelected,
  });
  final RouteWeatherFilter selected;
  final ValueChanged<RouteWeatherFilter> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: RouteWeatherFilter.values.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final filter = RouteWeatherFilter.values[index];
        return ChoiceChip(
          selected: filter == selected,
          avatar: Icon(filter.icon, size: 17, color: filter.color),
          label: Text(filter.label),
          onSelected: (_) => onSelected(filter),
        );
      },
    ),
  );
}

class _RouteFullMapPage extends StatefulWidget {
  const _RouteFullMapPage({
    required this.origin,
    required this.destination,
    required this.route,
    required this.climatePoints,
    required this.initialFilter,
  });
  final LatLng? origin;
  final RouteDestination? destination;
  final RouteResult route;
  final List<RouteClimatePoint> climatePoints;
  final RouteWeatherFilter initialFilter;

  @override
  State<_RouteFullMapPage> createState() => _RouteFullMapPageState();
}

class _RouteFullMapPageState extends State<_RouteFullMapPage> {
  final _mapController = MapController();
  late RouteWeatherFilter _filter = widget.initialFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: widget.route.points,
          padding: const EdgeInsets.all(64),
          maxZoom: 15,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rota com clima')),
    body: _RouteMap(
      mapController: _mapController,
      origin: widget.origin,
      destination: widget.destination,
      route: widget.route,
      climatePoints: widget.climatePoints,
      filter: _filter,
      liveLocation: null,
    ),
    bottomNavigationBar: Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        minimum: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RouteFilterSelector(
              selected: _filter,
              onSelected: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: 10),
            RouteWeatherLegend(filter: _filter),
          ],
        ),
      ),
    ),
  );
}

class TransportSelector extends StatelessWidget {
  const TransportSelector({
    required this.selected,
    required this.onSelected,
    super.key,
  });
  final TransportType selected;
  final ValueChanged<TransportType> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: TransportType.values.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final transport = TransportType.values[index];
        return ChoiceChip(
          selected: transport == selected,
          avatar: Icon(transport.icon, size: 18),
          label: Text(transport.label),
          onSelected: (_) => onSelected(transport),
        );
      },
    ),
  );
}

enum TransportType {
  walking('Caminhada', 'walk', Icons.directions_walk),
  bike('Bicicleta', 'bicycle', Icons.directions_bike),
  motorcycle('Moto', 'motorcycle', Icons.two_wheeler),
  car('Carro', 'drive', Icons.directions_car);

  const TransportType(this.label, this.routingMode, this.icon);
  final String label;
  final String routingMode;
  final IconData icon;
}
