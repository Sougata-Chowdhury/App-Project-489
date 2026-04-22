import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class RemoteReminderPermissionStatus {
  const RemoteReminderPermissionStatus({
    required this.notificationsEnabled,
    required this.token,
  });

  final bool notificationsEnabled;
  final String? token;

  bool get notificationAllowed => notificationsEnabled;
  bool get canReceivePush => notificationsEnabled && token != null;
}

class RemoteReminderService {
  RemoteReminderService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _messaging.setAutoInitEnabled(true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await requestPermissions();

    _messaging.onTokenRefresh.listen((token) async {
      await _upsertDeviceToken(token);
    });

    _isInitialized = true;
  }

  Future<RemoteReminderPermissionStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    final token = await _messaging.getToken();
    final enabled =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    return RemoteReminderPermissionStatus(
      notificationsEnabled: enabled,
      token: token,
    );
  }

  Future<RemoteReminderPermissionStatus> requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return getPermissionStatus();
  }

  Future<RemoteReminderPermissionStatus> ensureNotificationPermission() async {
    final current = await getPermissionStatus();
    if (current.notificationAllowed) return current;

    final requested = await requestPermissions();
    if (requested.notificationAllowed) return requested;

    throw StateError(
      'Enable Notification permission to receive reminder push notifications.',
    );
  }

  Future<void> registerCurrentDeviceToken() async {
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('Could not fetch device push token.');
    }
    await _upsertDeviceToken(token);
  }

  Future<void> syncMedicationRoutineSchedule({
    required String routineId,
    required String medicineName,
    String? dosage,
    required List<String> reminderTimes,
    required bool isActive,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in is required to schedule remote reminders.');
    }

    final permission = await ensureNotificationPermission();
    final token = permission.token;
    if (token == null || token.isEmpty) {
      throw StateError('Push token unavailable. Try again.');
    }

    await _upsertDeviceToken(token);

    final existing = await _db
        .collection('users')
        .doc(user.uid)
        .collection('remote_medication_reminders')
        .where('routineId', isEqualTo: routineId)
        .get();

    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    if (isActive) {
      final now = FieldValue.serverTimestamp();
      for (final time in reminderTimes) {
        final ref = _db
            .collection('users')
            .doc(user.uid)
            .collection('remote_medication_reminders')
            .doc();
        batch.set(ref, {
          'uid': user.uid,
          'routineId': routineId,
          'medicineName': medicineName.trim(),
          'dosage': dosage?.trim(),
          'timeLabel': time,
          'repeat': 'daily',
          'channel': 'fcm_primary',
          'fallbackChannel': 'local_notification',
          'status': 'scheduled',
          'targetToken': token,
          'createdAt': now,
          'updatedAt': now,
        });
      }
    }

    await batch.commit();
  }

  Future<void> removeMedicationRoutineSchedule(String routineId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final existing = await _db
        .collection('users')
        .doc(user.uid)
        .collection('remote_medication_reminders')
        .where('routineId', isEqualTo: routineId)
        .get();

    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> _upsertDeviceToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = FieldValue.serverTimestamp();
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('device_tokens')
        .doc(token)
        .set({
          'token': token,
          'platform': 'android',
          'updatedAt': now,
          'createdAt': now,
        }, SetOptions(merge: true));

    await _db.collection('elder_profiles').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': now,
    }, SetOptions(merge: true));
  }
}
