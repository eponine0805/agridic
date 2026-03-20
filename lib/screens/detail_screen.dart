import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../utils/app_colors.dart';
import '../widgets/rich_text_content.dart';

class DetailScreen extends StatelessWidget {
  final Post post;

  const DetailScreen({super.key, required this.post});

  String _activeMode() {
    final m = post.viewMode;
    return m.isNotEmpty ? m : 'text';
  }

  String _getTextForMode(String mode) {
    final content = post.content;
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
                          color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content — rendered in the format the author chose, no switching
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

  Widget _buildContent() {
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

    final mode = _activeMode();
    final fullText = _getTextForMode(mode);
    final imgs = post.content.images;

    if (mode == 'text') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichTextContent(text: fullText, images: imgs, useHighRes: false),
          if (post.content.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            StepsCard(steps: post.content.steps),
          ],
        ],
      );
    } else if (mode == 'manual') {
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
      // visual mode — image-based report
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
      } catch (_) {
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
