import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../services/firebase_service.dart';

class AppState extends ChangeNotifier {
  String searchQuery = '';
  (double, double) currentLocation = (-0.95, 36.87);

  List<Post> _posts = [];
  bool isLoading = true;
  bool isSeeding = false;

  StreamSubscription<List<Post>>? _sub;

  AppState() {
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
      visiblePosts.where((p) => p.isOfficial && p.dictCrop.isNotEmpty).toList();

  List<Post> filteredPosts(String query) {
    if (query.isEmpty) {
      final all = visiblePosts.toList();
      all.sort((a, b) =>
          (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
      return all;
    }
    final q = query.toLowerCase();
    return visiblePosts
        .where((p) =>
            p.content.textShort.toLowerCase().contains(q) ||
            p.content.textFull.toLowerCase().contains(q) ||
            p.userName.toLowerCase().contains(q) ||
            p.dictTags.any((t) => t.toLowerCase().contains(q)))
        .toList();
  }

  void reportPost(Post post) {
    post.reports++;
    if (post.reports >= 3) post.isHidden = true;
    notifyListeners();
    FirebaseService.updatePost(post.postId, {
      'reports': post.reports,
      'isHidden': post.isHidden,
    });
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
