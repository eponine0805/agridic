import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../utils/app_colors.dart';
import 'detail_screen.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final List<String> _path = [];
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  static const Map<String, String> _cropIcons = {
    'Maize': '🌽',
    'Tomato': '🍅',
    'Bean': '🫘',
    'Potato': '🥔',
    'Coffee': '☕',
  };

  static const Map<String, IconData> _catIcons = {
    'Growing Guide': Icons.menu_book,
    'Pests & Diseases': Icons.bug_report,
    'Fertilizer': Icons.science,
    'Harvest & Storage': Icons.warehouse,
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Post> _getDictPosts(AppState state) =>
      state.posts.where((p) => p.isOfficial && p.inDictionary).toList();

  Map<String, int> _getCrops(AppState state) {
    final map = <String, int>{};
    for (final p in _getDictPosts(state)) {
      map[p.dictCrop] = (map[p.dictCrop] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> _getCategories(AppState state, String crop) {
    final map = <String, int>{};
    for (final p in _getDictPosts(state)) {
      if (p.dictCrop == crop && p.dictCategory.isNotEmpty) {
        map[p.dictCategory] = (map[p.dictCategory] ?? 0) + 1;
      }
    }
    return map;
  }

  List<Post> _getReports(AppState state, String crop, String category) =>
      _getDictPosts(state)
          .where((p) => p.dictCrop == crop && p.dictCategory == category)
          .toList();

  void _navigate(String value) {
    setState(() {
      _path.add(value);
      _searchQuery = '';
      _searchCtrl.clear();
    });
  }

  void _goBack() {
    if (_path.isNotEmpty) {
      setState(() {
        _path.removeLast();
        _searchQuery = '';
        _searchCtrl.clear();
      });
    } else {
      Navigator.pop(context);
    }
  }

  String get _title {
    if (_path.isEmpty) return 'Official Guides';
    if (_path.length == 1) return _path[0];
    return _path[1];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // Header
              Container(
                color: AppColors.primaryDark,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 12),
                    child: Row(
                      children: [
                        if (_path.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white, size: 20),
                            onPressed: _goBack,
                          )
                        else
                          const SizedBox(width: 8),
                        const Icon(Icons.menu_book,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 4),
                        Text(_title,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
              // Search
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
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
              // Content
              Expanded(
                child: _buildContent(state),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(AppState state) {
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults(state);
    }
    if (_path.isEmpty) return _buildCrops(state);
    if (_path.length == 1) return _buildCategories(state, _path[0]);
    return _buildReportsList(state, _path[0], _path[1]);
  }

  Widget _buildSearchResults(AppState state) {
    final q = _searchQuery;
    final results = _getDictPosts(state).where((p) {
      final searchable =
          '${p.content.textShort} ${p.content.textFull} ${p.dictCrop} ${p.dictCategory} ${p.dictTags.join(' ')}'
              .toLowerCase();
      return searchable.contains(q);
    }).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text('No official guides found for "$_searchQuery"',
                style:
                    const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('⭐ ${results.length} official guide${results.length == 1 ? '' : 's'} found',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
        ),
        ...results.map((p) => _listTile(
              title: p.content.textShort,
              subtitle:
                  '${_cropIcons[p.dictCrop] ?? '📄'} ${p.dictCrop} → ${p.dictCategory}',
              leading: const Icon(Icons.star,
                  size: 18, color: AppColors.verifiedGold),
              onTap: () => _openDetail(p),
            )),
      ],
    );
  }

  Widget _buildCrops(AppState state) {
    final crops = _getCrops(state);
    final sortedCrops = crops.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Select a crop',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        ...sortedCrops.map((e) => _listTile(
              title: e.key,
              subtitle: '⭐ ${e.value} official guide${e.value == 1 ? '' : 's'}',
              leading: Text(_cropIcons[e.key] ?? '🌱',
                  style: const TextStyle(fontSize: 28)),
              trailing: _countBadge(e.value),
              onTap: () => _navigate(e.key),
            )),
      ],
    );
  }

  Widget _buildCategories(AppState state, String crop) {
    final cats = _getCategories(state, crop);
    final emoji = _cropIcons[crop] ?? '🌱';
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(crop,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        ...(cats.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
            .map((e) => _listTile(
                  title: e.key,
                  subtitle: '⭐ ${e.value} guide${e.value == 1 ? '' : 's'}',
                  leading: Icon(_catIcons[e.key] ?? Icons.folder_outlined,
                      size: 22, color: AppColors.primary),
                  trailing: _countBadge(e.value),
                  onTap: () => _navigate(e.key),
                )),
      ],
    );
  }

  Widget _buildReportsList(AppState state, String crop, String category) {
    final reports = _getReports(state, crop, category);
    final emoji = _cropIcons[crop] ?? '🌱';
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('$crop › $category',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary)),
            ],
          ),
        ),
        ...reports.map((p) => _listTile(
              title: p.content.textShort,
              subtitle: 'by ${p.userName}',
              leading: const Icon(Icons.star,
                  size: 18, color: AppColors.verifiedGold),
              onTap: () => _openDetail(p),
            )),
      ],
    );
  }

  Widget _listTile({
    required String title,
    required String subtitle,
    required Widget leading,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (trailing != null) trailing,
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.modeActive,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$count',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary)),
    );
  }

  void _openDetail(Post post) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => DetailScreen(post: post)));
  }
}
