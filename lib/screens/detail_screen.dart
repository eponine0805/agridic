import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../providers/user_prefs.dart';
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

  void _showEditSheet(BuildContext context, AppState state) {
    final controller =
        TextEditingController(text: widget.post.content.textShort);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('投稿を編集',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 500,
                maxLines: 5,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '内容を入力...',
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                onPressed: () async {
                  final newText = controller.text.trim();
                  if (newText.isEmpty) return;
                  Navigator.pop(ctx);
                  final newContent = PostContent(
                    textShort: newText,
                    textFull: widget.post.content.textFull,
                    textFullManual: widget.post.content.textFullManual,
                    textFullVisual: widget.post.content.textFullVisual,
                    imageLow: widget.post.content.imageLow,
                    imageHigh: widget.post.content.imageHigh,
                    images: widget.post.content.images,
                    steps: widget.post.content.steps,
                  );
                  await state.editPost(widget.post.postId, newContent);
                },
                child: const Text('保存',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final prefs = context.read<UserPrefs>();
    final available = _availableModes();
    final showTabs = available.length > 1;
    final canEdit = !widget.post.isOfficial &&
        widget.post.userId == prefs.userId;

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
                          if (canEdit) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: Colors.white70, size: 18),
                              onPressed: () =>
                                  _showEditSheet(context, state),
                              tooltip: '編集',
                            ),
                          ],
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
            _buildImage(widget.post.content.imageHigh.isNotEmpty
                ? widget.post.content.imageHigh
                : widget.post.content.imageLow),
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

    if (_activeTab == 'text') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichTextContent(text: fullText, images: imgs, useHighRes: false),
        if (widget.post.content.steps.isNotEmpty) ...[
          const SizedBox(height: 12),
          StepsCard(steps: widget.post.content.steps),
        ],
      ]);
    } else if (_activeTab == 'manual') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichTextContent(text: fullText, images: imgs, useHighRes: true),
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
