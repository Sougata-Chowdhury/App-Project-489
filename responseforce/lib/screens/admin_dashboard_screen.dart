import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/request_type_mapper.dart';
import 'admin_analytics_screen.dart';
import 'admin_case_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String? _filter; // pending | in_progress | resolved

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Control Center'),
          actions: [
            IconButton(
              tooltip: 'Logout',
              onPressed: () => context.read<AuthService>().signOut(),
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'SOS Alerts'),
              Tab(text: 'Assistance'),
              Tab(text: 'Analytics'),
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
                    _FilterChip(
                      label: 'Resolved',
                      selected: _filter == 'resolved',
                      onTap: () => setState(() => _filter = 'resolved'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _AdminSosTab(service: service, statusFilter: _filter),
                  _AdminAssistanceTab(service: service, statusFilter: _filter),
                  AdminAnalyticsScreen(service: service),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSosTab extends StatelessWidget {
  const _AdminSosTab({required this.service, required this.statusFilter});

  final FirestoreService service;
  final String? statusFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.adminSosAlertsStream(status: statusFilter),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _ListStateMessage('Could not load SOS alerts.');
        }
        final docs = [...(snap.data?.docs ?? const [])]
          ..sort((a, b) {
            final at = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bt = (b.data()['createdAt'] as Timestamp?)?.toDate();
            return (bt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              at ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
          });
        if (docs.isEmpty) {
          return const _ListStateMessage('No SOS alerts for this filter.');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final status = (data['status'] ?? 'pending').toString();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final name = (data['elderName'] ?? '').toString();
            final hasLoc =
                data['latitude'] != null && data['longitude'] != null;

            return _AdminCaseCard(
              icon: Icons.sos,
              iconColor: Colors.red.shade700,
              title: name.isEmpty ? 'SOS Alert' : 'SOS: $name',
              subtitle:
                  '${hasLoc ? 'Location available' : 'Location missing'}'
                  ' • ${createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt) : '—'}',
              status: status,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminCaseDetailScreen(
                    type: CaseType.sos,
                    docRef: d.reference,
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

class _AdminAssistanceTab extends StatelessWidget {
  const _AdminAssistanceTab({
    required this.service,
    required this.statusFilter,
  });

  final FirestoreService service;
  final String? statusFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.adminAssistanceRequestsStream(status: statusFilter),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _ListStateMessage('Could not load assistance requests.');
        }
        final docs = [...(snap.data?.docs ?? const [])]
          ..sort((a, b) {
            final at = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bt = (b.data()['createdAt'] as Timestamp?)?.toDate();
            return (bt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              at ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
          });
        if (docs.isEmpty) {
          return const _ListStateMessage(
            'No assistance requests for this filter.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final status = (data['status'] ?? 'pending').toString();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final name = (data['elderName'] ?? '').toString();
            final type = friendlyRequestType((data['type'] ?? '').toString());

            return _AdminCaseCard(
              icon: Icons.volunteer_activism,
              iconColor: Colors.indigo.shade700,
              title: name.isEmpty ? 'Request: $type' : '$name • $type',
              subtitle:
                  '$type • ${createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt) : '—'}',
              status: status,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminCaseDetailScreen(
                    type: CaseType.assistance,
                    docRef: d.reference,
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

String _statusLabel(String status) {
  return switch (status) {
    'in_progress' => 'In Progress',
    'resolved' => 'Resolved',
    _ => 'Pending',
  };
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
      selected: selected,
      label: Text(label),
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
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _AdminCaseCard extends StatelessWidget {
  const _AdminCaseCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.12),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StatusBadge(status: status),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'resolved' => Colors.green.shade700,
      'in_progress' => Colors.orange.shade700,
      _ => Colors.blueGrey.shade700,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
