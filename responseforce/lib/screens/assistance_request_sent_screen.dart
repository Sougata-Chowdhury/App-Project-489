import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/primary_button.dart';
import 'request_status_screen.dart';

class AssistanceRequestSentScreen extends StatelessWidget {
  const AssistanceRequestSentScreen({
    super.key,
    required this.requestRef,
    required this.requestTypeLabel,
  });

  final DocumentReference<Map<String, dynamic>> requestRef;
  final String requestTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistance Request')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Emergency Alert Sent!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        requestTypeLabel.isEmpty
                            ? 'Your request has been sent.'
                            : 'Your $requestTypeLabel request has been sent.',
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'OK',
                        onPressed: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RequestStatusScreen(
                              title: 'Request Sent',
                              subtitle: 'Track your request status below.',
                              requestRef: requestRef,
                              caseTypeLabel: 'ASSISTANCE',
                            ),
                          ),
                        ),
                        child: const Text('View Status'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
