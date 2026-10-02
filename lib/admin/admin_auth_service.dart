// Admin authentication service.
//
// SECURITY MODEL: the admin role lives ONLY in the Firebase Auth custom claim
// (admin: true), which is set off device via the Firebase Admin SDK. This app
// never hardcodes admin credentials and never grants admin access without
// verifying that claim on a fresh ID token. A signed-in user whose token does
// not carry the claim is signed back out immediately.
import 'package:firebase_auth/firebase_auth.dart';

/// Outcome of an admin sign-in attempt.
class AdminSignInResult {
  final bool ok;
  final String? error;
  final String? email;

  const AdminSignInResult({required this.ok, this.error, this.email});
}

/// Static admin sign-in helpers backed by Firebase Authentication.
class AdminAuthService {
  AdminAuthService._();

  /// Returns true only when the token claims carry admin: true. Pure and
  /// unit-testable; any other shape of claim is treated as non-admin.
  static bool isAdminFromClaims(Map<String, dynamic>? claims) {
    return claims?['admin'] == true;
  }

  /// Signs in with email and password, force-refreshes the ID token, and
  /// allows the session to continue ONLY when the custom admin claim is
  /// present. Otherwise the session is signed out and a failure is returned.
  static Future<AdminSignInResult> signInAsAdmin({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final tokenResult = await cred.user!.getIdTokenResult(true);
      if (isAdminFromClaims(tokenResult.claims)) {
        return AdminSignInResult(ok: true, email: cred.user!.email);
      }
      await FirebaseAuth.instance.signOut();
      return const AdminSignInResult(
        ok: false,
        error: 'Not an authorized admin account.',
      );
    } on FirebaseAuthException catch (e) {
      return AdminSignInResult(ok: false, error: _friendlyMessage(e));
    } catch (_) {
      return const AdminSignInResult(
        ok: false,
        error: 'Admin sign-in needs Firebase setup first.',
      );
    }
  }

  /// Signs out of any Firebase session. Never throws: safe to call when
  /// Firebase is not configured or no session exists.
  static Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Nothing to sign out from; ignore.
    }
  }

  static String _friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No network connection. Please try again.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }
}
