import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/post.dart';
import '../services/firebase_service.dart';

class AppState extends ChangeNotifier {
  (double, double) currentLocation = (-0.95, 36.87);
  bool locationReady = false;
  bool isDetectingLocation = false;

  List<Post> _posts = [];
  bool isLoading = true;
  bool isSeeding = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;

  AppState() {
    detectLocation();
    _loadInitial();
  }

  List<Post> get posts => _posts;

  List<Post> get visiblePosts => _posts.where((p) => !p.isHidden).toList();

  List<Post> get officialPosts =>
      visiblePosts.where((p) => p.isOfficial && p.inDictionary).toList();

  // ─── 読み込み ──────────────────────────────────────────────────

  Future<void> _loadInitial() async {
    isLoading = true;
    notifyListeners();
    try {
      final result = await FirebaseService.fetchPostsPage();
      _posts = result.posts;
      _lastDoc = result.lastDoc;
      _hasMore = result.posts.length >= 20;
    } catch (_) {}
    isLoading = false;
    notifyListeners();
  }

  /// 上に引っ張って更新 — 直近の投稿より新しいものだけ取得して先頭に追加
  /// 新着3件なら3 reads、新着なしなら0 reads
  Future<void> refresh() async {
    try {
      final since = _posts.isNotEmpty ? _posts.first.timestamp : null;
      if (since == null) {
        await _loadInitial();
        return;
      }
      final newPosts = await FirebaseService.fetchPostsSince(since);
      if (newPosts.isNotEmpty) {
        _posts = [...newPosts, ..._posts];
        notifyListeners();
      }
    } catch (_) {}
  }

  /// 下スクロールで追加読み込み
  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || _lastDoc == null) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final result = await FirebaseService.fetchPostsPage(after: _lastDoc);
      if (result.posts.isNotEmpty) {
        _posts = [..._posts, ...result.posts];
        _lastDoc = result.lastDoc ?? _lastDoc;
        _hasMore = result.posts.length >= 20;
      } else {
        _hasMore = false;
      }
    } catch (_) {}
    _loadingMore = false;
    notifyListeners();
  }

  // ─── 位置情報 ────────────────────────────────────────────────────

  Future<void> detectLocation() async {
    isDetectingLocation = true;
    notifyListeners();
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        isDetectingLocation = false;
        notifyListeners();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      currentLocation = (pos.latitude, pos.longitude);
      locationReady = true;
    } catch (_) {}
    isDetectingLocation = false;
    notifyListeners();
  }

  // ─── フィルタリング ───────────────────────────────────────────────

  List<Post> filteredPosts({
    String crop = '',
    String type = 'all',
    String sort = 'newest',
  }) {
    var result = visiblePosts.toList();

    if (crop.isNotEmpty) {
      result = result.where((p) => p.dictCrop == crop).toList();
    }

    if (type == 'official') {
      result = result.where((p) => p.isOfficial).toList();
    } else if (type == 'community') {
      result = result.where((p) => !p.isOfficial).toList();
    }

    switch (sort) {
      case 'likes':
        result.sort((a, b) => b.likes.compareTo(a.likes));
      case 'distance':
        result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      default:
        result.sort((a, b) =>
            (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
    }

    return result;
  }

  List<Post> postsBy(String userId) {
    final result = _posts.where((p) => p.userId == userId).toList();
    result.sort((a, b) =>
        (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
    return result;
  }

  // ─── 操作 ───────────────────────────────────────────────────────

  Future<void> toggleLike(String postId, String userId) async {
    await FirebaseService.toggleLike(postId, userId);
    // ローカルで楽観的更新（再取得不要）
    final idx = _posts.indexWhere((p) => p.postId == postId);
    if (idx >= 0) {
      final p = _posts[idx];
      final already = p.likedBy.contains(userId);
      if (already) {
        p.likes--;
        p.likedBy = p.likedBy.where((id) => id != userId).toList();
      } else {
        p.likes++;
        p.likedBy = [...p.likedBy, userId];
      }
      notifyListeners();
    }
  }

  Future<void> addPost(Post post) async {
    await FirebaseService.savePost(post);
    // 先頭ページを再取得して新投稿を即座に反映
    final result = await FirebaseService.fetchPostsPage();
    _posts = result.posts;
    _lastDoc = result.lastDoc;
    _hasMore = result.posts.length >= 20;
    notifyListeners();
  }

  Future<bool> seedDemoData() async {
    isSeeding = true;
    notifyListeners();
    final seeded = await FirebaseService.seedDemoData();
    if (seeded) {
      final result = await FirebaseService.fetchPostsPage();
      _posts = result.posts;
      _lastDoc = result.lastDoc;
      _hasMore = result.posts.length >= 20;
    }
    isSeeding = false;
    notifyListeners();
    return seeded;
  }

  String formatTime(DateTime? ts) {
    if (ts == null) return '';
    final delta = DateTime.now().difference(ts);
    final seconds = delta.inSeconds;
    if (seconds < 60) return 'now';
    if (seconds < 3600) return '${delta.inMinutes}m';
    if (seconds < 86400) return '${delta.inHours}h';
    return '${delta.inDays}d';
  }
}
