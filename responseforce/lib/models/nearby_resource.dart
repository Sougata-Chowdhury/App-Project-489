import 'package:latlong2/latlong.dart';

enum NearbyCategory { hospital, pharmacy, police }

extension NearbyCategoryX on NearbyCategory {
  String get label {
    return switch (this) {
      NearbyCategory.hospital => 'Hospital',
      NearbyCategory.pharmacy => 'Pharmacy',
      NearbyCategory.police => 'Police',
    };
  }

  String get amenityTag {
    return switch (this) {
      NearbyCategory.hospital => 'hospital',
      NearbyCategory.pharmacy => 'pharmacy',
      NearbyCategory.police => 'police',
    };
  }

  List<String> get overpassFilters {
    return switch (this) {
      NearbyCategory.hospital => const [
        '["amenity"="hospital"]',
        '["healthcare"="hospital"]',
        '["amenity"="clinic"]',
      ],
      NearbyCategory.pharmacy => const [
        '["amenity"="pharmacy"]',
        '["shop"="chemist"]',
      ],
      NearbyCategory.police => const ['["amenity"="police"]'],
    };
  }
}

class NearbyResource {
  NearbyResource({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.address,
    this.phone,
  });

  final String id;
  final String name;
  final NearbyCategory category;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String address;
  final String? phone;

  static NearbyResource? fromOverpassElement({
    required Map<String, dynamic> raw,
    required NearbyCategory category,
    required double fromLatitude,
    required double fromLongitude,
    required Distance distance,
  }) {
    final lat =
        (raw['lat'] as num?)?.toDouble() ??
        (raw['center'] as Map<String, dynamic>?)?['lat']?.toDouble();
    final lng =
        (raw['lon'] as num?)?.toDouble() ??
        (raw['center'] as Map<String, dynamic>?)?['lon']?.toDouble();

    if (lat == null || lng == null) return null;

    final tags = (raw['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final name = (tags['name'] ?? '').toString().trim();

    final meters = distance.as(
      LengthUnit.Meter,
      LatLng(fromLatitude, fromLongitude),
      LatLng(lat, lng),
    );

    final resolvedName = name.isEmpty ? category.label : name;
    final id = '${raw['type'] ?? 'node'}-${raw['id'] ?? '$lat,$lng'}';

    return NearbyResource(
      id: id,
      name: resolvedName,
      category: category,
      latitude: lat,
      longitude: lng,
      distanceKm: meters / 1000,
      address: _buildAddress(tags),
      phone: _phone(tags),
    );
  }

  static String _phone(Map<String, dynamic> tags) {
    final p = (tags['phone'] ?? tags['contact:phone'] ?? '').toString().trim();
    return p;
  }

  static String _buildAddress(Map<String, dynamic> tags) {
    final full = (tags['addr:full'] ?? '').toString().trim();
    if (full.isNotEmpty) return full;

    final parts = <String>[
      (tags['addr:housenumber'] ?? '').toString().trim(),
      (tags['addr:street'] ?? '').toString().trim(),
      (tags['addr:suburb'] ?? '').toString().trim(),
      (tags['addr:city'] ?? '').toString().trim(),
    ].where((e) => e.isNotEmpty).toList();

    if (parts.isEmpty) return 'Address unavailable';
    return parts.join(', ');
  }
}
