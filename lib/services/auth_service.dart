import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Email/password auth backed by Firebase Auth + a `users` doc in Firestore.
///
/// Firebase credentials are added by the developer (see PUBLISHING.md). Until
/// then, [init] is never called, [_auth] stays null, and every operation
/// returns a friendly "setup required" message instead of crashing.
class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;
  FirebaseFirestore? _db;

  bool get configured => _auth != null && _db != null;

  AppUser? _user;
  AppUser? get user => _user;
  bool get signedIn => _user != null;
  bool _ready = false;
  bool get ready => _ready;

  /// Lazily resolved so constructing this class never crashes when Firebase
  /// has not been configured yet (deleteAccount only runs while signed in).
  FirebaseStorage _storageForCleanup() => FirebaseStorage.instance;

  /// Set when an auth-state restore finds a suspended account (which is then
  /// signed out). The login screen shows this once and clears it.
  bool _suspendedNotice = false;
  bool get suspendedNotice => _suspendedNotice;
  void clearSuspendedNotice() {
    _suspendedNotice = false;
  }

  static const String _notConfigured =
      'Sign-in needs Firebase setup first. Follow PUBLISHING.md to add your Firebase project keys, then rebuild the app.';

  StreamSubscription<User?>? _authSub;
  // Guards overlapping auth callbacks: each event takes a generation, and a
  // slow async continuation (suspend check, profile fetch) bails out when a
  // newer event has already superseded it.
  int _authGen = 0;

  Future<void> init() async {
    _auth = FirebaseAuth.instance;
    _db = FirebaseFirestore.instance;
    _authSub = _auth!.authStateChanges().listen((fbUser) async {
      final gen = ++_authGen;
      AppUser? next;
      var suspended = false;
      if (fbUser == null) {
        next = null;
      } else if (await _isSuspended(fbUser.uid)) {
        // Suspended accounts are signed out immediately, including on
        // auth-state restore. The `suspended` flag itself can only be set by
        // admins (enforced in firestore.rules), so users cannot evade this.
        suspended = true;
        await _auth!.signOut();
      } else {
        next = await _fetchUser(fbUser.uid, fbUser.email ?? '');
      }
      if (gen != _authGen) return;
      _user = next;
      if (suspended) _suspendedNotice = true;
      _ready = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Reads the admin-only `suspended` flag. Fails closed-ish: a read error
  /// returns false, but the flag can only be written by admins server-side,
  /// so a suspended user cannot clear it to get back in.
  Future<bool> _isSuspended(String uid) async {
    try {
      final doc = await _db!.collection('users').doc(uid).get();
      return doc.exists && doc.data()!['suspended'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<AppUser> _fetchUser(String uid, String email) async {
    final doc = await _db!.collection('users').doc(uid).get();
    if (doc.exists) return AppUser.fromMap(uid, doc.data()!);
    final fresh = AppUser(uid: uid, name: email.split('@').first, email: email);
    await _db!.collection('users').doc(uid).set(fresh.toMap());
    return fresh;
  }

  Future<void> refreshUser() async {
    if (!configured) return;
    final fb = _auth!.currentUser;
    if (fb == null) return;
    _user = await _fetchUser(fb.uid, fb.email ?? '');
    notifyListeners();
  }

  Future<String?> signUp(
      {required String name,
      required String email,
      required String password,
      int? age,
      String? gender,
      String? location,
      String? bio}) async {
    if (!configured) return _notConfigured;
    try {
      final cred = await _auth!.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      final uid = cred.user!.uid;
      _user = AppUser(uid: uid, name: name.trim(), email: email.trim());
      await _db!.collection('users').doc(uid).set(_user!.toMap());
      // Full traveler profile (AppUser contract fields). onboardingDone
      // starts false so HomeShell pushes the first-run tutorial once.
      await _db!.collection('users').doc(uid).update({
        if (age != null) 'age': age,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (location != null && location.isNotEmpty) 'location': location,
        if (bio != null && bio.isNotEmpty) 'bio': bio,
        'onboardingDone': false,
      });
      await refreshUser();
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendly(e);
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> signIn(
      {required String email, required String password}) async {
    if (!configured) return _notConfigured;
    try {
      final cred = await _auth!
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      if (await _isSuspended(cred.user!.uid)) {
        await _auth!.signOut();
        return 'This account has been suspended.';
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendly(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> signOut() async {
    if (configured) await _auth!.signOut();
    _user = null;
    notifyListeners();
  }

  /// Re-authenticates the current email/password user. Returns null on
  /// success, otherwise a user-facing error message.
  ///
  /// Call this immediately before [deleteAccount]: Firebase requires a
  /// recent sign-in to delete a user, and re-authenticating first means the
  /// destructive cleanup never runs against a stale credential (which would
  /// otherwise delete the user's data while the account itself survives).
  Future<String?> reauthenticate(String password) async {
    if (!configured || _user == null) return _notConfigured;
    final fbUser = _auth!.currentUser;
    if (fbUser == null) return 'You are already signed out.';
    final email = _user!.email;
    if (email.isEmpty) {
      return 'Could not verify your sign-in. Please sign out and sign back in.';
    }
    try {
      await fbUser.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      return _friendly(e);
    } catch (_) {
      return 'Could not verify your password. Please try again.';
    }
    return null;
  }

  /// Permanently deletes the account (Apple guideline 5.1.1(v)).
  ///
  /// Order matters: Firestore and Storage writes need a signed-in user, so
  /// the Firebase Auth user is deleted last, then we sign out locally.
  ///
  /// LIMITS (documented for App Review and future work):
  /// - Subcollections (donePlaces, likesGiven, passes, post comments,
  ///   matches, conversations/messages) are NOT deleted client-side and
  ///   become orphaned. Full cleanup needs a Cloud Function triggered on
  ///   users/{uid} deletion.
  /// - Storage cleanup is best-effort: each file delete is wrapped in
  ///   try/catch and failures are skipped so one bad file cannot block
  ///   the deletion.
  /// - Firebase Auth requires a recent sign-in to delete the user. When
  ///   the credential is stale this returns a friendly message asking the
  ///   user to sign in again first. Prefer calling [reauthenticate] right
  ///   before this so no destructive step runs on a stale credential.
  /// Returns null on success, otherwise a user-facing error message.
  Future<String?> deleteAccount() async {
    if (!configured || _user == null) return _notConfigured;
    final uid = _user!.uid;
    final fbUser = _auth!.currentUser;
    if (fbUser == null) return 'You are already signed out.';
    try {
      // Best-effort: delete the user's post images, then the post docs.
      final posts =
          await _db!.collection('posts').where('uid', isEqualTo: uid).get();
      for (final doc in posts.docs) {
        final imageUrl = (doc.data()['imageUrl'] as String?) ?? '';
        if (imageUrl.isNotEmpty) {
          try {
            await _storageForCleanup().refFromURL(imageUrl).delete();
          } catch (_) {
            // Skip: a missing file must not block account deletion.
          }
        }
        try {
          await doc.reference.delete();
        } catch (_) {
          // Skip: continue with the rest of the cleanup.
        }
      }
      // Best-effort: delete the profile photo.
      final photoUrl = _user!.photoUrl;
      if (photoUrl.isNotEmpty) {
        try {
          await _storageForCleanup().refFromURL(photoUrl).delete();
        } catch (_) {
          // Skip: a missing file must not block account deletion.
        }
      }
      // Delete the user document (firestore.rules allows owners to
      // delete their own doc).
      await _db!.collection('users').doc(uid).delete();
      // Delete the Firebase Auth user last.
      await fbUser.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'For security, please sign out and sign back in, then delete your account again.';
      }
      return _friendly(e);
    } catch (_) {
      return 'Could not delete your account. Please try again.';
    }
    _user = null;
    try {
      await _auth!.signOut();
    } catch (_) {
      // Already signed out by the delete; ignore.
    }
    notifyListeners();
    return null;
  }

  Future<String?> updateProfile({
    required String name,
    int? age,
    required String location,
    required String bio,
    String? gender,
  }) async {
    if (!configured || _user == null) return _notConfigured;
    try {
      await _db!.collection('users').doc(_user!.uid).update({
        'name': name,
        'age': age ?? 0,
        'location': location,
        'bio': bio,
        if (gender != null) 'gender': gender,
      });
      _user = AppUser(
        uid: _user!.uid,
        name: name,
        email: _user!.email,
        age: age ?? 0,
        location: location,
        bio: bio,
        photoUrl: _user!.photoUrl,
        coverUrl: _user!.coverUrl,
        points: _user!.points,
        followers: _user!.followers,
        following: _user!.following,
        donePlaceIds: _user!.donePlaceIds,
        blockedUids: _user!.blockedUids,
      );
      notifyListeners();
      return null;
    } catch (_) {
      return 'Could not save your profile. Please try again.';
    }
  }

  String _friendly(FirebaseAuthException e) => friendlyAuthError(e.code);

  /// Pure Firebase Auth error-code mapping (static so it is unit-testable
  /// without Firebase).
  static String friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'That email is already registered. Try signing in.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'requires-recent-login':
        return 'For security, please sign out and sign back in, then try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
