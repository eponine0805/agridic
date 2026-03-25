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
  bool locationPermissionDeniedForever = false;

  List<Post> _posts = [];
  List<Post>? _visiblePostsCache; // memoized cache for visiblePosts
  bool isLoading = true;
  bool isSeeding = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  /// Non-null when the last _loadInitial call failed.
  String? lastLoadError;

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

    // Process entries in order, removing each from the queue after success.
    // If the app crashes mid-upload, already-uploaded image URLs are preserved
    // in the queue entry so they are not re-uploaded on the next retry.
    int offset = 0;
    for (var i = 0; i < items.length; i++) {
      var data = items[i];
      try {
        final bool isNewFormat = data.containsKey('post');
        final postData = isNewFormat
            ? (data['post'] as Map<String, dynamic>)
            : data;
        var post = Post.fromMap(postData);
        var dirty = false; // whether the queue entry needs updating

        // Upload tweet image if a local path is still stored
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
            // Persist uploaded URL to the queue entry to prevent re-uploading on retry
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

        // Upload any report block images still stored as local paths
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
                updated.add(img); // keep local path for next retry
              }
            } else {
              updated.add(img);
            }
          }
          post = _rebuildPost(post, _contentWith(post.content, images: updated));
          dirty = true;
        }

        // Persist uploaded URLs before writing to Firestore (crash-safe)
        if (dirty) {
          final updatedEntry = Map<String, dynamic>.from(data);
          updatedEntry['post'] = post.toJson();
          await OfflineQueueService.updateAt(i - offset, updatedEntry);
        }

        await FirebaseService.savePost(post);

        // Remove the successfully processed entry from the queue
        await OfflineQueueService.removeAt(i - offset);
        offset++; // adjust index for subsequent removals
      } catch (e) {
        debugPrint('[OfflineQueue] failed to process queued post: $e');
        // Leave the failed entry in the queue for the next online reconnect
      }
    }

    pendingQueueCount = await OfflineQueueService.count();
    // Refresh feed to surface newly posted items
    if (pendingQueueCount == 0) await _loadInitial();
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Returns a new Post built from [post] with [content] replaced.
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

  /// Returns a new PostContent with only the specified fields overridden.
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

  /// Visible (non-hidden) posts — memoized until [_posts] is replaced.
  List<Post> get visiblePosts => _visiblePostsCache ??=
      _posts.where((p) => !p.isHidden).toList();

  /// Replace the post list and invalidate the memoized cache.
  void _setPosts(List<Post> newPosts) {
    _posts = newPosts;
    _visiblePostsCache = null;
  }

  List<Post> get officialPosts =>
      visiblePosts.where((p) => p.isOfficial && p.inDictionary).toList();

  // ─── Loading ────────────────────────────────────────────────────────────

  Future<void> _loadInitial() async {
    isLoading = true;
    notifyListeners();
    try {
      final result = await FirebaseService.fetchPostsPage();
      _setPosts(result.posts);
      _lastDoc = result.lastDoc;
      _hasMore = result.posts.length >= 20;
      lastLoadError = null;
    } catch (e) {
      debugPrint('[AppState] _loadInitial failed: $e');
      lastLoadError = 'Failed to load posts. Check your connection and try again.';
    }
    isLoading = false;
    notifyListeners();
  }

  /// Pull-to-refresh — fetches only posts newer than the top of the list.
  /// Costs 0 reads if there are no new posts.
  Future<void> refresh() async {
    try {
      final since = _posts.isNotEmpty ? _posts.first.timestamp : null;
      if (since == null) {
        await _loadInitial();
        return;
      }
      final newPosts = await FirebaseService.fetchPostsSince(since);
      if (newPosts.isNotEmpty) {
        _setPosts([...newPosts, ..._posts]);
        notifyListeners();
      }
      lastLoadError = null;
    } catch (e) {
      debugPrint('[AppState] refresh failed: $e');
    }
  }

  /// Load additional pages when the user scrolls to the bottom.
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

  // ─── Location ────────────────────────────────────────────────────────────

  Future<void> detectLocation() async {
    isDetectingLocation = true;
    notifyListeners();
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        locationPermissionDeniedForever = true;
        isDetectingLocation = false;
        notifyListeners();
        return;
      }
      if (perm == LocationPermission.denied) {
        isDetectingLocation = false;
        notifyListeners();
        return;
      }
      locationPermissionDeniedForever = false;
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

  // ─── Filtering ───────────────────────────────────────────────────────────

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

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> toggleLike(
      String postId, String userId, String likerName) async {
    final idx = _posts.indexWhere((p) => p.postId == postId);
    if (idx < 0) return;
    final post = _posts[idx];
    final alreadyLiked = post.likedBy.contains(userId);

    // Optimistic update — create a new Post instance, no direct mutation
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
      // Increment the notification counter only when liking someone else's post
      if (!alreadyLiked && post.userId != userId) {
        await FirebaseService.incrementLikeCount(post.userId);
      }
    } catch (_) {
      // Roll back to the original post on Firestore failure
      _posts[idx] = post;
      _visiblePostsCache = null;
      notifyListeners();
    }
  }

  /// Update a post's content locally and in Firestore (used for editing).
  Future<void> editPost(
      String postId, PostContent newContent, String editorUid) async {
    final idx = _posts.indexWhere((p) => p.postId == postId);
    if (idx < 0) return;
    // Optimistic update — keep original for rollback
    final original = _posts[idx];
    final now = DateTime.now();
    _posts[idx] = original.copyWith(
        content: newContent, editedAt: now, editedBy: editorUid);
    _visiblePostsCache = null;
    notifyListeners();
    try {
      await FirebaseService.editPost(postId, newContent, editorUid);
    } catch (e) {
      // Roll back on failure
      _posts[idx] = original;
      _visiblePostsCache = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Remove a post from the local list.
  void removePost(String postId) {
    _posts.removeWhere((p) => p.postId == postId);
    _visiblePostsCache = null;
    notifyListeners();
  }

  /// Fetch the latest version of a post from Firestore and update locally.
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
        _visiblePostsCache = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppState] reloadPost($postId) failed: $e');
    }
  }

  /// Add a post, queuing it offline if there is no connection.
  ///
  /// Returns `true`  — posted online successfully.
  /// Returns `false` — saved to the offline queue.
  /// Returns `null`  — offline queue is full.
  Future<bool?> addPost(Post post, {String? localTweetImagePath}) async {
    if (!isOnline) {
      final queued = await OfflineQueueService.enqueue(post,
          localTweetImagePath: localTweetImagePath);
      if (!queued) return null; // queue full
      pendingQueueCount = await OfflineQueueService.count();
      notifyListeners();
      return false; // saved to offline queue
    }
    await FirebaseService.savePost(post);
    // Re-fetch first page to surface the new post immediately
    final result = await FirebaseService.fetchPostsPage();
    _setPosts(result.posts);
    _lastDoc = result.lastDoc;
    _hasMore = result.posts.length >= 20;
    notifyListeners();
    return true; // online post succeeded
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

  /// Force-seed demo data and refresh the feed (used by admin tools).
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
