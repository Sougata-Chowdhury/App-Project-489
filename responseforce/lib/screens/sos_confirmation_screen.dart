import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/firestore_service.dart';
import '../widgets/primary_button.dart';
import 'location_picker_screen.dart';
import 'request_status_screen.dart';

class SosConfirmationScreen extends StatefulWidget {
  const SosConfirmationScreen({super.key});

  @override
  State<SosConfirmationScreen> createState() => _SosConfirmationScreenState();
}

class _SosConfirmationScreenState extends State<SosConfirmationScreen> {
  bool _busy = false;
  String? _error;
  bool _capturing = false;

  double? _lat;
  double? _lng;
  bool _locationAttempted = false;

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _capturing = true;
      _error = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _locationAttempted = true;
          _error =
              'Location services are disabled. SOS can still be sent without coordinates.';
        });
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _locationAttempted = true;
          _error =
              'Location permission not granted. SOS can still be sent without coordinates.';
        });
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      setState(() {
        _locationAttempted = true;
        _lat = pos?.latitude;
        _lng = pos?.longitude;
        if (_lat == null || _lng == null) {
          _error = 'Could not lock GPS quickly. You can retry or send SOS now.';
        }
      });
    } catch (e) {
      setState(() {
        _locationAttempted = true;
        _error = 'Unable to capture location. SOS can still be sent.';
      });
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  Future<void> _sendSos() async {
    if (_lat == null || _lng == null) {
      setState(() {
        _error = 'Location is required for SOS. Retry GPS or pick on map.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ref = await context.read<FirestoreService>().createSosAlert(
        latitude: _lat!,
        longitude: _lng!,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RequestStatusScreen(
            title: 'Emergency alert sent',
            subtitle:
                'An Admin has been notified. Please stay calm and keep your phone nearby.',
            requestRef: ref,
            caseTypeLabel: 'SOS',
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) =>
            LocationPickerScreen(initialLatitude: _lat, initialLongitude: _lng),
      ),
    );

    if (picked == null) return;
    setState(() {
      _lat = picked.latitude;
      _lng = picked.longitude;
      _locationAttempted = true;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationText = _lat != null && _lng != null
        ? 'Location snapshot: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
        : _capturing
        ? 'Capturing location…'
        : _locationAttempted
        ? 'Location snapshot: unavailable'
        : 'Location not captured yet';

    return Scaffold(
      appBar: AppBar(title: const Text('SOS Confirmation')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Send emergency alert now?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(locationText)),
                  TextButton.icon(
                    onPressed: _busy || _capturing ? null : _captureLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Retry'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : _pickOnMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Pick location on map'),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'This sends a one-time alert to Admin.\n\n'
                    'SOS requires a location snapshot. Use GPS retry or map picker.',
                  ),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: _capturing ? 'Getting location…' : 'Confirm SOS Alert',
                isBusy: _busy,
                onPressed: _busy ? null : _sendSos,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
