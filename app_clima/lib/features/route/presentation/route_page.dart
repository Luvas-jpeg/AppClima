import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../weather/data/weather_service.dart';
import '../../weather/domain/weather_data.dart';
import '../data/route_service.dart';
import '../domain/route_result.dart';
import 'route_destination_picker_page.dart';

class RoutePage extends StatefulWidget {
  const RoutePage({super.key});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  final _destinationController = TextEditingController();
  final _mapController = MapController();
  TransportType _selectedTransport = TransportType.walking;
  RouteWeatherFilter _selectedFilter = RouteWeatherFilter.rain;
  LatLng? _origin;
  RouteDestination? _destination;
  RouteResult? _route;
  List<_RouteClimatePoint> _climatePoints = const [];
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _liveLocation;
  int _currentRouteIndex = 0;
  bool _isNavigating = false;
  bool _isLoading = false;
  bool _isLocating = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentLocation());
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final position = await LocationService.currentPosition();
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

  Future<void> _pickDestinationOnMap() async {
    final origin = await _ensureOrigin();
    if (origin == null || !mounted) return;
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => RouteDestinationPickerPage(userLocation: origin),
      ),
    );
    if (selected == null || !mounted) return;

    setState(() {
      _destination = RouteDestination(
        name: 'Ponto selecionado no mapa',
        location: selected,
      );
      _destinationController.text =
          '${selected.latitude.toStringAsFixed(5)}, ${selected.longitude.toStringAsFixed(5)}';
      _route = null;
      _climatePoints = const [];
      _errorMessage = null;
    });
    _mapController.move(selected, 14);
  }

  Future<void> _buildRoute() async {
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
      final destination = destinationText.isNotEmpty &&
              (_destination == null || _destination!.name != 'Ponto selecionado no mapa')
          ? await RouteService.findDestination(destinationText, origin)
          : _destination!;
      final route = await RouteService.calculateRoute(
        origin: origin,
        destination: destination.location,
        profile: _selectedTransport.orsProfile,
      );
      if (!mounted) return;
      setState(() {
        _destination = destination;
        _route = route;
        _climatePoints = const [];
        _isNavigating = false;
        _currentRouteIndex = 0;
      });
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitRoute(route);
      });

      try {
        final climatePoints = await _loadRouteClimate(route).timeout(
          const Duration(seconds: 20),
        );
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

  void _fitRoute(RouteResult route) {
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: route.points,
        padding: const EdgeInsets.all(44),
        maxZoom: 15,
      ),
    );
  }

  Future<List<_RouteClimatePoint>> _loadRouteClimate(RouteResult route) async {
    const sampleCount = 5;
    final now = DateTime.now();
    final samples = <({int index, LatLng location, DateTime arrivalAt})>[];
    for (var sample = 0; sample < sampleCount; sample++) {
      final progress = sample / (sampleCount - 1);
      final index = ((route.points.length - 1) * progress).round();
      samples.add((
        index: index,
        location: route.points[index],
        arrivalAt: now.add(
          Duration(milliseconds: (route.durationSeconds * progress * 1000).round()),
        ),
      ));
    }
    final weather = await Future.wait(
      samples.map((sample) => WeatherService.fetchForecastAt(sample.location, sample.arrivalAt)),
    );
    return [
      for (var index = 0; index < samples.length; index++)
        _RouteClimatePoint(
          routeIndex: samples[index].index,
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
    if (route == null) return;
    try {
      final position = await LocationService.currentPosition();
      if (!mounted) return;
      setState(() => _isNavigating = true);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ActiveNavigationMapPage(
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
    }
  }

  void _updateLiveLocation(LatLng location) {
    final route = _route;
    if (route == null || !mounted) return;
    var closestIndex = 0;
    var closestDistance = double.infinity;
    const distance = Distance();
    for (var index = 0; index < route.points.length; index++) {
      final pointDistance = distance.as(
        LengthUnit.Meter,
        location,
        route.points[index],
      );
      if (pointDistance < closestDistance) {
        closestDistance = pointDistance;
        closestIndex = index;
      }
    }
    setState(() {
      _liveLocation = location;
      _currentRouteIndex = closestIndex;
    });
    _mapController.move(location, 16);
  }

  _RouteClimatePoint? get _nextClimatePoint {
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

  @override
  Widget build(BuildContext context) {
    final route = _route;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeader(
          title: 'Rota com clima',
          subtitle: 'Escolha o destino e veja a previsao pelo caminho',
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _destinationController,
          textInputAction: TextInputAction.search,
          onChanged: (_) {
            if (_destination?.name == 'Ponto selecionado no mapa') {
              setState(() => _destination = null);
            }
          },
          onSubmitted: (_) => _buildRoute(),
          decoration: InputDecoration(
            hintText: 'Para onde voce vai?',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: _isLoading ? null : _buildRoute,
              icon: const Icon(Icons.arrow_forward),
              tooltip: 'Calcular rota',
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
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
                _isLocating ? 'Buscando sua localizacao...' : 'Saida: sua localizacao atual',
                style: const TextStyle(color: Color(0xFF5A6B70)),
              ),
            ),
            TextButton.icon(
              onPressed: _isLocating || _isLoading ? null : _pickDestinationOnMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Mapa'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TransportSelector(
          selected: _selectedTransport,
          onSelected: (transport) => setState(() => _selectedTransport = transport),
        ),
        const SizedBox(height: 12),
        _RouteFilterSelector(
          selected: _selectedFilter,
          onSelected: (filter) => setState(() => _selectedFilter = filter),
        ),
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
                      _destination?.name ?? 'Sua rota aparecera aqui',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (route != null)
                    Text(_routeSummary(route), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: _RouteMap(
                  mapController: _mapController,
                  origin: _origin,
                  destination: _destination,
                  route: route,
                  climatePoints: _climatePoints,
                  filter: _selectedFilter,
                  liveLocation: _liveLocation,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                route == null
                    ? 'Use o botao Mapa para marcar um destino manualmente.'
                    : '${_selectedFilter.label}: cores mais fortes indicam valores maiores no horario de passagem.',
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
              if (route != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _toggleNavigation,
                    icon: Icon(_isNavigating ? Icons.stop_circle_outlined : Icons.navigation),
                    label: Text(_isNavigating ? 'Encerrar rota' : 'Iniciar rota'),
                  ),
                ),
            ],
          ),
        ),
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
        if (_climatePoints.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionTitle('Previsao no trajeto'),
          const SizedBox(height: 12),
          for (var index = 0; index < _climatePoints.length; index++)
            _RouteWeatherTile(
              stage: switch (index) {
                0 => 'Saida',
                4 => 'Chegada',
                _ => 'Trecho ${index + 1}',
              },
              climatePoint: _climatePoints[index],
            ),
        ],
      ],
    );
  }

  String _routeSummary(RouteResult route) {
    final distance = route.distanceMeters >= 1000
        ? '${(route.distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${route.distanceMeters.round()} m';
    return '$distance\n${(route.durationSeconds / 60).round()} min';
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
  });
  final MapController mapController;
  final LatLng? origin;
  final RouteDestination? destination;
  final RouteResult? route;
  final List<_RouteClimatePoint> climatePoints;
  final RouteWeatherFilter filter;
  final LatLng? liveLocation;
  final BorderRadius borderRadius;
  final VoidCallback? onUserGesture;

  @override
  Widget build(BuildContext context) {
    final points = route?.points ?? const <LatLng>[];
    final center = origin ?? const LatLng(-23.5505, -46.6333);
    return ClipRRect(
      borderRadius: borderRadius,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 13,
          onPositionChanged: (_, hasGesture) {
            if (hasGesture) onUserGesture?.call();
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app_clima',
          ),
          const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
          if (points.length > 1)
            PolylineLayer(polylines: _routePolylines(points, climatePoints, filter)),
          MarkerLayer(
            markers: [
              if (origin != null)
                Marker(point: origin!, width: 42, height: 42, child: const Icon(Icons.my_location, color: Color(0xFF12343B), size: 30)),
              if (destination != null)
                Marker(point: destination!.location, width: 46, height: 46, child: const Icon(Icons.location_pin, color: Color(0xFFE05A47), size: 42)),
              for (var index = 1; index < climatePoints.length - 1; index++)
                Marker(
                  point: points[climatePoints[index].routeIndex],
                  width: 62,
                  height: 42,
                  child: _WeatherMarker(climatePoint: climatePoints[index], filter: filter),
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
    );
  }

  List<Polyline> _routePolylines(
    List<LatLng> points,
    List<_RouteClimatePoint> climatePoints,
    RouteWeatherFilter filter,
  ) {
    if (climatePoints.length < 2) {
      return [Polyline(points: points, color: const Color(0xFF1B7F8C), strokeWidth: 6)];
    }
    return [
      for (var index = 0; index < climatePoints.length - 1; index++)
        Polyline(
          points: points.sublist(climatePoints[index].routeIndex, climatePoints[index + 1].routeIndex + 1),
          color: _colorFor(climatePoints[index + 1].weather, filter),
          strokeWidth: 7,
        ),
    ];
  }

  Color _colorFor(WeatherData weather, RouteWeatherFilter filter) {
    final intensity = filter.intensity(weather);
    return Color.lerp(filter.color.withValues(alpha: 0.45), filter.color, intensity)!;
  }
}

class _WeatherMarker extends StatelessWidget {
  const _WeatherMarker({required this.climatePoint, required this.filter});
  final _RouteClimatePoint climatePoint;
  final RouteWeatherFilter filter;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filter.color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              filter.valueLabel(climatePoint.weather),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
            ),
            if (filter.detailLabel(climatePoint.weather) != null)
              Text(
                filter.detailLabel(climatePoint.weather)!,
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
          ],
        ),
      );
}

class _RouteWeatherTile extends StatelessWidget {
  const _RouteWeatherTile({required this.stage, required this.climatePoint});
  final String stage;
  final _RouteClimatePoint climatePoint;

  @override
  Widget build(BuildContext context) {
    final weather = climatePoint.weather;
    final time = '${climatePoint.arrivalAt.hour.toString().padLeft(2, '0')}:${climatePoint.arrivalAt.minute.toString().padLeft(2, '0')}';
    return AlertTile(
      icon: weather.rainChance >= 40 ? Icons.water_drop : Icons.cloud,
      title: '$stage · chegada prevista ${time}',
      description: '${weather.condition}. Chuva: ${weather.rainChance}% (${weather.precipitationMm.toStringAsFixed(1)} mm). Temperatura: ${weather.temperature.round()} C; sensacao: ${weather.feelsLike.round()} C.',
    );
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
  final _RouteClimatePoint? nextClimatePoint;

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
              Text('Rota em andamento', style: TextStyle(fontWeight: FontWeight.w800)),
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

class _ActiveNavigationMapPage extends StatefulWidget {
  const _ActiveNavigationMapPage({
    required this.route,
    required this.destination,
    required this.climatePoints,
    required this.filter,
    required this.initialPosition,
  });
  final RouteResult route;
  final RouteDestination? destination;
  final List<_RouteClimatePoint> climatePoints;
  final RouteWeatherFilter filter;
  final Position initialPosition;

  @override
  State<_ActiveNavigationMapPage> createState() => _ActiveNavigationMapPageState();
}

class _ActiveNavigationMapPageState extends State<_ActiveNavigationMapPage> {
  final _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  late RouteWeatherFilter _filter = widget.filter;
  late Position _position = widget.initialPosition;
  late int _currentRouteIndex = _closestRouteIndex(widget.initialPosition);
  var _isFollowingUser = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followPosition(widget.initialPosition);
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).listen(_followPosition);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _followPosition(Position position) {
    if (!mounted) return;
    final location = LatLng(position.latitude, position.longitude);
    setState(() {
      _position = position;
      _currentRouteIndex = _closestRouteIndex(position);
    });
    final heading = position.heading.isFinite && position.heading >= 0
        ? -position.heading
        : 0.0;
    // Deixa a posicao abaixo do centro para priorizar a via a frente,
    // como em aplicativos de navegacao.
    if (_isFollowingUser) _centerOnUser(location, heading, false);
  }

  void _centerOnUser([LatLng? location, double? heading, bool enableFollowing = true]) {
    if (enableFollowing && mounted) setState(() => _isFollowingUser = true);
    final userLocation = location ?? LatLng(_position.latitude, _position.longitude);
    final userHeading = heading ??
        (_position.heading.isFinite && _position.heading >= 0 ? -_position.heading : 0.0);
    _mapController.move(userLocation, 16, offset: const Offset(0, 130));
    _mapController.rotate(userHeading);
  }

  int _closestRouteIndex(Position position) {
    final location = LatLng(position.latitude, position.longitude);
    const distance = Distance();
    var closestIndex = 0;
    var closestDistance = double.infinity;
    for (var index = 0; index < widget.route.points.length; index++) {
      final value = distance.as(LengthUnit.Meter, location, widget.route.points[index]);
      if (value < closestDistance) {
        closestDistance = value;
        closestIndex = index;
      }
    }
    return closestIndex;
  }

  _RouteClimatePoint? get _nextClimatePoint {
    for (final climatePoint in widget.climatePoints) {
      if (climatePoint.routeIndex >= _currentRouteIndex) return climatePoint;
    }
    return widget.climatePoints.isEmpty ? null : widget.climatePoints.last;
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.route.points.length <= 1
        ? 0.0
        : _currentRouteIndex / (widget.route.points.length - 1);
    final nextClimate = _nextClimatePoint;
    final remainingSeconds = (widget.route.durationSeconds * (1 - progress)).clamp(0.0, double.infinity);
    final remainingMinutes = (remainingSeconds / 60).ceil();
    final destinationName = widget.destination?.name ?? 'Destino';
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _RouteMap(
              mapController: _mapController,
              origin: null,
              destination: widget.destination,
              route: widget.route,
              climatePoints: widget.climatePoints,
              filter: _filter,
              liveLocation: LatLng(_position.latitude, _position.longitude),
              borderRadius: BorderRadius.zero,
              onUserGesture: () => _isFollowingUser = false,
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Stack(
              children: [
            Align(
              alignment: Alignment.topCenter,
              child: _navigationHeader(destinationName, remainingMinutes),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 186),
                child: _recenterButton(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _navigationBottomPanel(progress, nextClimate),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigationHeader(String destinationName, int remainingMinutes) => Material(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.navigation, color: Color(0xFF1B7F8C)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(destinationName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), Text('Chegada em cerca de $remainingMinutes min', style: const TextStyle(color: Color(0xFF5A6B70)))])),
              IconButton(tooltip: 'Encerrar rota', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
            ],
          ),
        ),
      );

  Widget _recenterButton() => FloatingActionButton.small(heroTag: 'recenter_navigation', tooltip: 'Centralizar minha posicao', backgroundColor: Colors.white, foregroundColor: const Color(0xFF1B7F8C), onPressed: _centerOnUser, child: const Icon(Icons.my_location));

  Widget _navigationBottomPanel(double progress, _RouteClimatePoint? nextClimate) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(color: Colors.white.withValues(alpha: 0.96), borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(8), child: _RouteFilterSelector(selected: _filter, onSelected: (filter) => setState(() => _filter = filter)))),
          const SizedBox(height: 8),
          InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${(progress * 100).round()}% do trajeto percorrido', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), LinearProgressIndicator(value: progress.clamp(0.0, 1.0)), if (nextClimate != null) ...[const SizedBox(height: 10), Text('Proximo trecho: ${nextClimate.weather.rainChance}% de chuva, ${nextClimate.weather.precipitationMm.toStringAsFixed(1)} mm e sensacao de ${nextClimate.weather.feelsLike.round()} C.', style: const TextStyle(color: Color(0xFF5A6B70)))] ])),
        ],
      );
}

class _RouteClimatePoint {
  const _RouteClimatePoint({
    required this.routeIndex,
    required this.arrivalAt,
    required this.weather,
  });
  final int routeIndex;
  final DateTime arrivalAt;
  final WeatherData weather;
}

class _RouteFilterSelector extends StatelessWidget {
  const _RouteFilterSelector({required this.selected, required this.onSelected});
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
  final List<_RouteClimatePoint> climatePoints;
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
          padding: const EdgeInsets.all(40),
          maxZoom: 15,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Rota com clima')),
        body: Stack(
          children: [
            _RouteMap(
              mapController: _mapController,
              origin: widget.origin,
              destination: widget.destination,
              route: widget.route,
              climatePoints: widget.climatePoints,
              filter: _filter,
              liveLocation: null,
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: Material(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _RouteFilterSelector(
                    selected: _filter,
                    onSelected: (filter) => setState(() => _filter = filter),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class TransportSelector extends StatelessWidget {
  const TransportSelector({required this.selected, required this.onSelected, super.key});
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
  walking('Caminhada', 'foot-walking', Icons.directions_walk),
  bike('Bicicleta', 'cycling-regular', Icons.directions_bike),
  motorcycle('Moto', 'driving-car', Icons.two_wheeler),
  car('Carro', 'driving-car', Icons.directions_car);

  const TransportType(this.label, this.orsProfile, this.icon);
  final String label;
  final String orsProfile;
  final IconData icon;
}

enum RouteWeatherFilter {
  rain('Chuva', Icons.water_drop, Color(0xFF2F80ED)),
  wind('Vento', Icons.air, Color(0xFF6C63FF)),
  temperature('Temp.', Icons.device_thermostat, Color(0xFFE05A47)),
  uv('UV', Icons.wb_sunny, Color(0xFFE39D17));

  const RouteWeatherFilter(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  double intensity(WeatherData weather) => switch (this) {
        RouteWeatherFilter.rain => weather.rainChance / 100,
        RouteWeatherFilter.wind => (weather.windKph / 45).clamp(0.15, 1.0).toDouble(),
        RouteWeatherFilter.temperature =>
          (weather.temperature / 40).clamp(0.15, 1.0).toDouble(),
        RouteWeatherFilter.uv => (weather.uv / 11).clamp(0.15, 1.0).toDouble(),
      };

  String valueLabel(WeatherData weather) => switch (this) {
        RouteWeatherFilter.rain => '${weather.rainChance}%',
        RouteWeatherFilter.wind => '${weather.windKph.round()} km/h',
        RouteWeatherFilter.temperature => '${weather.temperature.round()} C',
        RouteWeatherFilter.uv => 'UV ${weather.uv.toStringAsFixed(1)}',
      };

  String? detailLabel(WeatherData weather) => switch (this) {
        RouteWeatherFilter.rain => '${weather.precipitationMm.toStringAsFixed(1)} mm',
        RouteWeatherFilter.temperature => 'S ${weather.feelsLike.round()} C',
        RouteWeatherFilter.wind || RouteWeatherFilter.uv => null,
      };
}
