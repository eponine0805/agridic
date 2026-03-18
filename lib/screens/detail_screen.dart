import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
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
    _activeMode = _availableModes.contains(preferred) ? preferred : (_availableModes.isNotEmpty ? _availableModes.first : 'text');
  }

  List<String> _computeAvailableModes() {
    if (!widget.post.isOfficial) return [];
    final hasText = widget.post.content.textFull.isNotEmpty || widget.post.content.textShort.isNotEmpty;
    final hasImages = widget.post.content.images.isNotEmpty;
    final hasManual = widget.post.content.textFullManual.isNotEmpty;
    final hasVisual = widget.post.content.textFullVisual.isNotEmpty;

    final modes = <String>[];
    if (hasText) modes.add('text');
    if (hasText && (hasImages || hasManual)) modes.add('manual');
    if (hasImages || hasVisual) modes.add('visual');
    if (modes.isEmpty) modes.add('text');
    return modes;
  }

  String _getTextForMode(String mode) {
    if (mode == 'manual' && widget.post.content.textFullManual.isNotEmpty) {
      return widget.post.content.textFullManual;
    } else if (mode == 'visual' && widget.post.content.textFullVisual.isNotEmpty) {
      return widget.post.content.textFullVisual;
    }
    return widget.post.content.textFull.isNotEmpty
        ? widget.post.content.textFull
        : widget.post.content.textShort;
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Icon(
                          post.isOfficial ? Icons.verified_user : Icons.person,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          post.userName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Text(
                      state.formatTime(post.timestamp),
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Mode selector (if multiple modes available)
          if (_availableModes.length > 1)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: _availableModes.map((mode) => _buildModeTab(mode)).toList(),
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
    final labels = {'text': 'Text Only', 'manual': 'Text + Image', 'visual': 'Image Main'};
    final icons = {'text': Icons.text_snippet_outlined, 'manual': Icons.auto_awesome_outlined, 'visual': Icons.image_outlined};

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
              Icon(icons[mode], size: 16, color: isActive ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(height: 2),
              Text(
                labels[mode] ?? mode,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
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
          Text(post.content.textShort, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
          if (post.content.imageLow.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(child: Text(post.content.imageLow, style: const TextStyle(fontSize: 64))),
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
          RichTextContent(text: fullText, images: const [], stripImages: true),
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
          RichTextContent(text: fullText, images: imgs),
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
              child: _buildImagePlaceholder(img),
            ))
          else if (post.content.imageLow.isNotEmpty)
            Center(child: Text(post.content.imageLow, style: const TextStyle(fontSize: 64))),
          if (post.content.steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...post.content.steps.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                ],
              ),
            )),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              _stripMarkdown(fullText),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ],
      );
    }
  }

  Widget _buildImagePlaceholder(String imgPath) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, size: 24, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(imgPath, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }

  String _stripMarkdown(String text) {
    var result = text.replaceAll(RegExp(r'!\[\d+\]'), '');
    for (final prefix in ['## ', '### ', '- ']) {
      result = result.replaceAll(prefix, '');
    }
    return result.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join('\n');
  }
}
