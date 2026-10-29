import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/route_service.dart';
import '../domain/route_result.dart';
import 'geoapify_attribution.dart';
import 'route_destination_picker_page.dart';

class RouteSearchPage extends StatefulWidget {
  const RouteSearchPage({this.origin, this.service, super.key});

  final LatLng? origin;
  final RouteService? service;

  @override
  State<RouteSearchPage> createState() => _RouteSearchPageState();
}

class _RouteSearchPageState extends State<RouteSearchPage> {
  late final _service = widget.service ?? RouteService();
  final _controller = TextEditingController();
  Timer? _debounce;
  int _request = 0;
  bool _loading = false;
  bool _selecting = false;
  String? _activeSearch;
  String? _message;
  List<RouteDestination> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    if (widget.service == null) _service.close();
    super.dispose();
  }

  void _changed(String text) {
    _debounce?.cancel();
    final request = ++_request;
    setState(() {
      _results = const [];
      _message = null;
      _loading = text.trim().length >= 3;
    });
    if (!_loading) return;
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search(text, request);
    });
  }

  Future<void> _search(
    String text,
    int request, {
    bool autocomplete = true,
  }) async {
    if (_selecting) return;
    _activeSearch = text.trim();
    try {
      final results = await _service.searchDestinations(
        text,
        widget.origin,
        autocomplete: autocomplete,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _results = results;
        _message = results.isEmpty
            ? 'Nenhum endereço encontrado. Confira o CEP completo ou inclua rua e cidade.'
            : null;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(
        () => _message = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
        _activeSearch = null;
      }
    }
  }

  void _submit() {
    if (_selecting || (_loading && _activeSearch == _controller.text.trim())) {
      return;
    }
    _debounce?.cancel();
    if (_controller.text.trim().length < 3) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _message = null;
      _results = const [];
    });
    _search(_controller.text, request, autocomplete: false);
  }

  Future<void> _selectResult(RouteDestination result) async {
    if (_selecting) return;
    setState(() => _selecting = true);
    _debounce?.cancel();
    ++_request;
    var leavingPage = false;
    try {
      if (!result.requiresMapConfirmation) {
        leavingPage = true;
        Navigator.of(context).pop(result);
        return;
      }
      FocusScope.of(context).unfocus();
      final location = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(
          builder: (_) => RouteDestinationPickerPage(
            userLocation: widget.origin,
            initialDestination: result.location,
            destinationLabel: result.name,
            requiresPreciseSelection: result.requiresPreciseMapSelection,
          ),
        ),
      );
      if (!mounted || location == null) return;
      leavingPage = true;
      Navigator.of(context).pop(
        RouteDestination(
          name: result.name,
          location: location,
          isMapSelection: true,
        ),
      );
    } finally {
      if (mounted && !leavingPage) setState(() => _selecting = false);
    }
  }

  Future<void> _pickOnMap() async {
    if (_selecting) return;
    _debounce?.cancel();
    ++_request;
    FocusScope.of(context).unfocus();
    setState(() {
      _selecting = true;
      _loading = false;
    });
    try {
      final location = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(
          builder: (_) =>
              RouteDestinationPickerPage(userLocation: widget.origin),
        ),
      );
      if (!mounted || location == null) return;
      Navigator.of(context).pop(
        RouteDestination(
          name: 'Ponto selecionado no mapa',
          location: location,
          isMapSelection: true,
        ),
      );
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Buscar destino')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            enabled: !_selecting,
            autofocus: true,
            onChanged: _changed,
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Lugar, endereço ou CEP',
              hintText: 'Ex.: Avenida Paulista ou 01310-100',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Buscar endereço',
                onPressed: _loading || _selecting ? null : _submit,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _selecting ? null : _pickOnMap,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Escolher destino no mapa'),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_message != null) Text(_message!),
          if (!_loading && _message == null && _results.isEmpty)
            const Text(
              'Busque por nome, endereço ou CEP completo (com ou sem hífen).',
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(result.name),
                  subtitle: result.requiresMapConfirmation
                      ? const Text(
                          'CEP encontrado. Confira a localização no mapa.',
                        )
                      : null,
                  onTap: _selecting ? null : () => _selectResult(result),
                );
              },
            ),
          ),
          const GeoapifyAttribution(),
        ],
      ),
    ),
  );
}
