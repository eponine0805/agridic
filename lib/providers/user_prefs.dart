import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/post.dart' show UserRole;
import '../services/firebase_service.dart';

class UserPrefs extends ChangeNotifier with WidgetsBindingObserver {
  static const _keyFirstLoginDone = 'dict_first_download_done';
  static const _keyAvatarBase64 = 'user_avatar_base64';
  static const _keyRole = 'user_role_cached';
  static const _keyBio = 'user_bio_cached';
  static const _keyUnreadCount = 'user_unread_count';

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  User? _user;
  String _role = 'farmer';
  Timer? _fcmTokenRefreshDebounce;
  StreamSubscription? _fcmTokenRefreshSubscription;
  String _bio = '';
  String _avatarBase64 = '';
  bool _firstDownloadDone = false;
  bool _loading = true;

  // ─── Unread like count ──────────────────────────────────────────────────
  int _unreadCount = 0;

  // ─── FCM permission denied flag ─────────────────────────────────────────
  bool _fcmPermissionDenied = false;

  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null;
  String get userId => _user?.uid ?? '';
  String get userName =>
      _user?.displayName?.isNotEmpty == true
          ? _user!.displayName!
          : (_user?.email?.split('@').first ?? '');
  String get userEmail => _user?.email ?? '';
  String get userRole => _role;
  /// Type-safe role accessor.
  UserRole get role => switch (_role) {
        'expert' => UserRole.expert,
        'admin' => UserRole.admin,
        _ => UserRole.farmer,
      };
  String get userBio => _bio;
  String get avatarBase64 => _avatarBase64;
  bool get isAdmin => role == UserRole.admin;
  bool get isExpert => role == UserRole.expert || role == UserRole.admin;
  bool get firstDownloadDone => _firstDownloadDone;
  int get unreadCount => _unreadCount;
  bool get fcmPermissionDenied => _fcmPermissionDenied;

  UserPrefs() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _firstDownloadDone = prefs.getBool(_keyFirstLoginDone) ?? false;
    _avatarBase64 = prefs.getString(_keyAvatarBase64) ?? '';
    // Load cached role/bio so offline starts work without Firestore
    _role = prefs.getString(_keyRole) ?? 'farmer';
    _bio = prefs.getString(_keyBio) ?? '';
    // Persist unread count so force-quit doesn't reset the badge
    _unreadCount = prefs.getInt(_keyUnreadCount) ?? 0;

    // Immediately use locally-cached auth state — works completely offline.
    // Firebase Auth stores credentials on device; currentUser is synchronous.
    _user = _auth.currentUser;
    _loading = false;
    notifyListeners();

    // Background: refresh role/bio from Firestore and set up FCM when online.
    // Also handles sign-in / sign-out events while the app is running.
    _auth.authStateChanges().listen((user) async {
      final prevUser = _user;
      _user = user;
      try {
        if (user != null) {
          await _loadRole(user.uid);
          await _setupFcm(user.uid);
        } else if (prevUser != null) {
          // Explicit sign-out
          _fcmTokenRefreshSubscription?.cancel();
          _fcmTokenRefreshSubscription = null;
          _fcmTokenRefreshDebounce?.cancel();
          _role = 'farmer';
          _bio = '';
          _unreadCount = 0;
          final sp = await SharedPreferences.getInstance();
          await sp.remove(_keyRole);
          await sp.remove(_keyBio);
          await sp.remove(_keyUnreadCount);
        }
      } catch (e) {
        debugPrint('[UserPrefs] auth state handler error: $e');
      }
      notifyListeners();
    });
  }

  Future<void> _loadRole(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _role = (data['role'] ?? 'farmer') as String;
        _bio = (data['bio'] ?? '') as String;
        _unreadCount = (data['newLikeCount'] as int?) ?? 0;
        // On a new device, restore the avatar from Firestore if not cached locally
        if (_avatarBase64.isEmpty) {
          final remote = (data['avatarBase64'] ?? '') as String;
          if (remote.isNotEmpty) {
            _avatarBase64 = remote;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyAvatarBase64, remote);
          }
        }
        // Cache role/bio/unread locally for offline startups
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyRole, _role);
        await prefs.setString(_keyBio, _bio);
        await prefs.setInt(_keyUnreadCount, _unreadCount);
        // Record app open for analytics
        final lastOpenDate = data['lastOpenDate'] as String?;
        FirebaseService.recordAppOpen(uid, lastOpenDate);
      } else {
        _role = 'farmer';
        _bio = '';
        _unreadCount = 0;
        FirebaseService.recordAppOpen(uid, null);
      }
    } catch (_) {
      // Offline or error — keep cached values loaded at startup
    }
  }

  // ─── FCM setup ──────────────────────────────────────────────────────────

  // ─── App lifecycle: refresh role on foreground resume ───────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _user != null) {
      // Single Firestore read on app foreground — refreshes role if changed by admin
      _loadRole(_user!.uid).then((_) => notifyListeners()).catchError((_) {});
    }
  }

  Future<void> _setupFcm(String uid) async {
    try {
      // Request notification permission (Android 13+ / iOS)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _fcmPermissionDenied = true;
        notifyListeners();
        return;
      }

      // Fetch the FCM token and save it to Firestore
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseService.saveFcmToken(uid, token);
      }

      // Re-save the token when it rotates (1-second debounce to avoid rapid Firestore writes)
      _fcmTokenRefreshSubscription?.cancel();
      _fcmTokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _fcmTokenRefreshDebounce?.cancel();
        _fcmTokenRefreshDebounce =
            Timer(const Duration(seconds: 1), () {
          FirebaseService.saveFcmToken(uid, newToken);
        });
      });

      // Subscribe to the broadcast topic for system-wide alerts
      await FirebaseMessaging.instance.subscribeToTopic('broadcasts');
    } catch (_) {
      // FCM is unavailable in emulators or restricted environments — skip silently
    }
  }

  // ─── Unread count (loaded from Firestore on startup, then incremented by FCM) ──

  /// Call this when an FCM push notification is received (from main.dart foreground handler).
  void incrementUnreadCount() {
    _unreadCount++;
    notifyListeners();
    // Persist so force-quit doesn't reset the badge
    SharedPreferences.getInstance().then((p) => p.setInt(_keyUnreadCount, _unreadCount));
  }

  /// Call this when the notifications screen is opened — also resets Firestore newLikeCount.
  Future<void> resetLikeCount() async {
    _unreadCount = 0;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUnreadCount, 0);
    try {
      if (_user != null) await FirebaseService.resetLikeCount(_user!.uid);
    } catch (_) {}
  }

  // ─── Authentication ──────────────────────────────────────────────────────

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
    _fcmTokenRefreshSubscription?.cancel();
    _fcmTokenRefreshSubscription = null;
    _fcmTokenRefreshDebounce?.cancel();
    // Remove FCM token from Firestore before signing out
    try {
      final uid = _user?.uid;
      if (uid != null) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          // Remove from the tokens sub-collection
          await _db
              .collection('users')
              .doc(uid)
              .collection('tokens')
              .doc(token)
              .delete();
          // Also clear the legacy fcmToken field
          await _db
              .collection('users')
              .doc(uid)
              .update({'fcmToken': FieldValue.delete()});
        }
        await FirebaseMessaging.instance.deleteToken();
      }
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

  /// Update the avatar image (saved locally and backed up to Firestore).
  /// Throws if the base64 string exceeds 2 MB.
  Future<void> updateAvatar(String base64) async {
    const maxSize = 2 * 1024 * 1024; // 2 MB
    if (base64.length > maxSize) {
      throw Exception('Avatar image too large (max 2 MB)');
    }
    _avatarBase64 = base64;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAvatarBase64, base64);
    if (_user != null) {
      await _db.collection('users').doc(_user!.uid).set(
          {'avatarBase64': base64}, SetOptions(merge: true));
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _fcmTokenRefreshSubscription?.cancel();
    _fcmTokenRefreshDebounce?.cancel();
    super.dispose();
  }
}
