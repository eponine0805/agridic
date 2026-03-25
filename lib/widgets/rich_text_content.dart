import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_colors.dart';

class RichTextContent extends StatelessWidget {
  final String text;
  final List<String> images;
  final bool stripImages;
  /// When true, displays images at full resolution using CachedNetworkImage.
  final bool useHighRes;

  const RichTextContent({
    super.key,
    required this.text,
    this.images = const [],
    this.stripImages = false,
    this.useHighRes = false,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = _parseRichText(text, images, stripImages, useHighRes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static List<Widget> _parseRichText(
      String text, List<String> images, bool stripImages, bool useHighRes) {
    if (text.isEmpty) return [];
    final List<Widget> result = [];

    for (final line in text.split('\n')) {
      final stripped = line.trim();

      if (stripped.isEmpty) {
        result.add(const SizedBox(height: 4));
      } else if (stripped.startsWith('### ')) {
        result.add(Text(
          stripped.substring(4),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ));
      } else if (stripped.startsWith('## ')) {
        result.add(const SizedBox(height: 4));
        result.add(Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.primaryLight, width: 2)),
          ),
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            stripped.substring(3),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ));
      } else if (stripped.startsWith('![') && stripped.contains(']')) {
        if (stripImages) continue;
        try {
          final endIdx = stripped.indexOf(']');
          final idxStr = stripped.substring(2, endIdx);
          final idx = int.parse(idxStr) - 1;
          if (idx >= 0 && idx < images.length) {
            final imgPath = images[idx];
            result.add(_buildNetworkImage(imgPath, highRes: useHighRes));
          }
        } catch (e) {
          debugPrint('[RichTextContent] image marker parse failed: $e');
          result.add(Text(stripped, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)));
        }
      } else if (stripped.startsWith('- ')) {
        result.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 7, right: 8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                stripped.substring(2),
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
          ],
        ));
      } else {
        result.add(Text(stripped, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)));
      }
    }
    return result;
  }

  static Widget _buildNetworkImage(String url, {bool highRes = true}) {
    // base64 data URL (fallback when Firebase Storage is not configured)
    if (url.startsWith('data:image')) {
      try {
        final base64Data = url.split(',').last;
        final height = highRes ? null : 120.0;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(base64Data),
              width: double.infinity,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        );
      } catch (e) {
        debugPrint('[RichTextContent] base64 decode failed: $e');
        return const SizedBox.shrink();
      }
    }
    if (!url.startsWith('http')) {
      return const SizedBox.shrink();
    }
    final height = highRes ? null : 120.0;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          memCacheHeight: highRes ? null : 240,
          placeholder: (_, __) => Container(
            height: height ?? 180,
            color: const Color(0xFFF5F5F5),
            child: const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2)),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 80,
            color: const Color(0xFFF5F5F5),
            child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }

}

class StepsCard extends StatelessWidget {
  final List<String> steps;

  const StepsCard({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.modeActive,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rtl, size: 16, color: AppColors.primaryDark),
              SizedBox(width: 6),
              Text(
                'Action Plan',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...steps.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
