import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class RichTextContent extends StatelessWidget {
  final String text;
  final List<String> images;
  final bool stripImages;

  const RichTextContent({
    super.key,
    required this.text,
    this.images = const [],
    this.stripImages = false,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = _parseRichText(text, images, stripImages);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static List<Widget> _parseRichText(String text, List<String> images, bool stripImages) {
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
            result.add(_buildImagePlaceholder(imgPath, idx + 1));
          }
        } catch (_) {
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

  static Widget _buildImagePlaceholder(String imgPath, int num) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '[Image $num: $imgPath]',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
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
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
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
