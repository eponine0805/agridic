import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../utils/app_colors.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const PostCard({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final isExpert = post.userRole == 'expert';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: post.isOfficial ? AppColors.officialBg : AppColors.surface,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: const BorderSide(color: AppColors.divider, width: 1),
            left: post.isOfficial
                ? const BorderSide(color: AppColors.primary, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: isExpert ? AppColors.primary : AppColors.accent,
              child: Text(
                post.userName.isNotEmpty ? post.userName[0] : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (post.isOfficial)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.modeActive,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user, size: 12, color: AppColors.primaryDark),
                              SizedBox(width: 2),
                              Text('Official', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                            ],
                          ),
                        ),
                      Text(post.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (post.isVerified)
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: post.isOfficial ? AppColors.verifiedGold : AppColors.primary,
                        ),
                      Text('@${post.userRole}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const Text('•', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(state.formatTime(post.timestamp), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Text
                  Text(post.content.textShort, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                  // Image placeholder
                  if (post.content.imageLow.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(post.content.imageLow, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          const Text('Photo', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                  // CTA for official
                  if (post.isOfficial) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.modeActive,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_outlined, size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('Tap to read full report', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                  // Actions
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        color: AppColors.textSecondary,
                        onPressed: () {},
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.favorite_border, size: 16),
                        color: AppColors.textSecondary,
                        onPressed: () {},
                        visualDensity: VisualDensity.compact,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.flag_outlined, size: 14, color: AppColors.textSecondary),
                        label: Text(
                          'Report (${post.reports})',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        onPressed: () {
                          state.reportPost(post);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                post.isHidden
                                    ? 'Post hidden based on community reports.'
                                    : 'Reported. (${post.reports}/3)',
                              ),
                              backgroundColor: post.isHidden ? AppColors.danger : AppColors.accent,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
