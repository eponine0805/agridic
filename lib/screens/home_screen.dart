import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../utils/app_colors.dart';
import '../widgets/post_card.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    setState(() => _searchQuery = value);
  }

  void _resetSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearch,
            onSubmitted: _onSearch,
            decoration: InputDecoration(
              hintText: 'Search timeline or tags...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _resetSearch,
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        // Feed
        Expanded(
          child: Consumer<AppState>(
            builder: (context, state, _) {
              return _buildFeed(state);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeed(AppState state) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Firestore から読み込み中…',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults(state);
    }
    final posts = state.filteredPosts('');
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text('投稿がありません',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 8),
            const Text('右上メニューからデモデータを投入できます',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return PostCard(
          post: post,
          onTap: () => _openDetail(context, post),
        );
      },
    );
  }

  Widget _buildSearchResults(AppState state) {
    final all = state.filteredPosts(_searchQuery);
    final officials = all.where((p) => p.isOfficial).toList()
      ..sort((a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
    final farmers = all.where((p) => !p.isOfficial).toList()
      ..sort((a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));

    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text('No results for "$_searchQuery"', style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (officials.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: const [
                Icon(Icons.verified_user, size: 14, color: AppColors.primary),
                SizedBox(width: 4),
                Text('Official Results', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          ...officials.map((p) => PostCard(post: p, onTap: () => _openDetail(context, p))),
        ],
        if (farmers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: const Text('Discussions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          ...farmers.map((p) => PostCard(post: p, onTap: () => _openDetail(context, p))),
        ],
      ],
    );
  }

  void _openDetail(BuildContext context, Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(post: post)),
    );
  }
}
