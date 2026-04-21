import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum CaseType { sos, assistance }

class AdminRiskUserInsight {
  const AdminRiskUserInsight({
    required this.uid,
    required this.elderName,
    required this.totalSos,
    required this.unresolvedSos,
    required this.lastIncidentAt,
    required this.riskScore,
  });

  final String uid;
  final String elderName;
  final int totalSos;
  final int unresolvedSos;
  final DateTime? lastIncidentAt;
  final int riskScore;
}

class AdminSosAnalytics {
  const AdminSosAnalytics({
    required this.weekTotal,
    required this.monthTotal,
    required this.resolvedCount,
    required this.pendingCount,
    required this.inProgressCount,
    required this.avgResponseMinutes,
    required this.repeatEmergencyUsers,
    required this.highRiskUsers,
  });

  final int weekTotal;
  final int monthTotal;
  final int resolvedCount;
  final int pendingCount;
  final int inProgressCount;
  final double? avgResponseMinutes;
  final int repeatEmergencyUsers;
  final List<AdminRiskUserInsight> highRiskUsers;
}

class FirestoreService {
  FirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get uid => _auth.currentUser!.uid;

  // ----------------------------
  // Elder profile
  // ----------------------------

  Stream<DocumentSnapshot<Map<String, dynamic>>> elderProfileStream({
    String? forUid,
  }) {
    return _db.collection('elder_profiles').doc(forUid ?? uid).snapshots();
  }

  Future<void> updateElderProfile({
    required String fullName,
    required String phoneNumber,
    required String age,
    required String bloodGroup,
    required String medicalSummary,
    required String emergencyContactNumber,
  }) async {
    final parsedAge = int.tryParse(age.trim());

    await _db.collection('elder_profiles').doc(uid).set({
      'uid': uid,
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'age': parsedAge,
      'bloodGroup': bloodGroup.trim().isEmpty ? null : bloodGroup.trim(),
      'medicalSummary': medicalSummary.trim().isEmpty
          ? null
          : medicalSummary.trim(),
      'emergencyContactNumber': emergencyContactNumber.trim().isEmpty
          ? null
          : emergencyContactNumber.trim(),
      'user_id': uid,
      'full_name': fullName.trim(),
      'age_int': parsedAge,
      'blood_group': bloodGroup.trim().isEmpty ? null : bloodGroup.trim(),
      'medical_conditions': medicalSummary.trim().isEmpty
          ? null
          : medicalSummary.trim(),
      'emergency_contact_number': emergencyContactNumber.trim().isEmpty
          ? null
          : emergencyContactNumber.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getElderProfileSnapshot(String forUid) async {
    final snap = await _db.collection('elder_profiles').doc(forUid).get();
    return snap.data();
  }

  // ----------------------------
  // Assistance requests
  // ----------------------------

  Future<DocumentReference<Map<String, dynamic>>> createAssistanceRequest(
    String type, {
    String? summary,
    String urgency = 'medium',
    Map<String, dynamic>? details,
    DateTime? preferredTime,
  }) async {
    final now = FieldValue.serverTimestamp();
    final profile = await getElderProfileSnapshot(uid);
    final normalizedUrgency = _normalizeUrgency(urgency);
    final cleanDetails = _cleanDetailsMap(details ?? const {});
    final effectiveSummary = _effectiveSummary(type, summary, cleanDetails);

    final ref = await _db.collection('assistance_requests').add({
      'uid': uid,
      'request_type': type,
      'type': type,
      'summary': effectiveSummary,
      'urgency': normalizedUrgency,
      if (cleanDetails.isNotEmpty) 'details': cleanDetails,
      if (preferredTime != null)
        'preferredTime': Timestamp.fromDate(preferredTime),
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
      'handledBy': null,
      'notes': null,
      'elderName': profile?['fullName'] ?? profile?['full_name'],
      'elderPhone': profile?['phoneNumber'],
      'elderBloodGroup': profile?['bloodGroup'] ?? profile?['blood_group'],
      'elderMedicalSummary':
          profile?['medicalSummary'] ?? profile?['medical_conditions'],
      'elderAge': profile?['age'] ?? profile?['age_int'],
      'elderEmergencyContact':
          profile?['emergencyContactNumber'] ??
          profile?['emergency_contact_number'],
    });

    await _db.collection('status_history').add({
      'targetType': 'ASSISTANCE',
      'targetId': ref.id,
      'targetUid': uid,
      'oldStatus': null,
      'newStatus': 'pending',
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'comment': 'Created',
    });

    await _createNotificationLog(
      recipientUid: uid,
      eventType: 'assistance_created',
      relatedRecord: ref,
      title: 'Assistance request sent',
      body: _assistanceCreateBody(
        type: type,
        summary: effectiveSummary,
        urgency: normalizedUrgency,
      ),
    );

    return ref;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> assistanceRequestStream(
    String requestId,
  ) {
    return _db.collection('assistance_requests').doc(requestId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> elderAssistanceRequestsStream({
    String? status,
  }) {
    var q = _db.collection('assistance_requests').where('uid', isEqualTo: uid);
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> adminAssistanceRequestsStream({
    String? status,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('assistance_requests');
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.snapshots();
  }

  Future<void> updateAssistanceRequestStatus({
    required String requestId,
    required String newStatus,
    String? comment,
  }) async {
    final ref = _db.collection('assistance_requests').doc(requestId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final oldStatus = (data['status'] ?? 'pending').toString();
      final targetUid = (data['uid'] ?? '').toString();

      tx.set(ref, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'handledBy': uid,
        if (comment != null && comment.trim().isNotEmpty)
          'notes': comment.trim(),
      }, SetOptions(merge: true));

      tx.set(_db.collection('status_history').doc(), {
        'targetType': 'ASSISTANCE',
        'targetId': requestId,
        'targetUid': targetUid,
        'oldStatus': oldStatus,
        'newStatus': newStatus,
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'comment': comment?.trim(),
      });
    });

    final snap = await ref.get();
    final targetUid = (snap.data()?['uid'] ?? '').toString();
    final requestSummary = (snap.data()?['summary'] ?? '').toString().trim();
    if (targetUid.isNotEmpty) {
      await _createNotificationLog(
        recipientUid: targetUid,
        eventType: 'assistance_status_update',
        relatedRecord: ref,
        title: 'Assistance request updated',
        body:
            'New status: ${_statusLabel(newStatus)}'
            '${requestSummary.isNotEmpty ? '\nRequest: $requestSummary' : ''}'
            '${comment != null && comment.trim().isNotEmpty ? '\nNote: ${comment.trim()}' : ''}',
      );
    }
  }

  // ----------------------------
  // SOS alerts
  // ----------------------------

  Future<DocumentReference<Map<String, dynamic>>> createSosAlert({
    required double latitude,
    required double longitude,
  }) async {
    final now = FieldValue.serverTimestamp();
    final profile = await getElderProfileSnapshot(uid);

    final ref = await _db.collection('sos_alerts').add({
      'uid': uid,
      'latitude': latitude,
      'longitude': longitude,
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
      'handledBy': null,
      'notes': null,
      'elderName': profile?['fullName'] ?? profile?['full_name'],
      'elderPhone': profile?['phoneNumber'],
      'elderBloodGroup': profile?['bloodGroup'] ?? profile?['blood_group'],
      'elderMedicalSummary':
          profile?['medicalSummary'] ?? profile?['medical_conditions'],
      'elderAge': profile?['age'] ?? profile?['age_int'],
      'elderEmergencyContact':
          profile?['emergencyContactNumber'] ??
          profile?['emergency_contact_number'],
    });

    await _db.collection('status_history').add({
      'targetType': 'SOS',
      'targetId': ref.id,
      'targetUid': uid,
      'oldStatus': null,
      'newStatus': 'pending',
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'comment': 'Created',
    });

    await _createNotificationLog(
      recipientUid: uid,
      eventType: 'sos_created',
      relatedRecord: ref,
      title: 'SOS sent',
      body:
          'Location attached (${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}). '
          'Status: pending',
    );

    return ref;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> elderSosAlertsStream({
    String? status,
  }) {
    var q = _db.collection('sos_alerts').where('uid', isEqualTo: uid);
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> adminSosAlertsStream({
    String? status,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('sos_alerts');
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.snapshots();
  }

  Future<void> updateSosStatus({
    required String alertId,
    required String newStatus,
    String? comment,
  }) async {
    final ref = _db.collection('sos_alerts').doc(alertId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final oldStatus = (data['status'] ?? 'pending').toString();
      final targetUid = (data['uid'] ?? '').toString();

      tx.set(ref, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'handledBy': uid,
        if (comment != null && comment.trim().isNotEmpty)
          'notes': comment.trim(),
      }, SetOptions(merge: true));

      tx.set(_db.collection('status_history').doc(), {
        'targetType': 'SOS',
        'targetId': alertId,
        'targetUid': targetUid,
        'oldStatus': oldStatus,
        'newStatus': newStatus,
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'comment': comment?.trim(),
      });
    });

    final snap = await ref.get();
    final targetUid = (snap.data()?['uid'] ?? '').toString();
    if (targetUid.isNotEmpty) {
      await _createNotificationLog(
        recipientUid: targetUid,
        eventType: 'sos_status_update',
        relatedRecord: ref,
        title: 'SOS updated',
        body:
            'New status: ${_statusLabel(newStatus)}'
            '${comment != null && comment.trim().isNotEmpty ? '\nNote: ${comment.trim()}' : ''}',
      );
    }
  }

  // ----------------------------
  // Admin analytics
  // ----------------------------

  Future<AdminSosAnalytics> getAdminSosAnalytics({DateTime? now}) async {
    final anchor = now ?? DateTime.now();
    final today = DateTime(anchor.year, anchor.month, anchor.day);
    final startOfWeek = today.subtract(Duration(days: anchor.weekday - 1));
    final startOfMonth = DateTime(anchor.year, anchor.month, 1);
    final rolling30Start = today.subtract(const Duration(days: 29));

    final monthSosSnap = await _db
        .collection('sos_alerts')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .get();
    final rollingSosSnap = await _db
        .collection('sos_alerts')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(rolling30Start),
        )
        .get();

    final monthDocs = monthSosSnap.docs;
    final rollingDocs = rollingSosSnap.docs;

    var weekTotal = 0;
    var monthTotal = 0;
    var resolvedCount = 0;
    var pendingCount = 0;
    var inProgressCount = 0;

    final monthTargetIds = <String>{};
    final createdByTargetId = <String, DateTime>{};

    for (final doc in monthDocs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt == null) continue;

      monthTotal += 1;
      if (!createdAt.isBefore(startOfWeek)) weekTotal += 1;

      final status = (data['status'] ?? 'pending').toString();
      if (status == 'resolved') {
        resolvedCount += 1;
      } else if (status == 'in_progress') {
        inProgressCount += 1;
      } else {
        pendingCount += 1;
      }

      monthTargetIds.add(doc.id);
      createdByTargetId[doc.id] = createdAt;
    }

    final firstResponseByTargetId = <String, DateTime>{};
    if (monthTargetIds.isNotEmpty) {
      final historySnap = await _db
          .collection('status_history')
          .where('targetType', isEqualTo: 'SOS')
          .get();

      for (final doc in historySnap.docs) {
        final data = doc.data();
        final targetId = (data['targetId'] ?? '').toString();
        if (!monthTargetIds.contains(targetId)) continue;

        final newStatus = (data['newStatus'] ?? '').toString();
        if (newStatus != 'in_progress' && newStatus != 'resolved') continue;

        final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
        if (updatedAt == null) continue;

        final existing = firstResponseByTargetId[targetId];
        if (existing == null || updatedAt.isBefore(existing)) {
          firstResponseByTargetId[targetId] = updatedAt;
        }
      }
    }

    var totalResponseMinutes = 0.0;
    var responseSamples = 0;
    for (final entry in createdByTargetId.entries) {
      final respondedAt = firstResponseByTargetId[entry.key];
      if (respondedAt == null || respondedAt.isBefore(entry.value)) continue;
      totalResponseMinutes +=
          respondedAt.difference(entry.value).inSeconds / 60.0;
      responseSamples += 1;
    }
    final avgResponseMinutes = responseSamples == 0
        ? null
        : totalResponseMinutes / responseSamples;

    final byUser = <String, _RiskAggregate>{};
    for (final doc in rollingDocs) {
      final data = doc.data();
      final uidValue = (data['uid'] ?? '').toString();
      if (uidValue.isEmpty) continue;

      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final status = (data['status'] ?? 'pending').toString();
      final elderName = (data['elderName'] ?? '').toString();

      final aggregate = byUser.putIfAbsent(
        uidValue,
        () => _RiskAggregate(uid: uidValue, elderName: elderName),
      );
      aggregate.totalSos += 1;
      if (status != 'resolved') aggregate.unresolvedSos += 1;
      if (createdAt != null &&
          (aggregate.lastIncidentAt == null ||
              createdAt.isAfter(aggregate.lastIncidentAt!))) {
        aggregate.lastIncidentAt = createdAt;
      }
      if (aggregate.elderName.trim().isEmpty && elderName.trim().isNotEmpty) {
        aggregate.elderName = elderName;
      }
    }

    final riskInsights =
        byUser.values
            .map((agg) {
              var score = agg.totalSos * 2 + agg.unresolvedSos * 3;
              if (agg.totalSos >= 4) score += 2;
              return AdminRiskUserInsight(
                uid: agg.uid,
                elderName: agg.elderName.trim().isEmpty
                    ? 'Unknown Elder'
                    : agg.elderName.trim(),
                totalSos: agg.totalSos,
                unresolvedSos: agg.unresolvedSos,
                lastIncidentAt: agg.lastIncidentAt,
                riskScore: score,
              );
            })
            .where(
              (insight) => insight.totalSos >= 2 || insight.unresolvedSos > 0,
            )
            .toList()
          ..sort((a, b) {
            final byScore = b.riskScore.compareTo(a.riskScore);
            if (byScore != 0) return byScore;
            final byTotal = b.totalSos.compareTo(a.totalSos);
            if (byTotal != 0) return byTotal;
            return b.unresolvedSos.compareTo(a.unresolvedSos);
          });

    final repeatEmergencyUsers = byUser.values
        .where((agg) => agg.totalSos >= 2)
        .length;

    return AdminSosAnalytics(
      weekTotal: weekTotal,
      monthTotal: monthTotal,
      resolvedCount: resolvedCount,
      pendingCount: pendingCount,
      inProgressCount: inProgressCount,
      avgResponseMinutes: avgResponseMinutes,
      repeatEmergencyUsers: repeatEmergencyUsers,
      highRiskUsers: riskInsights.take(8).toList(),
    );
  }

  // ----------------------------
  // Medication routines & logs
  // ----------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> elderMedicationRoutinesStream() {
    return _db
        .collection('medication_routines')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> adminMedicationRoutinesStream() {
    return _db.collection('medication_routines').snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> createMedicationRoutine({
    required String medicineName,
    String? dosage,
    String? instructions,
    required List<String> reminderTimes,
    bool isActive = true,
  }) async {
    final profile = await getElderProfileSnapshot(uid);
    final normalizedTimes = _normalizeReminderTimes(reminderTimes);
    if (normalizedTimes.isEmpty) {
      throw ArgumentError('At least one valid reminder time is required.');
    }

    final now = FieldValue.serverTimestamp();
    final ref = await _db.collection('medication_routines').add({
      'uid': uid,
      'medicineName': medicineName.trim(),
      'dosage': dosage?.trim(),
      'instructions': instructions?.trim(),
      'reminderTimes': normalizedTimes,
      'isActive': isActive,
      'createdAt': now,
      'updatedAt': now,
      'elderName': profile?['fullName'] ?? profile?['full_name'],
      'elderPhone': profile?['phoneNumber'],
    });

    await _createNotificationLog(
      recipientUid: uid,
      eventType: 'medication_routine_created',
      relatedRecord: ref,
      title: 'Medication reminder saved',
      body:
          'Routine for ${medicineName.trim()} set at ${normalizedTimes.join(', ')}.',
    );

    return ref;
  }

  Future<void> updateMedicationRoutine({
    required String routineId,
    required String medicineName,
    String? dosage,
    String? instructions,
    required List<String> reminderTimes,
    required bool isActive,
  }) async {
    final normalizedTimes = _normalizeReminderTimes(reminderTimes);
    if (normalizedTimes.isEmpty) {
      throw ArgumentError('At least one valid reminder time is required.');
    }

    await _db.collection('medication_routines').doc(routineId).set({
      'medicineName': medicineName.trim(),
      'dosage': dosage?.trim(),
      'instructions': instructions?.trim(),
      'reminderTimes': normalizedTimes,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteMedicationRoutine(String routineId) async {
    await _db.collection('medication_routines').doc(routineId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> elderMedicationLogsStream({
    DateTime? from,
  }) {
    final lowerBound = from ?? DateTime.now().subtract(const Duration(days: 7));
    return _db
        .collection('medication_logs')
        .where('uid', isEqualTo: uid)
        .where(
          'scheduledAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(lowerBound),
        )
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> adminMedicationLogsStream({
    DateTime? from,
  }) {
    final lowerBound = from ?? DateTime.now().subtract(const Duration(days: 7));
    return _db
        .collection('medication_logs')
        .where(
          'scheduledAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(lowerBound),
        )
        .snapshots();
  }

  Future<void> setMedicationDoseStatus({
    required String routineId,
    required DateTime scheduledAt,
    required String status,
    String source = 'elder_manual',
  }) async {
    if (status != 'taken' && status != 'missed') {
      throw ArgumentError('Status must be taken or missed.');
    }

    final routineRef = _db.collection('medication_routines').doc(routineId);
    final routineSnap = await routineRef.get();
    final routine = routineSnap.data();
    if (routine == null) {
      throw StateError('Medication routine not found.');
    }

    final normalizedScheduled = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
      scheduledAt.hour,
      scheduledAt.minute,
    );

    final docId = _medicationLogId(
      uid: uid,
      routineId: routineId,
      scheduledAt: normalizedScheduled,
    );
    final logRef = _db.collection('medication_logs').doc(docId);

    final medicineName = (routine['medicineName'] ?? '').toString();
    final dosage = (routine['dosage'] ?? '').toString();
    final elderName = (routine['elderName'] ?? '').toString();
    final now = FieldValue.serverTimestamp();

    await logRef.set({
      'uid': uid,
      'routineId': routineId,
      'medicineName': medicineName,
      'dosage': dosage,
      'elderName': elderName,
      'scheduledAt': Timestamp.fromDate(normalizedScheduled),
      'scheduledDateKey': _dateKey(normalizedScheduled),
      'scheduledTimeLabel': _timeKey(normalizedScheduled),
      'status': status,
      'markedBy': uid,
      'source': source,
      'updatedAt': now,
      'createdAt': now,
      'routinePath': routineRef.path,
    }, SetOptions(merge: true));
  }

  Future<void> markOverdueMedicationLogsAsMissed({
    Duration grace = const Duration(minutes: 90),
    DateTime? now,
  }) async {
    final moment = now ?? DateTime.now();
    final cutoff = moment.subtract(grace);
    final startOfDay = DateTime(moment.year, moment.month, moment.day);

    final routinesSnap = await _db
        .collection('medication_routines')
        .where('uid', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in routinesSnap.docs) {
      final data = doc.data();
      final times = _normalizeReminderTimes(
        ((data['reminderTimes'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

      for (final time in times) {
        final parts = time.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        final scheduled = DateTime(
          startOfDay.year,
          startOfDay.month,
          startOfDay.day,
          hour,
          minute,
        );
        if (!scheduled.isBefore(cutoff)) continue;

        final logRef = _db
            .collection('medication_logs')
            .doc(
              _medicationLogId(
                uid: uid,
                routineId: doc.id,
                scheduledAt: scheduled,
              ),
            );
        final existing = await logRef.get();
        if (existing.exists) continue;

        await setMedicationDoseStatus(
          routineId: doc.id,
          scheduledAt: scheduled,
          status: 'missed',
          source: 'auto_overdue',
        );
      }
    }
  }

  // ----------------------------
  // Status history & notifications
  // ----------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> statusHistoryStream({
    required CaseType type,
    required String targetId,
  }) {
    return _db
        .collection('status_history')
        .where(
          'targetType',
          isEqualTo: type == CaseType.sos ? 'SOS' : 'ASSISTANCE',
        )
        .where('targetId', isEqualTo: targetId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationLogsStream() {
    return _db
        .collection('notification_logs')
        .where('recipientUid', isEqualTo: uid)
        .snapshots();
  }

  Future<void> _createNotificationLog({
    required String recipientUid,
    required String eventType,
    required DocumentReference<Map<String, dynamic>> relatedRecord,
    required String title,
    required String body,
  }) async {
    await _db.collection('notification_logs').add({
      'recipientUid': recipientUid,
      'eventType': eventType,
      'relatedRecordPath': relatedRecord.path,
      'title': title,
      'body': body,
      'deliveryStatus': 'in_app',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _statusLabel(String status) {
    return switch (status) {
      'in_progress' => 'In Progress',
      'resolved' => 'Resolved',
      _ => 'Pending',
    };
  }

  String _normalizeUrgency(String raw) {
    final value = raw.trim().toLowerCase();
    return switch (value) {
      'low' => 'low',
      'high' => 'high',
      'urgent' => 'urgent',
      _ => 'medium',
    };
  }

  Map<String, dynamic> _cleanDetailsMap(Map<String, dynamic> raw) {
    final cleaned = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      final value = entry.value;
      if (value == null) continue;
      if (value is String) {
        final v = value.trim();
        if (v.isEmpty) continue;
        cleaned[key] = v;
        continue;
      }
      if (value is List) {
        final normalized = value
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
        if (normalized.isEmpty) continue;
        cleaned[key] = normalized;
        continue;
      }
      cleaned[key] = value;
    }
    return cleaned;
  }

  String _effectiveSummary(
    String type,
    String? summary,
    Map<String, dynamic> details,
  ) {
    final provided = (summary ?? '').trim();
    if (provided.isNotEmpty) return provided;

    final category = _requestTypeLabel(type);
    if (details.isEmpty) return '$category request';
    final first = details.entries.first;
    return '$category: ${first.value}';
  }

  String _requestTypeLabel(String raw) {
    final value = raw.trim();
    return switch (value) {
      'MedicineHelp' || 'medicine' => 'Medicine Help',
      'GroceryHelp' || 'grocery' => 'Grocery Help',
      'GeneralAssistance' || 'general' => 'General Assistance',
      _ => value,
    };
  }

  String _urgencyLabel(String status) {
    return switch (status) {
      'low' => 'Low',
      'high' => 'High',
      'urgent' => 'Urgent',
      _ => 'Medium',
    };
  }

  String _assistanceCreateBody({
    required String type,
    required String summary,
    required String urgency,
  }) {
    final lines = <String>[
      'Type: ${_requestTypeLabel(type)}',
      'Status: pending',
      'Urgency: ${_urgencyLabel(urgency)}',
    ];
    if (summary.trim().isNotEmpty) {
      lines.insert(1, 'Request: ${summary.trim()}');
    }
    return lines.join('\n');
  }

  List<String> _normalizeReminderTimes(List<String> rawTimes) {
    final out = <String>{};
    for (final raw in rawTimes) {
      final value = raw.trim();
      final parts = value.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) continue;
      out.add(
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      );
    }

    final list = out.toList()..sort();
    return list;
  }

  String _medicationLogId({
    required String uid,
    required String routineId,
    required DateTime scheduledAt,
  }) {
    return '${uid}_${routineId}_${_dateKey(scheduledAt)}_${_timeKey(scheduledAt)}';
  }

  String _dateKey(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
  }

  String _timeKey(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _RiskAggregate {
  _RiskAggregate({required this.uid, required this.elderName});

  final String uid;
  String elderName;
  int totalSos = 0;
  int unresolvedSos = 0;
  DateTime? lastIncidentAt;
}
