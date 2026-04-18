import 'package:firebase_auth/firebase_auth.dart';

String friendlyAuthError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Invalid credentials. Check your email and password.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in.';
      case 'weak-password':
        return 'Password is too weak (minimum 6 characters).';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again later.';
      case 'not-admin':
        return e.message ?? 'This email is not authorized as an Admin.';
      case 'admin-must-use-admin-login':
        return e.message ?? 'Please use Admin login for this account.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }

  return 'Something went wrong. Please try again.';
}
