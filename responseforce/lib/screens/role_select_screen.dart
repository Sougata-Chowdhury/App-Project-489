import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/primary_button.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.health_and_safety, size: 54, color: Colors.red),
              const SizedBox(height: 10),
              Text(
                'Healing Hands\nResponse Force',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Continue as Elder',
                onPressed: () => appState.setRole(AppRole.elder),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Continue as Admin',
                onPressed: () => appState.setRole(AppRole.admin),
              ),
              const SizedBox(height: 16),
              Text(
                'Please select your role to continue.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
