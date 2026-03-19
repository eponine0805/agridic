import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../providers/connectivity_prefs.dart';
import '../utils/app_colors.dart';
import '../widgets/rich_text_content.dart';

class DetailScreen extends StatefulWidget {
  final Post post;

  const DetailScreen({super.key, required this.post});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late String _activeMode;
  late List<String> _availableModes;

  @override
  void initState() {
    super.initState();
    _availableModes = _computeAvailableModes();
    final preferred = widget.post.viewMode;
    _activeMode = _availableModes.contains(preferred)
        ? preferred
        : (_availableModes.isNotEmpty ? _availableModes.first : 'text');
  }

  List<String> _computeAvailableModes() {
    if (!widget.post.isOfficial) return [];
    final content = widget.post.content;
    final hasText =
        content.textFull.isNotEmpty || content.textShort.isNotEmpty;
    final hasImages = content.images.isNotEmpty;
    final hasManual = content.textFullManual.isNotEmpty;
    final hasVisual = content.textFullVisual.isNotEmpty;

    // ConnectivityPrefs でフィルタリング
    final connPrefs = context.read<ConnectivityPrefs>();

    final allModes = <String>[];
    if (hasText) allModes.add('text');
    if (hasText && (hasImages || hasManual)) allModes.add('manual');
    if (hasImages || hasVisual) allModes.add('visual');
    if (allModes.isEmpty) allModes.add('text');

    // ユーザーが有効にしているモードのみ残す（textは常に有効）
    final filtered =
        allModes.where((m) => connPrefs.isEnabled(m)).toList();
    return filtered.isEmpty ? ['text'] : filtered;
  }

  String _getTextForMode(String mode) {
    final content = widget.post.content;
    if (mode == 'manual' && content.textFullManual.isNotEmpty) {
      return content.textFullManual;
    } else if (mode == 'visual' && content.textFullVisual.isNotEmpty) {
      return content.textFullVisual;
    }
    return content.textFull.isNotEmpty ? content.textFull : content.textShort;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final post = widget.post;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        if (post.isOfficial) ...[
                          const Icon(Icons.star,
                              color: AppColors.verifiedGold, size: 16),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          post.userName,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ],
                    ),
                    Text(
                      state.formatTime(post.timestamp),
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Mode selector
          if (_availableModes.length > 1)
            Container(
              color: AppColors.surface,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children:
                    _availableModes.map((mode) => _buildModeTab(mode)).toList(),
              ),
            ),
          // Content
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

  Widget _buildModeTab(String mode) {
    final isActive = _activeMode == mode;
    final labels = {
      'text': 'テキスト\n(軽い)',
      'manual': 'テキスト+画像\n(標準)',
      'visual': '画像メイン\n(高画質)',
    };
    final icons = {
      'text': Icons.text_snippet_outlined,
      'manual': Icons.auto_awesome_outlined,
      'visual': Icons.image_outlined,
    };

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeMode = mode),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.modeActive : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.divider,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icons[mode],
                  size: 16,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.textSecondary),
              const SizedBox(height: 2),
              Text(
                labels[mode] ?? mode,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final post = widget.post;
    if (!post.isOfficial) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.content.textShort,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textPrimary)),
          if (post.content.imageLow.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildImage(post.content.imageHigh.isNotEmpty
                ? post.content.imageHigh
                : post.content.imageLow),
          ],
        ],
      );
    }

    final fullText = _getTextForMode(_activeMode);
    final imgs = post.content.images;

    if (_activeMode == 'text') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichTextContent(
              text: fullText, images: const [], stripImages: true),
          if (post.content.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            StepsCard(steps: post.content.steps),
          ],
        ],
      );
    } else if (_activeMode == 'manual') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichTextContent(text: fullText, images: imgs, useHighRes: true),
          if (post.content.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            StepsCard(steps: post.content.steps),
          ],
        ],
      );
    } else {
      // visual mode
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imgs.isNotEmpty)
            ...imgs.map((img) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildImage(img),
                ))
          else if (post.content.imageLow.isNotEmpty)
            _buildImage(post.content.imageHigh.isNotEmpty
                ? post.content.imageHigh
                : post.content.imageLow),
          if (post.content.steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...post.content.steps.asMap().entries.map(
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
        ],
      );
    }
  }

  Widget _buildImage(String url) {
    if (!url.startsWith('http')) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.image_outlined,
                size: 24, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(url,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      );
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
