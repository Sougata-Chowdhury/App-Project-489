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
        if (docs.isEmpty) {
          return const Center(child: Text('No SOS alerts.'));
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
            final name = (data['elderName'] ?? '').toString();
            final hasLoc =
                data['latitude'] != null && data['longitude'] != null;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.sos, color: Colors.red),
                title: Text(name.isEmpty ? 'SOS Alert' : 'SOS: $name'),
                subtitle: Text(
                  '${_statusLabel(status)} • ${hasLoc ? 'Location' : 'No location'}'
                  ' • ${createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt) : '—'}',
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
        if (docs.isEmpty) {
          return const Center(child: Text('No assistance requests.'));
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
            final name = (data['elderName'] ?? '').toString();
            final type = friendlyRequestType((data['type'] ?? '').toString());

            return Card(
              child: ListTile(
                leading: const Icon(Icons.volunteer_activism),
                title: Text(name.isEmpty ? 'Request: $type' : '$name • $type'),
                subtitle: Text(
                  '${_statusLabel(status)}'
                  ' • ${createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt) : '—'}',
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

String _statusLabel(String status) {
  return switch (status) {
    'in_progress' => 'In Progress',
    'resolved' => 'Resolved',
    _ => 'Pending',
  };
}
