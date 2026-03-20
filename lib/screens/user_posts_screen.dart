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
  final bool isOwn;

  const UserPostsScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.isOwn = false,
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

  Future<void> _editProfile(BuildContext context) async {
    final userPrefs = context.read<UserPrefs>();
    final nameCtrl = TextEditingController(text: userPrefs.userName);
    final bioCtrl = TextEditingController(text: userPrefs.userBio);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell us about yourself…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final nameErr = await userPrefs.updateDisplayName(nameCtrl.text);
      final bioErr = await userPrefs.updateBio(bioCtrl.text);
      if (!context.mounted) return;
      final err = nameErr ?? bioErr;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err),
          backgroundColor: AppColors.danger,
        ));
      }
    }
    nameCtrl.dispose();
    bioCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: context.read<AppState>()),
        ChangeNotifierProvider.value(value: context.read<UserPrefs>()),
      ],
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              _buildSliverHeader(context),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_posts.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No posts yet',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                )
              else ...[
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _posts.length) return null;
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
                    childCount: _posts.length,
                  ),
                ),
                if (_loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2)),
                    ),
                  )
                else if (!_hasMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('— no more posts —',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSliverHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      actions: widget.isOwn
          ? [
              Consumer<UserPrefs>(
                builder: (context, userPrefs, _) => IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  onPressed: () => _editProfile(context),
                  tooltip: 'Edit profile',
                ),
              ),
            ]
          : null,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          color: AppColors.primary,
          child: SafeArea(
            child: widget.isOwn
                ? Consumer<UserPrefs>(
                    builder: (context, userPrefs, _) =>
                        _ProfileHeader(
                          userName: userPrefs.userName,
                          userBio: userPrefs.userBio,
                          userRole: userPrefs.userRole,
                          postCount: _posts.length,
                        ),
                  )
                : _ProfileHeader(
                    userName: widget.userName,
                    userBio: '',
                    userRole: '',
                    postCount: _posts.length,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String userName;
  final String userBio;
  final String userRole;
  final int postCount;

  const _ProfileHeader({
    required this.userName,
    required this.userBio,
    required this.userRole,
    required this.postCount,
  });

  Color _roleColor(String role) => switch (role) {
        'admin' => AppColors.danger,
        'expert' => const Color(0xFF1DA1F2),
        _ => Colors.white54,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    if (userRole.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _roleColor(userRole).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _roleColor(userRole).withOpacity(0.6)),
                        ),
                        child: Text(
                          userRole.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _roleColor(userRole)),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '$postCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Posts',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          if (userBio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              userBio,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
