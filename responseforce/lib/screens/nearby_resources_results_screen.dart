import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nearby_resource.dart';
import '../services/nearby_resources_service.dart';
import '../widgets/nearby_resource_card.dart';

class NearbyResourcesResultsScreen extends StatefulWidget {
  const NearbyResourcesResultsScreen({
    super.key,
    required this.initialCategory,
    required this.latitude,
    required this.longitude,
  });

  final NearbyCategory initialCategory;
  final double latitude;
  final double longitude;

  @override
  State<NearbyResourcesResultsScreen> createState() =>
      _NearbyResourcesResultsScreenState();
}

class _NearbyResourcesResultsScreenState
    extends State<NearbyResourcesResultsScreen> {
  final NearbyResourcesService _service = NearbyResourcesService();
  late NearbyCategory _category;
  late Future<List<NearbyResource>> _future;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _future = _load();
  }

  Future<List<NearbyResource>> _load() {
    return _service.fetchNearbyResources(
      latitude: widget.latitude,
      longitude: widget.longitude,
      category: _category,
    );
  }

  void _switchCategory(NearbyCategory next) {
    if (_category == next) return;
    setState(() {
      _category = next;
      _future = _load();
    });
  }

  Future<void> _openDirections(NearbyResource resource) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${resource.latitude},${resource.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callResource(NearbyResource resource) async {
    final phone = resource.phone?.trim() ?? '';
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Results')),
      body: SafeArea(
        child: FutureBuilder<List<NearbyResource>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not load nearby places. Please try again.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => setState(() => _future = _load()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final resources = snap.data ?? const [];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: NearbyCategory.values
                          .map(
                            (c) => ChoiceChip(
                              selected: _category == c,
                              label: Text(c.label),
                              onSelected: (_) => _switchCategory(c),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                SizedBox(
                  height: 260,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(widget.latitude, widget.longitude),
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.responseforce',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(widget.latitude, widget.longitude),
                            width: 38,
                            height: 38,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                          ...resources
                              .take(50)
                              .map(
                                (r) => Marker(
                                  point: LatLng(r.latitude, r.longitude),
                                  width: 38,
                                  height: 38,
                                  child: Icon(
                                    _iconFor(r.category),
                                    color: _colorFor(r.category),
                                    size: 30,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${resources.length} result${resources.length == 1 ? '' : 's'} found',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Expanded(
                  child: resources.isEmpty
                      ? const Center(
                          child: Text(
                            'No nearby resources found in this area.\nTry another category or location.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: resources.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final resource = resources[i];
                            return NearbyResourceCard(
                              resource: resource,
                              onDirections: () => _openDirections(resource),
                              onCall:
                                  (resource.phone?.trim().isNotEmpty ?? false)
                                  ? () => _callResource(resource)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

IconData _iconFor(NearbyCategory category) {
  return switch (category) {
    NearbyCategory.hospital => Icons.local_hospital,
    NearbyCategory.pharmacy => Icons.local_pharmacy,
    NearbyCategory.police => Icons.local_police,
  };
}

Color _colorFor(NearbyCategory category) {
  return switch (category) {
    NearbyCategory.hospital => Colors.red.shade700,
    NearbyCategory.pharmacy => Colors.green.shade700,
    NearbyCategory.police => Colors.indigo.shade700,
  };
}
