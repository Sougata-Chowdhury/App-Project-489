import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum CaseType { sos, assistance }

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

      // camelCase (existing app)
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

      // snake_case (schema-aligned)
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
      // Schema-aligned field name; keep 'type' for backwards compatibility/UI.
      'request_type': type, // MedicineHelp | GroceryHelp | GeneralAssistance
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
      // denormalized snapshot for admin list/detail
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

    // Notification log as best-effort (non-transactional)
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
      // denormalized snapshot for admin list/detail
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
}
