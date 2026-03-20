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
      final tokens = query
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((t) => t.length >= 2)
          .toList();

      if (tokens.isEmpty) {
        // 1文字クエリはそのまま単純 contains
        final q = query.toLowerCase();
        result = result
            .where((p) =>
                p.content.textShort.toLowerCase().contains(q) ||
                p.content.textFull.toLowerCase().contains(q) ||
                p.userName.toLowerCase().contains(q) ||
                p.dictTags.any((t) => t.toLowerCase().contains(q)))
            .toList();
      } else {
        // 複数トークン対応のスコアリング式ファジー検索
        final scored = <({Post post, double score})>[];
        for (final p in result) {
          final searchable = [
            p.content.textShort,
            p.content.textFull,
            p.content.textFullManual,
            p.userName,
            p.dictCrop,
            p.dictCategory,
            ...p.dictTags,
          ].join(' ').toLowerCase();

          final words = RegExp(r'\w+')
              .allMatches(searchable)
              .map((m) => m.group(0)!)
              .toList();

          double score = 0;
          for (final token in tokens) {
            if (searchable.contains(token)) {
              score += 2.0; // 完全部分一致
            } else if (token.length >= 3) {
              if (words.any((w) => w.startsWith(token))) {
                score += 1.5; // 単語の前方一致
              } else if (token.length >= 4 &&
                  searchable.contains(token.substring(0, token.length - 1))) {
                score += 0.8; // 末尾1文字省略（タイポ対応）
              }
            }
          }
          if (score > 0) scored.add((post: p, score: score));
        }
        // スコア降順、同スコア内は指定の並び順
        scored.sort((a, b) {
          final diff = b.score.compareTo(a.score);
          if (diff != 0) return diff;
          switch (sort) {
            case 'likes':
              return b.post.likes.compareTo(a.post.likes);
            case 'distance':
              return a.post.distanceKm.compareTo(b.post.distanceKm);
            default:
              return (b.post.timestamp ?? DateTime(0))
                  .compareTo(a.post.timestamp ?? DateTime(0));
          }
        });
        result = scored.map((e) => e.post).toList();
      }
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
