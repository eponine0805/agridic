import 'dart:async';
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
  List<Post>? _visiblePostsCache; // visiblePosts のメモ化キャッシュ
  bool isLoading = true;
  bool isSeeding = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  bool isOnline = true;
  int pendingQueueCount = 0;

  StreamSubscription? _connectivitySubscription;
  bool _processingQueue = false;

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

    _connectivitySubscription =
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
    if (_processingQueue) return;
    _processingQueue = true;
    try {
      await _processOfflineQueueInternal();
    } finally {
      _processingQueue = false;
    }
  }

  Future<void> _processOfflineQueueInternal() async {
    final items = await OfflineQueueService.getAll();
    if (items.isEmpty) return;

    // 先頭から順に処理し、成功したものを1件ずつキューから削除する
    // → クラッシュしても処理済み画像URLがキューに保存されており、再起動後に重複アップロードしない
    int offset = 0;
    for (var i = 0; i < items.length; i++) {
      var data = items[i];
      try {
        final bool isNewFormat = data.containsKey('post');
        final postData = isNewFormat
            ? (data['post'] as Map<String, dynamic>)
            : data;
        var post = Post.fromMap(postData);
        var dirty = false; // キューエントリを更新すべきか

        // ツイート画像のローカルパスがあればアップロード
        final tweetImagePath = data['localTweetImagePath'] as String?;
        if (tweetImagePath != null &&
            !tweetImagePath.startsWith('http') &&
            !tweetImagePath.startsWith('data:')) {
          try {
            final urls = await FirebaseService.uploadImage(
                post.postId, XFile(tweetImagePath));
            post = _rebuildPost(
              post,
              _contentWith(post.content,
                  imageLow: urls.low, imageHigh: urls.high),
            );
            // アップロード済み URL をキューエントリへ反映（クラッシュ再試行時に再アップロードしない）
            final updatedEntry = Map<String, dynamic>.from(data);
            updatedEntry['post'] = post.toJson();
            updatedEntry.remove('localTweetImagePath');
            await OfflineQueueService.updateAt(i - offset, updatedEntry);
            data = updatedEntry;
            dirty = true;
          } catch (e) {
            debugPrint('[OfflineQueue] tweet image upload failed: $e');
          }
        }

        // レポートのブロック画像（ローカルパスが残っている場合）
        if (post.content.images.any((img) =>
            !img.startsWith('http') && !img.startsWith('data:'))) {
          final updated = <String>[];
          for (var j = 0; j < post.content.images.length; j++) {
            final img = post.content.images[j];
            if (!img.startsWith('http') && !img.startsWith('data:')) {
              try {
                final urls = await FirebaseService.uploadImage(
                    '${post.postId}_img_$j', XFile(img));
                updated.add(urls.high.isNotEmpty ? urls.high : urls.low);
              } catch (e) {
                debugPrint('[OfflineQueue] block image upload failed ($j): $e');
                updated.add(img); // 失敗したままにして次回再試行
              }
            } else {
              updated.add(img);
            }
          }
          post = _rebuildPost(post, _contentWith(post.content, images: updated));
          dirty = true;
        }

        // アップロード済み URL をキューへ反映（Firestore書き込み前に保存）
        if (dirty) {
          final updatedEntry = Map<String, dynamic>.from(data);
          updatedEntry['post'] = post.toJson();
          await OfflineQueueService.updateAt(i - offset, updatedEntry);
        }

        await FirebaseService.savePost(post);

        // Firestore書き込み成功後に1件削除
        await OfflineQueueService.removeAt(i - offset);
        offset++; // 削除した分だけインデックスをずらす
      } catch (e) {
        debugPrint('[OfflineQueue] failed to process queued post: $e');
        // 失敗したエントリはキューに残し、次回オンライン復帰時に再試行
      }
    }

    pendingQueueCount = await OfflineQueueService.count();
    // 投稿反映のためリフレッシュ
    if (pendingQueueCount == 0) await _loadInitial();
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
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

  /// isHidden でないポストのリスト（メモ化：_posts が差し替わるまでキャッシュを再利用）
  List<Post> get visiblePosts => _visiblePostsCache ??=
      _posts.where((p) => !p.isHidden).toList();

  /// _posts を差し替えるときはキャッシュを同時に無効化する
  void _setPosts(List<Post> newPosts) {
    _posts = newPosts;
    _visiblePostsCache = null;
  }

  List<Post> get officialPosts =>
      visiblePosts.where((p) => p.isOfficial && p.inDictionary).toList();

  // ─── 読み込み ──────────────────────────────────────────────────

  Future<void> _loadInitial() async {
    isLoading = true;
    notifyListeners();
    try {
      final result = await FirebaseService.fetchPostsPage();
_setPosts(result.posts);
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
        _setPosts([...newPosts, ..._posts];
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
_setPosts([..._posts, ...result.posts]);
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

    // copyWith で新しい Post インスタンスを作って楽観的更新（直接ミューテーションなし）
    final optimistic = alreadyLiked
        ? post.copyWith(
            likes: post.likes - 1,
            likedBy: post.likedBy.where((id) => id != userId).toList(),
          )
        : post.copyWith(
            likes: post.likes + 1,
            likedBy: [...post.likedBy, userId],
          );
    _posts[idx] = optimistic;
    _visiblePostsCache = null;
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
      // Firestore 失敗時はロールバック（元の post に戻す）
      _posts[idx] = post;
      _visiblePostsCache = null;
      notifyListeners();
    }
  }

  /// 投稿のコンテンツをローカル + Firestore で更新（編集用）
  Future<void> editPost(String postId, PostContent newContent) async {
    final idx = _posts.indexWhere((p) => p.postId == postId);
    if (idx < 0) return;
    // 楽観的更新
    final updated = _posts[idx].copyWith(content: newContent);
    _posts[idx] = updated;
    _visiblePostsCache = null;
    notifyListeners();
    try {
      await FirebaseService.editPost(postId, newContent);
    } catch (e) {
      // ロールバック
      _posts[idx] = _posts[idx].copyWith(content: _posts[idx].content);
      _visiblePostsCache = null;
      notifyListeners();
      rethrow;
    }
  }

  /// 投稿をローカルリストから削除
  void removePost(String postId) {
    _posts.removeWhere((p) => p.postId == postId);
    _visiblePostsCache = null; // キャッシュ無効化
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
        _visiblePostsCache = null; // キャッシュ無効化
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppState] reloadPost($postId) failed: $e');
    }
  }

  /// 投稿を追加（オフライン時はキューに保存）
  /// [localTweetImagePath]: オフライン時の添付画像ローカルパス。
  ///   オンライン復帰時に自動アップロードされる。
  /// 戻り値: true = オンライン投稿成功 / false = オフラインキュー保存 / null = キュー満杯
  Future<bool?> addPost(Post post, {String? localTweetImagePath}) async {
    if (!isOnline) {
      final queued = await OfflineQueueService.enqueue(post,
          localTweetImagePath: localTweetImagePath);
      if (!queued) return null; // キュー満杯
      pendingQueueCount = await OfflineQueueService.count();
      notifyListeners();
      return false; // オフラインキューに保存
    }
    await FirebaseService.savePost(post);
    // 先頭ページを再取得して新投稿を即座に反映
    final result = await FirebaseService.fetchPostsPage();
_setPosts(result.posts);
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
_setPosts(result.posts);
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
_setPosts(result.posts);
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
