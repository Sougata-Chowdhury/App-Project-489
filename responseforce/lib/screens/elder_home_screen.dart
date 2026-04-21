import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'elder_notifications_screen.dart';
import 'general_assistance_screen.dart';
import 'grocery_help_screen.dart';
import 'medication_reminder_screen.dart';
import 'medicine_help_screen.dart';
import 'nearby_resources_screen.dart';
import 'profile_screen.dart';
import 'sos_confirmation_screen.dart';

class ElderHomeScreen extends StatelessWidget {
  const ElderHomeScreen({super.key});

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
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ElderNotificationsScreen(),
                  ),
                ),
                icon: const Icon(Icons.notifications),
              ),
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
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SosConfirmationScreen(),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'SOS',
                                    style: TextStyle(
                                      fontSize: isTablet ? 56 : 48,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap for emergency',
                                    style: TextStyle(
                                      fontSize: isTablet ? 16 : 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Quick Assistance',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              _AssistanceActionTile(
                                title: 'Medicine Help',
                                subtitle:
                                    'Request medicine pickup or pharmacy support.',
                                icon: Icons.medication_outlined,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const MedicineHelpScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _AssistanceActionTile(
                                title: 'Grocery Help',
                                subtitle:
                                    'Send grocery list and delivery instructions.',
                                icon: Icons.local_grocery_store_outlined,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const GroceryHelpScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _AssistanceActionTile(
                                title: 'General Assistance',
                                subtitle: 'Describe any other help you need.',
                                icon: Icons.support_agent_outlined,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const GeneralAssistanceScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _AssistanceActionTile(
                            title: 'Medication & Reminders',
                            subtitle:
                                'Set routine reminders and log taken/missed doses.',
                            icon: Icons.alarm,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const MedicationReminderScreen(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _AssistanceActionTile(
                            title: 'Find Nearby',
                            subtitle:
                                'Hospitals, pharmacies and police near your location.',
                            icon: Icons.place_outlined,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NearbyResourcesScreen(),
                              ),
                            ),
                          ),
                        ),
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

class _AssistanceActionTile extends StatelessWidget {
  const _AssistanceActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.7),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
                  Text(subtitle),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
