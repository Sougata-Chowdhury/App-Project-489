import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'screens/web_firebase_notice_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // We haven't configured Firebase Web options yet, so avoid a crash/blank screen.
    runApp(const MaterialApp(home: WebFirebaseNoticeScreen()));
    return;
  }

  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..load()),
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
      ],
      child: const App(),
    ),
  );
}
