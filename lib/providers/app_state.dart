import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/post.dart';
import '../services/firebase_service.dart';

class AppState extends ChangeNotifier {
  String searchQuery = '';
  (double, double) currentLocation = (-0.95, 36.87);
  bool locationReady = false;
  bool isDetectingLocation = false;

  List<Post> _posts = [];
  bool isLoading = true;
  bool isSeeding = false;

  StreamSubscription<List<Post>>? _sub;

  AppState() {
    detectLocation();
    _sub = FirebaseService.streamPosts().listen(
      (posts) {
        _posts = posts;
        isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<Post> get posts => _posts;

  List<Post> get visiblePosts => _posts.where((p) => !p.isHidden).toList();

  List<Post> get officialPosts =>
      visiblePosts.where((p) => p.isOfficial && p.inDictionary).toList();

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

  List<Post> filteredPosts(
    String query, {
    String crop = '',
    String type = 'all',
    String sort = 'newest',
  }) {
    var result = visiblePosts.toList();

    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result
          .where((p) =>
              p.content.textShort.toLowerCase().contains(q) ||
              p.content.textFull.toLowerCase().contains(q) ||
              p.userName.toLowerCase().contains(q) ||
              p.dictTags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }

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

  Future<void> toggleLike(String postId, String userId) async {
    await FirebaseService.toggleLike(postId, userId);
    // ストリームが自動で更新
  }

  Future<void> addPost(Post post) async {
    await FirebaseService.savePost(post);
    // Firestoreストリームが自動で_postsを更新する
  }

  /// デモデータをFirestoreに投入する
  /// 既にデータがある場合は何もしない
  Future<bool> seedDemoData() async {
    isSeeding = true;
    notifyListeners();
    final seeded = await FirebaseService.seedDemoData();
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
