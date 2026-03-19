import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../models/report_reason.dart';
import '../providers/app_state.dart';
import '../providers/user_prefs.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';
import '../screens/comment_sheet.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final userPrefs = context.watch<UserPrefs>();
    final isOfficial = post.isOfficial;
    final isLiked = post.likedBy.contains(userPrefs.userId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isOfficial ? AppColors.officialBg : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: isOfficial
              ? const Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(post: post),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                post.userName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOfficial) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.star,
                                  color: AppColors.verifiedGold, size: 14),
                              const SizedBox(width: 2),
                              const Text('Official',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.verifiedGold,
                                      fontWeight: FontWeight.bold)),
                            ] else if (post.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  color: AppColors.primary, size: 14),
                            ],
                            const SizedBox(width: 6),
                            Text(
                              state.formatTime(post.timestamp),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Text(
                          '@${post.userRole}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Three dots menu
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          size: 16, color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined,
                                  size: 16, color: AppColors.danger),
                              SizedBox(width: 8),
                              Text('Report post',
                                  style: TextStyle(color: AppColors.danger)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == 'report') {
                          _showReportDialog(context, userPrefs.userId);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Content
              Text(
                post.content.textShort,
                style: const TextStyle(fontSize: 14),
                maxLines: isOfficial ? 2 : 5,
                overflow: TextOverflow.ellipsis,
              ),
              // Thumbnail image
              if (post.content.imageLow.isNotEmpty) ...[
                const SizedBox(height: 8),
                _Thumbnail(url: post.content.imageLow),
              ],
              // Official CTA
              if (isOfficial) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.menu_book_outlined,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    const Text('Read more →',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500)),
                    if (post.dictCrop.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _Tag(label: post.dictCrop),
                    ],
                    if (post.dictCategory.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      _Tag(label: post.dictCategory),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 6),
              const Divider(height: 1, color: AppColors.divider),
              // Action bar
              Row(
                children: [
                  _ActionBtn(
                    icon: Icons.chat_bubble_outline,
                    label: '',
                    color: AppColors.textSecondary,
                    onTap: () => _openComments(context),
                  ),
                  const SizedBox(width: 4),
                  _ActionBtn(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: post.likes > 0 ? '${post.likes}' : '',
                    color:
                        isLiked ? AppColors.danger : AppColors.textSecondary,
                    onTap: () =>
                        state.toggleLike(post.postId, userPrefs.userId),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<AppState>()),
          ChangeNotifierProvider.value(value: context.read<UserPrefs>()),
        ],
        child: CommentSheet(post: post),
      ),
    );
  }

  Future<void> _showReportDialog(
      BuildContext context, String userId) async {
    final already = await FirebaseService.hasReported(post.postId, userId);
    if (!context.mounted) return;
    if (already) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You have already reported this post'),
        backgroundColor: AppColors.textSecondary,
      ));
      return;
    }
    ReportReason? selected;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Report this post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ReportReason.values
                .map((r) => RadioListTile<ReportReason>(
                      title: Text(r.label),
                      value: r,
                      groupValue: selected,
                      onChanged: (v) => setS(() => selected = v),
                      activeColor: AppColors.primary,
                      dense: true,
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white),
              onPressed: selected == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await FirebaseService.reportPost(
                          post.postId, userId, selected!.name);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                        content: Text('Reported. Thank you for your feedback.'),
                        backgroundColor: AppColors.textSecondary,
                      ));
                    },
              child: const Text('Report'),
            ),
          ],
        );
      }),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Post post;
  const _Avatar({required this.post});

  @override
  Widget build(BuildContext context) {
    final isExpert = post.userRole == 'expert';
    return CircleAvatar(
      radius: 18,
      backgroundColor: isExpert ? AppColors.primary : AppColors.accent,
      child: Text(
        post.userName.isNotEmpty ? post.userName[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;
  const _Thumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    if (!url.startsWith('http')) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_outlined,
                  color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 6),
              Text(url,
                  style: const TextStyle(
                      fontSize: 24, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 120,
          color: const Color(0xFFF5F5F5),
          child: const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 120,
          color: const Color(0xFFF5F5F5),
          child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.modeActive,
        borderRadius: BorderRadius.circular(4),
        border:
            Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10, color: AppColors.primaryDark)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
