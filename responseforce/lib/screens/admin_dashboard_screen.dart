import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/request_type_mapper.dart';
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
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
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
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AdminSosTab(service: service, statusFilter: _filter),
            _AdminAssistanceTab(service: service, statusFilter: _filter),
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
        final docs = [...(snap.data?.docs ?? const [])]
          ..sort((a, b) {
            final at = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bt = (b.data()['createdAt'] as Timestamp?)?.toDate();
            return (bt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              at ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
          });
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.isEmpty ? 2 : docs.length + 1,
          separatorBuilder: (_, i) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _SectionSummaryCard(
                title: 'SOS Alerts',
                count: docs.length,
                filter: statusFilter,
                icon: Icons.sos,
                tint: Colors.red,
              );
            }
            if (docs.isEmpty && i == 1) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No SOS alerts for the selected filter.'),
                ),
              );
            }
            final d = docs[i - 1];
            final data = d.data();
            final status = (data['status'] ?? 'pending').toString();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final name = (data['elderName'] ?? '').toString();
            final hasLoc =
                data['latitude'] != null && data['longitude'] != null;

            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.red.withValues(alpha: 0.12),
                  child: const Icon(Icons.sos, color: Colors.red),
                ),
                title: Text(name.isEmpty ? 'SOS Alert' : 'SOS: $name'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(status: status),
                        _MetaPill(
                          icon: hasLoc ? Icons.place : Icons.location_off,
                          label: hasLoc ? 'Location' : 'No location',
                        ),
                        _MetaPill(
                          icon: Icons.schedule_outlined,
                          label: createdAt != null
                              ? DateFormat.yMMMd().add_jm().format(createdAt)
                              : '—',
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminCaseDetailScreen(
                      type: CaseType.sos,
                      docRef: d.reference,
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
        final docs = [...(snap.data?.docs ?? const [])]
          ..sort((a, b) {
            final at = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bt = (b.data()['createdAt'] as Timestamp?)?.toDate();
            return (bt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              at ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
          });
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.isEmpty ? 2 : docs.length + 1,
          separatorBuilder: (_, i) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _SectionSummaryCard(
                title: 'Assistance Requests',
                count: docs.length,
                filter: statusFilter,
                icon: Icons.volunteer_activism,
                tint: Colors.blue,
              );
            }
            if (docs.isEmpty && i == 1) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No assistance requests for the selected filter.',
                  ),
                ),
              );
            }
            final d = docs[i - 1];
            final data = d.data();
            final status = (data['status'] ?? 'pending').toString();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final name = (data['elderName'] ?? '').toString();
            final type = friendlyRequestType((data['type'] ?? '').toString());
            final summary = (data['summary'] ?? '').toString().trim();
            final urgency = _urgencyLabel((data['urgency'] ?? '').toString());

            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.12),
                  child: const Icon(Icons.volunteer_activism),
                ),
                title: Text(name.isEmpty ? 'Request: $type' : '$name • $type'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(status: status),
                        _MetaPill(icon: Icons.flag_outlined, label: urgency),
                        _MetaPill(
                          icon: Icons.schedule_outlined,
                          label: createdAt != null
                              ? DateFormat.yMMMd().add_jm().format(createdAt)
                              : '—',
                        ),
                      ],
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminCaseDetailScreen(
                      type: CaseType.assistance,
                      docRef: d.reference,
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

class _SectionSummaryCard extends StatelessWidget {
  const _SectionSummaryCard({
    required this.title,
    required this.count,
    required this.filter,
    required this.icon,
    required this.tint,
  });

  final String title;
  final int count;
  final String? filter;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: tint.withValues(alpha: 0.12),
              child: Icon(icon, color: tint),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text('$count total'),
                ],
              ),
            ),
            _MetaPill(
              icon: Icons.filter_alt_outlined,
              label: filter == null ? 'All' : _statusLabel(filter!),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'resolved' => Colors.green.shade700,
      'in_progress' => Colors.orange.shade700,
      _ => Colors.blueGrey.shade700,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(_statusLabel(status)),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      side: BorderSide(color: color.withValues(alpha: 0.22)),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
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

String _urgencyLabel(String raw) {
  return switch (raw) {
    'low' => 'Low',
    'high' => 'High',
    'urgent' => 'Urgent',
    _ => 'Medium',
  };
}
