import 'package:flutter/material.dart';

import '../models/nearby_resource.dart';

class NearbyResourceCard extends StatelessWidget {
  const NearbyResourceCard({
    super.key,
    required this.resource,
    required this.onDirections,
    required this.onCall,
  });

  final NearbyResource resource;
  final VoidCallback onDirections;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer.withValues(alpha: 0.7),
                  child: Icon(_iconFor(resource.category)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    resource.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(resource.category.label),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${resource.distanceKm.toStringAsFixed(2)} km away',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(resource.address),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.directions_outlined),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.call_outlined),
                    label: Text(onCall == null ? 'No phone' : 'Call'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(NearbyCategory category) {
  return switch (category) {
    NearbyCategory.hospital => Icons.local_hospital_outlined,
    NearbyCategory.pharmacy => Icons.local_pharmacy_outlined,
    NearbyCategory.police => Icons.local_police_outlined,
  };
}
