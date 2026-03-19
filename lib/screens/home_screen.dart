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
              hintText: '農薬・作物・病気を検索…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _resetSearch,
                    )
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
      ..sort((a, b) =>
          (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
    final farmers = all.where((p) => !p.isOfficial).toList()
      ..sort((a, b) =>
          (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));

    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text('"$_searchQuery" に一致する情報が見つかりません',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            const Text('辞書タブで作物・カテゴリを探せます',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // ── 辞書降臨バナー ──
        if (officials.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.modeActive,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '⭐ 公式ガイドが見つかりました (${officials.length}件)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          ...officials.map((p) => _OfficialSearchCard(
                post: p,
                onTap: () => _openDetail(context, p),
              )),
        ],
        // ── コミュニティの声 ──
        if (farmers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              officials.isEmpty
                  ? '検索結果 — コミュニティの声'
                  : 'コミュニティの声',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary),
            ),
          ),
          ...farmers.map((p) => PostCard(
                post: p,
                onTap: () => _openDetail(context, p),
              )),
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

/// 検索時に「辞書エントリー」として表示する公式投稿カード
class _OfficialSearchCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const _OfficialSearchCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            left: const BorderSide(color: AppColors.primary, width: 4),
            right: BorderSide(color: AppColors.primary.withOpacity(0.2)),
            bottom: BorderSide(color: AppColors.primary.withOpacity(0.2)),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge row
              Row(
                children: [
                  const Icon(Icons.star,
                      color: AppColors.verifiedGold, size: 14),
                  const SizedBox(width: 4),
                  const Text('公式ガイド',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.verifiedGold,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (post.dictCrop.isNotEmpty) _SmallTag(post.dictCrop),
                  if (post.dictCategory.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _SmallTag(post.dictCategory),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.content.textShort,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (post.dictTags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: post.dictTags
                      .take(4)
                      .map((t) => _SmallTag('#$t'))
                      .toList(),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(post.userName,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  const Row(
                    children: [
                      Text('詳細を読む',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios,
                          size: 10, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  final String label;
  const _SmallTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.modeActive,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10, color: AppColors.primaryDark)),
    );
  }
}
