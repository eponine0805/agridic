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
  String _cropFilter = '';
  String _typeFilter = 'all';
  String _sortOption = 'newest';

  final _scrollCtrl = ScrollController();

  static const _crops = ['', 'Maize', 'Tomato', 'Bean', 'Potato', 'Coffee'];
  static const _cropLabels = ['All', 'Maize', 'Tomato', 'Bean', 'Potato', 'Coffee'];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<AppState>().loadMore();
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('Sort by',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              for (final entry in const [
                ('newest', Icons.schedule, 'Newest first'),
                ('likes', Icons.favorite_outline, 'Most liked'),
                ('distance', Icons.near_me_outlined, 'Closest first'),
              ])
                ListTile(
                  leading: Icon(entry.$2,
                      color: _sortOption == entry.$1
                          ? AppColors.primary
                          : AppColors.textSecondary),
                  title: Text(entry.$3,
                      style: TextStyle(
                          fontWeight: _sortOption == entry.$1
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _sortOption == entry.$1
                              ? AppColors.primary
                              : AppColors.textPrimary)),
                  trailing: _sortOption == entry.$1
                      ? const Icon(Icons.check, color: AppColors.primary, size: 18)
                      : null,
                  onTap: () {
                    setState(() => _sortOption = entry.$1);
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              // Filter chips + sort button
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < _crops.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(_cropLabels[i],
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _cropFilter == _crops[i]
                                      ? Colors.white
                                      : AppColors.textSecondary)),
                          selected: _cropFilter == _crops[i],
                          onSelected: (_) =>
                              setState(() => _cropFilter = _crops[i]),
                          selectedColor: AppColors.primary,
                          checkmarkColor: Colors.white,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                              color: _cropFilter == _crops[i]
                                  ? AppColors.primary
                                  : AppColors.divider),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    const SizedBox(width: 8),
                    const SizedBox(
                      height: 20,
                      child: VerticalDivider(color: AppColors.divider, width: 1),
                    ),
                    const SizedBox(width: 8),
                    for (final entry in const [
                      ('all', 'All'),
                      ('official', 'Official'),
                      ('community', 'Community'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(entry.$2,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _typeFilter == entry.$1
                                      ? Colors.white
                                      : AppColors.textSecondary)),
                          selected: _typeFilter == entry.$1,
                          onSelected: (_) =>
                              setState(() => _typeFilter = entry.$1),
                          selectedColor: AppColors.accent,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                              color: _typeFilter == entry.$1
                                  ? AppColors.accent
                                  : AppColors.divider),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _showSortSheet,
                      icon: const Icon(Icons.sort),
                      color: _sortOption != 'newest'
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      tooltip: 'Sort',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(
          child: Consumer<AppState>(
            builder: (context, state, _) => _buildFeed(state),
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
            Text('Loading…',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    final posts = state.filteredPosts(
      crop: _cropFilter,
      type: _typeFilter,
      sort: _sortOption,
    );

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text('No posts yet',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 8),
            const Text('Seed demo data from the top-right menu',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: state.refresh,
      child: ListView.builder(
        controller: _scrollCtrl,
        // +1 for the bottom indicator row
        itemCount: posts.length + 1,
        itemBuilder: (context, index) {
          if (index == posts.length) {
            // bottom indicator
            if (state.loadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2),
                ),
              );
            }
            if (!state.hasMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('— no more posts —',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              );
            }
            return const SizedBox.shrink();
          }
          return PostCard(
            post: posts[index],
            onTap: () => _openDetail(context, posts[index]),
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(post: post)),
    );
  }
}
