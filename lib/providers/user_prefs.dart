import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserPrefs extends ChangeNotifier {
  static const _keyFirstLoginDone = 'dict_first_download_done';

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
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

  /// Register a new account. Returns null on success, error message on failure.
  Future<String?> register(
      String email, String password, String userName) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user?.updateDisplayName(userName.trim());
      await _db.collection('users').doc(cred.user!.uid).set({
        'role': 'farmer',
        'userName': userName.trim(),
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Registration failed';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Reload role from Firestore (call after role changes)
  Future<void> reloadRole() async {
    if (_user == null) return;
    await _loadRole(_user!.uid);
    notifyListeners();
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
