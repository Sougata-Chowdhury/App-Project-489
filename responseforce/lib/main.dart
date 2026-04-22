import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'screens/web_firebase_notice_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/in_app_reminder_watcher_service.dart';
import 'services/local_reminder_service.dart';
import 'services/remote_reminder_service.dart';
import 'state/app_state.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // We haven't configured Firebase Web options yet, so avoid a crash/blank screen.
    runApp(const MaterialApp(home: WebFirebaseNoticeScreen()));
    return;
  }

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final localReminderService = LocalReminderService();
  await localReminderService.initialize();
  final remoteReminderService = RemoteReminderService();
  await remoteReminderService.initialize();
  final inAppReminderWatcherService = InAppReminderWatcherService();
  await inAppReminderWatcherService.start();
  FirebaseMessaging.onMessage.listen((message) async {
    final title =
        message.notification?.title ??
        (message.data['title']?.toString() ?? '').trim();
    final body =
        message.notification?.body ??
        (message.data['body']?.toString() ?? '').trim();
    if (title.isEmpty && body.isEmpty) return;

    await localReminderService.showInstantNotification(
      title: title.isEmpty ? 'Medicine reminder' : title,
      body: body.isEmpty ? 'It is time to take your medicine.' : body,
      payload: message.data['payload']?.toString(),
    );
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..load()),
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
        Provider<LocalReminderService>.value(value: localReminderService),
        Provider<RemoteReminderService>.value(value: remoteReminderService),
        Provider<InAppReminderWatcherService>.value(
          value: inAppReminderWatcherService,
        ),
      ],
      child: const App(),
    ),
  );
}
