import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/firebase_service.dart';

class UserPrefs extends ChangeNotifier {
  static const _keyFirstLoginDone = 'dict_first_download_done';

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();
  StreamSubscription<User?>? _authSub;

  User? _user;
  String _role = 'farmer';
  bool _firstDownloadDone = false;
  bool _loading = true;

  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null;
  String get userId => _user?.uid ?? '';
  String get userName =>
      _user?.displayName?.isNotEmpty == true
          ? _user!.displayName!
          : (_user?.email?.split('@').first ?? '');
  String get userEmail => _user?.email ?? '';
  String get userRole => _role;
  bool get isAdmin => _role == 'admin';
  bool get isExpert => _role == 'expert' || _role == 'admin';
  bool get firstDownloadDone => _firstDownloadDone;

  UserPrefs() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _firstDownloadDone = prefs.getBool(_keyFirstLoginDone) ?? false;

    // 全ユーザーをadminに昇格する一回限りのマイグレーション
    final migrated = prefs.getBool('admin_migration_v1') ?? false;
    if (!migrated) {
      try {
        await FirebaseService.promoteAllUsersToAdmin();
        await prefs.setBool('admin_migration_v1', true);
      } catch (_) {}
    }

    _authSub = _auth.authStateChanges().listen((user) async {
      _user = user;
      if (user != null) {
        await _loadRole(user.uid);
      } else {
        _role = 'farmer';
      }
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> _loadRole(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        _role = (doc.data()?['role'] ?? 'farmer') as String;
      } else {
        _role = 'farmer';
      }
    } catch (_) {
      _role = 'farmer';
    }
  }


  /// Sign in with email/password. Returns null on success, error message on failure.
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign in failed';
    }
  }

  /// Sign in with Google. Returns null on success, error message on failure.
  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        // Ensure user document exists in Firestore
        final doc = await _db.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          await _db.collection('users').doc(user.uid).set({
            'role': 'admin',
            'userName':
                user.displayName ?? user.email?.split('@').first ?? 'User',
            'email': user.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
          _role = 'admin';
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Google sign-in failed';
    } catch (e) {
      final msg = e.toString();
      // Only treat explicit user-cancel as silent (not developer errors)
      if (msg.contains('sign_in_canceled') || msg.contains('sign_in_cancelled')) {
        return null;
      }
      // Surface all other errors (including DEVELOPER_ERROR / code 10)
      return msg;
    }
  }

  /// Register a new account. Returns null on success, error message on failure.
  Future<String?> register(
      String email, String password, String userName) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user?.updateDisplayName(userName.trim());
      await _db.collection('users').doc(cred.user!.uid).set({
        'role': 'admin',
        'userName': userName.trim(),
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      // ロールを明示的に反映（authStateChanges との race condition を回避）
      _role = 'admin';
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Registration failed';
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Reload role from Firestore (call after role changes)
  Future<void> reloadRole() async {
    if (_user == null) return;
    await _loadRole(_user!.uid);
    notifyListeners();
  }

  /// Update display name in Firebase Auth and Firestore
  Future<String?> updateDisplayName(String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return 'Name cannot be empty';
    try {
      await _user?.updateDisplayName(name);
      await _db.collection('users').doc(_user!.uid).set(
          {'userName': name}, SetOptions(merge: true));
      // Firebase Auth のキャッシュを再読み込みして displayName を反映させる
      await _auth.currentUser?.reload();
      _user = _auth.currentUser;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to update name';
    }
  }


  Future<void> markFirstDownloadDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstLoginDone, true);
    _firstDownloadDone = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
