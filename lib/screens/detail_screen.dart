import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../providers/user_prefs.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';
import '../widgets/rich_text_content.dart';

class DetailScreen extends StatefulWidget {
  final Post post;
  const DetailScreen({super.key, required this.post});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late String _activeTab;
  // 一度でも表示したタブを記録（遅延レンダリング用）
  final Set<String> _loadedTabs = {};

  @override
  void initState() {
    super.initState();
    final available = _availableModes();
    // テキストモードが存在すれば優先、なければ viewMode、なければ最初のもの
    if (available.contains('text')) {
      _activeTab = 'text';
    } else if (available.contains(widget.post.viewMode)) {
      _activeTab = widget.post.viewMode;
    } else {
      _activeTab = available.isNotEmpty ? available.first : widget.post.viewMode;
    }
    _loadedTabs.add(_activeTab);
  }

  /// 実際にコンテンツが入力されているモードのみ返す
  List<String> _availableModes() {
    if (!widget.post.isOfficial) return [];
    final c = widget.post.content;
    return [
      if (c.textFull.isNotEmpty) 'text',
      if (c.textFullManual.isNotEmpty) 'manual',
      if (c.textFullVisual.isNotEmpty) 'visual',
    ];
  }

  String _getTextForMode(String mode) {
    final c = widget.post.content;
    return switch (mode) {
      'manual' => c.textFullManual,
      'visual' => c.textFullVisual,
      _ => c.textFull.isNotEmpty ? c.textFull : c.textShort,
    };
  }

  void _showEditSheet(BuildContext context, AppState state,
      {required String editorUid}) {
    final shortCtrl = TextEditingController(text: widget.post.content.textShort);
    final fullCtrl = TextEditingController(text: widget.post.content.textFull);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Edit Post',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: shortCtrl,
                  maxLength: 500,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Short description',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (widget.post.isOfficial && widget.post.content.textFull.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: fullCtrl,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Full text (text mode)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: () async {
                    final newText = shortCtrl.text.trim();
                    if (newText.isEmpty) return;
                    Navigator.pop(ctx);
                    final newContent = PostContent(
                      textShort: newText,
                      textFull: widget.post.isOfficial
                          ? fullCtrl.text.trim()
                          : widget.post.content.textFull,
                      textFullManual: widget.post.content.textFullManual,
                      textFullVisual: widget.post.content.textFullVisual,
                      imageLow: widget.post.content.imageLow,
                      imageHigh: widget.post.content.imageHigh,
                      images: widget.post.content.images,
                      steps: widget.post.content.steps,
                    );
                    await state.editPost(
                        widget.post.postId, newContent, editorUid);
                  },
                  child: const Text('Save',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminMenu(BuildContext context, AppState state, bool canDelete, bool canManageDict) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
      itemBuilder: (_) => [
        if (canManageDict) ...[
          PopupMenuItem(
            value: 'dict',
            child: Row(children: [
              Icon(
                widget.post.inDictionary ? Icons.menu_book : Icons.menu_book_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                widget.post.inDictionary ? 'Remove from dictionary' : 'Add to dictionary',
                style: const TextStyle(color: AppColors.primary),
              ),
            ]),
          ),
          PopupMenuItem(
            value: 'star',
            child: Row(children: [
              Icon(
                widget.post.isOfficial ? Icons.star : Icons.star_outline,
                size: 16,
                color: AppColors.verifiedGold,
              ),
              const SizedBox(width: 8),
              Text(
                widget.post.isOfficial ? 'Unstar' : 'Star (make official)',
                style: const TextStyle(color: AppColors.verifiedGold),
              ),
            ]),
          ),
        ],
        if (canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
              SizedBox(width: 8),
              Text('Delete post', style: TextStyle(color: AppColors.danger)),
            ]),
          ),
      ],
      onSelected: (v) async {
        if (v == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete post'),
              content: const Text('This post will be permanently deleted.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            await FirebaseService.deletePost(widget.post.postId);
            if (context.mounted) {
              state.removePost(widget.post.postId);
              Navigator.pop(context);
            }
          }
        } else if (v == 'dict') {
          await FirebaseService.updatePost(widget.post.postId, {
            'inDictionary': !widget.post.inDictionary,
          });
          if (context.mounted) await state.reloadPost(widget.post.postId);
        } else if (v == 'star') {
          await FirebaseService.updatePost(widget.post.postId, {
            'isOfficial': !widget.post.isOfficial,
          });
          if (context.mounted) await state.reloadPost(widget.post.postId);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final prefs = context.read<UserPrefs>();

    // AppState のメモリ上のリストから投稿が消えていたら自動で閉じる
    // Firestore ストリームは使わず追加読み取り 0
    final postExists = state.posts.any((p) => p.postId == widget.post.postId);
    if (!postExists && state.posts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('この投稿は削除されました')),
          );
        }
      });
    }

    final available = _availableModes();
    final showTabs = available.length > 1;
    // Own post, admin, or expert editing official posts
    final canEdit = widget.post.userId == prefs.userId ||
        prefs.isAdmin ||
        (widget.post.isOfficial && prefs.isExpert);
    final canDelete = widget.post.userId == prefs.userId || prefs.isAdmin;
    final canManageDict = prefs.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          if (widget.post.isOfficial) ...[
                            const Icon(Icons.star,
                                color: AppColors.verifiedGold, size: 16),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            widget.post.userName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ]),
                        Row(children: [
                          Text(
                            state.formatTime(widget.post.timestamp),
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.7)),
                          ),
                          if (widget.post.editedAt != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              'edited',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white.withOpacity(0.55)),
                            ),
                          ],
                          if (canEdit) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: Colors.white70, size: 18),
                              onPressed: () => _showEditSheet(
                                  context, state,
                                  editorUid: prefs.userId),
                              tooltip: 'Edit',
                            ),
                          ],
                          if (canDelete || canManageDict)
                            _buildAdminMenu(context, state, canDelete, canManageDict),
                        ]),
                      ],
                    ),
                  ),
                  // 複数モードがある場合のみタブを表示
                  if (showTabs) _buildModeTabs(available),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabs(List<String> modes) {
    const labels = {
      'text': 'Text',
      'manual': 'Text + Images',
      'visual': 'Visual',
    };
    const icons = {
      'text': Icons.text_snippet_outlined,
      'manual': Icons.auto_awesome_outlined,
      'visual': Icons.image_outlined,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: modes.map((mode) {
          final isActive = _activeTab == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _activeTab = mode;
                _loadedTabs.add(mode); // 初めてタップしたときに読み込み
              }),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  Icon(icons[mode],
                      size: 14,
                      color: isActive ? AppColors.primary : Colors.white70),
                  const SizedBox(height: 2),
                  Text(
                    labels[mode] ?? mode,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive ? AppColors.primary : Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    // 非公式投稿（ツイート）
    if (!widget.post.isOfficial) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.post.content.textShort,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textPrimary)),
          if (widget.post.content.imageLow.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Show low-res initially; tap to open high-res viewer
            _buildTappableImage(
              lowUrl: widget.post.content.imageLow,
              highUrl: widget.post.content.imageHigh,
            ),
          ],
        ],
      );
    }

    // 未ロードのタブはローディング表示（遅延レンダリング）
    if (!_loadedTabs.contains(_activeTab)) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: AppColors.primary),
      ));
    }

    final fullText = _getTextForMode(_activeTab);
    final imgs = widget.post.content.images;

    // 辞書に登録されている投稿は高解像度、それ以外は低解像度で表示
    final useHigh = widget.post.inDictionary;

    if (_activeTab == 'text') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichTextContent(text: fullText, images: imgs, useHighRes: useHigh),
        if (widget.post.content.steps.isNotEmpty) ...[
          const SizedBox(height: 12),
          StepsCard(steps: widget.post.content.steps),
        ],
      ]);
    } else if (_activeTab == 'manual') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichTextContent(text: fullText, images: imgs, useHighRes: useHigh),
        if (widget.post.content.steps.isNotEmpty) ...[
          const SizedBox(height: 12),
          StepsCard(steps: widget.post.content.steps),
        ],
      ]);
    } else {
      // visual
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (imgs.isNotEmpty)
          ...imgs.map((img) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildImage(img),
              ))
        else if (widget.post.content.imageLow.isNotEmpty)
          _buildImage(widget.post.content.imageHigh.isNotEmpty
              ? widget.post.content.imageHigh
              : widget.post.content.imageLow),
        if (widget.post.content.steps.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...widget.post.content.steps.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('${entry.key + 1}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(entry.value,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary))),
                    ],
                  ),
                ),
              ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            _stripMarkdown(fullText),
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ]);
    }
  }

  /// For tweets: shows low-res, opens full-res viewer on tap
  Widget _buildTappableImage({required String lowUrl, required String highUrl}) {
    return GestureDetector(
      onTap: () {
        final viewUrl = highUrl.isNotEmpty ? highUrl : lowUrl;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenImageViewer(url: viewUrl),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          _buildImage(lowUrl),
          if (highUrl.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 12),
                  SizedBox(width: 2),
                  Text('HD', style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64Data = url.split(',').last;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(base64Data),
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        );
      } catch (e) {
        debugPrint('[DetailScreen] base64 decode failed: $e');
        return const SizedBox.shrink();
      }
    }
    if (!url.startsWith('http')) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 200,
          color: const Color(0xFFF5F5F5),
          child: const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 200,
          color: const Color(0xFFF5F5F5),
          child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: AppColors.textSecondary, size: 40)),
        ),
      ),
    );
  }

  String _stripMarkdown(String text) {
    var result = text.replaceAll(RegExp(r'!\[\d+\]'), '');
    for (final prefix in ['## ', '### ', '- ']) {
      result = result.replaceAll(prefix, '');
    }
    return result
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
  }
}

// ─── Full-screen image viewer ────────────────────────────────────────────────

class _FullScreenImageViewer extends StatelessWidget {
  final String url;
  const _FullScreenImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: url.startsWith('data:image')
              ? _buildBase64(url)
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBase64(String url) {
    try {
      final data = url.split(',').last;
      return Image.memory(base64Decode(data), fit: BoxFit.contain);
    } catch (_) {
      return const Icon(Icons.broken_image_outlined, color: Colors.white, size: 60);
    }
  }
}
