import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/primary_button.dart';
import 'profile_screen.dart';
import 'request_status_screen.dart';

class ElderHomeScreen extends StatelessWidget {
  const ElderHomeScreen({super.key});

  Future<void> _createRequest(BuildContext context, String type) async {
    final ref = await context.read<FirestoreService>().createAssistanceRequest(type);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestStatusScreen(
          title: 'Request Sent',
          subtitle: 'Your $type request has been sent.',
          requestRef: ref,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final isTablet = maxW >= 700;

        final sosSize = math.min(isTablet ? 320.0 : 260.0, maxW * 0.7);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Elder Home'),
            actions: [
              IconButton(
                tooltip: 'Profile',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                icon: const Icon(Icons.person),
              ),
              IconButton(
                tooltip: 'Logout',
                onPressed: () => context.read<AuthService>().signOut(),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isTablet ? 700 : 520),
                  child: Column(
                    children: [
                      SizedBox(
                        height: math.min(maxH * 0.45, sosSize + 20),
                        child: Center(
                          child: SizedBox(
                            width: sosSize,
                            height: sosSize,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(),
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Send emergency alert?'),
                                    content: const Text(
                                      'This will notify the Admin. (SOS location capture will be added next.)',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        child: const Text('Confirm SOS Alert'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Text(
                                'SOS',
                                style: TextStyle(
                                  fontSize: isTablet ? 56 : 48,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Medicine Help',
                              onPressed: () => _createRequest(context, 'medicine'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Grocery Help',
                              onPressed: () => _createRequest(context, 'grocery'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'General Assistance',
                        onPressed: () => _createRequest(context, 'general'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
