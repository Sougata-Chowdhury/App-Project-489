import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/primary_button.dart';
import 'elder_notifications_screen.dart';

class RequestStatusScreen extends StatelessWidget {
  const RequestStatusScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.requestRef,
    this.caseTypeLabel,
  });

  final String title;
  final String subtitle;
  final DocumentReference<Map<String, dynamic>> requestRef;
  final String? caseTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Status')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(subtitle),
              const SizedBox(height: 16),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: requestRef.snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final status = data?['status']?.toString() ?? 'pending';
                  final notes = data?['notes']?.toString();
                  final handledBy = data?['handledBy']?.toString();

                  final createdAt = (data?['createdAt'] as Timestamp?)
                      ?.toDate();
                  final updatedAt = (data?['updatedAt'] as Timestamp?)
                      ?.toDate();

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: ${status.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (caseTypeLabel != null)
                            Text('Case: $caseTypeLabel'),
                          if (createdAt != null)
                            Text(
                              'Created: ${DateFormat.yMMMd().add_jm().format(createdAt)}',
                            ),
                          if (updatedAt != null)
                            Text(
                              'Updated: ${DateFormat.yMMMd().add_jm().format(updatedAt)}',
                            ),
                          if (handledBy != null && handledBy.trim().isNotEmpty)
                            Text('Handled by: $handledBy'),
                          if (notes != null && notes.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Notes: $notes'),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ElderNotificationsScreen(),
                  ),
                ),
                child: const Text('View Notifications'),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Back to Home',
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
