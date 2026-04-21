import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/firestore_service.dart';
import '../utils/request_type_mapper.dart';
import 'request_status_screen.dart';

class ElderNotificationsScreen extends StatefulWidget {
  const ElderNotificationsScreen({super.key});

  @override
  State<ElderNotificationsScreen> createState() =>
      _ElderNotificationsScreenState();
}

class _ElderNotificationsScreenState extends State<ElderNotificationsScreen> {
  String? _filter; // pending | in_progress | resolved

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Requests'),
              Tab(text: 'SOS'),
              Tab(text: 'Updates'),
            ],
          ),
          actions: [
            PopupMenuButton<String?>(
              tooltip: 'Filter',
              initialValue: _filter,
              onSelected: (v) => setState(() => _filter = v),
              itemBuilder: (context) => const [
                PopupMenuItem(value: null, child: Text('All')),
                PopupMenuItem(value: 'pending', child: Text('Pending')),
                PopupMenuItem(value: 'in_progress', child: Text('In Progress')),
                PopupMenuItem(value: 'resolved', child: Text('Resolved')),
              ],
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _RequestsTab(service: service, statusFilter: _filter),
            _SosTab(service: service, statusFilter: _filter),
            _UpdatesTab(service: service),
          ],
        ),
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.service, required this.statusFilter});

  final FirestoreService service;
  final String? statusFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.elderAssistanceRequestsStream(status: statusFilter),
      builder: (context, snap) {
        final docs = [...(snap.data?.docs ?? const [])]
          ..sort((a, b) {
            final at = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bt = (b.data()['createdAt'] as Timestamp?)?.toDate();
            return (bt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              at ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
          });
        if (docs.isEmpty) {
          return const Center(child: Text('No assistance requests yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, i) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final status = (data['status'] ?? 'pending').toString();
            final type = friendlyRequestType((data['type'] ?? '').toString());
            final summary = (data['summary'] ?? '').toString().trim();
            final urgency = _urgencyLabel((data['urgency'] ?? '').toString());
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            return Card(
              child: ListTile(
                title: Text('Help: ${type.toUpperCase()}'),
                isThreeLine: summary.isNotEmpty,
                subtitle: Text(
                  '${_statusLabel(status)} • ${createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt) : '—'}'
                  '${summary.isNotEmpty ? '\n$urgency • $summary' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RequestStatusScreen(
                      title: 'Assistance request',
                      subtitle: 'Type: $type',
                      requestRef: d.reference,
                      caseTypeLabel: 'ASSISTANCE',
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SosTab extends StatelessWidget {
  const _SosTab({required this.service, required this.statusFilter});

  final FirestoreService service;
  final String? statusFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.elderSosAlertsStream(status: statusFilter),
      builder: (context, snap) {
        final docs = [...(snap.data?.docs ?? const [])]
          ..sort((a, b) {
            final at = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bt = (b.data()['createdAt'] as Timestamp?)?.toDate();
            return (bt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              at ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
          });
        if (docs.isEmpty) {
          return const Center(child: Text('No SOS alerts yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, i) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final status = (data['status'] ?? 'pending').toString();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final hasLoc =
                data['latitude'] != null && data['longitude'] != null;

            return Card(
              child: ListTile(
                title: const Text('SOS Alert'),
                subtitle: Text(
                  '${_statusLabel(status)} • ${hasLoc ? 'Location attached' : 'No location'}'
                  ' • ${createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt) : '—'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RequestStatusScreen(
                      title: 'SOS alert',
                      subtitle: 'Emergency case',
                      requestRef: d.reference,
                      caseTypeLabel: 'SOS',
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _UpdatesTab extends StatelessWidget {
  const _UpdatesTab({required this.service});

  final FirestoreService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.notificationLogsStream(),
      builder: (context, snap) {
        final docs = [...(snap.data?.docs ?? const [])]
          ..sort((a, b) {
            final at = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bt = (b.data()['createdAt'] as Timestamp?)?.toDate();
            return (bt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              at ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
          });

        final shown = docs.take(50).toList();
        if (shown.isEmpty) {
          return const Center(child: Text('No updates yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: shown.length,
          separatorBuilder: (_, i) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data = shown[i].data();
            final title = (data['title'] ?? 'Update').toString();
            final body = (data['body'] ?? '').toString();
            final ts = (data['createdAt'] as Timestamp?)?.toDate();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (ts != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.yMMMd().add_jm().format(ts),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(body),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'in_progress' => 'In Progress',
    'resolved' => 'Resolved',
    _ => 'Pending',
  };
}

String _urgencyLabel(String status) {
  return switch (status) {
    'low' => 'Low',
    'high' => 'High',
    'urgent' => 'Urgent',
    _ => 'Medium',
  };
}
