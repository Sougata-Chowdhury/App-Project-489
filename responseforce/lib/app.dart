import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/admin_dashboard_screen.dart';
import 'screens/elder_home_screen.dart';
import 'screens/elder_setup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/role_select_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Healing Hands Response Force',
      theme: AppTheme.build(),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: const TextScaler.linear(1.1)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _Bootstrap(),
    );
  }
}

class _Bootstrap extends StatelessWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AppState>().role;

    if (role == null) {
      return const RoleSelectScreen();
    }

    return StreamBuilder<User?>(
      stream: context.read<AuthService>().authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;
        if (user == null) {
          return LoginScreen(role: role);
        }

        return FutureBuilder<AppRole?>(
          future: context.read<AuthService>().getCurrentUserRole(user.uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final dbRole = roleSnap.data;
            if (dbRole != null && dbRole != role) {
              // Keep local selection in sync with Firestore-stored role.
              final appState = context.read<AppState>();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                appState.setRole(dbRole);
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final appState = context.watch<AppState>();

            if (role == AppRole.elder && !appState.elderSetupDone) {
              return const ElderSetupScreen();
            }

            return MultiProvider(
              providers: [
                Provider<FirestoreService>(create: (_) => FirestoreService()),
              ],
              child: role == AppRole.elder
                  ? const ElderHomeScreen()
                  : const AdminDashboardScreen(),
            );
          },
        );
      },
    );
  }
}
