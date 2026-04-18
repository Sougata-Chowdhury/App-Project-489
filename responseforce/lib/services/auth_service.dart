import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../state/app_state.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signIn({
    required String email,
    required String password,
    required AppRole expectedRole,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // If this email is an Admin, force them through Admin flow.
    final isAdmin = await _isAdminEmail(normalizedEmail);
    if (isAdmin && expectedRole != AppRole.admin) {
      throw FirebaseAuthException(
        code: 'admin-must-use-admin-login',
        message: 'This email is an Admin. Please use Admin login.',
      );
    }

    if (!isAdmin && expectedRole == AppRole.admin) {
      throw FirebaseAuthException(
        code: 'not-admin',
        message: 'This email is not authorized as an Admin.',
      );
    }

    final cred = await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final user = cred.user;
    if (user == null) return;

    final finalRole = isAdmin ? AppRole.admin : expectedRole;

    // Ensure a user doc exists and role is set.
    await _upsertUserDoc(
      uid: user.uid,
      email: normalizedEmail,
      role: finalRole,
    );

    // If elder, ensure profile doc exists.
    if (finalRole == AppRole.elder) {
      await _ensureElderProfile(uid: user.uid);
    }
  }

  Future<void> registerElder({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    final cred = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final user = cred.user;
    if (user == null) return;

    await user.updateDisplayName(fullName.trim());

    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': normalizedEmail,
      'role': 'elder',
      'authProvider': 'email',
      'sessionActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('elder_profiles').doc(user.uid).set({
      'uid': user.uid,
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'age': null,
      'bloodGroup': null,
      'medicalSummary': null,
      'emergencyContactNumber': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<AppRole?> getCurrentUserRole(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final role = snap.data()?['role'];
    return switch (role) {
      'admin' => AppRole.admin,
      'elder' => AppRole.elder,
      _ => null,
    };
  }

  Future<void> _upsertUserDoc({
    required String uid,
    required String email,
    required AppRole role,
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'role': role.name,
      'authProvider': 'email',
      'sessionActive': true,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureElderProfile({required String uid}) async {
    final ref = _db.collection('elder_profiles').doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'uid': uid,
      'fullName': _auth.currentUser?.displayName,
      'phoneNumber': _auth.currentUser?.phoneNumber,
      'age': null,
      'bloodGroup': null,
      'medicalSummary': null,
      'emergencyContactNumber': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> _isAdminEmail(String normalizedEmail) async {
    // Prefer Firestore-managed whitelist: admin_whitelist/{email}
    try {
      final snap = await _db
          .collection('admin_whitelist')
          .doc(normalizedEmail)
          .get();
      final enabled = snap.data()?['enabled'];
      if (enabled is bool) return enabled;
      if (snap.exists) return true;
    } catch (_) {
      // ignore and fall back to local list
    }

    // Local fallback (add your admin emails here if you want a hardcoded backup)
    const local = <String>{};
    return local.contains(normalizedEmail);
  }
}
