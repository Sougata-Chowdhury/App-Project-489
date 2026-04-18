import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/primary_button.dart';

class ElderSetupScreen extends StatefulWidget {
  const ElderSetupScreen({super.key});

  @override
  State<ElderSetupScreen> createState() => _ElderSetupScreenState();
}

class _ElderSetupScreenState extends State<ElderSetupScreen> {
  bool _busy = false;
  String? _msg;
  String? _error;

  Future<void> _requestLocation() async {
    setState(() {
      _busy = true;
      _msg = null;
      _error = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(
          () => _error =
              'Location services are disabled. Please enable GPS and try again.',
        );
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied) {
        setState(
          () => _error =
              'Location permission denied. SOS can still work, but without coordinates.',
        );
        return;
      }

      if (perm == LocationPermission.deniedForever) {
        setState(
          () => _error =
              'Location permission permanently denied. Enable it in Settings to attach SOS location.',
        );
        return;
      }

      setState(() => _msg = 'Location permission granted.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    await context.read<AppState>().setElderSetupDone(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions & Setup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'To send SOS alerts, the app can attach a one-time GPS location snapshot.\n\n'
                'Notifications are shown in-app (push notifications can be added later).',
              ),
              const SizedBox(height: 16),
              if (_msg != null) ...[
                Text(_msg!, style: const TextStyle(color: Colors.green)),
                const SizedBox(height: 8),
              ],
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              PrimaryButton(
                label: 'Allow Location',
                isBusy: _busy,
                onPressed: _busy ? null : _requestLocation,
              ),
              const Spacer(),
              PrimaryButton(label: 'Continue', onPressed: _finish),
            ],
          ),
        ),
      ),
    );
  }
}
