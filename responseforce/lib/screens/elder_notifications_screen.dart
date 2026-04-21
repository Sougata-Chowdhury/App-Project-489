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
  String? _filter; // pending | in_progress

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
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    _FilterChip(
                      label: 'Pending',
                      selected: _filter == 'pending',
                      onTap: () => setState(() => _filter = 'pending'),
                    ),
                    _FilterChip(
                      label: 'In Progress',
                      selected: _filter == 'in_progress',
                      onTap: () => setState(() => _filter = 'in_progress'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _RequestsTab(service: service, statusFilter: _filter),
                  _SosTab(service: service, statusFilter: _filter),
                  _UpdatesTab(service: service),
                ],
              ),
            ),
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
          ..removeWhere(
            (d) => (d.data()['status'] ?? '').toString() == 'resolved',
          )
          ..sort((a, b) {
            final at = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bt = (b.data()['createdAt'] as Timestamp?)?.toDate();
            return (bt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              at ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
          });
        if (docs.isEmpty) {
          return const _ListStateMessage('No assistance requests yet.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final status = (data['status'] ?? 'pending').toString();
            final type = friendlyRequestType((data['type'] ?? '').toString());
            final summary = (data['summary'] ?? '').toString().trim();
            final urgency = _urgencyLabel((data['urgency'] ?? '').toString());
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            return _NotificationCard(
              icon: Icons.volunteer_activism_outlined,
              title: type,
              status: status,
              subtitle:
                  '${createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt) : '—'}'
                  '${summary.isNotEmpty ? '\n$urgency • $summary' : ''}',
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
          ..removeWhere(
            (d) => (d.data()['status'] ?? '').toString() == 'resolved',
          )
          ..sort((a, b) {
            final at = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bt = (b.data()['createdAt'] as Timestamp?)?.toDate();
            return (bt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              at ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
          });
        if (docs.isEmpty) {
          return const _ListStateMessage('No SOS alerts yet.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final status = (data['status'] ?? 'pending').toString();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final hasLoc =
                data['latitude'] != null && data['longitude'] != null;

            return _NotificationCard(
              icon: Icons.sos_outlined,
              title: hasLoc ? 'SOS alert (location attached)' : 'SOS alert',
              status: status,
              subtitle: createdAt != null
                  ? DateFormat.yMMMd().add_jm().format(createdAt)
                  : '—',
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
          return const _ListStateMessage('No updates yet.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: shown.length,
          itemBuilder: (context, i) {
            final data = shown[i].data();
            final title = (data['title'] ?? 'Update').toString();
            final body = (data['body'] ?? '').toString();
            final ts = (data['createdAt'] as Timestamp?)?.toDate();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _ListStateMessage extends StatelessWidget {
  const _ListStateMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String status;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatusChip(status: status),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'in_progress' => Colors.orange.shade700,
      'resolved' => Colors.green.shade700,
      _ => Colors.blueGrey.shade700,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
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
