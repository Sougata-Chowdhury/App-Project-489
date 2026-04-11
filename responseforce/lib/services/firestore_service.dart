import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser!.uid;

  Future<DocumentReference<Map<String, dynamic>>> createAssistanceRequest(String type) async {
    final now = FieldValue.serverTimestamp();
    return _db.collection('assistance_requests').add({
      'uid': _uid,
      'type': type, // medicine | grocery | general
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
      'handledBy': null,
      'notes': null,
    });
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

    await _db.collection('elder_profiles').doc(_uid).set({
      'uid': _uid,
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'age': parsedAge,
      'bloodGroup': bloodGroup.trim().isEmpty ? null : bloodGroup.trim(),
      'medicalSummary': medicalSummary.trim().isEmpty ? null : medicalSummary.trim(),
      'emergencyContactNumber': emergencyContactNumber.trim().isEmpty
          ? null
          : emergencyContactNumber.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> elderProfileStream() {
    return _db.collection('elder_profiles').doc(_uid).snapshots();
  }
}
