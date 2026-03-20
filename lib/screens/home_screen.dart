import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../services/dict_local_service.dart';
import '../utils/app_colors.dart';
import '../widgets/post_card.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.scrollController});
  final ScrollController? scrollController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _cropFilter = '';
  String _categoryFilter = '';
  String _typeFilter = 'all';
  String _sortOption = 'newest';

  // Filter panel state
  bool _filtersVisible = false;
  bool _cropsExpanded = false;

  final _ownScrollCtrl = ScrollController();
  ScrollController get _scrollCtrl =>
      widget.scrollController ?? _ownScrollCtrl;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ローカルキャッシュ（辞書ダウンロード済みデータ）
  List<Post> _dictCache = [];

  static const _crops = ['Maize', 'Tomato', 'Bean', 'Potato', 'Coffee'];

  // Category filters: label → dictCategory value (empty = no filter)
  static const _categoryFilters = [
    ('', 'All'),
    ('Pests & Diseases', 'Disease / Pest'),
    ('Growing Guide', 'Growing Guide'),
    ('Fertilizer', 'Fertilizer'),
    ('Harvest & Storage', 'Harvest & Storage'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadDictCache();
  }

  Future<void> _loadDictCache() async {
    final result = await DictLocalService.load();
    if (result.posts.isNotEmpty && mounted) {
      setState(() => _dictCache = result.posts);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _ownScrollCtrl.dispose(); // 外部コントローラは dispose しない
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<AppState>().loadMore();
    }
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Crops section ──────────────────────────────────────
          _FilterSectionHeader(
            label: 'Crops',
            isExpanded: _cropsExpanded,
            isActive: _cropFilter.isNotEmpty,
            onTap: () =>
                setState(() => _cropsExpanded = !_cropsExpanded),
            onClear: _cropFilter.isNotEmpty
                ? () => setState(() => _cropFilter = '')
                : null,
          ),
          if (_cropsExpanded) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _crops.map((crop) {
                final selected = _cropFilter == crop;
                return FilterChip(
                  label: Text(crop,
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              selected ? Colors.white : AppColors.textSecondary)),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _cropFilter = selected ? '' : crop),
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  backgroundColor: AppColors.background,
                  side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.divider),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          // ── Category section ───────────────────────────────────
          const Text('Category',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _categoryFilters.map((entry) {
              final (value, label) = entry;
              final selected = _categoryFilter == value;
              return FilterChip(
                label: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary)),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _categoryFilter = selected ? '' : value),
                selectedColor: AppColors.accent,
                checkmarkColor: Colors.white,
                backgroundColor: AppColors.background,
                side: BorderSide(
                    color:
                        selected ? AppColors.accent : AppColors.divider),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          // ── Post type section ──────────────────────────────────
          const Text('Post type',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final entry in const [
                ('all', 'All'),
                ('official', 'Official'),
                ('community', 'Community'),
              ])
                FilterChip(
                  label: Text(entry.$2,
                      style: TextStyle(
                          fontSize: 12,
                          color: _typeFilter == entry.$1
                              ? Colors.white
                              : AppColors.textSecondary)),
                  selected: _typeFilter == entry.$1,
                  onSelected: (_) =>
                      setState(() => _typeFilter = entry.$1),
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  backgroundColor: AppColors.background,
                  side: BorderSide(
                      color: _typeFilter == entry.$1
                          ? AppColors.primary
                          : AppColors.divider),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          // Clear all
          if (_hasActiveFilters) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _cropFilter = '';
                  _categoryFilter = '';
                  _typeFilter = 'all';
                }),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear all filters',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
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

  bool get _hasActiveFilters =>
      _cropFilter.isNotEmpty ||
      _categoryFilter.isNotEmpty ||
      _typeFilter != 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              // Search bar + filter toggle
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search official guides…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Filter toggle button
                  _FilterToggleButton(
                    isOpen: _filtersVisible,
                    hasActive: _hasActiveFilters,
                    onTap: () =>
                        setState(() => _filtersVisible = !_filtersVisible),
                  ),
                  // Sort button
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
              // Expandable filter panel
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: _filtersVisible
                    ? _buildFilterPanel()
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(
          child: _searchQuery.isNotEmpty
              ? _buildDictResults()
              : Consumer<AppState>(
                  builder: (context, state, _) => _buildFeed(state),
                ),
        ),
      ],
    );
  }

  /// ローカルキャッシュに対してファジー検索（Firestoreへの読み取り0回）
  Widget _buildDictResults() {
    if (_dictCache.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download_outlined,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            const Text('Dictionary not downloaded yet',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            const Text('Go to the Dictionary tab to download guides for offline use',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final tokens = _searchQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();

    List<Post> results;
    if (tokens.isEmpty) {
      results = _dictCache.where((p) {
        final s = '${p.content.textShort} ${p.content.textFull} '
            '${p.dictCrop} ${p.dictCategory} ${p.dictTags.join(' ')}'
            .toLowerCase();
        return s.contains(_searchQuery);
      }).toList();
    } else {
      final scored = <({Post post, double score})>[];
      for (final p in _dictCache) {
        final s = [
          p.content.textShort,
          p.content.textFull,
          p.dictCrop,
          p.dictCategory,
          ...p.dictTags,
        ].join(' ').toLowerCase();
        final words =
            RegExp(r'\w+').allMatches(s).map((m) => m.group(0)!).toList();
        double score = 0;
        for (final token in tokens) {
          if (s.contains(token)) {
            score += 2.0;
          } else if (token.length >= 3 &&
              words.any((w) => w.startsWith(token))) {
            score += 1.5;
          } else if (token.length >= 4 &&
              s.contains(token.substring(0, token.length - 1))) {
            score += 0.8;
          }
        }
        if (score > 0) scored.add((post: p, score: score));
      }
      scored.sort((a, b) => b.score.compareTo(a.score));
      results = scored.map((e) => e.post).toList();
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text('No guides found for "$_searchQuery"',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            const Text('Try a different keyword',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '⭐ ${results.length} official guide${results.length == 1 ? '' : 's'} found',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600),
          ),
        ),
        ...results.map((p) => _DictResultTile(
              post: p,
              onTap: () => _openDetail(context, p),
            )),
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
      category: _categoryFilter,
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

class _DictResultTile extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  const _DictResultTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            left: const BorderSide(color: AppColors.primary, width: 4),
            right:
                BorderSide(color: AppColors.primary.withOpacity(0.2)),
            bottom:
                BorderSide(color: AppColors.primary.withOpacity(0.2)),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star,
                      color: AppColors.verifiedGold, size: 13),
                  const SizedBox(width: 4),
                  const Text('Official Guide',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.verifiedGold,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (post.dictCrop.isNotEmpty)
                    _Tag(post.dictCrop),
                  if (post.dictCategory.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _Tag(post.dictCategory),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                post.content.textShort,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(post.userName,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  const Row(
                    children: [
                      Text('Read more',
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

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

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
          style: const TextStyle(fontSize: 10, color: AppColors.primaryDark)),
    );
  }
}

// Filter toggle button (funnel icon with active indicator)
class _FilterToggleButton extends StatelessWidget {
  final bool isOpen;
  final bool hasActive;
  final VoidCallback onTap;

  const _FilterToggleButton({
    required this.isOpen,
    required this.hasActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (isOpen || hasActive)
              ? AppColors.primary.withOpacity(0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (isOpen || hasActive) ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.tune,
              size: 18,
              color: (isOpen || hasActive)
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            if (hasActive)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Filter section header with expand/collapse and clear button
class _FilterSectionHeader extends StatelessWidget {
  final String label;
  final bool isExpanded;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterSectionHeader({
    required this.label,
    required this.isExpanded,
    required this.isActive,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 16,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 6),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
          const Spacer(),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close,
                  size: 14, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
