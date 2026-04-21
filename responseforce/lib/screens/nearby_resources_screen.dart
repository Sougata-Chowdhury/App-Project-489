import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/nearby_resource.dart';
import '../widgets/primary_button.dart';
import 'location_picker_screen.dart';
import 'nearby_resources_results_screen.dart';

class NearbyResourcesScreen extends StatefulWidget {
  const NearbyResourcesScreen({super.key});

  @override
  State<NearbyResourcesScreen> createState() => _NearbyResourcesScreenState();
}

class _NearbyResourcesScreenState extends State<NearbyResourcesScreen> {
  NearbyCategory _selected = NearbyCategory.hospital;
  bool _capturing = false;
  double? _lat;
  double? _lng;
  String? _error;

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _capturing = true;
      _error = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _error = 'Location services are disabled.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission is required.');
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        setState(() => _error = 'Could not capture your location.');
        return;
      }
      final lat = pos.latitude;
      final lng = pos.longitude;
      setState(() {
        _lat = lat;
        _lng = lng;
      });
    } catch (_) {
      setState(() => _error = 'Could not capture your location.');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: 'Pick Nearby Search Location',
          initialLatitude: _lat,
          initialLongitude: _lng,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _lat = picked.latitude;
      _lng = picked.longitude;
      _error = null;
    });
  }

  void _openResults() {
    if (_lat == null || _lng == null) {
      setState(() => _error = 'Set your location first to find nearby places.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NearbyResourcesResultsScreen(
          initialCategory: _selected,
          latitude: _lat!,
          longitude: _lng!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationText = _lat != null && _lng != null
        ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
        : _capturing
        ? 'Capturing location...'
        : 'Location not set';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Resources')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(
                        Icons.near_me_outlined,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Find nearby hospitals, pharmacies, and police stations with one tap.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Category',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: NearbyCategory.values
                            .map(
                              (c) => ChoiceChip(
                                selected: _selected == c,
                                label: Text(c.label),
                                onSelected: (_) =>
                                    setState(() => _selected = c),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Search Location',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(locationText),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _capturing ? null : _captureLocation,
                            icon: const Icon(Icons.my_location_outlined),
                            label: const Text('Retry GPS'),
                          ),
                          TextButton.icon(
                            onPressed: _capturing ? null : _pickOnMap,
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Pick on Map'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'View Nearby',
                isBusy: _capturing,
                onPressed: _capturing ? null : _openResults,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
