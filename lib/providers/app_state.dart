import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../services/firebase_service.dart';
import '../services/offline_queue_service.dart';

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

  bool isOnline = true;
  int pendingQueueCount = 0;

  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;

  AppState() {
    detectLocation();
    _loadInitial();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    isOnline = !result.contains(ConnectivityResult.none);
    pendingQueueCount = await OfflineQueueService.count();
    notifyListeners();

    Connectivity().onConnectivityChanged.listen((results) async {
      final wasOffline = !isOnline;
      isOnline = !results.contains(ConnectivityResult.none);
      pendingQueueCount = await OfflineQueueService.count();
      notifyListeners();
      if (wasOffline && isOnline) {
        await _processOfflineQueue();
      }
    });
  }

  Future<void> _processOfflineQueue() async {
    final items = await OfflineQueueService.getAll();
    if (items.isEmpty) return;
    for (final data in items) {
      try {
        // 新フォーマット: {'post': {...}, 'localTweetImagePath': '...'}
        // 旧フォーマット: 直接 postJson（後方互換）
        final bool isNewFormat = data.containsKey('post');
        final postData = isNewFormat
            ? (data['post'] as Map<String, dynamic>)
            : data;
        var post = Post.fromMap(postData);

        // ツイート画像のローカルパスがあればアップロード
        final tweetImagePath = data['localTweetImagePath'] as String?;
        if (tweetImagePath != null) {
          try {
            final urls = await FirebaseService.uploadImage(
                post.postId, XFile(tweetImagePath));
            post = _rebuildPost(
              post,
              _contentWith(post.content,
                  imageLow: urls.low, imageHigh: urls.high),
            );
          } catch (e) {
            debugPrint('[OfflineQueue] tweet image upload failed: $e');
          }
        }

        // レポートのブロック画像（content.images にローカルパスが入っている場合）
        if (post.content.images.any((img) => !img.startsWith('http'))) {
          final updated = <String>[];
          for (var i = 0; i < post.content.images.length; i++) {
            final img = post.content.images[i];
            if (!img.startsWith('http')) {
              try {
                final urls = await FirebaseService.uploadImage(
                    '${post.postId}_img_$i', XFile(img));
                updated.add(urls.high.isNotEmpty ? urls.high : urls.low);
              } catch (e) {
                debugPrint('[OfflineQueue] block image upload failed (index $i): $e');
                updated.add('');
              }
            } else {
              updated.add(img);
            }
          }
          post = _rebuildPost(post, _contentWith(post.content, images: updated));
        }

        await FirebaseService.savePost(post);
      } catch (e) {
        debugPrint('[OfflineQueue] failed to process queued post: $e');
      }
    }
    await OfflineQueueService.clear();
    pendingQueueCount = 0;
    // 投稿反映のためリフレッシュ
    await _loadInitial();
  }

  /// Post を新しい PostContent で再生成するヘルパー
  Post _rebuildPost(Post post, PostContent content) => Post(
        postId: post.postId,
        userId: post.userId,
        isOfficial: post.isOfficial,
        userRole: post.userRole,
        userName: post.userName,
        content: content,
        location: post.location,
        timestamp: post.timestamp,
        isVerified: post.isVerified,
        reports: post.reports,
        isHidden: post.isHidden,
        likes: post.likes,
        likedBy: post.likedBy,
        distanceKm: post.distanceKm,
        viewMode: post.viewMode,
        dictCrop: post.dictCrop,
        dictCategory: post.dictCategory,
        dictTags: post.dictTags,
        inDictionary: post.inDictionary,
      );

  /// PostContent の一部フィールドだけ差し替えるヘルパー
  PostContent _contentWith(PostContent c,
          {String? imageLow, String? imageHigh, List<String>? images}) =>
      PostContent(
        textShort: c.textShort,
        textFull: c.textFull,
        textFullManual: c.textFullManual,
        textFullVisual: c.textFullVisual,
        steps: c.steps,
        imageLow: imageLow ?? c.imageLow,
        imageHigh: imageHigh ?? c.imageHigh,
        images: images ?? c.images,
      );

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
    } catch (e) {
      debugPrint('[AppState] _loadInitial failed: $e');
    }
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
    } catch (e) {
      debugPrint('[AppState] refresh failed: $e');
    }
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
    } catch (e) {
      debugPrint('[AppState] loadMore failed: $e');
    }
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
    } catch (e) {
      debugPrint('[AppState] detectLocation failed: $e');
    }
    isDetectingLocation = false;
    notifyListeners();
  }

  // ─── フィルタリング ───────────────────────────────────────────────

  List<Post> filteredPosts({
    String crop = '',
    String type = 'all',
    String sort = 'newest',
    String category = '',
  }) {
    var result = visiblePosts.toList();

    if (crop.isNotEmpty) {
      result = result.where((p) => p.dictCrop == crop).toList();
    }

    if (category.isNotEmpty) {
      result = result.where((p) => p.dictCategory == category).toList();
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

  Future<void> toggleLike(
      String postId, String userId, String likerName) async {
    final idx = _posts.indexWhere((p) => p.postId == postId);
    if (idx < 0) return;
    final post = _posts[idx];
    final alreadyLiked = post.likedBy.contains(userId);

    // ローカルで楽観的更新（Firestore読み込み不要）
    if (alreadyLiked) {
      post.likes--;
      post.likedBy = post.likedBy.where((id) => id != userId).toList();
    } else {
      post.likes++;
      post.likedBy = [...post.likedBy, userId];
    }
    notifyListeners();

    try {
      await FirebaseService.toggleLike(postId, userId, alreadyLiked);
      // いいね追加時に通知を作成（自分の投稿でない場合のみ）
      if (!alreadyLiked && post.userId != userId) {
        await FirebaseService.addNotification(
          userId: post.userId,
          type: 'like',
          title: '$likerName がいいねしました',
          body: post.content.textShort,
          postId: postId,
        );
      }
    } catch (_) {
      // Firestore 失敗時はロールバック
      if (alreadyLiked) {
        post.likes++;
        post.likedBy = [...post.likedBy, userId];
      } else {
        post.likes--;
        post.likedBy = post.likedBy.where((id) => id != userId).toList();
      }
      notifyListeners();
    }
  }

  /// 投稿をローカルリストから削除
  void removePost(String postId) {
    _posts.removeWhere((p) => p.postId == postId);
    notifyListeners();
  }

  /// Firestoreから最新の投稿を取得してローカルを更新
  Future<void> reloadPost(String postId) async {
    try {
      final updated = await FirebaseService.fetchPostById(postId);
      if (updated == null) {
        removePost(postId);
        return;
      }
      final idx = _posts.indexWhere((p) => p.postId == postId);
      if (idx >= 0) {
        _posts[idx] = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppState] reloadPost($postId) failed: $e');
    }
  }

  /// 投稿を追加（オフライン時はキューに保存）
  /// [localTweetImagePath]: オフライン時の添付画像ローカルパス。
  ///   オンライン復帰時に自動アップロードされる。
  Future<bool> addPost(Post post, {String? localTweetImagePath}) async {
    if (!isOnline) {
      await OfflineQueueService.enqueue(post,
          localTweetImagePath: localTweetImagePath);
      pendingQueueCount = await OfflineQueueService.count();
      notifyListeners();
      return false; // オフラインキューに保存
    }
    await FirebaseService.savePost(post);
    // 先頭ページを再取得して新投稿を即座に反映
    final result = await FirebaseService.fetchPostsPage();
    _posts = result.posts;
    _lastDoc = result.lastDoc;
    _hasMore = result.posts.length >= 20;
    notifyListeners();
    return true; // オンライン投稿成功
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

  /// デモデータを強制投入してフィードを更新（デバッグ用）
  Future<void> forceSeedDemoData() async {
    isSeeding = true;
    notifyListeners();
    await FirebaseService.forceSeedDemoData();
    final result = await FirebaseService.fetchPostsPage();
    _posts = result.posts;
    _lastDoc = result.lastDoc;
    _hasMore = result.posts.length >= 20;
    isSeeding = false;
    notifyListeners();
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
