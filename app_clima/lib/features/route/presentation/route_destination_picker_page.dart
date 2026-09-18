import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RouteDestinationPickerPage extends StatefulWidget {
  const RouteDestinationPickerPage({required this.userLocation, super.key});
  final LatLng userLocation;

  @override
  State<RouteDestinationPickerPage> createState() =>
      _RouteDestinationPickerPageState();
}

class _RouteDestinationPickerPageState extends State<RouteDestinationPickerPage> {
  LatLng? _selectedLocation;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: widget.userLocation,
                initialZoom: 14,
                onTap: (_, point) => setState(() => _selectedLocation = point),
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
                      width: 42,
                      height: 42,
                      child: const Icon(
                        Icons.my_location,
                        color: Color(0xFF12343B),
                        size: 30,
                      ),
                    ),
                    if (_selectedLocation != null)
                      Marker(
                        point: _selectedLocation!,
                        width: 46,
                        height: 46,
                        child: const Icon(
                          Icons.location_pin,
                          color: Color(0xFFE05A47),
                          size: 42,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SafeArea(
              minimum: const EdgeInsets.all(14),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Voltar',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const Text(
                              'Marque seu destino',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _selectedLocation == null
                            ? null
                            : () => Navigator.of(context).pop(_selectedLocation),
                        icon: const Icon(Icons.check),
                        label: Text(
                          _selectedLocation == null
                              ? 'Toque no mapa para marcar o destino'
                              : 'Usar este ponto como destino',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
