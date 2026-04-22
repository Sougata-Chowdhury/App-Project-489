import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InAppReminderWatcherService {
  InAppReminderWatcherService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Timer? _timer;
  String? _lastMinuteKey;
  final Set<String> _emittedMinuteKeys = <String>{};

  Future<void> start() async {
    if (_timer != null) return;
    await _tick();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      _tick();
    });
  }

  Future<void> _tick() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final minuteKey = _minuteKey(now);
    if (_lastMinuteKey == minuteKey) return;
    _lastMinuteKey = minuteKey;
    _emittedMinuteKeys.removeWhere((key) => !key.startsWith(minuteKey));

    final routines = await _db
        .collection('medication_routines')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .get();

    for (final routine in routines.docs) {
      final data = routine.data();
      final medicineName = (data['medicineName'] ?? '').toString().trim();
      final dosage = (data['dosage'] ?? '').toString().trim();
      final reminderTimes = ((data['reminderTimes'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();

      for (final timeLabel in reminderTimes) {
        final parsed = _parseTime(timeLabel);
        if (parsed == null) continue;
        if (parsed.$1 != now.hour || parsed.$2 != now.minute) continue;

        final emittedKey = '$minuteKey|${routine.id}|$timeLabel';
        if (_emittedMinuteKeys.contains(emittedKey)) continue;
        _emittedMinuteKeys.add(emittedKey);

        await _upsertReminderNotificationLog(
          uid: user.uid,
          routineId: routine.id,
          timeLabel: timeLabel,
          medicineName: medicineName,
          dosage: dosage,
          routinePath: routine.reference.path,
        );
      }
    }
  }

  Future<void> _upsertReminderNotificationLog({
    required String uid,
    required String routineId,
    required String timeLabel,
    required String medicineName,
    required String dosage,
    required String routinePath,
  }) async {
    final dateKey = _dateKey(DateTime.now());
    final cleanTime = timeLabel.replaceAll(':', '');
    final docId = 'medrem_${uid}_${routineId}_${dateKey}_$cleanTime';

    await _db.collection('notification_logs').doc(docId).set({
      'recipientUid': uid,
      'eventType': 'medication_due',
      'relatedRecordPath': routinePath,
      'title': 'Medication reminder',
      'body': dosage.isNotEmpty
          ? 'Time to take $medicineName ($dosage).'
          : 'Time to take $medicineName.',
      'deliveryStatus': 'in_app',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  (int, int)? _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour, minute);
  }

  String _dateKey(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
  }

  String _minuteKey(DateTime dt) {
    return '${_dateKey(dt)}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
  }
}
