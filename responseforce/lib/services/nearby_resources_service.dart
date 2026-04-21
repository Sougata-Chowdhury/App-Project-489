import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/nearby_resource.dart';

class NearbyResourcesService {
  NearbyResourcesService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Distance _distance = const Distance();
  final Map<String, _CacheEntry> _cache = {};

  Future<List<NearbyResource>> fetchNearbyResources({
    required double latitude,
    required double longitude,
    required NearbyCategory category,
    int radiusMeters = 3000,
  }) async {
    final cacheKey = _key(latitude, longitude, category, radiusMeters);
    final now = DateTime.now();
    final cached = _cache[cacheKey];
    if (cached != null && now.difference(cached.cachedAt).inSeconds < 120) {
      return cached.items;
    }

    final query =
        '''
[out:json][timeout:12];
(
  node["amenity"="${category.amenityTag}"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="${category.amenityTag}"](around:$radiusMeters,$latitude,$longitude);
  relation["amenity"="${category.amenityTag}"](around:$radiusMeters,$latitude,$longitude);
);
out center 60;
''';

    final response = await _client
        .post(
          Uri.parse('https://overpass-api.de/api/interpreter'),
          headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'data=${Uri.encodeQueryComponent(query)}',
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('Nearby search failed (${response.statusCode}).');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = (payload['elements'] as List?) ?? const [];

    final resources = elements
        .whereType<Map>()
        .map(
          (e) => NearbyResource.fromOverpassElement(
            raw: e.cast<String, dynamic>(),
            category: category,
            fromLatitude: latitude,
            fromLongitude: longitude,
            distance: _distance,
          ),
        )
        .whereType<NearbyResource>()
        .toList();

    final deduped = <String, NearbyResource>{};
    for (final r in resources) {
      final k =
          '${r.name.toLowerCase()}|${r.latitude.toStringAsFixed(5)}|${r.longitude.toStringAsFixed(5)}';
      deduped[k] = r;
    }

    final sorted = deduped.values.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    _cache[cacheKey] = _CacheEntry(cachedAt: now, items: sorted);
    return sorted;
  }

  String _key(
    double lat,
    double lng,
    NearbyCategory category,
    int radiusMeters,
  ) {
    return '${lat.toStringAsFixed(3)}:${lng.toStringAsFixed(3)}:${category.name}:$radiusMeters';
  }
}

class _CacheEntry {
  const _CacheEntry({required this.cachedAt, required this.items});

  final DateTime cachedAt;
  final List<NearbyResource> items;
}
