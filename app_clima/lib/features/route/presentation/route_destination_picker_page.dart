import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RouteDestinationPickerPage extends StatefulWidget {
  const RouteDestinationPickerPage({
    this.userLocation,
    this.initialDestination,
    this.destinationLabel,
    this.requiresPreciseSelection = false,
    super.key,
  });
  final LatLng? userLocation;
  final LatLng? initialDestination;
  final String? destinationLabel;
  final bool requiresPreciseSelection;

  @override
  State<RouteDestinationPickerPage> createState() =>
      _RouteDestinationPickerPageState();
}

class _RouteDestinationPickerPageState
    extends State<RouteDestinationPickerPage> {
  LatLng? _selectedLocation;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    if (!widget.requiresPreciseSelection) {
      _selectedLocation = widget.initialDestination;
    }
  }

  void _confirm() {
    if (_confirming || _selectedLocation == null) return;
    setState(() => _confirming = true);
    Navigator.of(context).pop(_selectedLocation);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Confirmar destino')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.destinationLabel != null) ...[
                  Text(
                    widget.destinationLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.requiresPreciseSelection
                        ? 'O CEP foi encontrado, mas só foi possível localizar a região. Toque no mapa para marcar o destino exato.'
                        : 'Confira o ponto encontrado. Confirme esse destino ou toque no mapa para ajustar a posição.',
                  ),
                ] else
                  const Text('Toque no mapa para escolher o destino.'),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter:
                    widget.initialDestination ??
                    widget.userLocation ??
                    const LatLng(-23.5505, -46.6333),
                initialZoom: widget.requiresPreciseSelection ? 13 : 16,
                onTap: (_, point) => setState(() => _selectedLocation = point),
                onLongPress: (_, point) =>
                    setState(() => _selectedLocation = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app_clima',
                ),
                MarkerLayer(
                  markers: [
                    if (widget.userLocation != null)
                      Marker(
                        point: widget.userLocation!,
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
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selectedLocation == null || _confirming
                        ? null
                        : _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar destino'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '© OpenStreetMap contributors',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
