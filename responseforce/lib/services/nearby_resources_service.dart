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
  static const List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

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

    final resources = await _fetchWithFallback(
      latitude: latitude,
      longitude: longitude,
      category: category,
      radiusMeters: radiusMeters,
    );

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

  Future<List<NearbyResource>> _fetchWithFallback({
    required double latitude,
    required double longitude,
    required NearbyCategory category,
    required int radiusMeters,
  }) async {
    final radiuses = {radiusMeters, 6000, 10000}.toList()..sort();
    Object? lastError;

    for (final radius in radiuses) {
      final query = _buildQuery(
        latitude: latitude,
        longitude: longitude,
        category: category,
        radiusMeters: radius,
      );

      for (final endpoint in _overpassEndpoints) {
        try {
          final response = await _client
              .post(
                Uri.parse(endpoint),
                headers: const {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'Accept': 'application/json',
                  'User-Agent': 'ResponseForce/1.0 (NearbyResources)',
                },
                body: 'data=${Uri.encodeQueryComponent(query)}',
              )
              .timeout(const Duration(seconds: 25));

          if (response.statusCode != 200) {
            lastError = Exception(
              'Nearby search failed (${response.statusCode}) on $endpoint',
            );
            continue;
          }

          final payload = jsonDecode(response.body) as Map<String, dynamic>;
          final elements = (payload['elements'] as List?) ?? const [];
          final items = elements
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

          if (items.isNotEmpty) return items;
        } catch (e) {
          lastError = e;
        }
      }
    }

    if (lastError != null) {
      throw Exception('Nearby search unavailable right now. $lastError');
    }
    return const [];
  }

  String _buildQuery({
    required double latitude,
    required double longitude,
    required NearbyCategory category,
    required int radiusMeters,
  }) {
    final filters = category.overpassFilters;
    final buffer = StringBuffer('[out:json][timeout:25];\n(\n');
    for (final filter in filters) {
      buffer.writeln(
        '  node$filter(around:$radiusMeters,$latitude,$longitude);',
      );
      buffer.writeln(
        '  way$filter(around:$radiusMeters,$latitude,$longitude);',
      );
      buffer.writeln(
        '  relation$filter(around:$radiusMeters,$latitude,$longitude);',
      );
    }
    buffer.write(');\nout center 100;');
    return buffer.toString();
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
