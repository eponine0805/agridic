import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_notification.dart';
import '../services/firebase_service.dart';

class UserPrefs extends ChangeNotifier {
  static const _keyFirstLoginDone = 'dict_first_download_done';

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();
  StreamSubscription<User?>? _authSub;
  StreamSubscription<int>? _unreadSub;

  User? _user;
  String _role = 'farmer';
  String _bio = '';
  bool _firstDownloadDone = false;
  bool _loading = true;

  // ─── 通知キャッシュ ────────────────────────────────────────────────
  int _unreadCount = 0;
  List<AppNotification>? _cachedNotifications;
  DateTime? _notifLastLoaded;

  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null;
  String get userId => _user?.uid ?? '';
  String get userName =>
      _user?.displayName?.isNotEmpty == true
          ? _user!.displayName!
          : (_user?.email?.split('@').first ?? '');
  String get userEmail => _user?.email ?? '';
  String get userRole => _role;
  String get userBio => _bio;
  bool get isAdmin => _role == 'admin';
  bool get isExpert => _role == 'expert' || _role == 'admin';
  bool get firstDownloadDone => _firstDownloadDone;
  int get unreadCount => _unreadCount;
  List<AppNotification>? get cachedNotifications => _cachedNotifications;
  bool get notifCacheValid =>
      _notifLastLoaded != null &&
      DateTime.now().difference(_notifLastLoaded!).inMinutes < 5;

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
        _startUnreadStream(user.uid);
        await _setupFcm(user.uid);
      } else {
        _role = 'farmer';
        _stopUnreadStream();
        _unreadCount = 0;
        _cachedNotifications = null;
        _notifLastLoaded = null;
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
        _bio = (doc.data()?['bio'] ?? '') as String;
      } else {
        _role = 'farmer';
        _bio = '';
      }
    } catch (_) {
      _role = 'farmer';
      _bio = '';
    }
  }

  // ─── FCM セットアップ ──────────────────────────────────────────────

  Future<void> _setupFcm(String uid) async {
    try {
      // 通知権限をリクエスト（Android 13+ / iOS）
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // FCM トークンを取得して Firestore に保存
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseService.saveFcmToken(uid, token);
      }

      // トークン更新時に再保存
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        FirebaseService.saveFcmToken(uid, newToken);
      });

      // 農業アラート全配信トピックを購読
      await FirebaseMessaging.instance.subscribeToTopic('broadcasts');
    } catch (_) {
      // FCM が使えない環境（エミュレータ等）はスキップ
    }
  }

  // ─── 未読数ストリーム（UserPrefs 内で 1 本だけ管理）─────────────────

  void _startUnreadStream(String uid) {
    _unreadSub?.cancel();
    _unreadSub = FirebaseService.streamUnreadCount(uid).listen((count) {
      _unreadCount = count;
      notifyListeners();
    });
  }

  void _stopUnreadStream() {
    _unreadSub?.cancel();
    _unreadSub = null;
  }

  // ─── 通知キャッシュ更新 ───────────────────────────────────────────

  /// 通知一覧をキャッシュとして保存（NotificationsScreen から呼ぶ）
  void setCachedNotifications(List<AppNotification> list) {
    _cachedNotifications = list;
    _notifLastLoaded = DateTime.now();
    notifyListeners();
  }

  /// 既読化後に未読数をローカルでリセット
  void resetUnreadCount() {
    _unreadCount = 0;
    notifyListeners();
  }

  // ─── 認証 ─────────────────────────────────────────────────────────

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign in failed';
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        final doc = await _db.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          await _db.collection('users').doc(user.uid).set({
            'role': 'farmer',
            'userName':
                user.displayName ?? user.email?.split('@').first ?? 'User',
            'email': user.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Google sign-in failed';
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('sign_in_canceled') ||
          msg.contains('sign_in_cancelled')) {
        return null;
      }
      return msg;
    }
  }

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
      _role = 'farmer';
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Registration failed';
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('broadcasts');
    } catch (_) {}
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> reloadRole() async {
    if (_user == null) return;
    await _loadRole(_user!.uid);
    notifyListeners();
  }

  Future<String?> updateBio(String newBio) async {
    try {
      await _db.collection('users').doc(_user!.uid).set(
          {'bio': newBio.trim()}, SetOptions(merge: true));
      _bio = newBio.trim();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to update bio';
    }
  }

  Future<String?> updateDisplayName(String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return 'Name cannot be empty';
    try {
      await _user?.updateDisplayName(name);
      await _db.collection('users').doc(_user!.uid).set(
          {'userName': name}, SetOptions(merge: true));
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
    _unreadSub?.cancel();
    super.dispose();
  }
}
