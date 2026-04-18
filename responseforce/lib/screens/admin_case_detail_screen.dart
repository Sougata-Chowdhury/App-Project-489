import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firestore_service.dart';
import '../utils/request_type_mapper.dart';

class AdminCaseDetailScreen extends StatelessWidget {
  const AdminCaseDetailScreen({
    super.key,
    required this.type,
    required this.docRef,
  });

  final CaseType type;
  final DocumentReference<Map<String, dynamic>> docRef;

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(type == CaseType.sos ? 'SOS Case' : 'Assistance Case'),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: docRef.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data();
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final status = (data['status'] ?? 'pending').toString();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final elderUid = (data['uid'] ?? '').toString();

            final elderName = (data['elderName'] ?? '').toString();
            final elderPhone = (data['elderPhone'] ?? '').toString();
            final elderBlood = (data['elderBloodGroup'] ?? '').toString();
            final elderMedical = (data['elderMedicalSummary'] ?? '').toString();
            final elderAge = (data['elderAge'] ?? '').toString();
            final elderEmergency = (data['elderEmergencyContact'] ?? '')
                .toString();

            final lat = (data['latitude'] as num?)?.toDouble();
            final lng = (data['longitude'] as num?)?.toDouble();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: ${status.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Created: ${createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt) : '—'}',
                        ),
                        if (type == CaseType.assistance) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Type: ${friendlyRequestType((data['type'] ?? '').toString())}',
                          ),
                        ],
                        if (type == CaseType.sos) ...[
                          const SizedBox(height: 6),
                          Text(
                            lat != null && lng != null
                                ? 'Location: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                                : 'Location: unavailable',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Elder Profile (Snapshot)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        _kv('Name', elderName.isEmpty ? '—' : elderName),
                        _kv(
                          'Age',
                          elderAge.isEmpty || elderAge == 'null'
                              ? '—'
                              : elderAge,
                        ),
                        _kv('Phone', elderPhone.isEmpty ? '—' : elderPhone),
                        _kv(
                          'Emergency Contact',
                          elderEmergency.isEmpty ? '—' : elderEmergency,
                        ),
                        _kv(
                          'Blood Group',
                          elderBlood.isEmpty ? '—' : elderBlood,
                        ),
                        _kv(
                          'Medical Summary',
                          elderMedical.isEmpty ? '—' : elderMedical,
                        ),
                        if (elderUid.isNotEmpty) _kv('UID', elderUid),
                      ],
                    ),
                  ),
                ),
                if (type == CaseType.sos && lat != null && lng != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openMaps(lat, lng),
                    icon: const Icon(Icons.map),
                    label: const Text('Open in Google Maps'),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Update Status',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusBtn(context, service, 'pending'),
                    _statusBtn(context, service, 'in_progress'),
                    _statusBtn(context, service, 'resolved'),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Status History',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: service.statusHistoryStream(
                    type: type,
                    targetId: docRef.id,
                  ),
                  builder: (context, histSnap) {
                    final hist = [...(histSnap.data?.docs ?? const [])]
                      ..sort((a, b) {
                        final at = (a.data()['updatedAt'] as Timestamp?)
                            ?.toDate();
                        final bt = (b.data()['updatedAt'] as Timestamp?)
                            ?.toDate();
                        return (bt ?? DateTime.fromMillisecondsSinceEpoch(0))
                            .compareTo(
                              at ?? DateTime.fromMillisecondsSinceEpoch(0),
                            );
                      });
                    if (hist.isEmpty) return const Text('No history yet.');
                    return Column(
                      children: hist.map((h) {
                        final hd = h.data();
                        final at = (hd['updatedAt'] as Timestamp?)?.toDate();
                        final oldS = (hd['oldStatus'] ?? '').toString();
                        final newS = (hd['newStatus'] ?? '').toString();
                        final by = (hd['updatedBy'] ?? '').toString();
                        final comment = (hd['comment'] ?? '').toString();
                        return Card(
                          child: ListTile(
                            title: Text(
                              '${oldS.toUpperCase()} → ${newS.toUpperCase()}',
                            ),
                            subtitle: Text(
                              '${at != null ? DateFormat.yMMMd().add_jm().format(at) : '—'}'
                              '${by.isNotEmpty ? ' • by $by' : ''}'
                              '${comment.trim().isNotEmpty ? '\n$comment' : ''}',
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusBtn(
    BuildContext context,
    FirestoreService service,
    String status,
  ) {
    return FilledButton(
      onPressed: () => _updateStatus(context, service, status),
      child: Text(_statusLabel(status)),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    FirestoreService service,
    String status,
  ) async {
    final comment = await _askComment(context);
    if (!context.mounted) return;

    try {
      if (type == CaseType.sos) {
        await service.updateSosStatus(
          alertId: docRef.id,
          newStatus: status,
          comment: comment,
        );
      } else {
        await service.updateAssistanceRequestStatus(
          requestId: docRef.id,
          newStatus: status,
          comment: comment,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated to ${_statusLabel(status)}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<String?> _askComment(BuildContext context) async {
    final c = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Optional comment'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'Add a note (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    return res;
  }

  Future<void> _openMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );
}

String _statusLabel(String status) {
  return switch (status) {
    'in_progress' => 'In Progress',
    'resolved' => 'Resolved',
    _ => 'Pending',
  };
}
