import 'package:flutter/material.dart';

class WebFirebaseNoticeScreen extends StatelessWidget {
  const WebFirebaseNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'This app is configured for Android Firebase (google-services.json).\n\n'
              'You are running on Web (Chrome), but Firebase Web options are not configured yet.\n\n'
              'To fix: Add a Web app in Firebase Console, then generate lib/firebase_options.dart using FlutterFire CLI, '
              'and initialize Firebase with DefaultFirebaseOptions.currentPlatform.\n\n'
              'For now, run on an Android emulator/phone to use the app.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
