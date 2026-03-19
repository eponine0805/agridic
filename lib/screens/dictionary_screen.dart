import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../services/firebase_service.dart';
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
    'Rice': '🌾',
    'Wheat': '🌾',
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
              Container(
                color: AppColors.primaryDark,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      children: [
                        if (_path.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            onPressed: _goBack,
                          )
                        else
                          const SizedBox(width: 8),
                        const Icon(Icons.menu_book, color: Colors.white, size: 22),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(_title,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                        // Manage button
                        TextButton.icon(
                          onPressed: () => _openManage(context, state),
                          icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 18),
                          label: const Text('Manage',
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    if (_searchQuery.isNotEmpty) return _buildSearchResults(state);
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
            const Icon(Icons.search_off, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text('No official guides found for "$_searchQuery"',
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('⭐ ${results.length} official guide${results.length == 1 ? '' : 's'} found',
              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
        ...results.map((p) => _listTile(
              title: p.content.textShort,
              subtitle: '${_cropIcons[p.dictCrop] ?? '📄'} ${p.dictCrop} → ${p.dictCategory}',
              leading: const Icon(Icons.star, size: 18, color: AppColors.verifiedGold),
              onTap: () => _openDetail(p),
            )),
      ],
    );
  }

  Widget _buildCrops(AppState state) {
    final crops = _getCrops(state);
    if (crops.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text('No guides in dictionary yet',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 8),
            const Text('Tap Manage to add official reports',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }
    final sortedCrops = crops.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Select a crop',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        ...sortedCrops.map((e) => _listTile(
              title: e.key,
              subtitle: '⭐ ${e.value} official guide${e.value == 1 ? '' : 's'}',
              leading: Text(_cropIcons[e.key] ?? '🌱', style: const TextStyle(fontSize: 28)),
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
              Text(crop, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            ],
          ),
        ),
        ...reports.map((p) => _listTile(
              title: p.content.textShort,
              subtitle: 'by ${p.userName}',
              leading: const Icon(Icons.star, size: 18, color: AppColors.verifiedGold),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (trailing != null) trailing,
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.modeActive,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$count',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
    );
  }

  void _openDetail(Post post) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(post: post)));
  }

  // ─── 管理画面 ────────────────────────────────────────────────────────────

  void _openManage(BuildContext context, AppState state) {
    final officialPosts = state.posts.where((p) => p.isOfficial && !p.isHidden).toList()
      ..sort((a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Dictionary Settings',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text('Tap a report to configure its dictionary settings.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
              Expanded(
                child: officialPosts.isEmpty
                    ? const Center(child: Text('No official reports yet'))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: officialPosts.length,
                        itemBuilder: (_, i) {
                          final post = officialPosts[i];
                          return ListTile(
                            leading: Icon(
                              post.inDictionary ? Icons.menu_book : Icons.menu_book_outlined,
                              color: post.inDictionary ? AppColors.primary : AppColors.textSecondary,
                              size: 22,
                            ),
                            title: Text(post.content.textShort,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: post.inDictionary
                                ? Text('${post.dictCrop} › ${post.dictCategory}',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.primary))
                                : const Text('Not in dictionary',
                                    style: TextStyle(
                                        fontSize: 11, color: AppColors.textSecondary)),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () {
                              Navigator.pop(ctx);
                              _openConfigSheet(context, state, post);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openConfigSheet(BuildContext context, AppState state, Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DictConfigSheet(post: post, state: state),
    );
  }
}

// ─── 辞書設定シート ──────────────────────────────────────────────────────────

class _DictConfigSheet extends StatefulWidget {
  final Post post;
  final AppState state;
  const _DictConfigSheet({required this.post, required this.state});

  @override
  State<_DictConfigSheet> createState() => __DictConfigSheetState();
}

class __DictConfigSheetState extends State<_DictConfigSheet> {
  late bool _inDictionary;
  late final TextEditingController _cropCtrl;
  late final TextEditingController _catCtrl;
  late final TextEditingController _tagCtrl;
  late final List<String> _tags;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _inDictionary = widget.post.inDictionary;
    _cropCtrl = TextEditingController(text: widget.post.dictCrop);
    _catCtrl = TextEditingController(text: widget.post.dictCategory);
    _tagCtrl = TextEditingController();
    _tags = List.from(widget.post.dictTags);
  }

  @override
  void dispose() {
    _cropCtrl.dispose();
    _catCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  // Existing crops and categories from all dict posts
  List<String> _existingCrops() => widget.state.posts
      .where((p) => p.isOfficial && p.dictCrop.isNotEmpty)
      .map((p) => p.dictCrop)
      .toSet()
      .toList()
    ..sort();

  List<String> _existingCategories() => widget.state.posts
      .where((p) => p.isOfficial && p.dictCategory.isNotEmpty)
      .map((p) => p.dictCategory)
      .toSet()
      .toList()
    ..sort();

  void _addTag() {
    final tag = _tagCtrl.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseService.updatePost(widget.post.postId, {
        'inDictionary': _inDictionary,
        'dictCrop': _cropCtrl.text.trim(),
        'dictCategory': _catCtrl.text.trim(),
        'dictTags': _tags,
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final existingCrops = _existingCrops();
    final existingCats = _existingCategories();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.post.content.textShort,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // In dictionary toggle
              Row(
                children: [
                  const Icon(Icons.menu_book_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Add to Official Dictionary',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  Switch(
                    value: _inDictionary,
                    onChanged: (v) => setState(() => _inDictionary = v),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              if (_inDictionary) ...[
                const Divider(height: 24, color: AppColors.divider),
                // Crop
                const Text('Crop', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _cropCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Maize, Tomato, Rice…',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
                if (existingCrops.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: existingCrops.map((c) => ActionChip(
                      label: Text(c, style: const TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _cropCtrl.text = c),
                      backgroundColor: AppColors.modeActive,
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                // Category
                const Text('Category', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _catCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Growing Guide, Pests & Diseases…',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
                if (existingCats.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: existingCats.map((c) => ActionChip(
                      label: Text(c, style: const TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _catCtrl.text = c),
                      backgroundColor: AppColors.modeActive,
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                // Tags
                const Text('Keywords / Tags', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (_tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _tags.map((t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      onDeleted: () => setState(() => _tags.remove(t)),
                      backgroundColor: AppColors.modeActive,
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    )).toList(),
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagCtrl,
                        decoration: InputDecoration(
                          hintText: 'Add keyword + Enter',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.primary),
                      onPressed: _addTag,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
