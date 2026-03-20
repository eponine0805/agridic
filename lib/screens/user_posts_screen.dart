import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../providers/user_prefs.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';
import '../widgets/post_card.dart';
import 'detail_screen.dart';

class UserPostsScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserPostsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserPostsScreen> createState() => _UserPostsScreenState();
}

class _UserPostsScreenState extends State<UserPostsScreen> {
  final List<Post> _posts = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final result =
          await FirebaseService.fetchPostsByUser(userId: widget.userId);
      _posts.addAll(result.posts);
      _lastDoc = result.lastDoc;
      _hasMore = result.posts.length >= 20;
    } catch (e) {
      debugPrint('[UserPostsScreen] loadInitial failed: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    _posts.clear();
    _lastDoc = null;
    _hasMore = true;
    await _loadInitial();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _loadingMore = true);
    try {
      final result = await FirebaseService.fetchPostsByUser(
        userId: widget.userId,
        after: _lastDoc,
      );
      if (result.posts.isNotEmpty) {
        _posts.addAll(result.posts);
        _lastDoc = result.lastDoc ?? _lastDoc;
        _hasMore = result.posts.length >= 20;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('[UserPostsScreen] loadMore failed: $e');
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: context.read<AppState>()),
        ChangeNotifierProvider.value(value: context.read<UserPrefs>()),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white.withOpacity(0.3),
                child: Text(
                  widget.userName.isNotEmpty
                      ? widget.userName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Text(widget.userName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          elevation: 2,
        ),
        body: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: _posts.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Text(
                              'No posts yet',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _posts.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _posts.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 2)),
                            );
                          }
                          final post = _posts[index];
                          return PostCard(
                            post: post,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DetailScreen(post: post)),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
