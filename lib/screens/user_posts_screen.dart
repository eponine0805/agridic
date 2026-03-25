import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../providers/user_prefs.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_editor.dart';
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

class _UserPostsScreenState extends State<UserPostsScreen>
    with SingleTickerProviderStateMixin {
  final List<Post> _allPosts = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  late final TabController _tabController;

  List<Post> get _tweets => _allPosts.where((p) => p.isTweet).toList();
  List<Post> get _reports => _allPosts.where((p) => p.isReport).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await FirebaseService.fetchPostsByUser(userId: widget.userId);
      _allPosts.addAll(result.posts);
      _lastDoc = result.lastDoc;
      _hasMore = result.posts.length >= 20;
    } catch (e) {
      debugPrint('[UserPostsScreen] loadInitial failed: $e');
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    _allPosts.clear();
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
        _allPosts.addAll(result.posts);
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

  Future<void> _editAvatar(BuildContext context) async {
    await showAvatarEditor(context);
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
          body: NestedScrollView(
            headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
              _buildSliverHeader(context, innerBoxIsScrolled),
            ],
            body: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _error != null
                    ? _buildErrorState()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPostList(_tweets, 'No tweets yet'),
                          _buildPostList(_reports, 'No reports yet'),
                        ],
                      ),
          ),
        );
      }),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: AppColors.textSecondary, size: 40),
            const SizedBox(height: 12),
            const Text('Could not load posts',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              _error!.contains('index')
                  ? 'Firestore index not deployed. Run: firebase deploy --only firestore:indexes'
                  : _error!,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList(List<Post> posts, String emptyLabel) {
    if (posts.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
            _loadMore();
          }
          return false;
        },
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: posts.length + (_loadingMore ? 1 : (!_hasMore ? 1 : 0)),
          itemBuilder: (context, index) {
            if (index >= posts.length) {
              if (_loadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2)),
                );
              }
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('— no more posts —',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              );
            }
            final post = posts[index];
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
    );
  }

  Widget _buildSliverHeader(BuildContext context, bool innerBoxIsScrolled) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      forceElevated: innerBoxIsScrolled,
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
                          tweetCount: _tweets.length,
                          reportCount: _reports.length,
                          avatarBase64: userPrefs.avatarBase64,
                          onEditAvatar: () => _editAvatar(context),
                        ),
                  )
                : _ProfileHeader(
                    userName: widget.userName,
                    userBio: '',
                    userRole: '',
                    tweetCount: _tweets.length,
                    reportCount: _reports.length,
                    avatarBase64: _allPosts.isNotEmpty
                        ? _allPosts.first.avatarBase64
                        : '',
                  ),
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        tabs: [
          Tab(text: 'Tweets (${_tweets.length})'),
          Tab(text: 'Reports (${_reports.length})'),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String userName;
  final String userBio;
  final String userRole;
  final int tweetCount;
  final int reportCount;
  final String avatarBase64;
  final VoidCallback? onEditAvatar;

  const _ProfileHeader({
    required this.userName,
    required this.userBio,
    required this.userRole,
    required this.tweetCount,
    required this.reportCount,
    this.avatarBase64 = '',
    this.onEditAvatar,
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
              Stack(
                children: [
                  avatarBase64.isNotEmpty
                      ? AvatarImage(base64: avatarBase64, radius: 32)
                      : CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white,
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                  if (onEditAvatar != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: onEditAvatar,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 14, color: AppColors.primary),
                        ),
                      ),
                    ),
                ],
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CountChip(count: tweetCount, label: 'Tweets'),
                  const SizedBox(width: 12),
                  _CountChip(count: reportCount, label: 'Reports'),
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
          const SizedBox(height: 52),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;
  final String label;
  const _CountChip({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$count',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}
